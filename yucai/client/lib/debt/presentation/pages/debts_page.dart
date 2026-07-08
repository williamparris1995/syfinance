import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';

/// 债务列表页(我欠别人 / 应付)。
///
/// **结构样式与 [ReceivablesPage] 完全一致(镜像)** —— 共享 [DebtListOverviewCard] /
/// [DebtListStatStrip] / [DebtListCard] / [DebtListFilterSegmented] 等组件,差异只在
/// 内容(文案/数据/颜色)由 [DebtViewSemantics.debt] 注入:
///  - 文案:债务总览 / 总借款本金 / 剩余待还(本金) / 本金还清进度 / 已还 / 待还 /
///    下次还款 / 查看还款计划 / 立即记账 / 债务清单 / 创建债务
///  - 数据:本地算(debt 无 summary repo)—— 笔数 / 总本金 / 累计已还本息 / 待还本金
///  - 颜色:累计已还本息 = 绿(positive);待还本金 = 逾期时红
///
/// debt 专属附录:列表底部「雪崩法」advice banner(receivables 无;不破坏主结构镜像)。
class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> with RouteAware {
  DebtListFilter _filter = DebtListFilter.active;

  static const _sem = DebtViewSemantics.debt;

  @override
  void initState() {
    super.initState();
    // borrowedIn 过滤:只列借入方向(负债),排除借出方向(债权/应收)。
    context
        .read<DebtBloc>()
        .add(const LoadDebtsRequested(typeFilter: DebtType.borrowedIn));
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
          .add(const LoadDebtsRequested(typeFilter: DebtType.borrowedIn));
    }
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
    final totalRepaid = totalPrincipal - totalRemaining;
    final overallRatio = totalPrincipal > 0
        ? (totalRepaid / totalPrincipal).clamp(0.0, 1.0)
        : 0.0;
    final nextPaymentDate = debts.isEmpty
        ? null
        : debts.map((d) => d.dueDate).reduce((a, b) => a.isBefore(b) ? a : b);

    final overdueCount = debts
        .where((d) =>
            d.remainingPrincipalCents > 0 && d.dueDate.isBefore(DateTime.now()))
        .length;

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
                totalCollected: totalRepaid,
                count: debts.length,
                overallRatio: overallRatio,
                nextCollectDate: nextPaymentDate,
                // debt 无 server summary:trend/精确下次还款留空 → fallback foot。
              ),
              const SizedBox(height: AppSpacing.md),
              DebtListStatStrip(
                  cards: _statCards(debts, totalPrincipal, totalRepaid,
                      totalRemaining, overdueCount, preferred)),
              const SizedBox(height: AppSpacing.lg),
              _sectionHeadWithFilter(debts.length),
              const SizedBox(height: AppSpacing.sm),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('该筛选下无债务',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                )
              else
                Column(
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
              const SizedBox(height: AppSpacing.lg),
              // debt 专属附录:雪崩法 advice banner(receivables 无;不破坏主结构镜像)。
              if (debts.where((d) => d.remainingPrincipalCents > 0).length >= 2)
                _AvalancheBanner(debts: debts),
            ],
          ),
        ),
      ),
    );
  }

  /// L2 stat strip 4 卡(本地算):债务笔数 / 总借款本金 / 累计已还本息(绿)/ 待还本金(逾期红)。
  List<DebtListStatCardData> _statCards(List<Debt> debts, int totalPrincipal,
      int totalRepaid, int totalRemaining, int overdueCount, String preferred) {
    return [
      DebtListStatCardData(
          label: _sem.statCountLabel,
          value: '${debts.length}',
          sub: '在途负债',
          icon: LucideIcons.layers),
      DebtListStatCardData(
          label: '总借款本金',
          value: sharedFmtSymbol(totalPrincipal, preferred),
          icon: LucideIcons.banknote,
          sub: '原始本金合计'),
      DebtListStatCardData(
          label: _sem.statCollectedLabel,
          value: sharedFmtSymbol(totalRepaid, preferred),
          icon: LucideIcons.trendingUp,
          color: AppColors.positive,
          sub: totalPrincipal > 0
              ? '${(totalRepaid * 100 / totalPrincipal).toStringAsFixed(1)}% 已还'
              : _sem.collectedSubEmpty),
      DebtListStatCardData(
          label: '待还本金',
          value: sharedFmtSymbol(totalRemaining, preferred),
          icon: LucideIcons.clock,
          color: overdueCount > 0 ? AppColors.negative : null,
          sub: overdueCount > 0 ? '含 $overdueCount 笔逾期' : '${debts.length} 笔待还'),
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

  int countWhere(bool Function(Debt) test) {
    final debts = _debtsOf(context.read<DebtBloc>().state);
    return debts.where(test).length;
  }

  // ───────────────────────── 类型 badge / avatar 色(DebtSubtypes 专属) ─────────────────────────

  DebtBadgeStyle _badgeFor(Debt debt) {
    if (debt.subtype.isNotEmpty) {
      final label = DebtSubtypes.labels[debt.subtype];
      if (label != null) {
        return DebtBadgeStyle(
            label: label, fg: AppColors.accentHover, bg: AppColors.accentSoft);
      }
    }
    return _inferBadge(debt.counterparty);
  }

  DebtBadgeStyle _inferBadge(String counterparty) {
    final s = counterparty.toLowerCase();
    if (counterparty.contains('房') || s.contains('mortgage')) {
      return const DebtBadgeStyle(
          label: '房贷', fg: AppColors.accentHover, bg: AppColors.accentSoft);
    }
    if (counterparty.contains('车') || s.contains('car')) {
      return const DebtBadgeStyle(
          label: '车贷', fg: Color(0xFF56606B), bg: Color(0xFFEEF0F2));
    }
    if (counterparty.contains('信用卡') || s.contains('credit')) {
      return const DebtBadgeStyle(
          label: '信用卡', fg: AppColors.negative, bg: Color(0x1AC4544D));
    }
    if (counterparty.contains('亲友') ||
        counterparty.contains('借') ||
        s.contains('friend')) {
      return const DebtBadgeStyle(
          label: '亲友借款', fg: AppColors.positive, bg: Color(0x1A2D8A6E));
    }
    return const DebtBadgeStyle(
        label: '借款', fg: AppColors.accentHover, bg: AppColors.accentSoft);
  }

  Color _avatarColorFor(Debt debt) {
    if (debt.subtype.isNotEmpty) return AppColors.accentHover;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('房') || s.contains('mortgage')) {
      return AppColors.accentHover;
    }
    if (debt.counterparty.contains('车') || s.contains('car')) {
      return const Color(0xFF56606B);
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return AppColors.negative;
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('借') ||
        s.contains('friend')) {
      return AppColors.positive;
    }
    return const Color(0xFF7A776E);
  }
}

// ───────────────────────── 雪崩法 advice banner(debt 专属附录) ─────────────────────────

/// 雪崩法 advice banner:建议优先还利率最高的债务。仅 ≥2 笔在途债务时显。
/// receivables 无对应物 —— 列表底部附录,不参与主结构(overview/stat/cards)镜像。
class _AvalancheBanner extends StatelessWidget {
  const _AvalancheBanner({required this.debts});
  final List<Debt> debts;

  @override
  Widget build(BuildContext context) {
    final active = debts.where((d) => d.remainingPrincipalCents > 0).toList();
    if (active.length < 2) return const SizedBox.shrink();
    final top = ([...active]
          ..sort((a, b) => b.interestRate.compareTo(a.interestRate)))
        .first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: const Color(0xFFDDCBA6), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 16, color: AppColors.accentHover),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                    fontSize: 12.5, color: Color(0xFF7C6A47), height: 1.5),
                children: [
                  const TextSpan(
                      text: '建议采用「雪崩法」优先偿还利率最高的 ',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  TextSpan(
                      text:
                          '${top.counterparty}(${top.interestRate.toStringAsFixed(2)}%)',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const TextSpan(
                      text: ',可在相同月供下节省更多利息。',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
