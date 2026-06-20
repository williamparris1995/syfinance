import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

/// 交易列表页。对齐 OD 原型 `yucai-transaction-trisize-9d3e/transactions.html`：
///   - 页头：H1 + 副标题（月份 · 共 N 笔）+ 导出按钮 + 新增交易
///   - 汇总四卡（SummaryCard）—— 本月收入/支出/净额/日均
///   - TxnFilterBar（类型分段 + 账户/分类/月份下拉 + 重置）
///   - 单张 tx-card 内按日分组：day-row 分隔条 + 表格行
///     （日期 / 交易详情（图标+描述）/ 分类 chip / 账户标签 / 金额 / ⋯ 操作）
///   - 分页页脚：显示第 X–Y 条，共 N 条 + 游标「加载更多」
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
    Navigator.of(context).pushNamed('/transactions/$id');
  }

  void _export() {
    // 导出占位：原型有「导出」按钮但后端导出 RPC 尚未落地；此处仅提示。
    if (!mounted) return;
    AppToast.show(context, '导出功能即将上线');
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
            onExport: _export,
            onOpenDetail: _openDetail,
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
    required this.onExport,
    required this.onOpenDetail,
    required this.onLoadMore,
  });

  /// TransactionsLoaded or TransactionsLoadingMore (both carry the list).
  final TransactionState state;
  final bool loadingMore;
  final ValueChanged<TxnFilterState> onFilterChanged;
  final VoidCallback onCreate;
  final VoidCallback onExport;
  final ValueChanged<String> onOpenDetail;
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
                        onOpenDetail: onOpenDetail,
                      ),
                      tablet: _TxCard(
                        groups: groups,
                        accounts: accounts,
                        onOpenDetail: onOpenDetail,
                        hasMore: _hasMore,
                        loadingMore: loadingMore,
                        onLoadMore: onLoadMore,
                        totalCount: _txns.length,
                      ),
                      desktop: _TxCard(
                        groups: groups,
                        accounts: accounts,
                        onOpenDetail: onOpenDetail,
                        hasMore: _hasMore,
                        loadingMore: loadingMore,
                        onLoadMore: onLoadMore,
                        totalCount: _txns.length,
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
              const Text('交易记录',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$monthLabel · 共 $count 笔',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        _ExportButton(onPressed: onExport),
        const SizedBox(width: AppSpacing.sm),
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
          decoration: const BoxDecoration(
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
            color: AppColors.surface,
            borderRadius: AppRadius.smBorder,
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_outlined, size: 15, color: AppColors.muted),
              SizedBox(width: 6),
              Text('导出',
                  style: TextStyle(
                      color: AppColors.muted,
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
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
    required this.totalCount,
  });

  final Map<String, List<Transaction>> groups;
  final List<Account> accounts;
  final ValueChanged<String> onOpenDetail;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;
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
          const Divider(height: 1, color: AppColors.border),
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
            total: totalCount,
            hasMore: hasMore,
            loadingMore: loadingMore,
            onLoadMore: onLoadMore,
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      color: AppColors.muted,
      fontSize: 11.5,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w500,
    );
    return const Padding(
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
      color: AppColors.surfaceAlt,
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
                  const TextStyle(color: AppColors.muted, fontSize: 11)),
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

  TxnFlavour get _flavour => inferFlavour(txn);

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
                  style: const TextStyle(
                      color: AppColors.muted,
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

  /// 转账判定：两条 entry 且两端账户都是 asset（无元信息退化为平衡两行）。
  bool get _isTransfer {
    if (txn.entries.length != 2) return false;
    final e0 = accountOf(txn.entries[0].accountId);
    final e1 = accountOf(txn.entries[1].accountId);
    if (e0 == null || e1 == null) return txn.isBalanced;
    return e0.accountType == AccountType.asset &&
        e1.accountType == AccountType.asset;
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward, size: 14, color: AppColors.muted),
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
  });

  final String description;
  final TxnFlavour flavour;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TxIconBox(flavour: flavour),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                description.isEmpty ? '(无描述)' : description,
                style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
              if (secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(secondary,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12),
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
  const _TxIconBox({required this.flavour});
  final TxnFlavour flavour;

  (Color, Color, IconData) get _styling {
    switch (flavour) {
      case TxnFlavour.income:
        return (AppColors.positive, const Color(0x1A2D8A6E), Icons.call_received);
      case TxnFlavour.expense:
        return (AppColors.negative, const Color(0x1AC4544D), Icons.call_made);
      case TxnFlavour.transfer:
        return (AppColors.accent, AppColors.accentSoft, Icons.swap_horiz);
      case TxnFlavour.compound:
        return (AppColors.accent, AppColors.accentSoft, Icons.receipt_outlined);
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
    final label = account!.category.label;
    final isIncomeType = account!.accountType == AccountType.income;
    final isExpenseType = account!.accountType == AccountType.expense;
    final fg = isIncomeType
        ? const Color(0xFF236B56)
        : (isExpenseType ? const Color(0xFFA0443E) : AppColors.muted);
    final bg = isIncomeType
        ? const Color(0x1A2D8A6E)
        : (isExpenseType ? const Color(0x1AC4544D) : AppColors.surfaceAlt);
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
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(ab,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              style: const TextStyle(color: AppColors.fg, fontSize: 13),
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
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.more_horiz, size: 16, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _PagerFooter extends StatelessWidget {
  const _PagerFooter({
    required this.showing,
    required this.total,
    required this.hasMore,
    required this.loadingMore,
    required this.onLoadMore,
  });

  final int showing;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text('显示 $showing 条',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const Spacer(),
          if (hasMore || loadingMore)
            _LoadMoreControl(
              loading: loadingMore,
              canLoad: hasMore,
              onTap: onLoadMore,
            )
          else
            const Text('已全部加载',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ───────────────────────── 移动端：卡片堆叠 ─────────────────────────

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

  TxnFlavour get _flavour => inferFlavour(txn);

  /// 转账判定：两条 entry 且两端账户都是 asset（无元信息退化为平衡两行）。
  bool get _isTransfer {
    if (txn.entries.length != 2) return false;
    final e0 = accountOf(txn.entries[0].accountId);
    final e1 = accountOf(txn.entries[1].accountId);
    if (e0 == null || e1 == null) return txn.isBalanced;
    return e0.accountType == AccountType.asset &&
        e1.accountType == AccountType.asset;
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
          color: AppColors.surface,
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _TxIconBox(flavour: flavour),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description.isEmpty ? '(无描述)' : txn.description,
                    style: const TextStyle(
                        color: AppColors.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  if (isTransfer)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                            child: _AccountTag(
                                label: fromLabel, account: null)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward,
                              size: 14, color: AppColors.muted),
                        ),
                        Flexible(
                            child:
                                _AccountTag(label: toLabel, account: null)),
                      ],
                    )
                  else
                    Text(
                      [
                        _formatDate(txn.transactionDate),
                        if (singleLabel.isNotEmpty) singleLabel,
                      ].join(' · '),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                ],
              ),
            ),
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
    return Opacity(
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
