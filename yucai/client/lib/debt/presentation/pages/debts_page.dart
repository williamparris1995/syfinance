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
import 'package:yucai_client/debt/domain/debt_query.dart';
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

  // F9 FR-4 查询态(页面 Stateful 管理,与 _filter 同管道,不动 bloc/repo 契约
  // —— 列表已全量在 bloc 状态里,前端 in-memory 过滤/排序即 NFR-3 口径,与
  // DS list 查询参数共用 domain 纯函数)。
  /// 提交制搜索词('' = 无,匹配口径 = debtSearchMatches)。
  String _search = '';
  /// 排序四态;默认 (dueDate, asc) = debtCompareList 现状序(NFR-2 逐位一致)。
  DebtSortKey _sortKey = DebtSortKey.dueDate;
  DebtSortDir _sortDir = DebtSortDir.asc;

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

    // F9 FR-4 前端查询管道(与 DS list 参数同口径,复用 domain 纯函数):
    // 搜索(counterparty contains 忽略大小写)→ 四态排序 → segmented 筛选。
    // 默认态(空搜索 + dueDate/asc)与改造前逐位一致(NFR-2)。总览/统计条仍按
    // 全量 debts 计算 —— 搜索只作用于列表,不改合计口径。
    final searched =
        debts.where((d) => debtSearchMatches(d, _search)).toList();
    final filtered = ([...searched]
          ..sort((a, b) => debtCompareQuery(a, b, _sortKey, _sortDir)))
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
              _sectionHeadWithFilter(searched.length),
              const SizedBox(height: AppSpacing.sm),
              if (filtered.isEmpty)
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('该筛选下无债务',
                        style:
                            TextStyle(color: context.yucai.muted, fontSize: 12)),
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
          color: context.yucai.positive,
          sub: totalPrincipal > 0
              ? '${(totalRepaid * 100 / totalPrincipal).toStringAsFixed(1)}% 已还'
              : _sem.collectedSubEmpty),
      DebtListStatCardData(
          label: '待还本金',
          value: sharedFmtSymbol(totalRemaining, preferred),
          icon: LucideIcons.clock,
          color: overdueCount > 0 ? context.yucai.negative : null,
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

  /// F9-T3:segmented 计数基于**搜索后**集合(搜索空 = 全量,与现状一致)。
  int countWhere(bool Function(Debt) test) {
    final debts = _debtsOf(context.read<DebtBloc>().state)
        .where((d) => debtSearchMatches(d, _search));
    return debts.where(test).length;
  }

  // ───────────────────────── 类型 badge / avatar 色(DebtSubtypes 专属) ─────────────────────────

  DebtBadgeStyle _badgeFor(Debt debt) {
    if (debt.subtype.isNotEmpty) {
      final label = DebtSubtypes.labels[debt.subtype];
      if (label != null) {
        return DebtBadgeStyle(
            label: label, fg: context.yucai.accentDeep, bg: context.yucai.accentSoft);
      }
    }
    return _inferBadge(debt.counterparty);
  }

  DebtBadgeStyle _inferBadge(String counterparty) {
    final s = counterparty.toLowerCase();
    if (counterparty.contains('房') || s.contains('mortgage')) {
      return DebtBadgeStyle(
          label: '房贷', fg: context.yucai.accentDeep, bg: context.yucai.accentSoft);
    }
    if (counterparty.contains('车') || s.contains('car')) {
      return DebtBadgeStyle(
          label: '车贷', fg: context.yucai.muted, bg: Color(0xFFEEF0F2));
    }
    if (counterparty.contains('信用卡') || s.contains('credit')) {
      return DebtBadgeStyle(
          label: '信用卡', fg: context.yucai.negative, bg: Color(0x1AC4544D));
    }
    if (counterparty.contains('亲友') ||
        counterparty.contains('借') ||
        s.contains('friend')) {
      return DebtBadgeStyle(
          label: '亲友借款', fg: context.yucai.positive, bg: Color(0x1A2D8A6E));
    }
    return DebtBadgeStyle(
        label: '借款', fg: context.yucai.accentDeep, bg: context.yucai.accentSoft);
  }

  Color _avatarColorFor(Debt debt) {
    if (debt.subtype.isNotEmpty) return context.yucai.accentDeep;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('房') || s.contains('mortgage')) {
      return context.yucai.accentDeep;
    }
    if (debt.counterparty.contains('车') || s.contains('car')) {
      return context.yucai.muted;
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return context.yucai.negative;
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('借') ||
        s.contains('friend')) {
      return context.yucai.positive;
    }
    return context.yucai.muted;
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
        color: context.yucai.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.yucai.accentDeep, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: context.yucai.accentDeep),
          const SizedBox(width: 11),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                    fontSize: 12.5, color: context.yucai.accentDeep, height: 1.5),
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
