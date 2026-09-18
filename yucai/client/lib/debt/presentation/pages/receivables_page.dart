import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';

/// 债权列表页(别人欠我 / 应收)。
///
/// **结构样式与 [DebtsPage] 完全一致(镜像)** —— 共享 [DebtListOverviewCard] /
/// [DebtListStatStrip] / [DebtListCard] / [DebtListFilterSegmented] 等组件,
/// 差异只在内容(文案/数据/颜色)由 [DebtViewSemantics.receivable] 注入:
///  - 文案:债权总览 / 总借出本金 / 剩余应收 / 本金收回进度 / 已收 / 待收 /
///    下次收款 / 查看收款计划 / 收款 / 债权明细 / 创建债权
///  - 数据:summary 驱动(ReceivablesSummary server-side)trend / 待收利息 / 下次收款
///  - 颜色:累计利息 = 绿(收入);待收本金中性
///
/// Bloc 以 `LoadDebtsRequested(typeFilter: DebtType.borrowedOut)` 仅取债权。
/// 注入:路由层 BlocProvider<DebtBloc>;本页 context.watch<DebtBloc>()。
class ReceivablesPage extends StatefulWidget {
  const ReceivablesPage({super.key});

  @override
  State<ReceivablesPage> createState() => _ReceivablesPageState();
}

class _ReceivablesPageState extends State<ReceivablesPage> with RouteAware {
  // 默认「全部」(2026-09-17 用户反馈:默认「进行中」会把已结清债务藏起来,
  // 总览总额与账户页负债口径对不上 —— 两页账目必须同口径可见)。
  DebtListFilter _filter = DebtListFilter.all;
  // 分类(subtype)筛选:null/空 = 全部(ReceivableSubtypes.* key)。
  String? _subtype;
  ReceivablesSummary? _summary;

  // F9 FR-4 查询态(与 debts_page 镜像:共享 DebtSearchSortBar + domain 纯函数
  // 管道;页面 Stateful 管理,不动 bloc/repo 契约)。
  /// 提交制搜索词('' = 无,匹配口径 = debtSearchMatches)。
  String _search = '';
  /// 排序四态;默认 (dueDate, asc) = debtCompareList 现状序(NFR-2 逐位一致)。
  DebtSortKey _sortKey = DebtSortKey.dueDate;
  DebtSortDir _sortDir = DebtSortDir.asc;

  static const _sem = DebtViewSemantics.receivable;

  @override
  void initState() {
    super.initState();
    // 不带 typeFilter 全量拉取(bloc 状态对 debts/receivables 两页共享),
    // 本页在 _debtsOf 表现层切片 borrowedOut(债权),与 DebtsPage 镜像。
    _dataRefresh.addListener(_onDataRefresh);
    context.read<DebtBloc>().add(const LoadDebtsRequested());
    _loadSummary();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅 receivables 分支观察者(router.dart branch observers):顶层
    // routeObserver 挂根 Navigator,看不到本分支嵌套 Navigator 的
    // /receivables/new、/receivables/:id push/pop → didPopNext 从未触发,
    // 汇总(债权笔数等)只在 initState 拉一次,创建首笔债权后停在 0。
    receivablesRouteObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  late final DataRefreshNotifier _dataRefresh = getIt<DataRefreshNotifier>();

  void _onDataRefresh() {
    if (mounted) {
      context.read<DebtBloc>().add(const LoadDebtsRequested());
    }
  }

  @override
  void dispose() {
    _dataRefresh.removeListener(_onDataRefresh);
    receivablesRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (mounted) {
      context.read<DebtBloc>().add(const LoadDebtsRequested());
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    final repo = getIt<ReceivablesSummaryRepository>();
    final result = await repo.fetch();
    if (!mounted) return;
    result.fold((_) => null, (s) => setState(() => _summary = s));
  }

  List<Debt> _debtsOf(DebtState state) {
    // 共享 bloc 状态可能含 borrowedIn(债务)—— 本页只取 borrowedOut 切片。
    List<Debt> slice(List<Debt> all) =>
        all.where((d) => d.type == DebtType.borrowedOut).toList();
    if (state is DebtsLoaded) return slice(state.debts);
    if (state is DebtSubmitting) return slice(state.last);
    if (state is DebtError) return slice(state.last);
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: BlocBuilder<DebtBloc, DebtState>(
        builder: (context, state) {
          final debts = _debtsOf(state);
          final loading = state is DebtLoading && debts.isEmpty;
          if (loading) return const Center(child: CircularProgressIndicator());
          if (debts.isEmpty) return _emptyState();
          return _content(debts);
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.yucai.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_sem.emptyIcon, size: 30, color: context.yucai.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_sem.emptyTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_sem.emptySub,
              style: TextStyle(color: context.yucai.muted, fontSize: 14)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push(_sem.newRoute),
            icon: const Icon(LucideIcons.plus),
            label: Text(_sem.emptyBtn),
            style: FilledButton.styleFrom(
              backgroundColor: context.yucai.accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<Debt> debts) {
    final cstate = context.watch<CurrencyBloc>().state;
    final preferred = cstate.preferred;

    int toPreferred(int cents) =>
        toPreferredCents(cents, 'CNY', cstate.rates, preferred);

    // F9 FR-4 前端查询管道(与 debts_page 镜像;DS list 参数同口径):搜索 →
    // 排序 → 状态筛选 → 分类筛选。
    final searched =
        debts.where((d) => debtSearchMatches(d, _search)).toList();
    final filtered = ([...searched]
          ..sort((a, b) => debtCompareQuery(a, b, _sortKey, _sortDir)))
        .where((d) => debtMatchesListFilter(d, _filter))
        .where((d) => debtMatchesSubtype(d, _subtype))
        .toList();

    // 总览/统计条按**筛选后**集合计算(与 debts_page 同裁决:统计跟随所见)。
    final totalRemaining = filtered.fold<int>(
        0, (s, d) => s + toPreferred(d.remainingPrincipalCents));
    // 未收利息单独成卡(不与本金混合)。
    final totalUnpaidInterest = filtered.fold<int>(
        0, (s, d) => s + toPreferred(d.unpaidInterestCents));
    final totalPrincipal = filtered.fold<int>(
        0, (s, d) => s + toPreferred(d.totalPrincipalCents));
    final totalCollected = totalPrincipal - totalRemaining;
    final overallRatio = totalPrincipal > 0
        ? (totalCollected / totalPrincipal).clamp(0.0, 1.0)
        : 0.0;
    final nextCollectDate = filtered.isEmpty
        ? null
        : filtered.map((d) => d.dueDate).reduce((a, b) => a.isBefore(b) ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DebtListOverviewCard(
                sem: _sem,
                preferred: preferred,
                totalPrincipal: totalPrincipal,
                totalRemaining: totalRemaining,
                totalCollected: totalCollected,
                count: filtered.length,
                overallRatio: overallRatio,
                nextCollectDate: nextCollectDate,
                trendCents: _summary?.principalTrendCents,
                newCountThisMonth: _summary?.newCountThisMonth ?? 0,
                pendingInterestCents: _summary?.pendingInterestCents,
                nextPayment: _summary?.nextPaymentDate == null
                    ? null
                    : OvNextPayment(
                        date: _summary!.nextPaymentDate!,
                        counterparty: _summary!.nextPaymentCounterparty,
                        periodNo: _summary!.nextPaymentPeriodNo,
                        amountCents: _summary!.nextPaymentAmountCents,
                      ),
                firstId: debts.isEmpty ? null : debts.first.id,
                unpaidInterestCents: totalUnpaidInterest,
              ),
              const SizedBox(height: AppSpacing.md),
              DebtListStatStrip(cards: _statCards(filtered, preferred, totalUnpaidInterest)),
              const SizedBox(height: AppSpacing.lg),
              // F9 FR-4 共享查询控件条(搜索 + 排序;无分页条 —— 矩阵定案)。
              DebtSearchSortBar(
                searchText: _search,
                sortKey: _sortKey,
                sortDir: _sortDir,
                onSearchCommit: (v) => setState(() => _search = v),
                onSortChanged: (k, d) => setState(() {
                  _sortKey = k;
                  _sortDir = d;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
              // 分类筛选 chips(全部 + ReceivableSubtypes)。
              DebtSubtypeChips(
                labels: ReceivableSubtypes.labels,
                selected: _subtype,
                onChanged: (v) => setState(() => _subtype = v),
              ),
              const SizedBox(height: AppSpacing.md),
              _sectionHeadWithFilter(searched.length),
              const SizedBox(height: AppSpacing.sm),
              if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('该筛选下无债权',
                        style:
                            TextStyle(color: context.yucai.muted, fontSize: 12)),
                  ),
                )
              else
                Column(
                  // key 供测试把列表断言与 overview callout(summary 驱动,
                  // 不随筛选变化)区分开。
                  key: const ValueKey('debtListItems'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      DebtListCard(
                        sem: _sem,
                        debt: filtered[i],
                        preferred: preferred,
                        badgeFor: _badgeFor,
                        avatarColorFor: _avatarColorFor,
                      ),
                      if (i < filtered.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// L2 stat strip 4 卡(summary 驱动;null → '—' 占位)。
  List<DebtListStatCardData> _statCards(
      List<Debt> debts, String preferred, int unpaidInterest) {
    if (_summary == null) {
      return [
        const DebtListStatCardData(
            label: '债权笔数', value: '—', icon: LucideIcons.layers),
        const DebtListStatCardData(
            label: '已收本息', value: '—', icon: LucideIcons.trendingUp),
        const DebtListStatCardData(
            label: '待收利息', value: '—', icon: LucideIcons.clock),
        const DebtListStatCardData(
            label: '逾期应收', value: '—', icon: LucideIcons.triangleAlert),
      ];
    }
    final s = _summary!;
    return [
      DebtListStatCardData(
          label: _sem.statCountLabel,
          value: '${s.count}',
          sub: '私人·商业·亲友',
          icon: LucideIcons.layers),
      DebtListStatCardData(
          label: _sem.statCollectedLabel,
          value: sharedFmtSymbol(s.totalCollectedCents, preferred),
          color: context.yucai.positive,
          icon: LucideIcons.trendingUp,
          sub: (s.totalCollectedCents + s.totalRemainingCents) > 0
              ? '${(s.totalCollectedCents * 100 / (s.totalCollectedCents + s.totalRemainingCents)).toStringAsFixed(1)}% 已收回'
              : _sem.collectedSubEmpty),
      DebtListStatCardData(
          label: _sem.statPendingInterestLabel,
          value: sharedFmtSymbol(s.pendingInterestCents, preferred),
          icon: LucideIcons.clock,
          sub: '${s.count} 笔在追'),
      DebtListStatCardData(
          label: _sem.statOverdueLabel,
          value: sharedFmtSymbol(s.overdueAmountCents, preferred),
          color: context.yucai.negative,
          sub: '${s.overdueCount} 笔',
          icon: LucideIcons.triangleAlert),
    ];
  }

  Widget _sectionHeadWithFilter(int count) {
    final segmented = DebtListFilterSegmented(
      filter: _filter,
      activeCount: countWhere((d) => d.remainingPrincipalCents > 0),
      settledCount: countWhere((d) => d.remainingPrincipalCents <= 0),
      overdueCount: countWhere(
          (d) => d.remainingPrincipalCents > 0 && d.dueDate.isBefore(DateTime.now())),
      onChanged: (f) => setState(() => _filter = f),
    );
    final head = Row(children: [
      Text(_sem.sectionListTitle,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback)),
      const SizedBox(width: 6),
      Text('$count 笔',
          style: TextStyle(
              fontSize: 12.5,
              color: context.yucai.muted,
              fontFeatures: AppTypography.tabularFigures)),
    ]);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 560) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [head, const Spacer(), segmented],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          head,
          const SizedBox(height: AppSpacing.sm),
          segmented,
        ],
      );
    });
  }

  // 计数 helper(避免重复 MediaQuery;基于全量 debts)。F9-T3:segmented 计数
  // 基于**搜索后**集合(搜索空 = 全量,与现状一致)。
  int countWhere(bool Function(Debt) test) {
    final debts = _debtsOf(context.read<DebtBloc>().state)
        .where((d) => debtSearchMatches(d, _search));
    return debts.where(test).length;
  }

  // ───────────────────────── 类型 badge / avatar 色(ReceivableSubtypes 专属) ─────────────────────────

  DebtBadgeStyle _badgeFor(Debt debt) {
    if (debt.subtype.isNotEmpty) {
      final label = ReceivableSubtypes.labels[debt.subtype];
      if (label != null) {
        return DebtBadgeStyle(
            label: label, fg: context.yucai.accentDeep, bg: context.yucai.accentSoft);
      }
    }
    return _inferBadge(debt.counterparty);
  }

  DebtBadgeStyle _inferBadge(String counterparty) {
    final s = counterparty.toLowerCase();
    if (counterparty.contains('公司') ||
        counterparty.contains('企业') ||
        counterparty.contains('商') ||
        s.contains('biz') ||
        s.contains('business')) {
      // F4-P2 fix:商业借款蓝 #3A6695 + 亮底 #EAF0F6(暗色下亮底刺眼/蓝偏闷)
      // → info 语义令牌(同 account_detail 蓝裁决)+ 10% 派生透底。
      return DebtBadgeStyle(
          label: '商业借款',
          fg: context.yucai.info,
          bg: context.yucai.info.withValues(alpha: 0.10));
    }
    if (counterparty.contains('亲友') ||
        counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return DebtBadgeStyle(
          label: '亲友借款',
          fg: context.yucai.positive,
          bg: context.yucai.positive.withValues(alpha: 0.10));
    }
    if (counterparty.contains('信用卡') || s.contains('credit')) {
      return DebtBadgeStyle(
          label: '信用卡',
          fg: context.yucai.negative,
          bg: context.yucai.negative.withValues(alpha: 0.10));
    }
    return DebtBadgeStyle(
        label: '私人借款', fg: context.yucai.accentDeep, bg: context.yucai.accentSoft);
  }

  Color _avatarColorFor(Debt debt) {
    if (debt.subtype.isNotEmpty) return context.yucai.accentDeep;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('公司') ||
        debt.counterparty.contains('企业') ||
        debt.counterparty.contains('商') ||
        s.contains('biz') ||
        s.contains('business')) {
      // 商业借款 avatar 蓝 → info 令牌(与 _inferBadge 同裁决)。
      return context.yucai.info;
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return context.yucai.positive;
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return context.yucai.negative;
    }
    return context.yucai.muted;
  }
}
