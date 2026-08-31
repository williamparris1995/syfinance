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
  DebtListFilter _filter = DebtListFilter.active;
  ReceivablesSummary? _summary;

  static const _sem = DebtViewSemantics.receivable;

  @override
  void initState() {
    super.initState();
    context
        .read<DebtBloc>()
        .add(const LoadDebtsRequested(typeFilter: DebtType.borrowedOut));
    _loadSummary();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (mounted) {
      context
          .read<DebtBloc>()
          .add(const LoadDebtsRequested(typeFilter: DebtType.borrowedOut));
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
    if (state is DebtsLoaded) return state.debts;
    if (state is DebtSubmitting) return state.last;
    if (state is DebtError) return state.last;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
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
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(_sem.emptyIcon, size: 30, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_sem.emptyTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_sem.emptySub,
              style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push(_sem.newRoute),
            icon: const Icon(LucideIcons.plus),
            label: Text(_sem.emptyBtn),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
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

    final totalRemaining = debts.fold<int>(
        0, (s, d) => s + toPreferred(d.remainingPrincipalCents));
    final totalPrincipal = debts.fold<int>(
        0, (s, d) => s + toPreferred(d.totalPrincipalCents));
    final totalCollected = totalPrincipal - totalRemaining;
    final overallRatio = totalPrincipal > 0
        ? (totalCollected / totalPrincipal).clamp(0.0, 1.0)
        : 0.0;
    final nextCollectDate = debts.isEmpty
        ? null
        : debts.map((d) => d.dueDate).reduce((a, b) => a.isBefore(b) ? a : b);

    final filtered = ([...debts]..sort(debtCompareList))
        .where((d) => debtMatchesListFilter(d, _filter))
        .toList();

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
                count: debts.length,
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
              ),
              const SizedBox(height: AppSpacing.md),
              DebtListStatStrip(cards: _statCards(debts, preferred)),
              const SizedBox(height: AppSpacing.lg),
              _sectionHeadWithFilter(debts.length),
              const SizedBox(height: AppSpacing.sm),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('该筛选下无债权',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 12)),
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
  List<DebtListStatCardData> _statCards(List<Debt> debts, String preferred) {
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
          color: AppColors.positive,
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
          color: AppColors.negative,
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
          style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.muted,
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

  // 计数 helper(避免重复 MediaQuery;基于全量 debts)。
  int countWhere(bool Function(Debt) test) {
    final debts = _debtsOf(context.read<DebtBloc>().state);
    return debts.where(test).length;
  }

  // ───────────────────────── 类型 badge / avatar 色(ReceivableSubtypes 专属) ─────────────────────────

  DebtBadgeStyle _badgeFor(Debt debt) {
    if (debt.subtype.isNotEmpty) {
      final label = ReceivableSubtypes.labels[debt.subtype];
      if (label != null) {
        return DebtBadgeStyle(
            label: label, fg: AppColors.accentHover, bg: AppColors.accentSoft);
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
      return const DebtBadgeStyle(
          label: '商业借款', fg: Color(0xFF3A6695), bg: Color(0xFFEAF0F6));
    }
    if (counterparty.contains('亲友') ||
        counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return const DebtBadgeStyle(
          label: '亲友借款', fg: AppColors.positive, bg: Color(0x1A2D8A6E));
    }
    if (counterparty.contains('信用卡') || s.contains('credit')) {
      return const DebtBadgeStyle(
          label: '信用卡', fg: AppColors.negative, bg: Color(0x1AC4544D));
    }
    return const DebtBadgeStyle(
        label: '私人借款', fg: AppColors.accentHover, bg: AppColors.accentSoft);
  }

  Color _avatarColorFor(Debt debt) {
    if (debt.subtype.isNotEmpty) return AppColors.accentHover;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('公司') ||
        debt.counterparty.contains('企业') ||
        debt.counterparty.contains('商') ||
        s.contains('biz') ||
        s.contains('business')) {
      return const Color(0xFF3A6695);
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return AppColors.positive;
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return AppColors.negative;
    }
    return const Color(0xFF7A776E);
  }
}
