import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/repayment_plan_panel.dart';
import 'package:yucai_client/core/widgets/yucai_menu.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/widgets/hero_shell.dart';
import 'package:yucai_client/core/widgets/pager_bar.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/widgets/txn_category_icon.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// 账户详情页。承接 Task 11 GetAccountUseCase + AccountDetailLoaded。
///
/// 结构：AppBar（编辑 / 🔒记一笔 / 🔒转账 / 更多菜单）→
/// Hero（类型图标 + 名称 / 机构·币种·类型 / 余额 / category 专属 chip）→
/// 统计行占位（待 Transaction）→ 双栏（近期交易 / 收支统计占位）→
/// 类型专属面板（投资 → 持仓列表占位 / 贷款 → 还款计划只读面板 F35）。
class AccountDetailPage extends StatefulWidget {
  const AccountDetailPage({super.key, required this.id});

  final String id;

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> with RouteAware {
  /// 关闭账户写操作进行中。_close dispatch 后置 true，BlocListener 收到
  /// AccountsLoaded（成功）/AccountError（失败）后清零 + toast + pop。
  /// 仿 accounts_page._pendingIds 的 listener 模式，避免 dispatch 即 toast
  /// 的过早提示，以及 UpdateAccountRequested → LoadAccountsRequested →
  /// AccountsLoaded 导致本页 BlocBuilder 渲染 SizedBox.shrink（页面空白）。
  bool _closePending = false;
  /// 写操作成功后的 toast 文案（关闭/激活共用同一套 pending → BlocListener 流程）。
  String? _pendingSuccessMsg;

  /// 跨 branch 刷新:交易在别处(交易 branch 的详情/编辑页)记/改/删后,本页
  /// 作为被覆盖的驻留路由不重建,余额/近期交易/统计滞留旧值 —— 订阅全局
  /// 通知器重拉(与 _recordTxn .then(ok) 的同组回拉,照 accounts_page 同款)。
  late final DataRefreshNotifier _dataRefresh = getIt<DataRefreshNotifier>();

  void _onDataRefresh() {
    if (!mounted) return;
    _refreshTxn();
    context.read<AccountBloc>().add(GetAccountRequested(widget.id));
  }

  /// 近期交易标准查询套件（F9 FR-2/ADR-4，替换 Task 6 的 5 条/页客户端
  /// 迷你分页 —— 旧 _recentPageSize/_recentPage/_recentPager 已删除）。
  ///
  /// 搜索/排序/分页状态不另起炉灶：复用路由层 provide 的 TransactionBloc
  /// （F7 查询管道，accountId 作用域）——筛选状态挂在 bloc 状态携带的
  /// TxnFilterState 上，分页游标由 bloc 内的共享 PageCursorStack（F9-T1
  /// 提取至 core/widgets）维护。本页只做三件事：
  ///   1. 读回当前 filter 驱动搜索框/排序控件（受控组件，单源真值）；
  ///   2. 任一筛选变化发 LoadTransactionsRequested（照 F7 语义 = 重置
  ///      第 1 页：bloc 清 PageCursorStack、pageIndex 归 0、pageSize 100）；
  ///   3. 翻页发 GoToTransactionsPageRequested（filter 不变，仅换 token）。

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

  /// 关联债务(该账户名下全部借入债务,一户可多笔):贷款字段的实时数据源。
  List<Debt> _linkedDebts = const [];

  /// F35:贷款账户「还款计划」面板数据(每笔债一节:债务 + 未来未还期次
  /// 前 3 条)。空 = 名下无借入债务,面板不渲染(FR-2 隐藏优于空占位)。
  List<({Debt debt, List<PaymentEntry> upcoming})> _debtPlans = const [];

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
    _loadLinkedDebt();
    _loadRepaymentPlans();
    _dataRefresh.addListener(_onDataRefresh);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // F35 FR-3:订阅 accounts 分支观察者(照 debt_detail_page 模式)——
    // 从编辑/记一笔/交易详情等表单 pop 回本页时 didPopNext 重拉。
    accountsRouteObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    // 从编辑/其他表单返回:详情 + 还款计划一并重拉(FR-3)。
    if (!mounted) return;
    context.read<AccountBloc>().add(GetAccountRequested(widget.id));
    _loadRepaymentPlans();
  }

  @override
  void dispose() {
    accountsRouteObserver.unsubscribe(this);
    _dataRefresh.removeListener(_onDataRefresh);
    super.dispose();
  }

  /// 按账户 id 收集名下全部借入债务(loan 字段聚合的数据源)。
  /// typeFilter: borrowedIn —— 与 _loadRepaymentPlans 同语义(borrowedOut
  /// 归应收模块,不进负债聚合)。

  /// F35 扩展:loan 与 otherLiability(个人待还款)挂借入债时,hero/信息卡/
  /// 还款计划面板均以债务实时数据呈现(单一数据源)。
  bool _isDebtDerivedLiability(Account a) =>
      (a.category == AccountCategory.loan ||
          a.category == AccountCategory.otherLiability) &&
      _linkedDebts.isNotEmpty;
  Future<void> _loadLinkedDebt() async {
    try {
      final r = await GetIt.instance<DebtRepository>()
          .list(typeFilter: DebtType.borrowedIn);
      r.fold((_) {}, (list) {
        final linked =
            list.where((d) => d.accountId == widget.id).toList();
        if (mounted) setState(() => _linkedDebts = linked);
      });
    } catch (_) {}
  }

  /// F35:「还款计划」面板数据管道 —— 借入债务 list(typeFilter: borrowedIn)
  /// → 本账户 accountId 过滤 → 逐笔 repo.get(id) 取 schedule → 未还期次按
  /// paymentDate 升序取前 3。失败/未注册(测试 harness)静默保持空面板。
  Future<void> _loadRepaymentPlans() async {
    try {
      final repo = getIt<DebtRepository>();
      final r = await repo.list(typeFilter: DebtType.borrowedIn);
      final linked =
          r.fold((_) => <Debt>[], (l) => l.where((d) => d.accountId == widget.id).toList());
      final plans = <({Debt debt, List<PaymentEntry> upcoming})>[];
      for (final d in linked) {
        final det = await repo.get(d.id);
        det.fold((_) {}, (detail) {
          final unpaid = detail.schedule.where((e) => !e.paid).toList()
            ..sort((a, b) => a.paymentDate.compareTo(b.paymentDate));
          plans.add((debt: detail.debt, upcoming: unpaid.take(3).toList()));
        });
      }
      if (mounted) setState(() => _debtPlans = plans);
    } catch (_) {}
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
      backgroundColor: context.yucai.bg,
      appBar: AppBar(
        backgroundColor: context.yucai.surface,
        foregroundColor: context.yucai.fg,
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
              // Task 6：≤900 tablet/mobile 仅 icon（防窄卡 3 个 TextButton 挤压）；
              // >900 desktop 保留 icon+文字 TextButton。lucide edit/penLine/
              // arrowLeftRight 已在 lucide_icons_flutter 3.1.14+2 验证存在。
              final isTablet =
                  MediaQuery.of(context).size.width <= 900;
              return Row(
                children: [
                  // 归档账户：移除编辑/记一笔/转账（不可再产生交易），
                  // 只留更多菜单（复制/重新激活/删除）。
                  if (!archived) ...[
                    if (isTablet) ...[
                      IconButton(
                        tooltip: '编辑',
                        icon: const Icon(LucideIcons.edit, size: 18),
                        onPressed: a == null ? null : () => _edit(a),
                      ),
                      IconButton(
                        tooltip: '记一笔',
                        icon: const Icon(LucideIcons.penLine, size: 18),
                        onPressed: a == null ? null : _recordTxn,
                      ),
                      IconButton(
                        tooltip: '转账',
                        icon:
                            const Icon(LucideIcons.arrowLeftRight, size: 18),
                        onPressed: a == null ? null : _transfer,
                      ),
                    ] else ...[
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
                  ],
                  // F5e:YucaiAnchoredMenu(CompositedTransformFollower)——
                  // 跨分支 Navigator 边界像素级贴合,替代 MenuAnchor。
                  YucaiAnchoredMenu(
                    items: [
                      YucaiMenuItemData(
                          label: '复制账户',
                          icon: LucideIcons.copy,
                          onTap: a == null ? null : () => _copy(a)),
                      YucaiMenuItemData(
                          label: archived ? '重新激活账户' : '关闭账户',
                          icon: archived
                              ? LucideIcons.rotateCcw
                              : LucideIcons.archive,
                          onTap: a == null
                              ? null
                              : () => archived ? _reactivate(a) : _close(a)),
                      YucaiMenuItemData(
                          label: '删除账户',
                          icon: LucideIcons.trash2,
                          destructive: true,
                          onTap: a == null ? null : () => _delete(a)),
                    ],
                    builder: (menuContext, open) => IconButton(
                      tooltip: '更多操作',
                      icon: Icon(LucideIcons.moreHorizontal,
                          size: 18, color: context.yucai.muted),
                      onPressed: open,
                    ),
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
    // 三端响应式断点（对齐 OD @media 900/720）。
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900; // ≤900 tablet（含 mobile）
    final isMobile = w <= 720; // ≤720 mobile
    return ListView(
      // OD .content padding 24/36/70（top/bottom 24,左右 36,底部 70）；
      // ≤720 缩到 16/14/60。
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 60)
          : const EdgeInsets.fromLTRB(36, 24, 36, 70),
      children: [
        _hero(a, summary?.netCents ?? 0),
        const SizedBox(height: 18),
        _statsRow(a, txns, summary),
        const SizedBox(height: 18),
        // OD .cols：>900 双栏（交易 1.5fr + 饼图 1fr）/ ≤900 堆叠单列。
        if (isTablet)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _recentTxnPanel(txnState, a.currencyCode),
              const SizedBox(height: 16),
              _summaryPanel(summary, a.currencyCode),
            ],
          )
        else
          Row(
            key: const ValueKey('detailBodyRow'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 3, child: _recentTxnPanel(txnState, a.currencyCode)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _summaryPanel(summary, a.currencyCode)),
            ],
          ),
        const SizedBox(height: 18),
        _infoCard(a),
        const SizedBox(height: AppSpacing.lg),
        if (a.category == AccountCategory.investment)
          _panel('持仓列表', '待 Holding 模块接入')
        else if (_isDebtDerivedLiability(a))
          // F35:还款计划只读面板(名下有借入债务才渲染,FR-2 隐藏优于空占位);
          // 「查看完整还款计划 →」跳债务详情页(完整交互计划所在处)。
          // F35 扩展:otherLiability(个人待还款)与 loan 同待遇。
          if (_debtPlans.isNotEmpty)
            AccountRepaymentPlanPanel(
              key: const ValueKey('repaymentPlanPanel'),
              plans: _debtPlans,
              preferred: a.currencyCode,
              onOpenDebt: (id) => context.push('/debts/$id'),
            )
          else
            const SizedBox.shrink()
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
      if (cents != null && cents != 0) {
        cells.add((label, _fmtSigned(cents, a.currencyCode)));
      }
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
      case AccountCategory.otherLiability:
        // 贷款字段以债务模块实时数据为准(一户多笔:原始/剩余/利息 = 合计,
        // 月供/下次 = 最早到期那笔);无关联债务时回退账户静态字段。
        // F35 扩展:otherLiability(个人待还款)同待遇。
        if (_linkedDebts.isNotEmpty) {
          final first1 = _linkedDebts.reduce((x, y) =>
              (x.nextPaymentDate ?? DateTime(9999))
                      .isBefore(y.nextPaymentDate ?? DateTime(9999))
                  ? x
                  : y);
          final totalPrincipal = _linkedDebts
              .fold<int>(0, (s, d) => s + d.totalPrincipalCents);
          final remainPrincipal = _linkedDebts
              .fold<int>(0, (s, d) => s + d.remainingPrincipalCents);
          addNum('原始本金', totalPrincipal);
          addNum('剩余本金', remainPrincipal);
          addNum('剩余利息',
              _linkedDebts.fold<int>(0, (s, d) => s + d.unpaidInterestCents));
          addNum('月供', first1.nextPaymentAmountCents);
          // F35 验收:已还比例自 stats 条挪入(原 stats 读静态字段恒 0)。
          if (totalPrincipal > 0) {
            add('已还比例',
                '${((totalPrincipal - remainPrincipal) / totalPrincipal * 100).toStringAsFixed(1)}%');
          }
          final npd1 = first1.nextPaymentDate;
          if (npd1 != null) add('下次还款', _fmtDate(npd1));
        } else {
          addNum('原始本金', a.loanOriginalCents);
          addNum('剩余本金', a.loanRemainingCents);
          addNum('月供', a.loanMonthlyCents);
          add('下次还款',
              a.loanNextPaymentDate == null ? null : _fmtDate(a.loanNextPaymentDate!));
        }
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
        // otherLiability 已由上方 loan 债务行分支覆盖(F35 扩展)。
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
              final isDesktop = MediaQuery.of(ctx).size.width > 900;
              return GridView.count(
                key: const ValueKey('infoCard'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 3 : 2,
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
              style: TextStyle(
                  fontSize: 11,
                  color: context.yucai.muted,
                  letterSpacing: 0.07)),
          const SizedBox(height: 5),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  color: context.yucai.fg,
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
        'HKD' => '港元',
        'GBP' => '英镑',
        'JPY' => '日元',
        _ => '',
      };

  Widget _hero(Account a, int netCents) {
    final isMobile = MediaQuery.of(context).size.width <= 720;
    final isLiability = a.accountType == AccountType.liability;
    final netPositive = netCents >= 0;
    // hero-org: 机构 · 人民币 币种 · 卡号 **** 尾号（对齐 OD .hero-org）。
    // 机构/尾号都缺失时回退到 类别 · 人民币 币种（保持 hero-org 非空）。
    final curName = _currencyName(a.currencyCode);
    final curLabel = curName.isEmpty
        ? a.currencyCode
        : '$curName ${a.currencyCode}';
    final org = a.institution.isEmpty && a.cardNumberTail.isEmpty
        ? '${a.category.label} · $curLabel'
        : [
            if (a.institution.isNotEmpty) a.institution,
            curLabel,
            if (a.cardNumberTail.isNotEmpty) '卡号 **** ${a.cardNumberTail}',
          ].join(' · ');
    // 第2 badge：{资产类/负债类}·活期/定期（fixedDeposit→定期，其他→活期）。
    final liquidity = a.category == AccountCategory.fixedDeposit ? '定期' : '活期';
    final classLabel = '${isLiability ? '负债类' : '资产类'} · $liquidity';
    // F4-P2 豁免已退役(F26,R12 sprint-1):hero 迁 design-v2 §4 变体 A(与
    // home 净资产 hero 同款)—— 暗 = surface 墨面卡 + 1.5px 金渐变描边 +
    // 余额数字 ShaderMask 渐变金;亮 = surface 白卡 + 柔影。历史:曾为 OD
    // 原型刻意固定深渐变面(#1C1E21→#2A2D33 两主题同款)+ 白系文本/白透描边
    // (hero-pick/ghost badge/hero-fields 分隔线)豁免,语义令牌化(fg/muted/
    // border)后退役;金晕/金饰/语义色本就走 context.yucai。
    return HeroShell(
      // OD .hero padding 28 32 30（top 28 / 左右 32 / bottom 30）。
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
      child: Stack(
        // 默认 Clip.hardEdge 把负偏移金晕裁在内容框上;放行后由 HeroShell
        // 卡面 antiAlias 按卡片圆角裁(同 home 净资产 hero 口径)。
        clipBehavior: Clip.none,
        children: [
          // 径向金色光晕（ADR-4 暗 0.18 / 亮 0.10 两主题保留）。
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
                    context.yucai.accent
                        .withValues(alpha: heroGlowAlpha(context)),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // hero-pick（右上角）：已绑定实名 · 银行直连（对齐 OD .hero-pick）。
          // Positioned 在 Column 之上但不挡 Column（Column 左上起，pill 右上角）。
          // Final-review #4：仅银行类账户（储蓄/信用卡/定期/贷款）+ institution 非空
          // 才显示「银行直连」pill —— 对 goldFx/realEstate/otherAsset/investment 等非银
          // 行账户该文案误导，隐藏。
          if (_isBankLinked(a))
            Positioned(top: 0, right: 0, child: _heroPick()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // hero-badges: 类型徽章（金色实心 + icon）+ 资产/负债类·活期/定期（ghost）。
              // 对齐 OD .hero-badges（第1 .hero-badge 金色 icon，第2 .hero-badge.ghost）。
              Wrap(
                spacing: 7,
                runSpacing: 8,
                children: [
                  _heroBadge(
                    '${a.category.label}账户',
                    icon: _categoryIcon(a.category),
                  ),
                  _heroBadge(classLabel, ghost: true),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // hero-name: 账户名 28px serif（对齐 OD .hero-name）。
              // 账户名从 AppBar title 移入 hero（AppBar title 保持「账户详情」）。
              // F26:名称走 fg 不渐变(ADR-2 克制 —— 仅「大数字」渐变金)。
              Text(
                a.name,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: context.yucai.fg,
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
                  color: context.yucai.muted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              // hero-bal-label「可用余额」（对齐 OD .hero-bal-label）。
              // F35 验收:挂债贷款账户改显「剩余应还」= 债务实时剩余本金
              // 合计 —— currentBalance 是流水残值(如 -¥6,795.20),用户无法
              // 理解;余额本身的重算治本在 F36,此处先做展示语义纠正。
              // F35 扩展:otherLiability(个人待还款)与 loan 同待遇。
              Text(
                _isDebtDerivedLiability(a) ? '剩余应还' : '可用余额',
                style: TextStyle(
                  fontSize: 12,
                  color: context.yucai.muted,
                  letterSpacing: 0.04,
                ),
              ),
              const SizedBox(height: 6),
              // 余额 mobile 32px / desktop 40px serif display。
              // F26:暗色经 HeroGradientText 渐变金(ADR-2),亮色 fg 直出。
              HeroGradientText(
                child: Text(
                  key: const ValueKey('heroBalance'),
                  _fmt(
                      _isDebtDerivedLiability(a)
                          ? _linkedDebts.fold<int>(0,
                              (s, d) => s + d.remainingPrincipalCents)
                          : a.currentBalanceCents,
                      a.currencyCode),
                  style: TextStyle(
                    fontSize: isMobile ? 32 : 40,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: context.yucai.fg,
                    fontFeatures: AppTypography.tabularFigures,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // hero-bal-sub {scope}收支（正绿 #6FCF9A 负红 #E57373）。
              // Task 11：前缀跟随 _scope（本日/本月/本年）。
              Text(
                '$_scopeLabel收支 ${netPositive ? '+' : '-'}${currencySymbol(a.currencyCode)}'
                '${(netCents.abs() ~/ 100).toString()}.'
                '${(netCents.abs() % 100).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 13,
                  color: netPositive
                      ? context.yucai.positive
                      : context.yucai.negative,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(height: 26),
              // hero-fields 类型专属字段网格（OD .hero-fields：margin-top 26，
              // padding-top 22 + border-top，gap 18）。
              _heroFields(a),
            ],
          ),
        ],
      ),
    );
  }

  /// Final-review #4：是否显示「已绑定实名 · 银行直连」pill。仅银行类账户
  /// （savings/creditCard/fixedDeposit/loan）且 institution 非空 —— 模拟「银行直连」
  /// 的真实语义。goldFx/realEstate/otherAsset/otherLiability/investment 等非银行账户
  /// （现金/黄金/房产/手工）该文案误导，隐藏。
  bool _isBankLinked(Account a) {
    const bankCategories = {
      AccountCategory.savings,
      AccountCategory.creditCard,
      AccountCategory.fixedDeposit,
      AccountCategory.loan,
    };
    return bankCategories.contains(a.category) && a.institution.isNotEmpty;
  }

  /// hero-pick：右上角 pill「已绑定实名 · 银行直连」（对齐 OD .hero-pick）。
  /// r9 + padding 8/14 + shieldCheck 金色。F26:白底 8%/白描边 14%/白字 85%
  /// 白系豁免退役 → fg 8% 派生底 + border 语义描边 + fg 文本。
  Widget _heroPick() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: context.yucai.fg.withValues(alpha: 0.08),
          border: Border.all(color: context.yucai.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.shieldCheck,
              size: 15,
              color: context.yucai.accent,
            ),
            const SizedBox(width: 8),
            Text(
              '已绑定实名 · 银行直连',
              style: TextStyle(
                fontSize: 12.5,
                color: context.yucai.fg,
              ),
            ),
          ],
        ),
      );

  /// 按 account.category 映射类型 lucide icon（hero-badge 第1徽章前置图标）。
  IconData _categoryIcon(AccountCategory c) => switch (c) {
        AccountCategory.savings => LucideIcons.landmark,
        AccountCategory.fixedDeposit => LucideIcons.landmark,
        AccountCategory.creditCard => LucideIcons.creditCard,
        AccountCategory.investment => LucideIcons.trendingUp,
        AccountCategory.goldFx => LucideIcons.gem,
        AccountCategory.realEstate => LucideIcons.building2,
        AccountCategory.loan => LucideIcons.landmark,
        AccountCategory.otherAsset => LucideIcons.wallet,
        AccountCategory.otherLiability => LucideIcons.wallet,
      };

  /// hero-badge：第1金色实心（icon + 文字）；第2 ghost（半透明）。
  /// 对齐 OD .hero-badge（金底 #b08d57 18% + 金描边 32% + #e0bd84 字 + bank icon）
  /// 与 .hero-badge.ghost（白底 7% + 白描边 12% + 白字 70%）。F26:ghost 的白系
  /// 豁免退役 → fg 7% 派生底 + border 语义描边 + muted 文本。
  Widget _heroBadge(String label, {IconData? icon, bool ghost = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ghost
                ? context.yucai.border
                : context.yucai.accent.withValues(alpha: 0.32),
          ),
          color: ghost
              ? context.yucai.fg.withValues(alpha: 0.07)
              : context.yucai.accent.withValues(alpha: 0.18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: context.yucai.accent),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.02,
                color: ghost ? context.yucai.muted : context.yucai.accent,
              ),
            ),
          ],
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
      if (cents != null && cents != 0) {
        fields.add((label, _fmt(cents, a.currencyCode)));
      }
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
      case AccountCategory.otherLiability:
        // F35 扩展:otherLiability(个人待还款)同待遇。
        if (_linkedDebts.isNotEmpty) {
          final first2 = _linkedDebts.reduce((x, y) =>
              (x.nextPaymentDate ?? DateTime(9999))
                      .isBefore(y.nextPaymentDate ?? DateTime(9999))
                  ? x
                  : y);
          addNum('原始本金',
              _linkedDebts.fold<int>(0, (s, d) => s + d.totalPrincipalCents));
          addNum('剩余本金',
              _linkedDebts.fold<int>(0, (s, d) => s + d.remainingPrincipalCents));
          addNum('剩余利息',
              _linkedDebts.fold<int>(0, (s, d) => s + d.unpaidInterestCents));
          addNum('月供', first2.nextPaymentAmountCents);
          if (first2.nextPaymentDate != null) {
            addDate('下次还款', first2.nextPaymentDate);
          }
        } else {
          addNum('原始本金', a.loanOriginalCents);
          addNum('剩余本金', a.loanRemainingCents);
          addNum('月供', a.loanMonthlyCents);
          addDate('下次还款', a.loanNextPaymentDate);
        }
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
        // otherLiability 已由上方 loan 债务行分支覆盖(F35 扩展)。
        // 对齐 OD .hero-fields 储蓄分支 4 字段：
        // 年化利率 / 开户日期 / 账户类型 ·活期·定期 / 币种（code + 中文名）。
        addRate('年化利率', a.interestRate);
        addDate('开户日期', a.openingDate);
        final liquidity =
            a.category == AccountCategory.fixedDeposit ? '定期' : '活期';
        add('账户类型', '${a.category.label} · $liquidity');
        final cn = _currencyName(a.currencyCode);
        add('币种', cn.isEmpty ? a.currencyCode : '${a.currencyCode} $cn');
    }

    return Container(
      // OD .hero-fields：padding-top 22 + 顶部细分割线。F26:白透分隔线
      // (#1AFFFFFF)豁免退役 → border 语义令牌。
      padding: const EdgeInsets.only(top: 22),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.yucai.border, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (ctx, c) {
          // 断点用 viewport 宽（MediaQuery）对齐 OD @media 900，而非 content 宽
          //（content = viewport - sidebar 240，会偏移断点）。
          final isDesktop = MediaQuery.of(ctx).size.width > 900;
          return GridView.count(
            key: const ValueKey('heroFields'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isDesktop ? 4 : 2,
            // OD .hero-fields gap 18px。
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            childAspectRatio: 2.6,
            children: [for (final f in fields) _heroField(f.$1, f.$2)],
          );
        },
      ),
    );
  }

  /// hero-field：浅色 label + fg value 的单格(F26 白系文本已语义令牌化)。
  Widget _heroField(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.yucai.muted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: context.yucai.fg,
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
    // F35 验收:loan 账户挂债时隐藏 stats 条——4 卡读账户静态贷款字段
    // (loanOriginalCents 等从未回填,恒 0),且标签与上方债务实时信息卡
    // 完全重合;已还比例已挪入信息卡债务行。
    if (a.category == AccountCategory.loan && _linkedDebts.isNotEmpty) {
      return const SizedBox.shrink();
    }
    final stats = _statsFor(a: a, txns: txns, summary: summary);
    // 4 卡按位置映射 colored icon square（OD .stat-ico 24×24 r6，icon ico-sm 15px）：
    //   card1 收入 → bg #e1efe8 + income-green LucideIcons.trendingUp
    //   card2 支出 → bg #f6e3e1 + expense-red LucideIcons.trendingDown
    //   card3 净流入 → bg #f3ebdd (accent-soft) + accent-gold LucideIcons.wallet
    //   card4 交易 → bg #e3ecf7 + #3b6fb0 blue LucideIcons.fileText
    // 全 account 类型共用同一 4 卡 icon set（按位置，不按 category）。
    // Lucide 线性 stroke 2px（最接近 OD 原型 inline SVG stroke 1.6px），取代
    // Task 14 的 Material 实心 icon。fileText 在 lucide 0.257 无 notebookText。
    // F4-P2:icon 方块软底由语义令牌 12% 派生(原 v1 硬软底 #E1EFE8/#F6E3E1/
    // #E3ECF7 为亮板专用,暗色下随令牌呈微亮底);蓝 #3B6FB0 → info 令牌
    // (同「中性信息」语义,暗色自动提亮)。
    final iconSpecs = <(Color, Color, IconData)>[
      (context.yucai.positive.withValues(alpha: 0.12),
          context.yucai.positive, LucideIcons.trendingUp),
      (context.yucai.negative.withValues(alpha: 0.12),
          context.yucai.negative, LucideIcons.trendingDown),
      (context.yucai.accentSoft, context.yucai.accent, LucideIcons.wallet),
      (context.yucai.info.withValues(alpha: 0.12),
          context.yucai.info, LucideIcons.fileText),
    ];
    // OD .stat-row：>900 4 列 / ≤900 2 列（gap 14）。
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900;
    return GridView.count(
      key: const ValueKey('statsRow'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 2 : 4,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      // 固定卡高(mainAxisExtent):内容 = label Row(24) + 6 + val(24) + 4 + tag(16)
      // + DataCard padding(30) ≈ 104,留余量 116。原 childAspectRatio(isTablet?3.0:1.6)
      // 在窄屏算出卡高 55-79 < 内容 104,导致 stat 文本竖向溢出卡高度。
      mainAxisExtent: 116,
      children: [
        for (var i = 0; i < stats.length; i++)
          DataCard(
            padding: const EdgeInsets.fromLTRB(17, 15, 17, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatIconSquare(
                      bg: iconSpecs[i].$1,
                      fg: iconSpecs[i].$2,
                      icon: iconSpecs[i].$3,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(stats[i].$1,
                          style: TextStyle(
                              color: context.yucai.muted, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(stats[i].$2,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: context.yucai.accentSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('实时',
                      style: TextStyle(
                        color: context.yucai.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      )),
                ),
              ],
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
          ('信用额度', _fmtSigned(limit, a.currencyCode)),
          ('已用额度', _fmtSigned(used, a.currencyCode)),
          ('可用额度', _fmtSigned(avail, a.currencyCode)),
          ('账单日', '${a.creditBillingDay ?? '-'}日'),
        ];
      case AccountCategory.loan:
        final orig = a.loanOriginalCents ?? 0;
        final remain = a.loanRemainingCents ?? 0;
        final repaidPct = orig > 0 ? ((orig - remain) / orig * 100) : 0.0;
        return [
          ('原始本金', _fmtSigned(orig, a.currencyCode)),
          ('剩余本金', _fmtSigned(remain, a.currencyCode)),
          ('月供', _fmtSigned(a.loanMonthlyCents ?? 0, a.currencyCode)),
          ('已还比例', '${repaidPct.toStringAsFixed(1)}%'),
        ];
      case AccountCategory.investment:
        return [
          ('当前市值', _fmtSigned(a.investMarketValueCents ?? 0, a.currencyCode)),
          ('投入成本', _fmtSigned(a.investCostCents ?? 0, a.currencyCode)),
          ('今年收益率', '${(a.investReturnYtd ?? 0).toStringAsFixed(2)}%'),
          ('持仓交易数', '${txns.length}'),
        ];
      case AccountCategory.fixedDeposit:
        return [
          ('本金', _fmtSigned(a.fixedPrincipalCents ?? 0, a.currencyCode)),
          ('到期日', a.fixedMaturityDate == null
              ? '-'
              : _fmtDate(a.fixedMaturityDate!)),
          ('年化利率', '${(a.interestRate ?? 0).toStringAsFixed(2)}%'),
          ('$_scopeLabel收支', _fmtSigned(summary?.netCents ?? 0, a.currencyCode)),
        ];
      case AccountCategory.goldFx:
        final cur = a.goldCurrentPriceCents ?? 0;
        final buy = a.goldBuyPriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return [
          ('现值', _fmtSigned(
              (cur * (a.goldQuantity ?? 0)).toInt(), a.currencyCode)),
          ('买入价', _fmtSigned(buy, a.currencyCode)),
          ('涨幅', '${pct.toStringAsFixed(2)}%'),
          ('$_scopeLabel收支', _fmtSigned(summary?.netCents ?? 0, a.currencyCode)),
        ];
      case AccountCategory.realEstate:
        final cur = a.estateCurrentValueCents ?? 0;
        final buy = a.estatePurchasePriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return [
          ('现估值', _fmtSigned(cur, a.currencyCode)),
          ('买入价', _fmtSigned(buy, a.currencyCode)),
          ('增值率', '${pct.toStringAsFixed(2)}%'),
          ('$_scopeLabel收支', _fmtSigned(summary?.netCents ?? 0, a.currencyCode)),
        ];
      case AccountCategory.savings:
      case AccountCategory.otherAsset:
      case AccountCategory.otherLiability:
        return [
          ('$_scopeLabel收入', _fmtSigned(summary?.incomeCents ?? 0, a.currencyCode)),
          ('$_scopeLabel支出', _fmtSigned(summary?.expenseCents ?? 0, a.currencyCode)),
          ('$_scopeLabel净流入', _fmtSigned(summary?.netCents ?? 0, a.currencyCode)),
          // Issue ②: 交易数 must match the scope of the other three cards
          // (which are scope-scoped via the summary RPC). The txns list is
          // account-scoped (all recent), so filter it by the current scope:
          // DAY = today, MONTH = this month, YEAR = this year. Otherwise the
          // count was inconsistent (scope-scoped totals + all-recent count).
          ('$_scopeLabel交易', '${_txnCountInScope(txns)}'),
        ];
    }
  }

  /// Counts the transactions in [txns] that fall within the current [_scope]
  /// (本日/本月/本年), based on each txn's calendar [Transaction.transactionDate]
  /// (local time). Used by the savings/other stat-card 4th tile so all four
  /// cards reflect the same period as the scope-scoped income/expense/net.
  int _txnCountInScope(List<Transaction> txns) {
    final now = DateTime.now();
    int inScope(Transaction t) {
      final d = t.transactionDate;
      switch (_scope) {
        case SummaryScope.day:
          return d.year == now.year &&
                  d.month == now.month &&
                  d.day == (_day ?? now.day)
              ? 1
              : 0;
        case SummaryScope.month:
          return d.year == now.year && d.month == now.month ? 1 : 0;
        case SummaryScope.year:
          return d.year == now.year ? 1 : 0;
      }
    }
    return txns.fold(0, (acc, t) => acc + inScope(t));
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
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 12)),
              ),
            ),
          ],
        ),
      );

  /// 近期交易 panel（F9 FR-2 升级为标准查询套件）：接 TransactionBloc 的
  /// account-scoped 分页列表（pageSize 100，第 N 页切片替换）。头部加
  /// 搜索框 + 排序控件（复用 F7 的 TxnSearchField/TxnSortControl —— 它们
  /// 依赖 transaction domain 的 TxnSortKey/TxnSortDir 类型，提升到 core 会
  /// 造成 core → 模块 domain 的反向依赖，故保持落点、跨模块 presentation
  /// import，与页内既有的 txn_category_icon/transaction_form_page 同模式）；
  /// 底部挂共享 PagerBar（单页隐藏，照 F7 _showPager 语义）。
  /// 空列表显示占位文案；行渲染仍是紧凑行（描述 + 金额，不用 TxnRow 宽表
  /// —— 该 panel 在窄列里，TxnRow 会溢出）。
  Widget _recentTxnPanel(TransactionState txnState, String currencyCode) {
    final txns = txnState is TransactionsLoaded
        ? txnState.transactions
        : (txnState is TransactionsLoadingMore
            ? txnState.transactions
            : const <Transaction>[]);
    final filter = _txnFilterOf(txnState);
    final pageIndex = txnState is TransactionsLoaded
        ? txnState.pageIndex
        : (txnState is TransactionsLoadingMore ? txnState.pageIndex : 0);
    final hasMore = txnState is TransactionsLoaded
        ? txnState.hasMore
        : (txnState is TransactionsLoadingMore ? txnState.hasMore : false);
    final loadingMore = txnState is TransactionsLoadingMore;
    // 单页（hasMore==false 且 pageIndex==0）整个分页条隐藏；翻页请求中
    // （loadingMore）保持显示 —— LoadingMore 态的 nextPageToken 是「正在取
    // 的页」token（prev 回第 1 页时为空 → hasMore 推出 false），不含 loading
    // 态会瞬闪隐藏，loading 双禁已防连点（照 F7 _showPager 语义逐位）。
    final showPager = hasMore || pageIndex > 0 || loadingMore;
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
                  Text('本页 ${txns.length} 笔',
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 12)),
                  const SizedBox(width: AppSpacing.md),
                  // 查看全部 → 交易列表（/transactions 在独立 branch，context.go
                  // 切换 branch；route 不支持 account 预筛 query，故仅导航）。
                  InkWell(
                    onTap: () => context.go('/transactions'),
                    child: Text('查看全部 →',
                        style: TextStyle(
                            color: context.yucai.accent, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // F9 FR-2 轻量控件行：搜索（提交制 —— 回车/清除才触发重查，防逐键
          // 重载丢焦点）+ 排序四态。口径与交易列表页一致（复用 F7 widget）。
          Row(
            children: [
              Expanded(
                child: TxnSearchField(
                  value: filter.searchText ?? '',
                  onCommit: _onTxnSearchCommit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TxnSortControl(
                sortKey: filter.sortKey,
                sortDir: filter.sortDir,
                onChanged: _onTxnSortChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (txns.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无交易',
                    style: TextStyle(color: context.yucai.muted, fontSize: 12)),
              ),
            )
          else
            for (final t in txns) _recentTxnRow(t, currencyCode),
          if (showPager) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              // F9 FR-1 共享 PagerBar：翻页 = GoToTransactionsPageRequested
              //（filter 不变，bloc 内共享 PageCursorStack 换 token 重查切片）。
              child: PagerBar(
                pageIndex: pageIndex,
                hasMore: hasMore,
                loading: loadingMore,
                onPrev: _txnPrevPage,
                onNext: _txnNextPage,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 从 TransactionBloc 状态读回当前交易筛选（F9 单源真值；与
  /// transactions_page._filter 同口径）。非 list-bearing 状态（Initial /
  /// detail 系）回退本账户默认筛选 —— 日期降序、无搜索（NFR-2 首屏语义）。
  TxnFilterState _txnFilterOf(TransactionState s) => switch (s) {
        TransactionsLoaded s => s.filter,
        TransactionsLoadingMore s => s.filter,
        TransactionsLoading s => s.filter,
        TransactionsError s => s.filter,
        _ => TxnFilterState(accountId: widget.id),
      };

  /// 当前 bloc 状态的筛选（供控件受控值与筛选变化 handler 读取）。
  TxnFilterState _currentTxnFilter() =>
      _txnFilterOf(context.read<TransactionBloc>().state);

  /// F9 FR-2 搜索提交（回车/清除）：换 filter 重查 —— Load 事件即
  /// 「重置第 1 页」（bloc 清 PageCursorStack、pageIndex 归 0），照 F7 语义。
  void _onTxnSearchCommit(String v) {
    context.read<TransactionBloc>().add(LoadTransactionsRequested(
        filter: _currentTxnFilter()
            .copyWith(searchText: v.isEmpty ? null : v)));
  }

  /// F9 FR-3 排序四态切换：同样走 Load 事件（重置第 1 页）。
  void _onTxnSortChanged(TxnSortKey key, TxnSortDir dir) {
    context.read<TransactionBloc>().add(LoadTransactionsRequested(
        filter: _currentTxnFilter().copyWith(sortKey: key, sortDir: dir)));
  }

  /// F9 FR-2 翻页：filter 不变，仅换 pageToken（bloc 内共享 PageCursorStack
  /// 维护前进/回退游标，回第 1 页用栈内空串 token）。
  void _txnPrevPage() => context.read<TransactionBloc>()
      .add(const GoToTransactionsPageRequested(TxnPageDirection.prev));

  void _txnNextPage() => context.read<TransactionBloc>()
      .add(const GoToTransactionsPageRequested(TxnPageDirection.next));

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
  Widget _recentTxnRow(Transaction t, String currencyCode) {
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
        ? context.yucai.positive
        : (flavour == TxnFlavour.expense ? context.yucai.negative : context.yucai.fg);

    return InkWell(
      key: ValueKey('recentTxn-${t.id}'),
      onTap: () => context.push('/transactions/${t.id}'),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
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
                  style: TextStyle(
                      color: context.yucai.muted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(dateLabel,
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isNegative
                ? '-${_fmtSigned(signedAmount.abs(), currencyCode)}'
                : (flavour == TxnFlavour.income
                    ? '+${_fmtSigned(signedAmount, currencyCode)}'
                    : _fmtSigned(signedAmount, currencyCode)),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: amountColor,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
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
  /// 容器 bg `#f7f6f2`（context.yucai.bg）+ 边框 `#e6e3dc`（context.yucai.border），
  /// active 段白底（context.yucai.surface）；inactive 段透明、灰字（context.yucai.muted）。
  /// active 段文字用 accent-press 金 `#98773f`（比 accent 更深，对齐 OD press 态）。
  /// 三段等宽，整组圆角 AppRadius.sm。
  Widget _periodSegmentedControl() {
    /// accent-press 金（OD 原型 active 段文字色，比 context.yucai.accent 更深）。
    final accentPress = context.yucai.accentDeep;
    const segments = [
      (SummaryScope.day, '日'),
      (SummaryScope.month, '月'),
      (SummaryScope.year, '年'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: context.yucai.bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.yucai.border),
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
          color: active ? context.yucai.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? activeColor : context.yucai.muted,
          ),
        ),
      ),
    );
  }

  /// 收支统计 panel：双色饼图 + 圆心净流入 + 图例（Task 13，对齐 OD .pie-wrap）。
  ///
  /// 双色饼图（取代 Task 8 按分类多色）：income 弧绿 + expense 弧红，
  /// 占比按 incomeCents/expenseCents 相对 (income+expense) 计算。圆心 overlay
  /// 显净流入（+¥X 正绿 / -¥X 负红）+「本X净流入」label（scope-aware via
  /// [_scopeLabel]）。图例 2 行：收入类 / 支出类（色点 + 金额 · 占比）。
  ///
  /// income+expense == 0 时改显占位「暂无收支」（避免除零 + 空弧）。
  Widget _summaryPanel(MonthlySummary? summary, String currencyCode) {
    final income = summary?.incomeCents ?? 0;
    final expense = summary?.expenseCents ?? 0;
    final net = summary?.netCents ?? 0;
    final total = income + expense;
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
          if (total == 0)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('暂无收支',
                    style: TextStyle(color: context.yucai.muted, fontSize: 12)),
              ),
            )
          else ...[
            _pieChart(income, expense, net, currencyCode),
            const SizedBox(height: AppSpacing.md),
            _legendRow(
                label: '收入类',
                amountCents: income,
                total: total,
                isIncome: true,
                currencyCode: currencyCode),
            _legendRow(
                label: '支出类',
                amountCents: expense,
                total: total,
                isIncome: false,
                currencyCode: currencyCode),
          ],
        ],
      ),
    );
  }

  /// 双色饼图：CustomPaint(_DonutPainter) + 圆心 overlay 净流入 + scope label。
  /// 净流入正 → context.yucai.positive（绿）；负 → context.yucai.negative（红）。
  Widget _pieChart(
      int incomeCents, int expenseCents, int netCents, String currencyCode) {
    final netColor =
        netCents >= 0 ? context.yucai.positive : context.yucai.negative;
    // 净流入金额带符号：正 + / 负 -（_fmtSigned 已含负号；正号此处补）。
    final netLabel = netCents >= 0
        ? '+${_fmtSigned(netCents, currencyCode)}'
        : _fmtSigned(netCents, currencyCode);
    return Center(
      child: SizedBox(
        width: 128,
        height: 128,
        child: CustomPaint(
          painter: _DonutPainter(
              incomeCents: incomeCents,
              expenseCents: expenseCents,
              // 背景环 = surfaceAlt(暗色随卡面浅一档)。
              trackColor: context.yucai.surfaceAlt,
              incomeColor: context.yucai.positive,
              expenseColor: context.yucai.negative),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(netLabel,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: netColor,
                        fontFeatures: AppTypography.tabularFigures)),
                Text('$_scopeLabel净流入',
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 图例行：色点 + 标签（收入类/支出类）+ 金额 · 占比%（对齐 OD .legend-row）。
  /// [isIncome] 决定色点颜色（收入绿 / 支出红）。
  Widget _legendRow({
    required String label,
    required int amountCents,
    required int total,
    required bool isIncome,
    required String currencyCode,
  }) {
    final pct = total > 0 ? (amountCents / total * 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isIncome ? context.yucai.positive : context.yucai.negative,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Text(label,
              style: TextStyle(color: context.yucai.muted, fontSize: 12)),
          const Spacer(),
          Text(
              '${_fmtSigned(amountCents, currencyCode)} · ${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                  color: context.yucai.muted,
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
  /// F9：list 重载保留当前搜索/排序（从 bloc 状态读回 filter；仍走 Load
  /// 事件 = 重置第 1 页，与 F7 语义一致）。
  void _refreshTxn() {
    final b = context.read<TransactionBloc>();
    final now = DateTime.now();
    b.add(LoadTransactionsRequested(filter: _currentTxnFilter()));
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

  String _fmt(int cents, String currencyCode) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign${currencySymbol(currencyCode)} $yuan.$fen';
  }

  /// 千分位 + 两位小数（与 SummaryCard 格式一致：¥1,234.56）。负数保留负号。
  String _fmtSigned(int cents, String currencyCode) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    final yuanStr = _groupThousands(yuan);
    return '$sign${currencySymbol(currencyCode)}$yuanStr.$frac';
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

/// 收支统计双色饼图 painter（Task 13，对齐 OD .pie-wrap）。
///
/// 仅两段弧（取代 Task 8 的按分类多色）：
///   - income 弧：[incomeColor]（context.yucai.positive），占比 = incomeCents/total。
///   - expense 弧：[expenseColor]（context.yucai.negative），占比 = expenseCents/total。
///
/// 12 点起顺时针先画 income 再画 expense。背景环 [trackColor]。total == 0 时仅画
/// 背景环（由调用方在 income+expense==0 时改为渲染占位，不走本 painter）。
///
/// F4-P2:CustomPainter 无 context,三色由调用方(_pieChart)从 context.yucai
/// 解析后经构造注入,暗色跟随主题(原 AppColors 静态量 = 亮色锁定)。
class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.incomeCents,
    required this.expenseCents,
    required this.trackColor,
    required this.incomeColor,
    required this.expenseColor,
  });

  final int incomeCents;
  final int expenseCents;
  final Color trackColor;
  final Color incomeColor;
  final Color expenseColor;

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
        ..color = trackColor,
    );
    final total = incomeCents + expenseCents;
    if (total == 0) return;
    final rect =
        Rect.fromCircle(center: center, radius: radius - thickness / 2);
    // income 绿弧（12 点起）。
    final incomeSweep = (incomeCents / total) * 2 * pi;
    canvas.drawArc(
      rect,
      -pi / 2,
      incomeSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = incomeColor,
    );
    // expense 红弧（紧接 income 弧之后）。
    final expenseSweep = (expenseCents / total) * 2 * pi;
    canvas.drawArc(
      rect,
      -pi / 2 + incomeSweep,
      expenseSweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = expenseColor,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.incomeCents != incomeCents ||
      old.expenseCents != expenseCents ||
      old.trackColor != trackColor ||
      old.incomeColor != incomeColor ||
      old.expenseColor != expenseColor;
}

/// 近期交易行的账户列解析结果（_recentTxnRow 内部用）。
class _RecentTxnCell {
  const _RecentTxnCell({required this.subLine, this.categoryAccount});
  final String subLine;
  final Account? categoryAccount;
}

/// 分类 icon 圆角方块（income 绿 #2d8a6e / expense 红 #c4544d / transfer 灰
/// #8a8b8f）。OD .txn-cat 36×36 r10，白色 lucide 线性 icon（stroke ~1.7）。
///
/// icon 按「分类语义」而非方向箭头选（对齐 OD 近期交易行 income→coins /
/// expense→receipt / transfer→card）：
///   - income → coins（默认）；可按分类 name 细化：工资→banknote / 利息→percent。
///   - expense → receipt（默认）；按分类 name 细化：餐饮→utensils / 购物→shoppingBag
///     / 交通→car / 娱乐→gamepad / 医疗→heartPulse。
///   - transfer / compound → creditCard（保留 arrowLeftRight 兜底语义）。
class _TxnTypeIcon extends StatelessWidget {
  const _TxnTypeIcon({required this.flavour, this.categoryAccount});
  final TxnFlavour flavour;
  final Account? categoryAccount;

  @override
  Widget build(BuildContext context) {
    final bg = switch (flavour) {
      TxnFlavour.income => context.yucai.positive,
      TxnFlavour.expense => context.yucai.negative,
      TxnFlavour.transfer => context.yucai.muted,
      TxnFlavour.compound => context.yucai.muted,
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      // F27 FR-1② 豁免:icon 方块底为交易类目身份彩底(positive/negative/
      // muted 品类色,OD .txn-cat 白色线性 icon)—— 固定白双板可辨识。
      child: Icon(txnCategoryIcon(flavour, categoryAccount),
          size: 18, color: Colors.white),
    );
  }
}

/// stat 卡 colored icon square（OD .stat-ico 24×24 r6，icon ico-sm 15px）。
/// bg = 浅色品类色（收入 #e1efe8 / 支出 #f6e3e1 / 净流入 #f3ebdd / 交易 #e3ecf7），
/// fg = 同色系深色（用于 icon）。尺寸/圆角对齐原型，lucide 线性 icon。
class _StatIconSquare extends StatelessWidget {
  const _StatIconSquare({
    required this.bg,
    required this.fg,
    required this.icon,
  });
  final Color bg;
  final Color fg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 15, color: fg),
    );
  }
}
