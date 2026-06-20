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

  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(GetAccountRequested(widget.id));
    // 跨模块：account 详情页接 transaction bloc。
    // TransactionBloc + 初始 LoadTransactionsRequested / LoadSummaryRequested
    //（account-scoped）在路由层 `/accounts/:id` 的 MultiBlocProvider 里
    // provide —— 详情页 State.context 位于该 BlocProvider 下，
    // context.watch<TransactionBloc>() 能找到。本页不再自建 BlocProvider
    //（旧实现把 Provider 放在 build 返回的 Builder child 里，而 State.context
    // 在 Provider 之上，运行时抛 ProviderNotFoundException）。
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
          _statsRow(txns, summary),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _recentTxnPanel(txns)),
              const SizedBox(width: AppSpacing.lg),
              // 右栏：收支统计（_statsRow 已展示 4 卡，这里显示月度净额说明）+
              // 快捷操作（对照原型 right-col：信息+快捷操作）
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryPanel(summary),
                    const SizedBox(height: AppSpacing.lg),
                    _quickActions(a),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _hero(Account a, int netCents) {
    final isLiability = a.accountType == AccountType.liability;
    final netPositive = netCents >= 0;
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
                // hero-badge: 类型 + 资产·负债类 + 活期/定期。
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroBadge(a.category.label),
                    _heroBadge(isLiability ? '负债类' : '资产类'),
                    _heroBadge(a.category == AccountCategory.fixedDeposit
                        ? '定期'
                        : '活期'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
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
                // hero-bal-sub 本月收支（正绿 #6FCF9A 负红 #E57373）。
                Text(
                  '本月收支 ${netPositive ? '+' : '-'}¥'
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

  /// 收支统计 4 卡：本月收入 / 本月支出 / 净值变动 / 交易数。
  /// 接 TransactionBloc 的 account-scoped MonthlySummary（Task 5.1 accountId
  /// scope）。summary 未到位前显示 —；交易数取已加载列表长度。
  Widget _statsRow(List<Transaction> txns, MonthlySummary? summary) {
    final labels = ['本月收入', '本月支出', '净值变动', '交易数'];
    final values = <String>[
      _fmtSigned(summary?.incomeCents ?? 0),
      _fmtSigned(summary?.expenseCents ?? 0),
      _fmtSigned(summary?.netCents ?? 0),
      '${txns.length}',
    ];
    // 卡片间 14px 间距（原型 .quick-stats gap:14px）；首尾无边缘缩进。
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 7,
                right: i == labels.length - 1 ? 0 : 7,
              ),
              child: DataCard(
                child: Column(
                  children: [
                    Text(values[i],
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(labels[i],
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
  /// 占位文案；非空取前 5 条用紧凑行渲染（描述 + 金额，不用 TxnRow 的宽表
  /// 布局 —— 该 panel 在窄列里，TxnRow 会溢出）。
  Widget _recentTxnPanel(List<Transaction> txns) {
    final recent = txns.take(5).toList();
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('近期交易',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${txns.length} 笔',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无交易',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            )
          else
            for (final t in recent) _recentTxnRow(t),
        ],
      ),
    );
  }

  /// 紧凑近期交易行：描述 + 日期 / 金额。
  Widget _recentTxnRow(Transaction t) {
    final amount = t.totalDebitCents;
    final dateLabel =
        '${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
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
                Text(dateLabel,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _fmtSigned(amount),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// 收支统计 panel：月度净额 + 日均，接 account-scoped MonthlySummary。
  /// 4 张 quick-stat 卡已在 _statsRow 展示，这里补一行说明（月度净额 / 日均）。
  Widget _summaryPanel(MonthlySummary? summary) {
    final lines = <String>[];
    if (summary != null) {
      lines
        ..add('本月净额：${_fmtSigned(summary.netCents)}')
        ..add('日均：${_fmtSigned(summary.dailyAvgCents)}');
    }
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('收支统计',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('统计加载中',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            )
          else
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(l,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12)),
              ),
        ],
      ),
    );
  }

  /// 快捷操作 card（对照原型 desktop-detail-account.html .actions-card）。
  /// 激活：编辑/记一笔/转账真实；查看账单/隐藏账户 🔒 占位。
  /// 归档：移除编辑/记一笔/转账（只读，需先重新激活）。
  Widget _quickActions(Account a) {
    final archived = a.status == AccountStatus.archived;
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快捷操作',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.md),
          if (!archived) ...[
            _actionBtn('编辑账户', Icons.edit_outlined, () => _edit(a)),
            _actionBtn('记一笔', Icons.add, _recordTxn),
            _actionBtn('转账', Icons.swap_horiz, _transfer),
          ],
          _actionBtn(
              '查看账单（待交易模块）', Icons.receipt_long_outlined, null),
          _actionBtn('隐藏账户（待功能）', Icons.visibility_off_outlined, null),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback? onTap) {
    final disabled = onTap == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: disabled ? AppColors.muted : AppColors.fg,
            backgroundColor: AppColors.bg,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.smBorder,
              side: BorderSide(color: AppColors.border),
            ),
          ),
        ),
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

  /// 重新拉取本账户的近期交易 + 月度统计。
  /// TransactionBloc 由路由层 provide（见 router.dart `/accounts/:id`）。
  void _refreshTxn() {
    final b = context.read<TransactionBloc>();
    final now = DateTime.now();
    b.add(LoadTransactionsRequested(
        filter: TxnFilterState(accountId: widget.id)));
    b.add(LoadSummaryRequested(
        year: now.year, month: now.month, accountId: widget.id));
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
