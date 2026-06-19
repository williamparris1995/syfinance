import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
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
import 'package:yucai_client/transaction/presentation/widgets/txn_row.dart';

/// 交易列表页。三尺寸响应式：
///   - Desktop ≥1200 / Tablet 600–1200：表格（日期 / 描述 / 账户 / 金额）+ 汇总横排
///   - Mobile ≤600：卡片堆叠 + 汇总四宫格
///
/// 组成：
///   - 汇总卡（SummaryCard）—— 接真实 [MonthlySummary]（Task 5.2）：TransactionBloc
///     在 LoadTransactionsRequested 后并行触发 TransactionSummary RPC，结果
///     挂在 TransactionsLoaded.summary 上，卡片显示本月收入/支出/净额/日均。
///   - TxnFilterBar（类型分段 + 账户/分类/月份下拉 + 重置）
///   - 按日分组（groupBy transactionDate）的 TxnRow
///   - 分页：游标 nextToken，「加载更多」按钮
///   - 新增交易入口：右上角按钮 + 空态/错误态的 CTA + Mobile FAB
///
/// 遵循 `accounts_page` 的 BlocConsumer 模式。
class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key, this.bloc});

  /// 测试可注入预构造 bloc；生产路径留空，页面从 getIt 构造。
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
    // Reuse a bloc provided higher in the tree (test harness pattern) when
    // present, so tests don't need to register TransactionRepository in GetIt.
    // BlocProvider.of throws ProviderNotFoundException when absent; treat that
    // as "no ambient bloc" and fall through to GetIt construction.
    try {
      BlocProvider.of<TransactionBloc>(context);
      return const _TransactionsView();
    } on ProviderNotFoundException {
      // fall through
    }
    return BlocProvider<TransactionBloc>(
      create: (_) {
        final b = TransactionBloc(getIt<TransactionRepository>());
        b.add(const LoadTransactionsRequested());
        return b;
      },
      child: const _TransactionsView(),
    );
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
    // Kick off the initial summary fetch alongside the list load. The list is
    // loaded by the TransactionsPage bloc factory; summary is a separate RPC
    // triggered here so the SummaryCard populates as soon as the bloc is live.
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
  /// LoadSummaryRequested（Task 5.2）。
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
      // 刷新列表 + 汇总（Task 5.2：新交易改变了本月统计）。
      final bloc = context.read<TransactionBloc>();
      final state = bloc.state;
      final filter = state is TransactionsLoaded
          ? state.filter
          : (state is TransactionsError ? state.filter : const TxnFilterState());
      bloc.add(LoadTransactionsRequested(filter: filter));
      _requestSummary(filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateForm,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('新增交易',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: AppColors.accent,
      ),
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
          final txns = state is TransactionsLoaded
              ? (state).transactions
              : (state as TransactionsLoadingMore).transactions;
          if (txns.isEmpty) {
            return _EmptyView(onCreate: _openCreateForm);
          }
          return _Content(
            state: state,
            loadingMore: state is TransactionsLoadingMore,
            onFilterChanged: _onFilterChanged,
            onCreate: _openCreateForm,
            onLoadMore: () => context
                .read<TransactionBloc>()
                .add(LoadMoreTransactionsRequested()),
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
    required this.onLoadMore,
  });

  /// TransactionsLoaded or TransactionsLoadingMore (both carry the list).
  final TransactionState state;
  final bool loadingMore;
  final ValueChanged<TxnFilterState> onFilterChanged;
  final VoidCallback onCreate;
  final VoidCallback onLoadMore;

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

  /// This month's summary (Task 5.2). null until the parallel
  /// `TransactionSummary` RPC resolves; the card falls back to zeros.
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

        return RefreshIndicator(
          onRefresh: () async => context
              .read<TransactionBloc>()
              .add(LoadTransactionsRequested(filter: _filter)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      count: _txns.length,
                      onCreate: onCreate,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SummaryCard(
                      incomeCents: _summary?.incomeCents ?? 0,
                      expenseCents: _summary?.expenseCents ?? 0,
                      netCents: _summary?.netCents ?? 0,
                      dailyAvgCents: _summary?.dailyAvgCents ?? 0,
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
                    ResponsiveLayout(
                      mobile: _MobileList(
                        groups: groups,
                        accounts: accounts,
                      ),
                      tablet: _TableList(
                        groups: groups,
                        accounts: accounts,
                      ),
                      desktop: _TableList(
                        groups: groups,
                        accounts: accounts,
                      ),
                    ),
                    if (_hasMore || loadingMore) ...[
                      const SizedBox(height: AppSpacing.md),
                      _LoadMoreControl(
                        loading: loadingMore,
                        canLoad: _hasMore,
                        onTap: onLoadMore,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<Account>> _loadAccounts(BuildContext context) async {
    final repo = context.read<AccountRepository?>();
    if (repo == null) return const [];
    final result = await repo.list();
    return result.fold((_) => const [], (list) => list);
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
  const _Header({required this.count, required this.onCreate});
  final int count;
  final VoidCallback onCreate;

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
              const Text('交易记录',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('共 $count 笔',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        _CreateButton(onPressed: onCreate),
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
            color: AppColors.accent,
            borderRadius: AppRadius.smBorder,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 15, color: Colors.white),
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

// ───────────────────────── 按日分组渲染 ─────────────────────────

class _TableList extends StatelessWidget {
  const _TableList({required this.groups, required this.accounts});
  final Map<String, List<Transaction>> groups;
  final List<Account> accounts;

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
        // 表头
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: const [
              SizedBox(width: 56, child: Text('日期')),
              SizedBox(width: AppSpacing.sm),
              Expanded(flex: 3, child: Text('交易详情')),
              SizedBox(width: AppSpacing.sm),
              SizedBox(width: 120, child: Text('账户')),
              SizedBox(width: AppSpacing.sm),
              SizedBox(
                  width: 120,
                  child: Align(
                      alignment: Alignment.centerRight, child: Text('金额'))),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        for (final entry in groups.entries) ...[
          _DayHeader(label: entry.key, count: entry.value.length),
          DataCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final t in entry.value)
                  TxnRow(
                    txn: t,
                    accountNameOf: _nameOf,
                    onTap: () {}, // 详情页在 Task 2.3
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _MobileList extends StatelessWidget {
  const _MobileList({required this.groups, required this.accounts});
  final Map<String, List<Transaction>> groups;
  final List<Account> accounts;

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
            TxnRow(
              txn: t,
              accountNameOf: _nameOf,
              onTap: () {},
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
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
                  const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ───────────────────────── 加载更多 ─────────────────────────

class _LoadMoreControl extends StatelessWidget {
  const _LoadMoreControl({
    required this.loading,
    required this.canLoad,
    required this.onTap,
  });
  final bool loading;
  final bool canLoad;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: canLoad ? 1.0 : 0.6,
        child: OutlinedButton.icon(
          onPressed: (loading || !canLoad) ? null : onTap,
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.expand_more, size: 18),
          label: Text(loading ? '加载中…' : '加载更多'),
        ),
      ),
    );
  }
}

// ───────────────────────── 空态 / 错误态 ─────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => context
          .read<TransactionBloc>()
          .add(const LoadTransactionsRequested()),
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      size: 30, color: AppColors.accent),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('还没有交易',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('点击「新增交易」开始记录第一笔',
                    style: TextStyle(color: AppColors.muted, fontSize: 14)),
                const SizedBox(height: AppSpacing.lg),
                _CreateButton(onPressed: onCreate),
              ],
            ),
          ),
        ],
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
              const Icon(Icons.error_outline,
                  size: 40, color: AppColors.negative),
              const SizedBox(height: AppSpacing.md),
              Text(message,
                  style: const TextStyle(
                      color: AppColors.negative, fontSize: 15)),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
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
