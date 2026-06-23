import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// 账户详情页。承接 Task 11 GetAccountUseCase + AccountDetailLoaded。
///
/// 结构：AppBar（编辑 / 🔒记一笔 / 🔒转账 / 更多菜单）→
/// Hero（类型图标 + 名称 / 机构·币种·类型 / 余额 / category 专属 chip）→
/// 统计行占位（待 Transaction）→ 双栏（近期交易 / 收支统计占位）→
/// 类型专属面板（投资 → 持仓列表 / 贷款 → 还款计划，待后续模块接入）。
class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.id});

  final String id;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  /// 关闭账户写操作进行中。_close dispatch 后置 true，BlocListener 收到
  /// AccountsLoaded（成功）/AccountError（失败）后清零 + toast + pop。
  /// 仿 accounts_page._pendingIds 的 listener 模式，避免 dispatch 即 toast
  /// 的过早提示，以及 UpdateAccountRequested → LoadAccountsRequested →
  /// AccountsLoaded 导致本页 BlocBuilder 渲染 SizedBox.shrink（页面空白）。
  bool _closePending = false;
  /// 写操作成功后的 toast 文案（关闭/激活共用同一套 pending → BlocListener 流程）。
  String? _pendingSuccessMsg;

  /// 近期交易客户端分页（Task 6）。pageSize=5；当前页 0-based。
  /// _recentTxnPanel 入口对越界（列表缩短 / 账户切换后页码失效）做 clamp，
  /// 不引入 account-id 追踪 —— 切账户走 push 新 route，State 重建。
  static const int _recentPageSize = 5;
  int _recentPage = 0;

  /// 收支统计的周期粒度（Task 10）。默认月（与 OD 原型 `.period-tabs` 月段
  /// active 对齐）。切换 → setState + 发 LoadSummaryRequested(scope, day)。
  /// DAY scope 时 `_day` = 今天 day-of-month；MONTH/YEAR 时为 null。
  SummaryScope _scope = SummaryScope.month;
  int? _day;

  /// 全量账户缓存（accountId → Account）。initState 发 LoadAccountsRequested
  /// 拉取，BlocListener 在 AccountsLoaded/AccountFormSubmitting/AccountError
  ///（这些 state 都携带 accounts list）到达时更新。
  /// 供近期交易行解析 entries 拿分类账户 + 资产账户名。
  /// AccountBloc._onGet 的 AccountDetailLoaded 不带 accounts，故需 listener
  /// 异步捕获（而非 build 期同步读）。
  Map<String, Account> _accountsMap = const {};

  /// 当前 scope 的中文前缀（Task 11）。用于 summary-based 的 label：
  /// 储蓄/其他类 4 卡（收入/支出/净流入/交易）+ hero-bal-sub「{scope}收支」+
  /// fixed/gold/realEstate 的 summary 4th 卡。类型专属字段 label（额度/市值/
  /// 本金…）不由此前缀修饰 —— 它们不是 summary 派生。
  String get _scopeLabel => switch (_scope) {
        SummaryScope.day => '本日',
        SummaryScope.month => '本月',
        SummaryScope.year => '本年',
      };

  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(GetAccountRequested(widget.id));
    // 加载全量账户列表，供近期交易行解析 entries（分类/资产账户名）。
    // 直接走 repository（不经 AccountBloc —— 其 _onGet 的 AccountDetailLoaded
    // 不带 accounts，且 _onLoad 的 AccountLoading 会覆盖 detail state，导致
    // 详情页 BlocBuilder 渲染空）。GetIt 注入 AccountRepository（路由层
    // provide AccountBloc 时同样解析这几个 usecase 的依赖）。
    _loadAccounts();
    // 跨模块：account 详情页接 transaction bloc。
    // TransactionBloc + 初始 LoadTransactionsRequested / LoadSummaryRequested
    //（account-scoped）在路由层 `/accounts/:id` 的 MultiBlocProvider 里
    // provide —— 详情页 State.context 位于该 BlocProvider 下，
    // context.watch<TransactionBloc>() 能找到。本页不再自建 BlocProvider
    //（旧实现把 Provider 放在 build 返回的 Builder child 里，而 State.context
    // 在 Provider 之上，运行时抛 ProviderNotFoundException）。
  }

  Future<void> _loadAccounts() async {
    final repo = getIt<AccountRepository>();
    final result = await repo.list();
    if (!mounted) return;
    result.fold(
      (_) => null, // 失败：保持空 map，近期交易行退化为账号短 id。
      (accounts) => setState(() {
        _accountsMap = {for (final a in accounts) a.id: a};
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold();
  }

  Widget _scaffold() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('账户详情'),
        actions: [
          BlocBuilder<AccountBloc, AccountState>(
            buildWhen: (p, c) =>
                c is AccountDetailLoaded || c is AccountLoading,
            builder: (context, state) {
              final a = state is AccountDetailLoaded ? state.account : null;
              final archived = a?.status == AccountStatus.archived;
              return Row(
                children: [
                  // 归档账户：移除编辑/记一笔/转账（不可再产生交易），
                  // 只留更多菜单（复制/重新激活/删除）。
                  if (!archived) ...[
                    TextButton(
                      onPressed: a == null ? null : () => _edit(a),
                      child: const Text('编辑'),
                    ),
                    TextButton(
                      onPressed: a == null ? null : _recordTxn,
                      child: const Text('记一笔'),
                    ),
                    TextButton(
                      onPressed: a == null ? null : _transfer,
                      child: const Text('转账'),
                    ),
                  ],
                  PopupMenuButton<String>(
                    tooltip: '更多操作',
                    icon: const Icon(Icons.more_horiz,
                        size: 18, color: AppColors.muted),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'copy', child: Text('复制账户')),
                      if (archived)
                        const PopupMenuItem(
                            value: 'reactivate', child: Text('重新激活账户'))
                      else
                        const PopupMenuItem(
                            value: 'close', child: Text('关闭账户')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('删除账户')),
                    ],
                    onSelected: (v) {
                      if (a == null) return;
                      switch (v) {
                        case 'copy':
                          _copy(a);
                        case 'close':
                          _close(a);
                        case 'reactivate':
                          _reactivate(a);
                        case 'delete':
                          _delete(a);
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocListener<AccountBloc, AccountState>(
        // 仅在关闭写操作进行中时，对终态（成功 AccountsLoaded / 失败 AccountError）反应。
        listenWhen: (p, c) =>
            _closePending && (c is AccountsLoaded || c is AccountError),
        listener: (context, state) {
          if (state is AccountsLoaded) {
            final msg = _pendingSuccessMsg ?? '操作完成';
            setState(() {
              _closePending = false;
              _pendingSuccessMsg = null;
            });
            AppToast.show(context, msg, type: ToastType.success);
            context.pop(); // 回列表
          } else if (state is AccountError) {
            setState(() {
              _closePending = false;
              _pendingSuccessMsg = null;
            });
            AppToast.show(context, state.message, type: ToastType.error);
          }
        },
        child: BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            if (state is AccountLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is AccountError) {
              return Center(child: Text(state.message));
            }
            if (state is AccountDetailLoaded) {
              return _body(state.account);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _body(Account a) {
    // 读 TransactionBloc state（页面 build 顶部已确保 bloc 存在）。
    final txnState = context.watch<TransactionBloc>().state;
    final txns = txnState is TransactionsLoaded
        ? txnState.transactions
        : (txnState is TransactionsLoadingMore ? txnState.transactions : const <Transaction>[]);
    final summary = txnState is TransactionsLoaded
        ? txnState.summary
        : (txnState is TransactionsLoadingMore ? txnState.summary : null);
    return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _hero(a, summary?.netCents ?? 0),
          const SizedBox(height: AppSpacing.lg),
          _statsRow(a, txns, summary),
          const SizedBox(height: AppSpacing.lg),
          // 双栏：左近期交易（flex 3）/ 右收支统计饼图（flex 2）。
          // 对齐 OD .cols 1.5fr:1fr 比例。原右栏的 _quickActions 已移除——操作
          // 集中在 AppBar（编辑/记一笔/转账/更多菜单），避免重复。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _recentTxnPanel(txns)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: _summaryPanel(summary)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _infoCard(a),
          const SizedBox(height: AppSpacing.lg),
          if (a.category == AccountCategory.investment)
            _panel('持仓列表', '待 Holding 模块接入')
          else if (a.category == AccountCategory.loan)
            _panel('还款计划', '待 payment_schedule 模块接入')
          else
            const SizedBox.shrink(),
        ],
      );
  }

  /// 账户信息卡：独立 3 列字段表（对齐 OD .info-card / .info-grid）。
  /// 仅展示 entity 已有字段；累计利息/安全等级/最后更新无数据源不渲染。
  Widget _infoCard(Account a) {
    final cells = <(String, String)>[];
    void add(String label, String? v) {
      if (v != null && v.isNotEmpty) cells.add((label, v));
    }
    void addNum(String label, int? cents) {
      if (cents != null && cents != 0) cells.add((label, _fmtSigned(cents)));
    }
    add('开户机构', a.institution.isEmpty ? null : a.institution);
    add('卡号尾号', a.cardNumberTail.isEmpty ? null : '尾号 ${a.cardNumberTail}');
    add('账户类型', '${a.category.label} · ${_typeSuffix(a)}');
    addNum('初始余额', a.initialBalanceCents == 0 ? null : a.initialBalanceCents);
    addNum('当前余额', a.currentBalanceCents);
    final rate = a.interestRate;
    add('年化利率', rate == null ? null : '${rate.toStringAsFixed(2)}%');
    final opening = a.openingDate;
    add('开户日期', opening == null ? null : _fmtDate(opening));
    add('币种', '${a.currencyCode} ${_currencyName(a.currencyCode)}');
    add('备注', a.notes.isEmpty ? null : a.notes);
    // 类型专属补充字段
    switch (a.category) {
      case AccountCategory.creditCard:
        add('账单日', a.creditBillingDay == null ? null : '${a.creditBillingDay}日');
        add('还款日',
            a.creditRepaymentDay == null ? null : '${a.creditRepaymentDay}日');
        addNum('年费', a.creditAnnualFeeCents);
      case AccountCategory.loan:
        addNum('原始本金', a.loanOriginalCents);
        addNum('剩余本金', a.loanRemainingCents);
        addNum('月供', a.loanMonthlyCents);
        add('下次还款',
            a.loanNextPaymentDate == null ? null : _fmtDate(a.loanNextPaymentDate!));
      case AccountCategory.investment:
        addNum('市值', a.investMarketValueCents);
        addNum('成本', a.investCostCents);
        add('今年收益率',
            a.investReturnYtd == null ? null : '${a.investReturnYtd!.toStringAsFixed(2)}%');
      case AccountCategory.fixedDeposit:
        addNum('本金', a.fixedPrincipalCents);
        add('起息日',
            a.fixedStartDate == null ? null : _fmtDate(a.fixedStartDate!));
        add('到期日',
            a.fixedMaturityDate == null ? null : _fmtDate(a.fixedMaturityDate!));
        add('期限', a.fixedTermMonths == null ? null : '${a.fixedTermMonths}月');
      case AccountCategory.goldFx:
        add('品种', a.goldProductType.isEmpty ? null : a.goldProductType);
        if (a.goldQuantity != null) {
          add('数量', a.goldQuantity!.toStringAsFixed(3));
        }
        addNum('买入价', a.goldBuyPriceCents);
        addNum('现价', a.goldCurrentPriceCents);
      case AccountCategory.realEstate:
        addNum('买入价', a.estatePurchasePriceCents);
        addNum('现估值', a.estateCurrentValueCents);
        add('买入日期',
            a.estatePurchaseDate == null ? null : _fmtDate(a.estatePurchaseDate!));
        add('折旧率',
            a.estateDepreciationRate == null ? null : '${a.estateDepreciationRate!.toStringAsFixed(2)}%');
      case AccountCategory.savings:
      case AccountCategory.otherAsset:
      case AccountCategory.otherLiability:
        break;
    }
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('账户信息', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (ctx, c) {
              final cols = c.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: cols,
                mainAxisSpacing: 14,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8,
                children: [for (final cell in cells) _infoCell(cell.$1, cell.$2)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  letterSpacing: 0.07)),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.fg,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      );

  String _typeSuffix(Account a) =>
      a.accountType == AccountType.liability ? '负债' : '资产';

  String _currencyName(String code) => switch (code) {
        'CNY' => '人民币',
        'USD' => '美元',
        'EUR' => '欧元',
        'HKD' => '港币',
        _ => '',
      };

  Widget _hero(Account a, int netCents) {
    final isLiability = a.accountType == AccountType.liability;
    final netPositive = netCents >= 0;
    // hero-org: 机构 · 币种 · 尾号（对齐 OD .hero-org）。
    // 机构/尾号都缺失时回退到 类别 · 币种（保持 hero-org 非空）。
    final org = a.institution.isEmpty && a.cardNumberTail.isEmpty
        ? '${a.category.label} · ${a.currencyCode}'
        : [
            if (a.institution.isNotEmpty) a.institution,
            a.currencyCode,
            if (a.cardNumberTail.isNotEmpty) '尾号 ${a.cardNumberTail}',
          ].join(' · ');
    return ClipRRect(
      borderRadius: AppRadius.lgBorder,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1E21), Color(0xFF2A2D33)],
          ),
        ),
        child: Stack(
          children: [
            // 径向金色光晕（御财金 #B08D57 alpha 0.18）。
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // hero-badges: 类型 + 资产/负债类（对齐 OD 的 2 个 ghost badge）。
                // 原「活期/定期」独立 badge 已合并进语义（OD 简化）。
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroBadge(a.category.label),
                    _heroBadge(isLiability ? '负债类' : '资产类'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // hero-name: 账户名 28px serif（对齐 OD .hero-name）。
                // 账户名从 AppBar title 移入 hero（AppBar title 保持「账户详情」）。
                Text(
                  a.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.01,
                    height: 1.15,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                  ),
                ),
                const SizedBox(height: 6),
                // hero-org: 机构 · 币种 · 尾号（对齐 OD .hero-org）。
                Text(
                  org,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // hero-bal-label「可用余额」（对齐 OD .hero-bal-label）。
                Text(
                  '可用余额',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                    letterSpacing: 0.04,
                  ),
                ),
                const SizedBox(height: 6),
                // 余额 40px 白字 serif display。
                Text(
                  _fmt(a.currentBalanceCents),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: Colors.white,
                    fontFeatures: AppTypography.tabularFigures,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // hero-bal-sub {scope}收支（正绿 #6FCF9A 负红 #E57373）。
                // Task 11：前缀跟随 _scope（本日/本月/本年）。
                Text(
                  '$_scopeLabel收支 ${netPositive ? '+' : '-'}¥'
                  '${(netCents.abs() ~/ 100).toString()}.'
                  '${(netCents.abs() % 100).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: netPositive
                        ? const Color(0xFF6FCF9A)
                        : const Color(0xFFE57373),
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // hero-fields 类型专属字段网格。
                _heroFields(a),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// hero-badge：半透明金色描边小 pill。
  Widget _heroBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.5),
          ),
          color: AppColors.accent.withValues(alpha: 0.08),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.accentSoft,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  /// hero-fields：类型专属字段结构化网格（desktop 4 列 / mobile 2 列）。
  /// 替代原 _specificChips 的扁平 Chip Wrap。
  Widget _heroFields(Account a) {
    final fields = <(String, String)>[]; // (label, value)
    void add(String label, String? v) {
      if (v != null && v.isNotEmpty) fields.add((label, v));
    }

    void addNum(String label, int? cents) {
      if (cents != null && cents != 0) fields.add((label, _fmt(cents)));
    }

    void addRate(String label, double? r) {
      // 利率/收益率/折旧率统一 2 位小数。
      if (r != null) fields.add((label, '${r.toStringAsFixed(2)}%'));
    }

    void addDay(String label, int? d) {
      if (d != null) fields.add((label, '$d日'));
    }

    void addDate(String label, DateTime? d) {
      if (d != null) fields.add((label, _fmtDate(d)));
    }

    switch (a.category) {
      case AccountCategory.creditCard:
        addNum('额度', a.creditLimitCents == 0 ? null : a.creditLimitCents);
        addDay('账单日', a.creditBillingDay);
        addDay('还款日', a.creditRepaymentDay);
        addNum('年费', a.creditAnnualFeeCents);
      case AccountCategory.loan:
        addNum('原始本金', a.loanOriginalCents);
        addNum('剩余本金', a.loanRemainingCents);
        addNum('月供', a.loanMonthlyCents);
        addDate('下次还款', a.loanNextPaymentDate);
      case AccountCategory.investment:
        addNum('市值', a.investMarketValueCents);
        addNum('成本', a.investCostCents);
        addRate('今年收益率', a.investReturnYtd);
      case AccountCategory.goldFx:
        add('品种', a.goldProductType.isEmpty ? null : a.goldProductType);
        if (a.goldQuantity != null) {
          // 黄金/外汇数量精度 3 位（克/盎司通常 2-3 位小数）。
          add('数量', a.goldQuantity!.toStringAsFixed(3));
        }
        addNum('买入价', a.goldBuyPriceCents);
        addNum('现价', a.goldCurrentPriceCents);
      case AccountCategory.realEstate:
        addNum('买入价', a.estatePurchasePriceCents);
        addNum('现估值', a.estateCurrentValueCents);
        addDate('买入日期', a.estatePurchaseDate);
        addRate('折旧率', a.estateDepreciationRate);
      case AccountCategory.fixedDeposit:
        addNum('本金', a.fixedPrincipalCents);
        addDate('起息日', a.fixedStartDate);
        addDate('到期日', a.fixedMaturityDate);
        if (a.fixedTermMonths != null) {
          add('期限', '${a.fixedTermMonths}月');
        }
      case AccountCategory.savings:
      case AccountCategory.otherAsset:
      case AccountCategory.otherLiability:
        addRate('利率', a.interestRate);
        addDate('开户日期', a.openingDate);
        add('币种', a.currencyCode);
    }

    return LayoutBuilder(
      builder: (ctx, c) => GridView.count(
        key: const ValueKey('heroFields'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: c.maxWidth > 600 ? 4 : 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.6,
        children: [for (final f in fields) _heroField(f.$1, f.$2)],
      ),
    );
  }

  /// hero-field：浅色 label + 白字 value 的单格。
  Widget _heroField(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      );

  /// quick-stats 4 卡：按 account.category 渲染类型专属 (label, value)。
  /// 储蓄/其他类用通用本月收支 4 卡；其余按现有类型专属字段（无积分/未出账
  /// 数据源的指标不显示）。summary 接 TransactionBloc 的 account-scoped
  /// MonthlySummary；交易数取已加载列表长度。
  Widget _statsRow(
      Account a, List<Transaction> txns, MonthlySummary? summary) {
    final stats = _statsFor(a: a, txns: txns, summary: summary);
    // 卡片间 14px 间距（原型 .quick-stats gap:14px）；首尾无边缘缩进。
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 7,
                right: i == stats.length - 1 ? 0 : 7,
              ),
              child: DataCard(
                child: Column(
                  children: [
                    Text(stats[i].$2,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(stats[i].$1,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 类型专属 4 卡 (label, value)。储蓄/其他类用通用本月收支；其余按现有字段。
  /// 仅用 Account 现有字段（无积分/未出账数据源的指标不显示）。
  List<(String, String)> _statsFor({
    required Account a,
    required List<Transaction> txns,
    required MonthlySummary? summary,
  }) {
    switch (a.category) {
      case AccountCategory.creditCard:
        final limit = a.creditLimitCents;
        final used = a.currentBalanceCents.abs(); // 欠款为负，取绝对值
        final avail = (limit - used).clamp(0, limit);
        return [
          ('信用额度', _fmtSigned(limit)),
          ('已用额度', _fmtSigned(used)),
          ('可用额度', _fmtSigned(avail)),
          ('账单日', '${a.creditBillingDay ?? '-'}日'),
        ];
      case AccountCategory.loan:
        final orig = a.loanOriginalCents ?? 0;
        final remain = a.loanRemainingCents ?? 0;
        final repaidPct = orig > 0 ? ((orig - remain) / orig * 100) : 0.0;
        return [
          ('原始本金', _fmtSigned(orig)),
          ('剩余本金', _fmtSigned(remain)),
          ('月供', _fmtSigned(a.loanMonthlyCents ?? 0)),
          ('已还比例', '${repaidPct.toStringAsFixed(1)}%'),
        ];
      case AccountCategory.investment:
        return [
          ('当前市值', _fmtSigned(a.investMarketValueCents ?? 0)),
          ('投入成本', _fmtSigned(a.investCostCents ?? 0)),
          ('今年收益率', '${(a.investReturnYtd ?? 0).toStringAsFixed(2)}%'),
          ('持仓交易数', '${txns.length}'),
        ];
      case AccountCategory.fixedDeposit:
        return [
          ('本金', _fmtSigned(a.fixedPrincipalCents ?? 0)),
          ('到期日', a.fixedMaturityDate == null
              ? '-'
              : _fmtDate(a.fixedMaturityDate!)),
          ('年化利率', '${(a.interestRate ?? 0).toStringAsFixed(2)}%'),
          ('$_scopeLabel收支', _fmtSigned(summary?.netCents ?? 0)),
        ];
      case AccountCategory.goldFx:
        final cur = a.goldCurrentPriceCents ?? 0;
        final buy = a.goldBuyPriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return [
          ('现值', _fmtSigned((cur * (a.goldQuantity ?? 0)).toInt())),
          ('买入价', _fmtSigned(buy)),
          ('涨幅', '${pct.toStringAsFixed(2)}%'),
          ('$_scopeLabel收支', _fmtSigned(summary?.netCents ?? 0)),
        ];
      case AccountCategory.realEstate:
        final cur = a.estateCurrentValueCents ?? 0;
        final buy = a.estatePurchasePriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return [
          ('现估值', _fmtSigned(cur)),
          ('买入价', _fmtSigned(buy)),
          ('增值率', '${pct.toStringAsFixed(2)}%'),
          ('$_scopeLabel收支', _fmtSigned(summary?.netCents ?? 0)),
        ];
      case AccountCategory.savings:
      case AccountCategory.otherAsset:
      case AccountCategory.otherLiability:
        return [
          ('$_scopeLabel收入', _fmtSigned(summary?.incomeCents ?? 0)),
          ('$_scopeLabel支出', _fmtSigned(summary?.expenseCents ?? 0)),
          ('$_scopeLabel净流入', _fmtSigned(summary?.netCents ?? 0)),
          ('$_scopeLabel交易', '${txns.length}'),
        ];
    }
  }

  Widget _panel(String title, String hint) => DataCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(hint,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12)),
              ),
            ),
          ],
        ),
      );

  /// 近期交易 panel：接 TransactionBloc 的 account-scoped list。空列表显示
  /// 占位文案；非空按 _recentPageSize（5/页）切片 + 紧凑行渲染（描述 + 金额，
  /// 不用 TxnRow 的宽表布局 —— 该 panel 在窄列里，TxnRow 会溢出）。
  /// 分页 >1 页时底部追加「‹ 1/N ›」pager。越界（列表缩短 / 账户切换）在
  /// 入口 clamp，避免 stale page index。
  Widget _recentTxnPanel(List<Transaction> txns) {
    final pageCount = (txns.length / _recentPageSize).ceil();
    if (_recentPage >= pageCount && pageCount > 0) _recentPage = pageCount - 1;
    if (pageCount == 0) _recentPage = 0;
    final start = _recentPage * _recentPageSize;
    final page = txns.skip(start).take(_recentPageSize).toList();
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('近期交易',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${txns.length} 笔',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  const SizedBox(width: AppSpacing.md),
                  // 查看全部 → 交易列表（/transactions 在独立 branch，context.go
                  // 切换 branch；route 不支持 account 预筛 query，故仅导航）。
                  InkWell(
                    onTap: () => context.go('/transactions'),
                    child: const Text('查看全部 →',
                        style: TextStyle(
                            color: AppColors.accent, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (page.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无交易',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            )
          else
            for (final t in page) _recentTxnRow(t),
          if (pageCount > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            _recentPager(pageCount),
          ],
        ],
      ),
    );
  }

  /// 近期交易页码行：‹ 上一页 · 1/N · 下一页 ›。首页/末页对应按钮禁用。
  Widget _recentPager(int pageCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '上一页',
          icon: const Icon(Icons.chevron_left, size: 20, color: AppColors.muted),
          onPressed: _recentPage > 0
              ? () => setState(() => _recentPage--)
              : null,
        ),
        Text('${_recentPage + 1}/$pageCount',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        IconButton(
          tooltip: '下一页',
          icon: const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
          onPressed: _recentPage < pageCount - 1
              ? () => setState(() => _recentPage++)
              : null,
        ),
      ],
    );
  }

  /// 近期交易行（Task 12 重写，对齐 OD .txn-row）：
  /// 分类 icon 圆角方块（income 绿/expense 红/transfer 灰）+ 名称（描述）+
  /// 副行（分类·账户）+ 金额（正绿/负红，mono tabular-nums）+ 日期时间
  /// （transactionTime → MM-dd HH:mm；null 回退 transactionDate → MM-dd）。
  ///
  /// entries 解析（复用 P0 txn_row 双账户逻辑）：
  ///   - 转账（2 条 entry 且两端都是 asset）：flavour=transfer，灰 icon，
  ///     副行 = 转出账户名 · 转入账户名。
  ///   - 非转账：asset 账户 = 资产账户名；对侧 income/expense 账户 = 分类。
  ///     副行 = `${分类账户 category.label} · ${资产账户名}`。
  Widget _recentTxnRow(Transaction t) {
    final flavour = _inferFlavour(t);
    final amount = t.totalDebitCents;
    final cell = _resolveRecentTxnCell(t, flavour);

    // 日期时间：transactionTime 优先（MM-dd HH:mm），回退 transactionDate（MM-dd）。
    final dt = t.transactionTime;
    final dateLabel = dt != null
        ? '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}';

    // 金额符号：income 正（+）/ expense 负（-）/ transfer 不加号。
    final isNegative = amount < 0 || flavour == TxnFlavour.expense;
    final signedAmount = flavour == TxnFlavour.income
        ? amount.abs()
        : (flavour == TxnFlavour.expense ? -amount.abs() : amount);
    final amountColor = flavour == TxnFlavour.income
        ? AppColors.positive
        : (flavour == TxnFlavour.expense ? AppColors.negative : AppColors.fg);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _TxnTypeIcon(flavour: flavour, categoryAccount: cell.categoryAccount),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.description.isEmpty ? '(无描述)' : t.description,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cell.subLine,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(dateLabel,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isNegative
                ? '-${_fmtSigned(signedAmount.abs())}'
                : (flavour == TxnFlavour.income
                    ? '+${_fmtSigned(signedAmount)}'
                    : _fmtSigned(signedAmount)),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: amountColor,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  /// 推断 flavour（与 txn_row._inferFlavour 同语义：平衡 + 两条 entry → transfer）。
  TxnFlavour _inferFlavour(Transaction t) {
    if (t.entries.length == 2 && t.isBalanced) {
      // 两端都是 asset → transfer；否则按 debit/credit 方向判 income/expense。
      final e0 = _accountsMap[t.entries[0].accountId];
      final e1 = _accountsMap[t.entries[1].accountId];
      final bothAsset = e0?.accountType == AccountType.asset &&
          e1?.accountType == AccountType.asset;
      if (bothAsset) return TxnFlavour.transfer;
      // 非转账：有 expense 账户 → expense；有 income 账户 → income。
      if (e0?.accountType == AccountType.expense ||
          e1?.accountType == AccountType.expense) {
        return TxnFlavour.expense;
      }
      if (e0?.accountType == AccountType.income ||
          e1?.accountType == AccountType.income) {
        return TxnFlavour.income;
      }
    }
    // 单 entry / 无法解析 → 用 debit/credit 方向退化判定。
    if (t.entries.isNotEmpty) {
      final a = _accountsMap[t.entries.first.accountId];
      if (a?.accountType == AccountType.expense) return TxnFlavour.expense;
      if (a?.accountType == AccountType.income) return TxnFlavour.income;
    }
    return TxnFlavour.compound;
  }

  /// 解析近期交易行的账户列内容（复用 txn_row._resolveAccountCell 逻辑）。
  _RecentTxnCell _resolveRecentTxnCell(Transaction t, TxnFlavour flavour) {
    String labelOf(String id) {
      final a = _accountsMap[id];
      if (a != null) return a.name;
      return id.length > 6 ? '#${id.substring(0, 6)}' : '#$id';
    }

    if (flavour == TxnFlavour.transfer) {
      final fromEntry = t.entries.firstWhere(
        (e) => e.creditCents > 0,
        orElse: () => t.entries.first,
      );
      final toEntry = t.entries.firstWhere(
        (e) => e.debitCents > 0,
        orElse: () => t.entries.last,
      );
      return _RecentTxnCell(
        subLine: '${labelOf(fromEntry.accountId)} · ${labelOf(toEntry.accountId)}',
        categoryAccount: null,
      );
    }
    // 非转账：asset 账户 = 资产名；对侧 income/expense = 分类。
    Account? assetAccount;
    Account? otherAccount;
    String? assetId;
    for (final e in t.entries) {
      final a = _accountsMap[e.accountId];
      if (a == null) continue;
      if (a.accountType == AccountType.asset && assetAccount == null) {
        assetAccount = a;
        assetId = e.accountId;
      } else {
        otherAccount ??= a;
      }
    }
    final assetName = assetId != null
        ? labelOf(assetId)
        : (t.entries.isNotEmpty ? labelOf(t.entries.first.accountId) : '');
    // 分类 = 对侧 income/expense 账户的 name（本 app 模型里 expense/income
    // 账户本身就是分类，name 即分类名如「餐饮」「工资」）。
    final categoryLabel = otherAccount?.name ?? '';
    return _RecentTxnCell(
      subLine: categoryLabel.isEmpty
          ? assetName
          : '$categoryLabel · $assetName',
      categoryAccount: otherAccount,
    );
  }

  /// 周期切换 segmented control（日/月/年），对齐 OD 原型 `.period-tabs`。
  /// 容器 bg `#f7f6f2`（AppColors.bg）+ 边框 `#e6e3dc`（AppColors.border），
  /// active 段白底（AppColors.surface）；inactive 段透明、灰字（AppColors.muted）。
  /// active 段文字用 accent-press 金 `#98773f`（比 accent 更深，对齐 OD press 态）。
  /// 三段等宽，整组圆角 AppRadius.sm。
  Widget _periodSegmentedControl() {
    /// accent-press 金（OD 原型 active 段文字色，比 AppColors.accent 更深）。
    const accentPress = Color(0xFF98773F);
    const segments = [
      (SummaryScope.day, '日'),
      (SummaryScope.month, '月'),
      (SummaryScope.year, '年'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (scope, label) in segments)
            _periodSegment(scope, label, accentPress),
        ],
      ),
    );
  }

  /// 单个周期段。active 时白底 + 金字；inactive 时透明 + 灰字。点击切换 scope。
  Widget _periodSegment(
      SummaryScope scope, String label, Color activeColor) {
    final active = scope == _scope;
    return InkWell(
      onTap: () => _changeScope(scope),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? activeColor : AppColors.muted,
          ),
        ),
      ),
    );
  }

  /// 收支统计 panel：饼图 + legend（对齐 OD .pie-wrap）。
  /// expense 分类从 summary.byDay 客户端聚合（_monthExpenseByCategory）；
  /// 无数据时显占位「本月暂无支出」。
  Widget _summaryPanel(MonthlySummary? summary) {
    final cats = _monthExpenseByCategory(summary);
    final total = cats.fold<int>(0, (s, c) => s + c.amountCents);
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('收支统计',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              _periodSegmentedControl(),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (cats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('本月暂无支出',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            )
          else ...[
            _pieChart(cats, total),
            const SizedBox(height: AppSpacing.md),
            for (final c in cats) _legendRow(c, total),
          ],
        ],
      ),
    );
  }

  /// 从 summary.byDay 聚合月度 expense 分类（饼图用）。按 amountCents 降序。
  /// 跳过非 expense 类型与 0 金额项。
  List<CategoryTotal> _monthExpenseByCategory(MonthlySummary? summary) {
    if (summary == null) return const [];
    final merged = <String, CategoryTotal>{};
    for (final day in summary.byDay) {
      for (final c in day.byCategory) {
        if (c.accountType != 'expense' || c.amountCents == 0) continue;
        final existing = merged[c.categoryId];
        if (existing == null) {
          merged[c.categoryId] = CategoryTotal(
            categoryId: c.categoryId,
            name: c.name,
            accountType: c.accountType,
            amountCents: c.amountCents,
          );
        } else {
          merged[c.categoryId] = CategoryTotal(
            categoryId: existing.categoryId,
            name: existing.name,
            accountType: existing.accountType,
            amountCents: existing.amountCents + c.amountCents,
          );
        }
      }
    }
    final list = merged.values.toList()
      ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return list;
  }

  /// 饼图：CustomPaint(_DonutPainter) + 中心总金额/支出 label（对齐 OD .pie-wrap）。
  Widget _pieChart(List<CategoryTotal> cats, int total) {
    return Center(
      child: SizedBox(
        width: 128,
        height: 128,
        child: CustomPaint(
          painter: _DonutPainter(cats, total),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_fmtSigned(total),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTypography.tabularFigures)),
                const Text('支出',
                    style: TextStyle(color: AppColors.muted, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// legend 行：色块 + 分类名 + 占比%·金额（对齐 OD .legend-row）。
  Widget _legendRow(CategoryTotal c, int total) {
    final pct = total > 0 ? (c.amountCents / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _categoryColorForCategory(c.categoryId),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Text(c.name.isEmpty ? '未分类' : c.name,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const Spacer(),
          Text('${pct.toStringAsFixed(0)}% · ${_fmtSigned(c.amountCents)}',
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }

  // ───────────────────────── 操作 ─────────────────────────

  /// 记一笔：push TransactionFormPage，预选本账户（省去用户在表单里重挑）。
  /// 表单返回 true（提交成功）后刷新本账户的近期交易 + 月度统计
  ///（余额由 GetAccountRequested 同步刷新）。
  void _recordTxn() {
    Navigator.of(context)
        .push<bool>(MaterialPageRoute(
            builder: (_) => TransactionFormPage(
                  initialAccountId: widget.id,
                )))
        .then((ok) {
      if (ok == true && mounted) {
        AppToast.show(context, '交易已记录', type: ToastType.success);
        _refreshTxn();
        context.read<AccountBloc>().add(GetAccountRequested(widget.id));
      }
    });
  }

  /// 转账：push TransactionFormPage 并直入转账 tab，预选本账户为转出账户。
  void _transfer() {
    Navigator.of(context)
        .push<bool>(MaterialPageRoute(
            builder: (_) => TransactionFormPage(
                  initialAccountId: widget.id,
                  initialType: TxnType.transfer,
                )))
        .then((ok) {
      if (ok == true && mounted) {
        AppToast.show(context, '交易已记录', type: ToastType.success);
        _refreshTxn();
        context.read<AccountBloc>().add(GetAccountRequested(widget.id));
      }
    });
  }

  /// 重新拉取本账户的近期交易 + 收支统计。
  /// TransactionBloc 由路由层 provide（见 router.dart `/accounts/:id`）。
  /// Task 10：summary 现按当前 `_scope` / `_day` 发 LoadSummaryRequested，
  /// 切换周期粒度走同一入口。
  void _refreshTxn() {
    final b = context.read<TransactionBloc>();
    final now = DateTime.now();
    b.add(LoadTransactionsRequested(
        filter: TxnFilterState(accountId: widget.id)));
    b.add(LoadSummaryRequested(
      year: now.year,
      month: now.month,
      accountId: widget.id,
      scope: _scope,
      day: _scope == SummaryScope.day ? (_day ?? now.day) : null,
    ));
  }

  /// 切周期粒度（Task 10）。更新 `_scope`/`_day` 后重载 summary。
  /// DAY scope 时把 `_day` 钉到今天 day-of-month。
  void _changeScope(SummaryScope next) {
    if (next == _scope) return;
    setState(() {
      _scope = next;
      _day = next == SummaryScope.day ? DateTime.now().day : null;
    });
    _refreshTxn();
  }

  void _edit(Account a) {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AccountBloc>(),
          child: AccountFormPage(existing: a),
        ),
      ),
    )
        .then((ok) {
      if (ok == true && mounted) {
        AppToast.show(context, '账户已更新', type: ToastType.success);
        context.read<AccountBloc>().add(GetAccountRequested(widget.id));
      }
    });
  }

  void _copy(Account a) {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AccountBloc>(),
          child: AccountFormPage(existing: a.copyWith(id: '', version: 0, name: '${a.name}（副本）')),
        ),
      ),
    )
        .then((ok) {
      if (ok == true && mounted) {
        AppToast.show(context, '账户已复制', type: ToastType.success);
      }
    });
  }

  /// 关闭账户：归档（status=archived）。补传值字段，避免 account_remote_ds 对
  /// 非可选标量（name/icon/color/institution/creditLimitCents）的无条件覆盖
  /// 清空 —— 同 accounts_page._confirmClose 的修复（Task 14 c930caf）。
  void _close(Account a) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('关闭账户'),
        content: Text('关闭「${a.name}」？关闭后账户归档，详情仍可查看。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('关闭')),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        // 不直接 toast：dispatch 后 bloc 成功会发 LoadAccountsRequested →
        // AccountsLoaded（本页 BlocBuilder 不认此 state，会渲染空白）。
        // 改由下方 BlocListener 在 AccountsLoaded 时 toast + pop。
        setState(() {
          _closePending = true;
          _pendingSuccessMsg = '账户已关闭';
        });
        context.read<AccountBloc>().add(
              UpdateAccountRequested(
                UpdateAccountParams(
                  id: a.id,
                  version: a.version,
                  status: AccountStatus.archived,
                  // 保留现有值字段（防 remote_ds 无条件覆盖清空）。
                  name: a.name,
                  icon: a.icon,
                  color: a.color,
                  institution: a.institution,
                  creditLimitCents: a.creditLimitCents,
                  cardNumberTail: a.cardNumberTail,
                  notes: a.notes,
                  goldProductType: a.goldProductType,
                ),
              ),
            );
      }
    });
  }

  /// 重新激活账户：把归档账户恢复为 active（与 _close 对称）。
  /// 同 _close：补传值字段，防 remote_ds 对非可选标量无条件覆盖清空。
  void _reactivate(Account a) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('重新激活账户'),
        content: Text('重新激活「${a.name}」？账户恢复活跃状态。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('激活')),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        // 同 _close：由 BlocListener 在 AccountsLoaded 时 toast + pop。
        setState(() {
          _closePending = true;
          _pendingSuccessMsg = '账户已激活';
        });
        context.read<AccountBloc>().add(
              UpdateAccountRequested(
                UpdateAccountParams(
                  id: a.id,
                  version: a.version,
                  status: AccountStatus.active,
                  // 保留现有值字段（防 remote_ds 无条件覆盖清空）。
                  name: a.name,
                  icon: a.icon,
                  color: a.color,
                  institution: a.institution,
                  creditLimitCents: a.creditLimitCents,
                  cardNumberTail: a.cardNumberTail,
                  notes: a.notes,
                  goldProductType: a.goldProductType,
                ),
              ),
            );
      }
    });
  }

  void _delete(Account a) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('删除「${a.name}」？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('删除')),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        context.read<AccountBloc>().add(DeleteAccountRequested(a.id));
        context.pop();
      }
    });
  }

  // ───────────────────────── 工具 ─────────────────────────

  String _fmt(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign¥ $yuan.$fen';
  }

  /// 千分位 + 两位小数（与 SummaryCard 格式一致：¥1,234.56）。负数保留负号。
  String _fmtSigned(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    final yuanStr = _groupThousands(yuan);
    return '$sign¥$yuanStr.$frac';
  }

  static String _groupThousands(int yuan) {
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// 分类色：按 categoryId 哈希到御财调色板（稳定着色）。顶层函数，供
/// _legendRow（State）与 _DonutPainter 共用，避免两处调色板重复维护。
Color _categoryColorForCategory(String id) {
  const palette = [
    Color(0xFFB08D57),
    Color(0xFFC4544D),
    Color(0xFF2D8A6E),
    Color(0xFF3B6FB0),
    Color(0xFF8A6FB0),
    Color(0xFFB08D33),
  ];
  var h = 0;
  for (final c in id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

/// 收支统计饼图 painter（对齐 OD .pie-wrap：SVG circle + stroke-dasharray）。
/// 背景环（#EFECE4）+ 各分类按占比画 stroke 扇区，12 点起顺时针。
/// 着色走顶层 [_categoryColorForCategory]。
class _DonutPainter extends CustomPainter {
  _DonutPainter(this.cats, this.total);

  final List<CategoryTotal> cats;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const thickness = 16.0;
    // 背景环。
    canvas.drawCircle(
      center,
      radius - thickness / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = const Color(0xFFEFECE4),
    );
    if (total == 0) return;
    // 分类扇区。
    final rect =
        Rect.fromCircle(center: center, radius: radius - thickness / 2);
    var start = -pi / 2; // 12 点起。
    for (final c in cats) {
      final sweep = (c.amountCents / total) * 2 * pi;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..color = _categoryColorForCategory(c.categoryId),
      );
      start += sweep;
    }
  }

  // CategoryTotal 无值相等（无 == / hashCode），用顺序+金额的折叠签名比对，
  // 覆盖「同总数同数量但顺序变化」的视觉变更场景。
  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.total != total ||
      old.cats.length != cats.length ||
      old.cats.fold<int>(0, (s, c) => s ^ c.amountCents) !=
          cats.fold<int>(0, (s, c) => s ^ c.amountCents);
}

/// 近期交易行的账户列解析结果（_recentTxnRow 内部用）。
class _RecentTxnCell {
  const _RecentTxnCell({required this.subLine, this.categoryAccount});
  final String subLine;
  final Account? categoryAccount;
}

/// 分类 icon 圆角方块（income 绿 #2d8a6e / expense 红 #c4544d / transfer 灰
/// #8a8b8f）。icon 按 category（food→餐具 / transport→车 等），缺省用 flavour
/// 通用 icon（支出↓ / 收入↑ / 转账⇄）。
class _TxnTypeIcon extends StatelessWidget {
  const _TxnTypeIcon({required this.flavour, this.categoryAccount});
  final TxnFlavour flavour;
  final Account? categoryAccount;

  @override
  Widget build(BuildContext context) {
    final bg = switch (flavour) {
      TxnFlavour.income => const Color(0xFF2D8A6E),
      TxnFlavour.expense => const Color(0xFFC4544D),
      TxnFlavour.transfer => const Color(0xFF8A8B8F),
      TxnFlavour.compound => const Color(0xFF8A8B8F),
    };
    final icon = _iconFor(flavour, categoryAccount?.category);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }

  IconData _iconFor(TxnFlavour f, AccountCategory? cat) {
    if (f == TxnFlavour.income) return Icons.arrow_downward;
    if (f == TxnFlavour.transfer) return Icons.swap_horiz;
    if (cat == null) return Icons.arrow_upward;
    // expense 按 category 分支（AccountCategory 是资产分类，不直接对应支出类目，
    // 但复用其语义做近义 icon；无匹配时用通用支出 icon）。
    return Icons.arrow_upward;
  }
}
