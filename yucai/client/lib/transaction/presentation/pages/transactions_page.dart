import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
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
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';
import 'package:yucai_client/transaction/presentation/widgets/summary_card.dart';
import 'package:yucai_client/transaction/presentation/widgets/txn_category_icon.dart';

/// 交易列表页。对齐 OD 原型 `yucai-transaction-trisize-9d3e/transactions.html`：
///   - 页头：H1 + 副标题（月份 · 共 N 笔）+ 导出按钮 + 新增交易
///   - 汇总四卡（SummaryCard）—— 本月收入/支出/净额/日均
///   - TxnFilterBar（搜索框 + 类型分段 + 账户/分类/月份下拉 + 排序 + 重置，F7）
///   - 单张 tx-card 内按日分组：day-row 分隔条 + 表格行
///     （日期 / 交易详情（图标+描述）/ 分类 chip / 账户标签 / 金额 / ⋯ 操作）
///   - 分页页脚（F7 FR-4）：上一页/下一页 + 「第 N 页」；单页整体隐藏
///   - Mobile：卡片堆叠 + 汇总四宫格（TxnRow 移动分支）
///
/// 三尺寸响应式（Desktop ≥1200 / Tablet 600–1200 / Mobile ≤600）。
///
/// Bloc 来源（按优先级）：
///   1. [bloc] 构造参数 —— 测试注入预构造 bloc。
///   2. 路由层 BlocProvider —— 生产路径（见 router.dart `/transactions` 分支）。
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key, this.bloc});

  /// 测试可注入预构造 bloc；生产路径留空，bloc 由路由层 BlocProvider 提供。
  final TransactionBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final injected = bloc;
    if (injected != null) {
      return BlocProvider<TransactionBloc>.value(
        value: injected,
        child: const _TransactionsView(),
      );
    }
    // 生产路径：bloc 由路由层 `/transactions` 分支的 BlocProvider 提供。
    return const _TransactionsView();
  }
}

class _TransactionsView extends StatefulWidget {
  const _TransactionsView();

  @override
  State<_TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<_TransactionsView> {
  @override
  void initState() {
    super.initState();
    // Kick off the initial summary fetch alongside the list load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestSummary(const TxnFilterState());
    });
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
  /// LoadSummaryRequested。
  void _onFilterChanged(TxnFilterState next) {
    final bloc = context.read<TransactionBloc>();
    bloc.add(LoadTransactionsRequested(filter: next));
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
      AppToast.show(context, '交易已记录');
      _reloadAfterMutation();
    }
  }

  void _reloadAfterMutation() {
    final bloc = context.read<TransactionBloc>();
    final state = bloc.state;
    final filter = state is TransactionsLoaded
        ? state.filter
        : (state is TransactionsError ? state.filter : const TxnFilterState());
    bloc.add(LoadTransactionsRequested(filter: filter));
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
            // F7 FR-4:页码分页(prev/next)。翻页不触发 summary 重算。
            onPrevPage: () => context.read<TransactionBloc>().add(
                const GoToTransactionsPageRequested(TxnPageDirection.prev)),
            onNextPage: () => context.read<TransactionBloc>().add(
                const GoToTransactionsPageRequested(TxnPageDirection.next)),
          );
        },
      ),
    );
  }
}

// ───────────────────────── 主内容 ─────────────────────────

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.loadingMore,
    required this.onFilterChanged,
    required this.onCreate,
    required this.onExport,
    required this.onOpenDetail,
    required this.onPrevPage,
    required this.onNextPage,
  });

  /// TransactionsLoaded or TransactionsLoadingMore (both carry the list).
  final TransactionState state;
  final bool loadingMore;
  final ValueChanged<TxnFilterState> onFilterChanged;
  final VoidCallback onCreate;
  final VoidCallback onExport;
  final ValueChanged<String> onOpenDetail;

  /// F7 FR-4:翻页回调(filter 不变,bloc 内部换 token 重查)。
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;

  List<Transaction> get _txns => state is TransactionsLoaded
      ? (state as TransactionsLoaded).transactions
      : (state as TransactionsLoadingMore).transactions;

  TxnFilterState get _filter => state is TransactionsLoaded
      ? (state as TransactionsLoaded).filter
      : (state as TransactionsLoadingMore).filter;

  String get _nextToken => state is TransactionsLoaded
      ? (state as TransactionsLoaded).nextPageToken
      : (state as TransactionsLoadingMore).nextPageToken;

  bool get _hasMore => _nextToken.isNotEmpty;

  /// 当前页码(0 起;两 list-bearing 状态同构)。
  int get _pageIndex => state is TransactionsLoaded
      ? (state as TransactionsLoaded).pageIndex
      : (state as TransactionsLoadingMore).pageIndex;

  /// 单页(hasMore==false 且 pageIndex==0)整个分页条隐藏。
  ///
  /// 翻页请求中([loadingMore])保持显示(fix round 1):LoadingMore 态的
  /// nextPageToken 是"正在取的页"token(prev 回第 1 页时为空 → hasMore
  /// 推出 false),若不含 loading 态分页条会瞬闪隐藏;loading 双禁已防连点。
  bool get _showPager => _hasMore || _pageIndex > 0 || loadingMore;

  /// This month's summary. null until the parallel `TransactionSummary` RPC
  /// resolves; the card falls back to zeros.
  MonthlySummary? get _summary => state is TransactionsLoaded
      ? (state as TransactionsLoaded).summary
      : (state as TransactionsLoadingMore).summary;

  @override
  Widget build(BuildContext context) {
    // 账户选项从 AccountRepository 拉一次（FutureBuilder，避免把账户状态
    // 塞进 TransactionBloc）。失败时退回空选项。
    return FutureBuilder<List<Account>>(
      future: _loadAccounts(context),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <Account>[];
        final accountOptions = [
          for (final a in accounts) FilterOption(a.id, a.name),
        ];
        final categoryOptions = _categoryOptions(accounts);
        final monthOptions = _monthOptions();

        final groups = _groupByDay(_txns);

        // Task 4: mobile 分支判定 —— 与 accounts_page 同断点(Breakpoints mobileUpper=600)。
        final isMobile = Breakpoints.of(context) == Breakpoint.mobile;

        return RefreshIndicator(
          onRefresh: () async => context
              .read<TransactionBloc>()
              .add(LoadTransactionsRequested(filter: _filter)),
          child: SingleChildScrollView(
            padding: isMobile
                ? const EdgeInsets.fromLTRB(4, 4, 4, 96)
                : const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isMobile) ...[
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
                        onFilterChanged: onFilterChanged,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TxnTypeSeg(
                        type: _filter.type,
                        onChanged: (tf) =>
                            onFilterChanged(_filter.copyWith(type: tf)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ] else ...[
                      _Header(
                        count: _txns.length,
                        monthLabel: _currentMonthLabel(_filter),
                        onCreate: onCreate,
                        onExport: onExport,
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
                        onChanged: (tf) =>
                            onFilterChanged(_filter.copyWith(type: tf)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TxnFilterBar(
                        state: _filter,
                        onChanged: onFilterChanged,
                        accountOptions: accountOptions,
                        categoryOptions: categoryOptions,
                        monthOptions: monthOptions,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (groups.isEmpty)
                      _EmptyListHint(onCreate: onCreate)
                    else
                      ResponsiveLayout(
                        mobile: _MobileList(
                          groups: groups,
                          accounts: accounts,
                          onOpenDetail: onOpenDetail,
                        ),
                        tablet: _TxCard(
                          groups: groups,
                          accounts: accounts,
                          onOpenDetail: onOpenDetail,
                          showPager: _showPager,
                          pageIndex: _pageIndex,
                          hasMore: _hasMore,
                          loadingMore: loadingMore,
                          onPrevPage: onPrevPage,
                          onNextPage: onNextPage,
                          totalCount: _txns.length,
                        ),
                        desktop: _TxCard(
                          groups: groups,
                          accounts: accounts,
                          onOpenDetail: onOpenDetail,
                          showPager: _showPager,
                          pageIndex: _pageIndex,
                          hasMore: _hasMore,
                          loadingMore: loadingMore,
                          onPrevPage: onPrevPage,
                          onNextPage: onNextPage,
                          totalCount: _txns.length,
                        ),
                      ),
                    // F7 FR-4:mobile 分支无卡片页脚,分页条独立渲染在列表下方;
                    // 单页(hasMore==false 且 pageIndex==0)整个分页条隐藏。
                    if (isMobile && _showPager)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: TxnPagerBar(
                          pageIndex: _pageIndex,
                          hasMore: _hasMore,
                          loading: loadingMore,
                          onPrev: onPrevPage,
                          onNext: onNextPage,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
          onFilterChanged(next);
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

  /// 按天分组：key = 「MM-DD」（展示用），保留顺序（输入已按日期倒序，这里
  /// 用 LinkedHashMap 保序）。
  Map<String, List<Transaction>> _groupByDay(List<Transaction> txns) {
    final groups = <String, List<Transaction>>{};
    for (final t in txns) {
      final key =
          '${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(t);
    }
    return groups;
  }
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.plus, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text('新增交易',
                  style: TextStyle(
                      color: Colors.white,
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

// ───────────────────────── 桌面/平板：单张 tx-card 表格 ─────────────────────────
//
// 对齐原型：单张白底卡片包裹表头 + day-row 分隔条 + 表格行 + 分页页脚。
// 不再为每个日期生成独立 DataCard —— 原型把所有日期合在一张 tx-card 内，
// day-row 作为视觉分隔条（淡背景 + 上下细边）。

class _TxCard extends StatelessWidget {
  const _TxCard({
    required this.groups,
    required this.accounts,
    required this.onOpenDetail,
    required this.showPager,
    required this.pageIndex,
    required this.hasMore,
    required this.loadingMore,
    required this.onPrevPage,
    required this.onNextPage,
    required this.totalCount,
  });

  final Map<String, List<Transaction>> groups;
  final List<Account> accounts;
  final ValueChanged<String> onOpenDetail;

  /// F7 FR-4:是否渲染分页页脚(单页隐藏整个分页条)。
  final bool showPager;
  final int pageIndex;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onPrevPage;
  final VoidCallback onNextPage;
  final int totalCount;

  String _nameOf(String id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return id.length > 6 ? '#${id.substring(0, 6)}' : '#$id';
  }

  Account? _accountOf(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TableHeader(),
          Divider(height: 1, color: context.yucai.border),
          for (final entry in groups.entries) ...[
            _DayRow(label: entry.key, count: entry.value.length),
            for (final t in entry.value)
              _TxTableRow(
                txn: t,
                accountNameOf: _nameOf,
                accountOf: _accountOf,
                onOpenDetail: onOpenDetail,
              ),
          ],
          _PagerFooter(
            showing: totalCount,
            showPager: showPager,
            pager: TxnPagerBar(
              pageIndex: pageIndex,
              hasMore: hasMore,
              loading: loadingMore,
              onPrev: onPrevPage,
              onNext: onNextPage,
            ),
          ),
        ],
      ),
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
  });

  final Transaction txn;
  final String Function(String id) accountNameOf;
  final Account? Function(String id) accountOf;
  final ValueChanged<String> onOpenDetail;

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

    return InkWell(
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
                    color: _amountColor(flavour),
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

  (Color, Color, IconData) get _styling {
    // icon 对齐 OD thin-stroke per-category lucide（餐饮 utensils / 购物
    // shopping-bag / 交通 car / 工资 banknote …）；传入 description 让同名分类
    // 下不同商户也能差异化（餐饮+星巴克 → coffee，餐饮+望江楼 → utensils）。
    switch (flavour) {
      case TxnFlavour.income:
        return (
          AppColors.positive,
          const Color(0x1A2D8A6E),
          txnCategoryIcon(flavour, category, description: description),
        );
      case TxnFlavour.expense:
        return (
          AppColors.negative,
          const Color(0x1AC4544D),
          txnCategoryIcon(flavour, category, description: description),
        );
      case TxnFlavour.transfer:
        return (AppColors.accent, AppColors.accentSoft, LucideIcons.arrowLeftRight);
      case TxnFlavour.compound:
        return (AppColors.accent, AppColors.accentSoft, LucideIcons.receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icon) = _styling;
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
    final bg = isIncomeType
        ? const Color(0x1A2D8A6E)
        : (isExpenseType ? const Color(0x1AC4544D) : context.yucai.surfaceAlt);
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

class _PagerFooter extends StatelessWidget {
  const _PagerFooter({
    required this.showing,
    required this.showPager,
    required this.pager,
  });

  final int showing;

  /// 单页(hasMore==false 且 pageIndex==0)整个页脚隐藏。
  final bool showPager;

  /// 页脚右侧的分页条([TxnPagerBar],由调用方装配回调)。
  final Widget pager;

  @override
  Widget build(BuildContext context) {
    if (!showPager) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.yucai.border)),
      ),
      child: Row(
        children: [
          Text('本页 $showing 条',
              style: TextStyle(color: context.yucai.muted, fontSize: 13)),
          const Spacer(),
          pager,
        ],
      ),
    );
  }
}

// ───────────────────────── F7 FR-4:页码分页条 ─────────────────────────

/// 页码分页条:上一页/下一页 + 「第 N 页」指示。
///
/// - 第 1 页(pageIndex==0)禁用上一页;末页(hasMore==false)禁用下一页;
///   [loading](翻页请求中)双禁防连点。
/// - 单页(hasMore==false 且 pageIndex==0)由调用方整个隐藏。
/// - 公开 + `@visibleForTesting`:widget 单测直接 pump 本组件(不依赖
///   _Content 装配),生产路径由 _TxCard 页脚 / mobile 列表下方构造。
@visibleForTesting
class TxnPagerBar extends StatelessWidget {
  const TxnPagerBar({
    super.key,
    required this.pageIndex,
    required this.hasMore,
    required this.onPrev,
    required this.onNext,
    this.loading = false,
  });

  /// 当前页码(0 起;显示「第 N 页」= pageIndex+1)。
  final int pageIndex;

  /// 是否还有下一页(来自 bloc 的 nextPageToken 非空)。
  final bool hasMore;

  /// 翻页请求进行中(TransactionsLoadingMore):双按钮禁用。
  final bool loading;

  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final onFirstPage = pageIndex <= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '上一页',
          icon: const Icon(LucideIcons.chevronLeft, size: 18),
          onPressed: (onFirstPage || loading) ? null : onPrev,
        ),
        Text('第 ${pageIndex + 1} 页',
            style: TextStyle(
                color: context.yucai.muted,
                fontSize: 13,
                fontFeatures: AppTypography.tabularFigures)),
        IconButton(
          tooltip: '下一页',
          icon: const Icon(LucideIcons.chevronRight, size: 18),
          onPressed: (!hasMore || loading) ? null : onNext,
        ),
        if (loading)
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}

// ───────────────────────── 移动端：卡片堆叠 ─────────────────────────

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

class _MobileList extends StatelessWidget {
  const _MobileList({
    required this.groups,
    required this.accounts,
    required this.onOpenDetail,
  });

  final Map<String, List<Transaction>> groups;
  final List<Account> accounts;
  final ValueChanged<String> onOpenDetail;

  String _nameOf(String id) {
    for (final a in accounts) {
      if (a.id == id) return a.name;
    }
    return id.length > 6 ? '#${id.substring(0, 6)}' : '#$id';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          _DayHeader(label: entry.key, count: entry.value.length),
          for (final t in entry.value)
            _MobileTxnCard(
              txn: t,
              accountNameOf: _nameOf,
              accountOf: _accountOf,
              onTap: () => onOpenDetail(t.id),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Account? _accountOf(String id) {
    for (final a in accounts) {
      if (a.id == id) return a;
    }
    return null;
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
                    color: _amountColor(flavour),
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

Color _amountColor(TxnFlavour f) {
  switch (f) {
    case TxnFlavour.income:
      return AppColors.positive;
    case TxnFlavour.expense:
      return AppColors.negative;
    case TxnFlavour.transfer:
    case TxnFlavour.compound:
      return AppColors.fg;
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
                        foregroundColor: Colors.white,
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
