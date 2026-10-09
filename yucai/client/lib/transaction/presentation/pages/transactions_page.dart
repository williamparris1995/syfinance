import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/core/widgets/current_route_selection_area.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:design_kit/design_kit.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';
import 'package:yucai_client/transaction/presentation/widgets/summary_card.dart';
import 'package:yucai_client/transaction/presentation/widgets/txn_category_icon.dart';

/// 交易列表页。对齐 YNAB/MoneyWiz 式桌面主流形态(反馈#2-B 无限滚动改版):
///   - 页头：H1 + 副标题（月份 · 共 N 笔）+ 导出按钮
///   - 汇总四卡（SummaryCard）—— 本月收入/支出/净额/日均
///   - TxnFilterBar（搜索框 + 类型分段 + 账户/分类/月份下拉 + 排序 + 重置，F7）
///   - 单一 ListView.builder 虚拟化列表,数据 = 分组展开模型：
///     月份组头（「YYYY年M月」+ 当月收入/支出小计）→ 日分隔条 → 表格行
///     （日期 / 交易详情（图标+描述）/ 分类 chip / 账户标签 / 金额 / ⋯ 操作）
///   - 滚动加载：距底 <400px 自动追加下一页（首页 [listPageSize] 条，追加
///     同页大小）；hasMore=false 页脚显示「已全部加载 · 共 N 条」（N=累计）
///   - Mobile：卡片堆叠 + 汇总四宫格（TxnRow 移动分支），同一分组展开模型
///
/// 三尺寸响应式（Desktop ≥1200 / Tablet 600–1200 / Mobile ≤600）。
///
/// Bloc 来源（按优先级）：
///   1. [bloc] 构造参数 —— 测试注入预构造 bloc。
///   2. 路由层 BlocProvider —— 生产路径（见 router.dart `/transactions` 分支）。
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key, this.bloc, this.initialFilter});

  /// 无限滚动首页/追加页大小（反馈#2-B 拍板 50）。路由层首查与本页内的
  /// 筛选/回拉/滚动追加共用同一常量;account_detail 近期交易不经过本页,
  /// 仍走事件默认 pageSize 100(F9 口径,见 TransactionBloc)。
  static const int listPageSize = 50;

  /// 测试可注入预构造 bloc；生产路径留空，bloc 由路由层 BlocProvider 提供。
  final TransactionBloc? bloc;

  /// 初始筛选(F8 FR-3:标签页跳转携 tagId 经路由 extra 注入);null = 默认。
  /// 列表首查由路由层 bloc.create 派发(同一 filter),这里只用于 initState
  /// 的 summary 请求对齐口径。
  final TxnFilterState? initialFilter;

  @override
  Widget build(BuildContext context) {
    final injected = bloc;
    if (injected != null) {
      return BlocProvider<TransactionBloc>.value(
        value: injected,
        child: _TransactionsView(initialFilter: initialFilter),
      );
    }
    // 生产路径：bloc 由路由层 `/transactions` 分支的 BlocProvider 提供。
    return _TransactionsView(initialFilter: initialFilter);
  }
}

class _TransactionsView extends StatefulWidget {
  const _TransactionsView({this.initialFilter});

  /// 见 [TransactionsPage.initialFilter]。
  final TxnFilterState? initialFilter;

  @override
  State<_TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<_TransactionsView> with RouteAware {
  @override
  void initState() {
    super.initState();
    // Kick off the initial summary fetch alongside the list load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // F8 FR-3:初始筛选(标签跳转)存在时按其口径请求 summary(month 维度
      // 对齐;tagId 不参与列表页 summary 口径,FR-4 只覆盖报表页)。
      _requestSummary(widget.initialFilter ?? const TxnFilterState());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅 transactions branch 专用 RouteObserver(F14 疑点 #3,照
    // accounts_page 先例):本页位于 StatefulShellRoute 的 IndexedStack 分支
    // 内常驻,顶栏创建(/transactions/new)或详情/编辑页提交 pop 回来时不会
    // 自动重建 —— didPopNext 统一触发回拉。前提:transactions branch 已挂
    // observers:[transactionsRouteObserver](router.dart),push/pop 都发生在
    // 该 branch 的嵌套 Navigator 上。
    transactionsRouteObserver.subscribe(
        this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    transactionsRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // F14 疑点 #3:pop 回列表 → 既有 Load 路径回拉(保留筛选,照 F7 语义,
    // _reloadAfterMutation 读当前 state.filter)。
    if (!mounted) return;
    _reloadAfterMutation();
  }

  /// Emits a [LoadSummaryRequested] matching [filter]'s month (or the current
  /// calendar month when no month filter is set). Safe to call repeatedly.
  void _requestSummary(TxnFilterState filter) {
    final scope = TransactionBloc.summaryScope(filter);
    context.read<TransactionBloc>().add(LoadSummaryRequested(
          year: scope.year,
          month: scope.month,
          accountId: filter.accountId,
        ));
  }

  /// FilterBar 受控状态：任何变化都重新发起 LoadTransactionsRequested +
  /// LoadSummaryRequested。Load = 重置第 1 页(#2-B:追加页清零)。
  void _onFilterChanged(TxnFilterState next) {
    final bloc = context.read<TransactionBloc>();
    bloc.add(LoadTransactionsRequested(
        filter: next, pageSize: TransactionsPage.listPageSize));
    _requestSummary(next);
  }

  Future<void> _openCreateForm() async {
    final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const TransactionFormPage(),
          ),
        ) ??
        false;
    if (ok && mounted) {
      // 回拉统一由 didPopNext 承担(F14 #3):本 push 也落在 branch 的嵌套
      // Navigator 上,pop 必触发 RouteAware;此处只负责成功 toast,避免
      // 双重 Load 造成两次 loading 闪烁。
      AppToast.show(context, '交易已记录');
    }
  }

  void _reloadAfterMutation() {
    final bloc = context.read<TransactionBloc>();
    final state = bloc.state;
    final filter = state is TransactionsLoaded
        ? state.filter
        : (state is TransactionsError ? state.filter : const TxnFilterState());
    bloc.add(LoadTransactionsRequested(
        filter: filter, pageSize: TransactionsPage.listPageSize));
    _requestSummary(filter);
  }

  void _openDetail(String id) {
    // GoRouter 管理 /transactions/:id —— Navigator.pushNamed 不认(GoRouter 用
    // context.push by path)。改 context.push,mobile 整卡 tap + tablet/desktop
    // more 按钮(_RowOpMenu)都走此 → 跳交易详情。
    context.push('/transactions/$id');
  }

  void _export() {
    // 导出占位：原型有「导出」按钮但后端导出 RPC 尚未落地；此处仅提示。
    if (!mounted) return;
    AppToast.show(context, '导出功能即将上线');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      // 创建入口移至全局 _TopBar(app_shell 路由感知创建按钮 /transactions/new);
      // emptyState 仍保留 _openCreateForm 引导。
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listener: (context, state) {
          // 错误态统一在 builder 内的 _ErrorView 展示（含重试按钮），
          // 不再额外弹 toast，避免「错误文案」在屏幕上重复出现。
        },
        builder: (context, state) {
          if (state is TransactionsInitial || state is TransactionsLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TransactionsError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context
                  .read<TransactionBloc>()
                  .add(RetryTransactionsRequested()),
              onCreate: _openCreateForm,
            );
          }
          // TransactionsLoaded / TransactionsLoadingMore —— 两者都携带列表。
          if (state is! TransactionsLoaded && state is! TransactionsLoadingMore) {
            return const Center(child: CircularProgressIndicator());
          }
          // 空列表(如切到无记录月份)保留 _Content 的 header(mobile month-bar/
          // sum-card/筛选 或 desktop _Header/SummaryCard/TxnFilterBar),列表区
          // 显示空提示(不再全屏 _EmptyView 覆盖 header)。
          return _Content(
            state: state,
            loadingMore: state is TransactionsLoadingMore,
            onFilterChanged: _onFilterChanged,
            onCreate: _openCreateForm,
            onExport: _export,
            onOpenDetail: _openDetail,
            // 反馈1b:右键删除后回拉(保留筛选,同 didPopNext 语义)。
            onRowDeleted: _reloadAfterMutation,
          );
        },
      ),
    );
  }
}

// ───────────────────────── 主内容 ─────────────────────────
//
// #2-B 无限滚动:列表区改为单一 ListView.builder(虚拟化),数据 = 分组
// 展开模型(头块 → 月份组头 → 日分隔 → 行 … 页脚)。滚动控制器归 _Content
// State 持有:距底 <400px 发 LoadMoreTransactionsRequested(页面侧仅
// Loaded+hasMore 才发,bloc 侧 LoadingMore 再兜一道防抖)。

class _Content extends StatefulWidget {
  const _Content({
    required this.state,
    required this.loadingMore,
    required this.onFilterChanged,
    required this.onCreate,
    required this.onExport,
    required this.onOpenDetail,
    this.onRowDeleted,
  });

  /// TransactionsLoaded or TransactionsLoadingMore (both carry the list).
  final TransactionState state;
  final bool loadingMore;
  final ValueChanged<TxnFilterState> onFilterChanged;
  final VoidCallback onCreate;
  final VoidCallback onExport;
  final ValueChanged<String> onOpenDetail;

  /// 反馈1b:行右键删除成功后的回拉(透传至 _TxTableRow)。
  final VoidCallback? onRowDeleted;

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  /// 滚动加载触发阈值(#2-B):距底不足 400px 时追加下一页(预取一段
  /// 滚动余量,避免用户看到加载底)。
  static const double _loadMoreEdge = 400;

  /// 附着页面主滚动,仅用于读取**定形后**的距底 extent(见
  /// [_onScrollNotification] 的估值坑)。
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 距底触发追加(#2-B)。评估时机:
  ///  - [ScrollUpdateNotification]:滚动途中持续评估(真实设备连续拖动,
  ///    extent 估值随布局收敛,近底即触发);
  ///  - [ScrollEndNotification] + 帧后回调:滚动收尾时通知携带的 metrics
  ///    取自**布局刷新前**(ListView 的 maxExtent 是估值,大步拖动只发
  ///    一次 update 且估值偏大,通知口径会漏判)—— 帧后布局定形,按
  ///    controller 活值再评一次。
  ///
  /// 防抖:仅 Loaded 且 hasMore 才发;LoadingMore 在途期间 bloc 侧兜底
  /// 忽略(见 TransactionBloc._onLoadMore)。
  bool _onScrollNotification(ScrollNotification n) {
    // depth==0:只看本页滚动(过滤筛选输入框等内嵌 scrollable)。
    if (n.depth != 0) return false;
    switch (n) {
      case ScrollUpdateNotification():
        _maybeRequestLoadMore();
      case ScrollEndNotification():
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeRequestLoadMore();
        });
      default:
        break;
    }
    return false;
  }

  void _maybeRequestLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter >= _loadMoreEdge) return;
    final bloc = context.read<TransactionBloc>();
    final s = bloc.state;
    if (s is! TransactionsLoaded || !s.hasMore) return;
    bloc.add(const LoadMoreTransactionsRequested(
        pageSize: TransactionsPage.listPageSize));
  }

  TransactionState get _state => widget.state;

  List<Transaction> get _txns => _state is TransactionsLoaded
      ? (_state as TransactionsLoaded).transactions
      : (_state as TransactionsLoadingMore).transactions;

  TxnFilterState get _filter => _state is TransactionsLoaded
      ? (_state as TransactionsLoaded).filter
      : (_state as TransactionsLoadingMore).filter;

  String get _nextToken => _state is TransactionsLoaded
      ? (_state as TransactionsLoaded).nextPageToken
      : (_state as TransactionsLoadingMore).nextPageToken;

  bool get _hasMore => _nextToken.isNotEmpty;

  /// This month's summary. null until the parallel `TransactionSummary` RPC
  /// resolves; the card falls back to zeros.
  MonthlySummary? get _summary => _state is TransactionsLoaded
      ? (_state as TransactionsLoaded).summary
      : (_state as TransactionsLoadingMore).summary;

  @override
  Widget build(BuildContext context) {
    // 账户选项从 AccountRepository 拉一次（FutureBuilder，避免把账户状态
    // 塞进 TransactionBloc）。失败时退回空选项。
    return FutureBuilder<List<Account>>(
      future: _loadAccounts(context),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <Account>[];

        // Task 4: mobile 分支判定 —— 与 accounts_page 同断点(Breakpoints mobileUpper=600)。
        final isMobile = Breakpoints.of(context) == Breakpoint.mobile;

        // #2-B 分组展开模型:月份组 → 日组 → 行,序保持输入序(默认日期倒序)。
        final months = _groupByMonth(_txns, accounts);
        final items = <_TxnListItem>[
          _TxnListItem.headerBlock(),
          if (months.isEmpty)
            _TxnListItem.emptyHint()
          else ...[
            // 表头带仅 desktop/tablet(mobile 卡片堆叠无表格头)。
            if (!isMobile) _TxnListItem.tableHeader(),
            for (final m in months) ...[
              _TxnListItem.monthHeader(m),
              for (final d in m.days.entries) ...[
                _TxnListItem.dayHeader(d.key, d.value.length),
                for (final t in d.value) _TxnListItem.row(t),
              ],
            ],
          ],
          if (months.isNotEmpty)
            _TxnListItem.listEnd(
              loadingMore: widget.loadingMore,
              hasMore: _hasMore,
              totalCount: _txns.length,
            ),
        ];

        // 反馈⑥(桌面文本选择)+ 反馈1a 修复:页身自包 [SelectionArea]
        // (行内描述/金额可选可拖选)。取舍:全局 scope(builder 层包整个
        // Router)在多滚动容器并存时拖选边沿更新被静默丢弃(Flutter
        // #153004 家族,真机拖选全废);修法 = scope 下沉到**页面体**,
        // 每页一个、随页生灭 —— 无跨页/跨滚动容器注册,拖选真实工作
        // (integration e2e 双面钉死);表头/顶栏等 chrome 不选,与标题
        // 栏同口径。TextField/表单自持选择系统不受影响(本页无表单)。
        // 注意:不要上移到 shell/路由层 —— 路由 push 过场中注册会触发
        // SelectionContainer 排序对未布局盒的断言(router_test 回归)。
        return CurrentRouteSelectionArea(
          child: RefreshIndicator(
            onRefresh: () async => context.read<TransactionBloc>().add(
                LoadTransactionsRequested(
                    filter: _filter,
                    pageSize: TransactionsPage.listPageSize)),
            // #2-B:单一虚拟化列表(ListView.builder)承载整页滚动 ——
            // 头块/分组/行/页脚都是列表项,超长数据只构建视口内元素。
            // NotificationListener 承接滚动加载(见 _onScrollNotification);
            // AlwaysScrollable:空/短列表也可下拉刷新。
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: isMobile
                    ? const EdgeInsets.fromLTRB(4, 4, 4, 96)
                    : const EdgeInsets.fromLTRB(
                        AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final cell = _buildItem(
                    context,
                    items[index],
                    accounts: accounts,
                    isMobile: isMobile,
                  );
                  // 与旧版 Center+ConstrainedBox 同宽约束:桌面/平板内容列
                  // ≤1120 居中;mobile 全宽。
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: isMobile ? double.infinity : 1120),
                      child: cell,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// 单个列表项渲染(分组展开模型 → 具体 widget)。
  Widget _buildItem(
    BuildContext context,
    _TxnListItem item, {
    required List<Account> accounts,
    required bool isMobile,
  }) {
    switch (item) {
      case _TxnHeaderBlock():
        return _buildHeaderBlock(
          context,
          accounts: accounts,
          isMobile: isMobile,
        );
      case _TxnEmptyHint():
        return _EmptyListHint(onCreate: widget.onCreate);
      case _TxnTableHeaderBandItem():
        return const _TableHeaderBand();
      case _TxnMonthHeader(:final month):
        return _MonthRow(month: month);
      case _TxnDayHeader(:final label, :final count):
        return isMobile
            ? _DayHeader(label: label, count: count)
            : _DayRow(label: label, count: count);
      case _TxnRow(:final txn):
        return isMobile
            ? _MobileTxnCard(
                txn: txn,
                accountNameOf: (id) => _accountNameOf(accounts, id),
                accountOf: (id) => _accountOf(accounts, id),
                onTap: () => widget.onOpenDetail(txn.id),
              )
            // 无整卡包裹后,行落在 surface 色带上(与 surfaceAlt 分隔条
            // 交替),视觉沿用卡片内景;右键菜单接线不变(反馈1b)。
            : ColoredBox(
                color: context.yucai.surface,
                child: _TxTableRow(
                  txn: txn,
                  accountNameOf: (id) => _accountNameOf(accounts, id),
                  accountOf: (id) => _accountOf(accounts, id),
                  onOpenDetail: widget.onOpenDetail,
                  onDeleted: widget.onRowDeleted,
                ),
              );
      case _TxnListEnd(:final loadingMore, :final hasMore, :final totalCount):
        return _ListFooter(
          loadingMore: loadingMore,
          hasMore: hasMore,
          totalCount: totalCount,
          surfaceBand: !isMobile,
        );
    }
  }

  /// 头块(列表首项):desktop/tablet = 页头 + SummaryCard + 类型段 + 筛选
  /// 条;mobile = appbar + MobileHeader + 类型段。与旧版 Column 头部逐位
  /// 同构,只是从外层 Column 挪进列表首项。
  Widget _buildHeaderBlock(
    BuildContext context, {
    required List<Account> accounts,
    required bool isMobile,
  }) {
    final accountOptions = [
      for (final a in accounts) FilterOption(a.id, a.name),
    ];
    final categoryOptions = _categoryOptions(accounts);
    final monthOptions = _monthOptions();
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MobileAppBar(
            onFilter: () => _showMobileFilterSheet(
              context,
              accountOptions: accountOptions,
              categoryOptions: categoryOptions,
              monthOptions: monthOptions,
            ),
          ),
          MobileHeader(
            filter: _filter,
            count: _txns.length,
            summary: _summary,
            onFilterChanged: widget.onFilterChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          TxnTypeSeg(
            type: _filter.type,
            onChanged: (tf) =>
                widget.onFilterChanged(_filter.copyWith(type: tf)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          count: _txns.length,
          monthLabel: _currentMonthLabel(_filter),
          onCreate: widget.onCreate,
          onExport: widget.onExport,
        ),
        const SizedBox(height: AppSpacing.md),
        SummaryCard(
          incomeCents: _summary?.incomeCents ?? 0,
          expenseCents: _summary?.expenseCents ?? 0,
          netCents: _summary?.netCents ?? 0,
          dailyAvgCents: _summary?.dailyAvgCents ?? 0,
        ),
        const SizedBox(height: AppSpacing.md),
        TxnTypeSeg(
          type: _filter.type,
          onChanged: (tf) => widget.onFilterChanged(_filter.copyWith(type: tf)),
        ),
        const SizedBox(height: AppSpacing.md),
        TxnFilterBar(
          state: _filter,
          onChanged: widget.onFilterChanged,
          accountOptions: accountOptions,
          categoryOptions: categoryOptions,
          monthOptions: monthOptions,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  /// mobile 筛选 sheet 弹出(Task 2 MobileFilterSheet)。
  /// 由 _MobileAppBar 的筛选 btn 触发,应用筛选后回调 onFilterChanged 并关闭 sheet。
  void _showMobileFilterSheet(
    BuildContext context, {
    required List<FilterOption> accountOptions,
    required List<FilterOption> categoryOptions,
    required List<FilterOption> monthOptions,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.yucai.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => MobileFilterSheet(
        initial: _filter,
        accountOptions: accountOptions,
        categoryOptions: categoryOptions,
        monthOptions: monthOptions,
        onApply: (next) {
          widget.onFilterChanged(next);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<List<Account>> _loadAccounts(BuildContext context) async {
    // 优先从树里读 RepositoryProvider<AccountRepository>（测试 harness 走这条）；
    // 路由层未 provide 时回退 getIt（生产路径）。与 detail 页同模式。
    AccountRepository? repo;
    try {
      repo = RepositoryProvider.of<AccountRepository>(context);
    } catch (_) {
      repo = null;
    }
    try {
      repo ??= GetIt.instance<AccountRepository>();
    } catch (_) {}
    if (repo == null) return const [];
    try {
      final result = await repo.list();
      return result.fold((_) => const [], (list) => list);
    } catch (_) {
      return const [];
    }
  }

  List<FilterOption> _categoryOptions(List<Account> accounts) {
    // 分类下拉复用账户 category（与 FilterBar 设计一致：account-as-category）。
    final seen = <String>{};
    final opts = <FilterOption>[];
    for (final a in accounts) {
      if (seen.add(a.category.label)) {
        opts.add(FilterOption(a.category.name, a.category.label));
      }
    }
    return opts;
  }

  /// 月份下拉：最近 6 个月（含当月），格式 YYYY-MM。
  List<FilterOption> _monthOptions() {
    final now = DateTime.now();
    final opts = <FilterOption>[];
    for (var i = 0; i < 6; i++) {
      final d = DateTime(now.year, now.month - i);
      final ym =
          '${d.year}-${d.month.toString().padLeft(2, '0')}';
      // label：YYYY年M月
      opts.add(FilterOption(ym, '${d.year}年${d.month}月'));
    }
    return opts;
  }

  /// 当前筛选月份的展示文案；无月份筛选时回退到当前自然月。
  String _currentMonthLabel(TxnFilterState filter) {
    final m = filter.month;
    if (m != null && m.length >= 7) {
      final parts = m.split('-');
      if (parts.length == 2) {
        return '${parts[0]}年${int.parse(parts[1])}月';
      }
    }
    final now = DateTime.now();
    return '${now.year}年${now.month}月';
  }

  /// 按月分组(#2-B):外层月份组、组内按日分组,组序保持输入序(输入默认
  /// 日期倒序;按金额排序时同样保首次出现序)。
  ///
  /// 月小计口径:income = Σ income 账户侧 credit;expense = Σ expense
  /// 账户侧 debit(与行内 flavour 判定同账户元数据源;转账 asset↔asset
  /// 两侧均不计入,复合多腿交易按腿累计)。账户元数据未就绪(列表先于
  /// accounts 到达)时小计为 0,accounts 到位后整页重建自然补齐。
  List<_MonthGroup> _groupByMonth(
      List<Transaction> txns, List<Account> accounts) {
    final months = <String, _MonthGroup>{};
    for (final t in txns) {
      final d = t.transactionDate;
      final monthKey = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final group =
          months.putIfAbsent(monthKey, () => _MonthGroup(d.year, d.month));
      for (final e in t.entries) {
        final a = _accountOf(accounts, e.accountId);
        if (a == null) continue;
        if (a.accountType == AccountType.income) {
          group.incomeCents += e.creditCents;
        } else if (a.accountType == AccountType.expense) {
          group.expenseCents += e.debitCents;
        }
      }
      final dayKey =
          '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      group.days.putIfAbsent(dayKey, () => <Transaction>[]).add(t);
    }
    return months.values.toList();
  }

  Account? _accountOf(List<Account> accounts, String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  String _accountNameOf(List<Account> accounts, String id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return id.length > 6 ? '#${id.substring(0, 6)}' : '#$id';
  }
}

/// 月份组(#2-B 分组展开模型的组节点):年月 + 当月小计 + 组内按日分组
/// (LinkedHashMap 保序)。
class _MonthGroup {
  _MonthGroup(this.year, this.month)
      : days = <String, List<Transaction>>{};

  final int year;
  final int month;
  int incomeCents = 0;
  int expenseCents = 0;
  final Map<String, List<Transaction>> days;

  int get count =>
      days.values.fold(0, (sum, txns) => sum + txns.length);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.monthLabel,
    required this.onCreate,
    required this.onExport,
  });
  final int count;
  final String monthLabel;
  final VoidCallback onCreate;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('交易管理',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              const SizedBox(height: 4),
              // OD sub：「2026年6月 · 共 47 笔交易 · 已对账 45 笔」。已对账笔数
              // 无数据源（backend 未返回 reconciled 计数）→ defer，仅展示月份+笔数。
              Text('$monthLabel · 共 $count 笔',
                  style: TextStyle(
                      color: context.yucai.muted, fontSize: 12)),
            ],
          ),
        ),
        _ExportButton(onPressed: onExport),
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: context.yucai.accent,
            borderRadius: AppRadius.smBorder,
          ),
          // F27 FR-1①:新增交易为 accent 面主按钮 —— icon/文字全部 onAccent
          // (暗=金底深墨 #1A1408,亮=绿底白)。
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 15, color: context.yucai.onAccent),
              const SizedBox(width: 6),
              Text('新增交易',
                  style: TextStyle(
                      color: context.yucai.onAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            borderRadius: AppRadius.smBorder,
            border: Border.all(color: context.yucai.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.download, size: 15, color: context.yucai.muted),
              SizedBox(width: 6),
              Text('导出',
                  style: TextStyle(
                      color: context.yucai.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 分组展开模型 + 列表项(#2-B) ─────────────────────────
//
// ListView.builder 的数据源:头块 → (desktop 表头带) → [月份组头 → 日分隔
// → 行]* → 页脚(加载 spinner / 「已全部加载 · 共 N 条」)。sealed 小类
// 区分项类型,itemBuilder 按类型分发(虚拟化:只构建视口内项)。
// 旧「单张 tx-card 包裹 + 分页页脚」形态已随无限滚动改版退役(DataCard/
// PagerBar 组件本体保留,其它列表页仍在用)。

sealed class _TxnListItem {
  const _TxnListItem();

  /// 页头块(desktop 页头+汇总+筛选 / mobile appbar+MobileHeader+类型段)。
  factory _TxnListItem.headerBlock() = _TxnHeaderBlock;

  /// 空列表提示(保留 header,列表区空态)。
  factory _TxnListItem.emptyHint() = _TxnEmptyHint;

  /// desktop/tablet 表头带(日期/交易详情/分类/账户/金额)。
  factory _TxnListItem.tableHeader() = _TxnTableHeaderBandItem;

  /// 月份组头(YYYY年M月 + 当月收入/支出小计)。
  factory _TxnListItem.monthHeader(_MonthGroup month) = _TxnMonthHeader;

  /// 日分隔(MM-DD + 当日笔数)。
  factory _TxnListItem.dayHeader(String label, int count) = _TxnDayHeader;

  /// 交易行(desktop 表格行 / mobile 卡片)。
  factory _TxnListItem.row(Transaction txn) = _TxnRow;

  /// 列表页脚:加载中 spinner;hasMore=false 时「已全部加载 · 共 N 条」。
  factory _TxnListItem.listEnd({
    required bool loadingMore,
    required bool hasMore,
    required int totalCount,
  }) = _TxnListEnd;
}

class _TxnHeaderBlock extends _TxnListItem {
  const _TxnHeaderBlock();
}

class _TxnEmptyHint extends _TxnListItem {
  const _TxnEmptyHint();
}

class _TxnTableHeaderBandItem extends _TxnListItem {
  const _TxnTableHeaderBandItem();
}

class _TxnMonthHeader extends _TxnListItem {
  const _TxnMonthHeader(this.month);
  final _MonthGroup month;
}

class _TxnDayHeader extends _TxnListItem {
  const _TxnDayHeader(this.label, this.count);
  final String label;
  final int count;
}

class _TxnRow extends _TxnListItem {
  const _TxnRow(this.txn);
  final Transaction txn;
}

class _TxnListEnd extends _TxnListItem {
  const _TxnListEnd({
    required this.loadingMore,
    required this.hasMore,
    required this.totalCount,
  });

  final bool loadingMore;
  final bool hasMore;

  /// 累计条数(已加载各页之和,非本页条数)。
  final int totalCount;
}

/// 月份组头(#2-B):「YYYY年M月」+ 当月笔数 + 收入/支出小计。
/// 样式照 design-v2 卡片分隔条先例:surfaceAlt 色带 + 上下细边,零裸色
/// (全部走 context.yucai 语义令牌;收入 positive / 支出 negative)。
class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.month});

  final _MonthGroup month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        border: Border(
          top: BorderSide(color: context.yucai.border),
          bottom: BorderSide(color: context.yucai.border),
        ),
      ),
      child: Row(
        children: [
          Text('${month.year}年${month.month}月',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
          const SizedBox(width: 8),
          Text('${month.count} 笔',
              style: TextStyle(color: context.yucai.muted, fontSize: 11)),
          const Spacer(),
          // 小计右对齐;窄屏(mobile)下超长金额省略号兜底。
          Flexible(
            child: Text(
              '收入 ${_formatCents(month.incomeCents)}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.yucai.positive,
                  fontSize: 11.5,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '支出 ${_formatCents(month.expenseCents)}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.yucai.negative,
                  fontSize: 11.5,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ),
        ],
      ),
    );
  }
}

/// desktop/tablet 表头带:无整卡包裹后表头落在 surface 色带上,收顶细边
/// (下沿分隔线由首个月份组头的上边提供,避免双线)。
class _TableHeaderBand extends StatelessWidget {
  const _TableHeaderBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border(top: BorderSide(color: context.yucai.border)),
      ),
      child: _TableHeader(),
    );
  }
}

/// 列表页脚(#2-B):加载中 spinner;hasMore=false 显示「已全部加载 · 共
/// N 条」(N=累计);还有下一页且不在加载中收一条窄 surface 带(保持底部
/// 细边不因加载态切换瞬闪)。
class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.loadingMore,
    required this.hasMore,
    required this.totalCount,
    required this.surfaceBand,
  });

  final bool loadingMore;
  final bool hasMore;
  final int totalCount;

  /// desktop/tablet:surface 色带 + 底部细边;mobile 无卡片 chrome。
  final bool surfaceBand;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (loadingMore) {
      content = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (!hasMore) {
      content = Text('已全部加载 · 共 $totalCount 条',
          style: TextStyle(color: context.yucai.muted, fontSize: 12));
    } else {
      content = const SizedBox(height: 6);
    }
    if (!surfaceBand) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        child: Center(child: content),
      );
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border(bottom: BorderSide(color: context.yucai.border)),
      ),
      child: content,
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      color: context.yucai.muted,
      fontSize: 11.5,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w500,
    );
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text('日期', style: headerStyle)),
          SizedBox(width: AppSpacing.sm),
          Expanded(flex: 3, child: Text('交易详情', style: headerStyle)),
          SizedBox(width: AppSpacing.sm),
          SizedBox(width: 100, child: Text('分类', style: headerStyle)),
          SizedBox(width: AppSpacing.sm),
          SizedBox(width: 120, child: Text('账户', style: headerStyle)),
          SizedBox(width: AppSpacing.sm),
          SizedBox(
              width: 110,
              child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('金额', style: headerStyle))),
          SizedBox(width: AppSpacing.sm),
          SizedBox(width: 36),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      color: context.yucai.surfaceAlt,
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
          const SizedBox(width: 8),
          Text('$count 笔',
              style:
                  TextStyle(color: context.yucai.muted, fontSize: 11)),
        ],
      ),
    );
  }
}

class _TxTableRow extends StatelessWidget {
  const _TxTableRow({
    required this.txn,
    required this.accountNameOf,
    required this.accountOf,
    required this.onOpenDetail,
    this.onDeleted,
  });

  final Transaction txn;
  final String Function(String id) accountNameOf;
  final Account? Function(String id) accountOf;
  final ValueChanged<String> onOpenDetail;

  /// 反馈1b:右键删除成功后的列表回拉(页面注入 _reloadAfterMutation,
  /// 保留当前筛选 —— 与 didPopNext 回拉同语义)。
  final VoidCallback? onDeleted;

  /// 反馈1b:右键「复制备注」—— Clipboard 直写(先例 feedback_launcher
  /// Clipboard.setData;本文件 TagRepository/TransactionRepository getIt
  /// 直取同款 widget 层先例)。
  void _copyNote(BuildContext context) {
    Clipboard.setData(ClipboardData(text: txn.description));
    AppToast.show(context, '已复制备注', type: ToastType.success);
  }

  /// 反馈1b:右键「删除」—— 确认对话框文案同详情页 _delete(冲销语义),
  /// 执行走 repo.delete(直连;列表 bloc 的 _onDelete 是详情页状态机,
  /// 不复用),成功后 toast + 回拉列表。
  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除交易'),
        content: Text('删除「${txn.description.isEmpty ? '此交易' : txn.description}」'
            '将生成一条冲销分录，撤销该笔借贷记录。此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: Text('删除',
                style: TextStyle(color: context.yucai.negative)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await getIt<TransactionRepository>().delete(txn.id);
    if (!context.mounted) return;
    result.fold(
      (failure) => AppToast.show(context, failure.displayMessage,
          type: ToastType.error),
      (_) {
        AppToast.show(context, '已删除', type: ToastType.success);
        onDeleted?.call();
      },
    );
  }

  /// 转账判定（两条 entry 且两端账户都是 asset）。
  bool get _isTransfer {
    if (txn.entries.length != 2) return false;
    final e0 = accountOf(txn.entries[0].accountId);
    final e1 = accountOf(txn.entries[1].accountId);
    if (e0 == null || e1 == null) return txn.isBalanced;
    return e0.accountType == AccountType.asset &&
        e1.accountType == AccountType.asset;
  }

  TxnFlavour get _flavour {
    // 用 account type 判定,避免 inferFlavour 误判 expense/income 为 transfer。
    if (_isTransfer) return TxnFlavour.transfer;
    for (final e in txn.entries) {
      final t = accountOf(e.accountId)?.accountType;
      if (t == AccountType.expense) return TxnFlavour.expense;
      if (t == AccountType.income) return TxnFlavour.income;
    }
    return TxnFlavour.compound;
  }

  @override
  Widget build(BuildContext context) {
    final flavour = _flavour;
    final amount = txn.totalDebitCents; // 表格用主金额（借方合计）展示
    final cell = _resolveAccountCell();

    // 反馈1b:行右键场景菜单(「编辑」「删除」「复制备注」)—— 编辑复用
    // 既有 /transactions/:id/edit 路由;复制/删除见上;共享组件
    // ContextMenuRegion(translucent 不进主键竞技场,行 tap/悬停
    // 既有测试零扰动)。两类先例面之一,不铺开。
    return ContextMenuRegion(
      items: [
        MenuItemData(
          label: '编辑',
          icon: LucideIcons.pencil,
          onTap: () => context.push('/transactions/${txn.id}/edit'),
        ),
        MenuItemData(
          label: '删除',
          icon: LucideIcons.trash2,
          destructive: true,
          onTap: () => _delete(context),
        ),
        MenuItemData(
          label: '复制备注',
          icon: LucideIcons.copy,
          onTap: () => _copyNote(context),
        ),
      ],
      child: InkWell(
      onTap: () => onOpenDetail(txn.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(_formatDate(txn.transactionDate),
                  style: TextStyle(
                      color: context.yucai.muted,
                      fontSize: 13,
                      fontFeatures: AppTypography.tabularFigures)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: _TxMain(
                description: txn.description,
                flavour: flavour,
                secondary: _secondaryLine(cell),
                category: cell.categoryAccount,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 100,
              child: _CategoryChip(account: cell.categoryAccount),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 120,
              child: cell.isTransfer
                  ? _TransferAccounts(
                      fromLabel: cell.fromLabel, toLabel: cell.toLabel)
                  : _AccountTag(
                      label: cell.primaryLabel,
                      account: accountOf(cell.primaryAccountId)),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 110,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCents(amount, signed: true),
                  style: TextStyle(
                    color: _amountColor(context, flavour),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: _RowOpMenu(onTap: () => onOpenDetail(txn.id)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// 副标题：转账 from → to；非转账用主账户名。
  String _secondaryLine(_AccountCell cell) {
    if (cell.isTransfer) {
      return '${cell.fromLabel} → ${cell.toLabel}';
    }
    return cell.primaryLabel;
  }

  /// 解析账户列内容（转账双账户 / 非转账单账户 + 分类）。
  _AccountCell _resolveAccountCell() {
    if (_isTransfer) {
      final fromEntry = txn.entries.firstWhere(
        (e) => e.creditCents > 0,
        orElse: () => txn.entries.first,
      );
      final toEntry = txn.entries.firstWhere(
        (e) => e.debitCents > 0,
        orElse: () => txn.entries.last,
      );
      return _AccountCell.transfer(
        accountNameOf(fromEntry.accountId),
        accountNameOf(toEntry.accountId),
      );
    }
    // 非转账：asset 账户为主，对侧（income/expense）为分类。
    Account? assetAccount;
    Account? otherAccount;
    String assetId = '';
    for (final e in txn.entries) {
      final a = accountOf(e.accountId);
      if (a == null) continue;
      if (a.accountType == AccountType.asset && assetAccount == null) {
        assetAccount = a;
        assetId = e.accountId;
      } else {
        otherAccount ??= a;
      }
    }
    final primaryId = assetId.isNotEmpty
        ? assetId
        : (txn.entries.isNotEmpty ? txn.entries.first.accountId : '');
    return _AccountCell.single(
      primaryId.isEmpty ? '' : accountNameOf(primaryId),
      otherAccount,
      primaryId,
    );
  }
}

/// 账户列解析结果。
class _AccountCell {
  _AccountCell.transfer(this.fromLabel, this.toLabel)
      : primaryLabel = fromLabel,
        primaryAccountId = '',
        categoryAccount = null;
  _AccountCell.single(
      this.primaryLabel, this.categoryAccount, this.primaryAccountId)
      : fromLabel = '',
        toLabel = '';

  final String primaryLabel;
  final String primaryAccountId;
  final String fromLabel;
  final String toLabel;
  final Account? categoryAccount;
  bool get isTransfer => fromLabel.isNotEmpty;
}

/// 转账双账户：from → to + 箭头。
class _TransferAccounts extends StatelessWidget {
  const _TransferAccounts({required this.fromLabel, required this.toLabel});
  final String fromLabel;
  final String toLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _AccountTag(label: fromLabel, account: null)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(LucideIcons.arrowRight, size: 14, color: context.yucai.muted),
        ),
        Flexible(child: _AccountTag(label: toLabel, account: null)),
      ],
    );
  }
}

/// 交易主信息：图标圆角块 + 描述 + 副标题。
class _TxMain extends StatelessWidget {
  const _TxMain({
    required this.description,
    required this.flavour,
    required this.secondary,
    this.category,
  });

  final String description;
  final TxnFlavour flavour;
  final String secondary;
  final Account? category;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TxIconBox(
            flavour: flavour, category: category, description: description),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                description.isEmpty ? '(无描述)' : description,
                style: TextStyle(
                    color: context.yucai.fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              if (secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(secondary,
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TxIconBox extends StatelessWidget {
  const _TxIconBox({required this.flavour, this.category, this.description = ''});
  final TxnFlavour flavour;
  final Account? category;
  final String description;

  /// F4-P2:原 getter 改方法补 context 收线;icon 底由语义令牌 10% 派生
  /// (原 v1 绿/红 10% 透底,暗色跟随主题)。
  (Color, Color, IconData) _styling(BuildContext context) {
    // icon 对齐 OD thin-stroke per-category lucide（餐饮 utensils / 购物
    // shopping-bag / 交通 car / 工资 banknote …）；传入 description 让同名分类
    // 下不同商户也能差异化（餐饮+星巴克 → coffee，餐饮+望江楼 → utensils）。
    switch (flavour) {
      case TxnFlavour.income:
        return (
          context.yucai.positive,
          context.yucai.positive.withValues(alpha: 0.10),
          txnCategoryIcon(flavour, category, description: description),
        );
      case TxnFlavour.expense:
        return (
          context.yucai.negative,
          context.yucai.negative.withValues(alpha: 0.10),
          txnCategoryIcon(flavour, category, description: description),
        );
      case TxnFlavour.transfer:
        return (context.yucai.accent, context.yucai.accentSoft, LucideIcons.arrowLeftRight);
      case TxnFlavour.compound:
        return (context.yucai.accent, context.yucai.accentSoft, LucideIcons.receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = _styling(context);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16, color: fg),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.account});
  final Account? account;

  @override
  Widget build(BuildContext context) {
    if (account == null) return const SizedBox.shrink();
    // 显示账户名(餐饮/购物/工资)而非 category.label(分类账户 category 可能是
    // savings/other,不代表分类语义)。
    final label = account!.name;
    final isIncomeType = account!.accountType == AccountType.income;
    final isExpenseType = account!.accountType == AccountType.expense;
    final fg = isIncomeType
        ? context.yucai.positive
        : (isExpenseType ? context.yucai.negative : context.yucai.muted);
    // chip 底由语义令牌 10% 派生(原 v1 绿/红 10% 透底,暗色跟随主题)。
    final bg = isIncomeType
        ? context.yucai.positive.withValues(alpha: 0.10)
        : (isExpenseType
            ? context.yucai.negative.withValues(alpha: 0.10)
            : context.yucai.surfaceAlt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: fg, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _AccountTag extends StatelessWidget {
  const _AccountTag({required this.label, required this.account});
  final String label;
  final Account? account;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final ab = label.isNotEmpty ? label.characters.first : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: context.yucai.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.yucai.border),
          ),
          alignment: Alignment.center,
          child: Text(ab,
              style: TextStyle(
                  color: context.yucai.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              style: TextStyle(color: context.yucai.fg, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _RowOpMenu extends StatelessWidget {
  const _RowOpMenu({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(LucideIcons.moreHorizontal, size: 16, color: context.yucai.muted),
        ),
      ),
    );
  }
}

// 旧「分页页脚」(_PagerFooter + F7 FR-4 页条装配)已随 #2-B 无限滚动改版
// 退役:分页条语义由滚动加载(距底自动追加)与列表页脚(_ListFooter:
// spinner / 「已全部加载 · 共 N 条」)接管。共享 PagerBar 组件保留在
// core/widgets,其它列表页(账户详情近期交易/持仓)仍在用。

// ───────────────────────── 移动端：卡片堆叠 ─────────────────────────
// (#2-B:旧 _MobileList Column 装配已并入分组展开模型的 itemBuilder ——
// mobile 与 desktop 同一 ListView,行项分发到 _MobileTxnCard。)

/// 类型 segmented(全部/收入/支出/转账)——对齐 OD typeSeg,复用 TxnTypeFilter。
/// mobile + tablet/desktop 共用(mobile 在 sum-card 后;tablet/desktop 在 SummaryCard 后)。
class TxnTypeSeg extends StatelessWidget {
  const TxnTypeSeg({super.key, required this.type, required this.onChanged});
  final TxnTypeFilter type;
  final ValueChanged<TxnTypeFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final tf in TxnTypeFilter.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(tf),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: type == tf
                        ? context.yucai.accentSoft
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(tf.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color:
                              type == tf ? context.yucai.accent : context.yucai.muted,
                          fontSize: 14,
                          fontWeight:
                              type == tf ? FontWeight.w600 : FontWeight.w400)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileTxnCard extends StatelessWidget {
  const _MobileTxnCard({
    required this.txn,
    required this.accountNameOf,
    required this.accountOf,
    required this.onTap,
  });

  final Transaction txn;
  final String Function(String id) accountNameOf;
  final Account? Function(String id) accountOf;
  final VoidCallback onTap;

  TxnFlavour get _flavour {
    // inferFlavour 仅看「2 entries + balanced → transfer」,会误判 expense/income
    // (它们也是 2 entries balanced)。改用 account type 判定:
    //   asset×2 → transfer;含 expense → expense;含 income → income;else compound。
    if (_isTransfer) return TxnFlavour.transfer;
    for (final e in txn.entries) {
      final t = accountOf(e.accountId)?.accountType;
      if (t == AccountType.expense) return TxnFlavour.expense;
      if (t == AccountType.income) return TxnFlavour.income;
    }
    return TxnFlavour.compound;
  }

  /// 转账判定：两条 entry 且两端账户都是 asset（无元信息退化为平衡两行）。
  bool get _isTransfer {
    if (txn.entries.length != 2) return false;
    final e0 = accountOf(txn.entries[0].accountId);
    final e1 = accountOf(txn.entries[1].accountId);
    if (e0 == null || e1 == null) return txn.isBalanced;
    return e0.accountType == AccountType.asset &&
        e1.accountType == AccountType.asset;
  }

  /// 分类账户:非转账交易的 expense/income 对方账户(account-as-category)。
  /// 转账无分类账户,返回 null(_CategoryChip 隐藏)。
  Account? get _categoryAccount {
    for (final e in txn.entries) {
      final a = accountOf(e.accountId);
      if (a != null &&
          (a.accountType == AccountType.expense ||
              a.accountType == AccountType.income)) {
        return a;
      }
    }
    return null;
  }

  /// HH:MM:优先 transactionTime,回退 transactionDate。
  String get _hhmm {
    final dt = txn.transactionTime ?? txn.transactionDate;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final flavour = _flavour;
    final amount = txn.totalDebitCents;
    final isTransfer = _isTransfer;
    String fromLabel = '';
    String toLabel = '';
    String singleLabel = '';
    if (isTransfer) {
      final fromEntry = txn.entries.firstWhere(
        (e) => e.creditCents > 0,
        orElse: () => txn.entries.first,
      );
      final toEntry = txn.entries.firstWhere(
        (e) => e.debitCents > 0,
        orElse: () => txn.entries.last,
      );
      fromLabel = accountNameOf(fromEntry.accountId);
      toLabel = accountNameOf(toEntry.accountId);
    } else {
      // 非转账：asset 账户为主，找不到 asset 退化为首条。
      String assetId = '';
      for (final e in txn.entries) {
        final a = accountOf(e.accountId);
        if (a != null && a.accountType == AccountType.asset) {
          assetId = e.accountId;
          break;
        }
      }
      final primaryId = assetId.isNotEmpty
          ? assetId
          : (txn.entries.isNotEmpty ? txn.entries.first.accountId : '');
      singleLabel = primaryId.isEmpty ? '' : accountNameOf(primaryId);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.yucai.surface,
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: context.yucai.border),
        ),
        child: Row(
          children: [
            _TxIconBox(
                flavour: flavour,
                category: _categoryAccount,
                description: txn.description),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description.isEmpty ? '(无描述)' : txn.description,
                    style: TextStyle(
                        color: context.yucai.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  if (isTransfer)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        _AccountTag(
                            label: fromLabel,
                            account: accountOf(txn.entries
                                .firstWhere(
                                    (e) => e.creditCents > 0,
                                    orElse: () => txn.entries.first)
                                .accountId)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(LucideIcons.arrowRight,
                              size: 14, color: context.yucai.muted),
                        ),
                        _AccountTag(
                            label: toLabel,
                            account: accountOf(txn.entries
                                .firstWhere(
                                    (e) => e.debitCents > 0,
                                    orElse: () => txn.entries.last)
                                .accountId)),
                        if (txn.transactionTime != null)
                          Text('· $_hhmm',
                              style: TextStyle(
                                  color: context.yucai.muted, fontSize: 12)),
                      ],
                    )
                  else
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        if (singleLabel.isNotEmpty)
                          _AccountTag(
                              label: singleLabel,
                              account: accountOf(txn.entries
                                  .firstWhere(
                                      (e) =>
                                          accountOf(e.accountId)?.accountType ==
                                              AccountType.asset,
                                      orElse: () => txn.entries.first)
                                  .accountId)),
                        if (txn.transactionTime != null)
                          Text('· $_hhmm',
                              style: TextStyle(
                                  color: context.yucai.muted, fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ),
            // 右侧:分类 chip + 金额
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CategoryChip(account: _categoryAccount),
                const SizedBox(height: 4),
                Text(
                  _formatCents(amount, signed: true),
                  style: TextStyle(
                    color: _amountColor(context, flavour),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
          const SizedBox(width: 8),
          Text('$count 笔',
              style:
                  TextStyle(color: context.yucai.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ───────────────────────── 空态 / 错误态 ─────────────────────────

/// 列表区空提示(非全屏):切到无记录月份时 _Content 列表区显示,保留 header。
class _EmptyListHint extends StatelessWidget {
  const _EmptyListHint({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.receipt,
                size: 36, color: context.yucai.muted),
            const SizedBox(height: 12),
            Text('本月暂无交易',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.muted)),
            const SizedBox(height: 16),
            _CreateButton(onPressed: onCreate),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onCreate,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              Icon(LucideIcons.alertCircle,
                  size: 40, color: context.yucai.negative),
              const SizedBox(height: AppSpacing.md),
              Text(message,
                  style: TextStyle(
                      color: context.yucai.negative, fontSize: 15)),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('重试'),
                  ),
                  _CreateButton(onPressed: onCreate),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 格式化辅助 ─────────────────────────

String _formatDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatCents(int cents, {bool signed = false}) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final sign = signed && cents < 0 ? '-' : '';
  return '$sign¥$yuan.$frac';
}

/// F4-P2:顶层函数无 context → 补形参穿线;语义色走 context.yucai。
Color _amountColor(BuildContext context, TxnFlavour f) {
  switch (f) {
    case TxnFlavour.income:
      return context.yucai.positive;
    case TxnFlavour.expense:
      return context.yucai.negative;
    case TxnFlavour.transfer:
    case TxnFlavour.compound:
      return context.yucai.fg;
  }
}

// ───────────────────────── Task 2: mobile 筛选 sheet + appbar ─────────────────────────
//
// mobile 专属筛选 UI:filterBtn 触发底部 sheet(类型/账户/分类/月份 chip 单选 +
// 重置/应用)。_MobileAppBar 提供标题 + 搜索 btn + 筛选 btn。
// 组装进 _Content 是 Task 4;此处仅新增 widget 定义,不改 _Content。

/// mobile 筛选底部 sheet(filterBtn 触发)。
/// 内部持临时 filter state,应用时一次性回传 onApply。
///
/// 公开 + `@visibleForTesting`:Task 2 单元 test 直接 pump 本 widget
/// (不依赖 _Content 组装,组装在 Task 4)。生产路径由 _Content 内部构造。
@visibleForTesting
class MobileFilterSheet extends StatefulWidget {
  const MobileFilterSheet({
    super.key,
    required this.initial,
    required this.accountOptions,
    required this.categoryOptions,
    required this.monthOptions,
    required this.onApply,
  });

  final TxnFilterState initial;
  final List<FilterOption> accountOptions;
  final List<FilterOption> categoryOptions;
  final List<FilterOption> monthOptions;
  final ValueChanged<TxnFilterState> onApply;

  @override
  State<MobileFilterSheet> createState() => _MobileFilterSheetState();
}

class _MobileFilterSheetState extends State<MobileFilterSheet> {
  late TxnFilterState _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  Widget _chipGroup({
    required String label,
    required List<FilterOption> options,
    required String? selectedId, // null = 全部
    required ValueChanged<String?> onSelect, // null = 选「全部」
    String allLabel = '全部',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Text(label,
                style: TextStyle(color: context.yucai.muted, fontSize: 12.5)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(allLabel, selectedId == null, () => onSelect(null)),
              for (final o in options)
                _filterChip(
                    o.label, selectedId == o.value, () => onSelect(o.value)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String text, bool on, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: on ? context.yucai.accentSoft : context.yucai.surfaceAlt,
          border:
              Border.all(color: on ? context.yucai.accentDeep : context.yucai.border),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(text,
            style: TextStyle(
                color: on ? context.yucai.accentDeep : context.yucai.fg,
                fontSize: 13.5,
                fontWeight: on ? FontWeight.w500 : FontWeight.w400)),
      ),
    );
  }

  Widget _typeGroup() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 9),
            child: Text('交易类型',
                style: TextStyle(color: context.yucai.muted, fontSize: 12.5)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tf in TxnTypeFilter.values)
                _filterChip(tf.label, _draft.type == tf,
                    () => setState(() => _draft = _draft.copyWith(type: tf))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: context.yucai.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text('筛选交易',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Georgia')),
              _typeGroup(),
              // 搜索 + 排序(F7 FR-2/3):同样进草稿,「应用筛选」一次性回传。
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Text('搜索描述',
                          style: TextStyle(
                              color: context.yucai.muted, fontSize: 12.5)),
                    ),
                    TxnSearchField(
                      value: _draft.searchText ?? '',
                      onChanged: (v) => setState(() =>
                          _draft = _draft.copyWith(
                              searchText: v.isEmpty ? null : v)),
                    ),
                    const SizedBox(height: 12),
                    TxnSortControl(
                      sortKey: _draft.sortKey,
                      sortDir: _draft.sortDir,
                      onChanged: (k, d) => setState(() =>
                          _draft = _draft.copyWith(sortKey: k, sortDir: d)),
                    ),
                  ],
                ),
              ),
              _chipGroup(
                label: '账户',
                options: widget.accountOptions,
                selectedId: _draft.accountId,
                onSelect: (id) =>
                    setState(() => _draft = _draft.copyWith(accountId: id)),
                allLabel: '全部账户',
              ),
              _chipGroup(
                label: '分类',
                options: widget.categoryOptions,
                selectedId: _draft.category,
                onSelect: (id) =>
                    setState(() => _draft = _draft.copyWith(category: id)),
                allLabel: '全部分类',
              ),
              _chipGroup(
                label: '月份',
                options: widget.monthOptions,
                selectedId: _draft.month,
                onSelect: (id) =>
                    setState(() => _draft = _draft.copyWith(month: id)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _draft = const TxnFilterState()),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.smBorder),
                      ),
                      child: const Text('重置'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onApply(_draft),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.yucai.accent,
                        // F27 FR-1①:accent 面主按钮前景 → onAccent(暗=金底深墨)。
                        foregroundColor: context.yucai.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.smBorder),
                      ),
                      child: const Text('应用筛选'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// mobile appbar:标题 + 搜索 btn + 筛选 btn。
class _MobileAppBar extends StatelessWidget {
  const _MobileAppBar({required this.onFilter});
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Text('交易管理',
              style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Georgia')),
          const Spacer(),
          IconButton(
            tooltip: '搜索',
            icon: const Icon(LucideIcons.search, size: 21),
            onPressed: () {}, // 搜索本期占位(P2 search)
          ),
          IconButton(
            tooltip: '筛选',
            icon: const Icon(LucideIcons.slidersHorizontal, size: 21),
            onPressed: onFilter,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Task 3: mobile month-bar + 可展开 sum-card ─────────────────────────
//
// mobile 顶部:month-bar(prev/text/next 切月) + 可展开 sum-card(收入/支出/净额 三列 +
// 「查看月度明细」展开日均支出)。组装进 _Content 是 Task 4;此处仅新增 widget 定义。

/// mobile 顶部:month-bar(prev/text/next) + 可展开 sum-card。
///
/// 公开 + `@visibleForTesting`:Task 3 单元 test 直接 pump 本 widget
/// (不依赖 _Content 组装,组装在 Task 4)。生产路径由 _Content 内部构造。
@visibleForTesting
class MobileHeader extends StatefulWidget {
  const MobileHeader({
    super.key,
    required this.filter,
    required this.count,
    required this.summary,
    required this.onFilterChanged,
  });

  final TxnFilterState filter;
  final int count;
  final MonthlySummary? summary;
  final ValueChanged<TxnFilterState> onFilterChanged;

  @override
  State<MobileHeader> createState() => _MobileHeaderState();
}

class _MobileHeaderState extends State<MobileHeader> {
  bool _expanded = false;

  String get _monthLabel {
    final m = widget.filter.month;
    if (m != null && m.length >= 7) {
      final parts = m.split('-');
      if (parts.length == 2) return '${parts[0]}年${int.parse(parts[1])}月';
    }
    final now = DateTime.now();
    return '${now.year}年${now.month}月';
  }

  void _shift(int delta) {
    final m = widget.filter.month;
    DateTime base;
    if (m != null && m.length >= 7) {
      final parts = m.split('-');
      base = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    } else {
      base = DateTime.now();
    }
    final d = DateTime(base.year, base.month + delta);
    final ym = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    widget.onFilterChanged(widget.filter.copyWith(month: ym));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Column(
      children: [
        // month-bar
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '上一月',
                icon: const Icon(LucideIcons.chevronLeft, size: 20),
                onPressed: () => _shift(-1),
              ),
              Column(
                children: [
                  Text(_monthLabel,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Georgia')),
                  Text('本月 · 共 ${widget.count} 笔',
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 11)),
                ],
              ),
              IconButton(
                tooltip: '下一月',
                icon: const Icon(LucideIcons.chevronRight, size: 20),
                onPressed: () => _shift(1),
              ),
            ],
          ),
        ),
        // sum-card
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            border: Border.all(color: context.yucai.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _sumCol('本月收入', s?.incomeCents ?? 0, context.yucai.positive),
                  _vd(),
                  _sumCol('本月支出', s?.expenseCents ?? 0, context.yucai.negative),
                  _vd(),
                  _sumCol('本月净额', s?.netCents ?? 0, null),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: context.yucai.border))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          _expanded ? '收起月度明细' : '查看月度明细',
                          style: TextStyle(
                              color: context.yucai.muted, fontSize: 12.5)),
                      Icon(
                        _expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 16,
                        color: context.yucai.muted,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(
                    children: [
                      _extraRow('日均支出', s?.dailyAvgCents ?? 0),
                      // 储蓄率/已对账/较上月 无数据源,本期省略(spec §3.3)
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sumCol(String label, int cents, Color? color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: context.yucai.muted, fontSize: 11.5)),
            const SizedBox(height: 6),
            Text(
              _formatCents(cents, signed: cents != 0),
              style: TextStyle(
                  color: color ?? context.yucai.fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vd() => Container(
      width: 1,
      margin: const EdgeInsets.symmetric(vertical: 12),
      color: context.yucai.border);

  Widget _extraRow(String label, int cents) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.yucai.muted, fontSize: 13)),
          Text(_formatCents(cents),
              style: TextStyle(
                  color: context.yucai.fg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}
