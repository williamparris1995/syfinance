// 投资目标关联页(holding-D,Task 11)。
//
// 数据源(holding-D 真接,D-goal Task 10 接口):
//   - HoldingRepository.listInvestmentGoals() → Either<Failure, List<GoalView>>
//     (server 按 type=INVESTMENT filter,跨模块 goal gRPC 经 GoalViewDataSource)
//   - 客户端 filter linkedAccountId == holding.accountId(investment goals 少,
//     首批客户端 filter 足够;避免 proto/repo 加 linked_account filter)
//   - D-goal account 级:goal.linked_account_id 关联 investment account,
//     progress = Σ 该账户下 holdings mv(server 算 current_amount_cents)。
//
// 构造:从 holding 详情进,接收 holding(含 accountId + marketValueCents,供
//   贡献占比计算)。goalRepo(HoldingRepository)注入便于 widget test。
//
// 对齐 A-od 设计源 goal-link-{desktop,tablet,mobile}.html:
//   ① 概览头(达成统计:总数 / 超前(≥100%) / 持平(80-100%) / 落后(<80%),3 列紧凑)
//   ② goal 紧凑卡片列表(名 / 进度% / current / target / 该 holding 贡献 / 进度条)
//   ③ 关联 holding 选择(同账户 holdings 列表渲染,picker)
//   ④ 实现说明(account 级 goal + 贡献口径)
//
// 渲染模式:FutureBuilder<Either<Failure, List<GoalView>>>(无新 bloc,简化)。
//   - loading → 圆圈
//   - Left(failure) → 错误空态(displayMessage)
//   - Right(空 filter 结果) → 空态「该账户暂无投资目标」
//   - Right(goals) → 概览头 + goal 卡片列表
// 关联 holding 选择仍走 HoldingBloc(ListHoldings 已加载,渲染同账户 holdings)。
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';

/// 投资目标关联页(holding-D)。对齐 A-od goal-link-*.html。
///
/// 接收 [holding](从 holding 详情进入,供 accountId + 贡献占比)与 [goalRepo]
/// (HoldingRepository,调 listInvestmentGoals)。goal 区走 FutureBuilder;
/// 关联 holding 选择走 context.read<HoldingBloc>()(ListHoldings)。
class GoalLinkPage extends StatefulWidget {
  const GoalLinkPage({
    super.key,
    required this.holding,
    required this.goalRepo,
  });

  /// 进入本页的 holding(提供 accountId 过滤 + marketValueCents 贡献占比)。
  final Holding holding;

  /// HoldingRepository(调 listInvestmentGoals,跨模块 goal gRPC 透传)。
  final HoldingRepository goalRepo;

  @override
  State<GoalLinkPage> createState() => _GoalLinkPageState();
}

class _GoalLinkPageState extends State<GoalLinkPage> {
  late Future<Either<Failure, List<GoalView>>> _goalsFuture;

  @override
  void initState() {
    super.initState();
    // goal 区数据源:listInvestmentGoals(客户端 filter linked_account)。
    _goalsFuture = widget.goalRepo.listInvestmentGoals();
    // 拉取持仓供关联选择(同账户 holdings 列表)。
    context.read<HoldingBloc>().add(const LoadHoldingsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        title: const Text('投资目标'),
      ),
      body: BlocBuilder<HoldingBloc, HoldingState>(
        builder: (context, state) {
          final loaded = _loadedOf(state);
          // holdings loading 且无背景 → 圆圈加载。
          if (state is HoldingLoading && loaded == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HoldingError) {
            // ⏳ 端点 fail(holdings 接口降级)→ holding 选择区降级为空。
            if (state.isPendingBackend) {
              return _goalsRegion(const <Holding>[]);
            }
            if (loaded == null) return _errorState(state.message);
          }
          final holdings = loaded?.holdings ?? const <Holding>[];
          return _goalsRegion(holdings);
        },
      ),
    );
  }

  /// 从任意 state 取出 HoldingLoaded(从 HoldingError.last / HoldingSubmitting.last
  /// 恢复背景,对齐 holdings_page _loadedOf 模式)。
  HoldingLoaded? _loadedOf(HoldingState state) {
    if (state is HoldingLoaded) return state;
    HoldingState? probe = state;
    while (true) {
      if (probe is HoldingLoaded) return probe;
      if (probe is HoldingError) {
        probe = probe.last;
      } else if (probe is HoldingSubmitting) {
        probe = probe.last;
      } else {
        return null;
      }
      if (probe == null) return null;
    }
  }

  // ───────────────────────── 主内容 ─────────────────────────

  Widget _goalsRegion(List<Holding> holdings) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _header(),
        const SizedBox(height: 14),
        // ① + ② goal 区(FutureBuilder 接真)。
        _goalsFutureRegion(),
        const SizedBox(height: 12),
        // ③ 关联 holding 选择(同账户 holdings 渲染)。
        _holdingPickerRegion(holdings),
        const SizedBox(height: 14),
        // ④ 实现说明(account 级 goal + 贡献口径)。
        _implNote(),
      ],
    );
  }

  /// 页面顶部说明(对齐 A-od topbar sub:持仓市值 vs 目标额)。
  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(LucideIcons.target, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '持仓市值 vs 目标额 · ${widget.holding.securitySymbol}',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── ① + ② goal 区(FutureBuilder) ─────────────────────────

  Widget _goalsFutureRegion() {
    return FutureBuilder<Either<Failure, List<GoalView>>>(
      future: _goalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _GoalLoading();
        }
        if (snapshot.hasError) {
          return _goalError('加载失败：${snapshot.error}');
        }
        return snapshot.data!.fold(
          (f) => _goalError(f.displayMessage),
          (allInvestmentGoals) {
            // 客户端 filter linked_account == holding.accountId。
            final goals = allInvestmentGoals
                .where((g) => g.linkedAccountId == widget.holding.accountId)
                .toList();
            if (goals.isEmpty) {
              return _goalEmptyCard();
            }
            return _goalsCard(goals);
          },
        );
      },
    );
  }

  /// goal 区 loading(对齐 A-od trades-loading,圆圈 + 文案)。
  Widget _goalError(String message) {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _goalCardTitle(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
              border:
                  Border.fromBorderSide(BorderSide(color: AppColors.border)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.alertCircle,
                      key: ValueKey('goalErrorIcon'),
                      size: 26,
                      color: AppColors.negative),
                  const SizedBox(height: 8),
                  const Text('加载失败',
                      key: ValueKey('goalErrorTitle'),
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(message,
                      key: const ValueKey('goalErrorMessage'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// goal 列表空态(该账户暂无投资目标)。
  Widget _goalEmptyCard() {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _goalCardTitle(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
              border:
                  Border.fromBorderSide(BorderSide(color: AppColors.border)),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.inbox,
                      key: ValueKey('goalEmptyIcon'),
                      size: 28,
                      color: AppColors.muted),
                  SizedBox(height: 8),
                  Text('该账户暂无投资目标',
                      key: ValueKey('goalEmptyTitle'),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.fg)),
                  SizedBox(height: 4),
                  Text(
                    '在目标页新建目标并关联本投资账户',
                    key: ValueKey('goalEmptyHint'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// goal 卡片容器:概览头(①) + goal 卡片列表(②)。
  Widget _goalsCard(List<GoalView> goals) {
    final over = goals.where((g) => g.progressPct >= 100).length;
    final onTrack = goals
        .where((g) => g.progressPct >= 80 && g.progressPct < 100)
        .length;
    final behind = goals.where((g) => g.progressPct < 80).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ① 概览头(总数 / 超前(≥100%) / 持平(80-100%) / 落后(<80%))。
        _overviewCard(
          total: goals.length,
          over: over,
          onTrack: onTrack,
          behind: behind,
        ),
        const SizedBox(height: 12),
        // ② goal 卡片列表。
        DataCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _goalCardTitle(),
              const SizedBox(height: 14),
              for (var i = 0; i < goals.length; i++) ...[
                _goalRow(goals[i]),
                if (i < goals.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _goalCardTitle() {
    return Row(
      children: [
        const Icon(LucideIcons.gem, size: 14, color: AppColors.accent),
        const SizedBox(width: 6),
        const Text('投资目标',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.positive.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: const Text('account 级',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.positive)),
        ),
      ],
    );
  }

  // ───────────────────────── ① 概览头 ─────────────────────────

  /// 概览统计卡(对齐 A-od m-goal-overview 3 列)。
  /// 总数 / 超前(≥100%) / 持平(80-100%) / 落后(<80%)。
  Widget _overviewCard({
    required int total,
    required int over,
    required int onTrack,
    required int behind,
  }) {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: _overviewCell(
            label: '总数',
            value: '$total',
            sub: 'holding-backed',
            key: const ValueKey('goalOverviewTotal'),
          )),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(
              child: _overviewCell(
            label: '超前',
            value: '$over',
            sub: '≥100%',
            key: const ValueKey('goalOverviewOver'),
            valueColor: AppColors.positive,
          )),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(
              child: _overviewCell(
            label: '持平',
            value: '$onTrack',
            sub: '80-100%',
            key: const ValueKey('goalOverviewOnTrack'),
            valueColor: AppColors.accent,
          )),
          Container(width: 1, height: 36, color: AppColors.border),
          Expanded(
              child: _overviewCell(
            label: '落后',
            value: '$behind',
            sub: '<80%',
            key: const ValueKey('goalOverviewBehind'),
            valueColor: AppColors.negative,
          )),
        ],
      ),
    );
  }

  Widget _overviewCell({
    required String label,
    required String value,
    required String sub,
    Color? valueColor,
    Key? key,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: key,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.fg,
                fontFeatures: AppTypography.tabularFigures)),
        const SizedBox(height: 2),
        Text(sub,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
      ],
    );
  }

  // ───────────────────────── ② goal 卡片 ─────────────────────────

  /// 单个 goal 卡片(对齐 A-od goalCards row):
  /// 名 / 进度% / current / target(元)/ 该 holding 贡献占比 / 进度条。
  Widget _goalRow(GoalView g) {
    final pct = g.progressPct.clamp(0, 999).toDouble();
    final pctLabel = pct >= 100
        ? '${pct.toStringAsFixed(0)}%'
        : '${pct.toStringAsFixed(1)}%';
    final code = widget.holding.currency ?? 'CNY';
    // 该 holding 对本 goal 的贡献占比 = holding.marketValueCents / goal.targetCents。
    // (account 级:goal.current 已含 Σ 账户 holdings mv;此处拆出该 holding 的份额。)
    final contributionPct = g.targetCents > 0
        ? (widget.holding.marketValueCents / g.targetCents * 100)
            .clamp(0, 999)
            .toStringAsFixed(1)
        : '0.0';
    final isOver = g.progressPct >= 100;
    final isBehind = g.progressPct < 80;

    return Container(
      key: ValueKey('goalRow-${g.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名 + 进度% 大数。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    key: ValueKey('goalRowName-${g.id}'),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(pctLabel,
                  key: ValueKey('goalRowPct-${g.id}'),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isOver
                          ? AppColors.positive
                          : (isBehind ? AppColors.negative : AppColors.accent),
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
          const SizedBox(height: 8),
          // current / target(元)。
          Row(
            children: [
              const Text('当前 ',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
              Text(_fmtRaw(g.currentCents, code),
                  key: ValueKey('goalRowCurrent-${g.id}'),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures)),
              const SizedBox(width: 10),
              const Text('目标 ',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
              Text(_fmtRaw(g.targetCents, code),
                  key: ValueKey('goalRowTarget-${g.id}'),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条。
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              key: ValueKey('goalRowBar-${g.id}'),
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOver
                    ? AppColors.positive
                    : (isBehind ? AppColors.negative : AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 该 holding 贡献占比。
          Row(
            children: [
              const Icon(LucideIcons.pieChart, size: 11, color: AppColors.muted),
              const SizedBox(width: 4),
              Text('${widget.holding.securitySymbol} 贡献 ',
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.muted)),
              Text('$contributionPct%',
                  key: ValueKey('goalRowContribution-${g.id}'),
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent)),
              const SizedBox(width: 6),
              if (g.isCompleted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.positive.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('已完成',
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.positive)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ③ 关联 holding 选择 ─────────────────────────

  /// 关联 holding 选择区(对齐 A-od gd-holding-picker):同账户 holdings 渲染,
  /// 供用户参考本账户下其他持仓(本 holding 已选中)。纯展示(无 goal 关联动作,
  /// account 级 goal 按 linked_account 自动归属)。
  Widget _holdingPickerRegion(List<Holding> holdings) {
    final sameAccount = holdings
        .where((h) => h.accountId == widget.holding.accountId)
        .toList();
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.link, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text('同账户持仓',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.positive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text('✅ holdings',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.positive)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '账户 ${widget.holding.accountId} 下的持仓(account 级 goal 自动归属)',
            key: const ValueKey('pickerHint'),
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          if (sameAccount.isEmpty)
            _pickerEmpty()
          else
            _holdingList(sameAccount),
        ],
      ),
    );
  }

  Widget _pickerEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.briefcase,
                key: ValueKey('pickerEmptyIcon'),
                size: 22,
                color: AppColors.muted),
            SizedBox(height: 6),
            Text('该账户暂无持仓',
                key: ValueKey('pickerEmptyTitle'),
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  /// holding 列表(对齐 A-od gd-hp-row:symbol/name + 市值 + 当前 holding 标记)。
  Widget _holdingList(List<Holding> holdings) {
    final sorted = [...holdings]
      ..sort((a, b) => b.marketValueCents.compareTo(a.marketValueCents));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _holdingRow(sorted[i]),
          if (i < sorted.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _holdingRow(Holding h) {
    final code = h.currency ?? 'CNY';
    final typeColor = h.securityType != null
        ? (kHoldingTypeColors[h.securityType!] ?? AppColors.accent)
        : AppColors.accent;
    final typeLabel = h.securityType != null
        ? (kHoldingTypeLabels[h.securityType!] ?? '')
        : '';
    final isCurrent = h.id == widget.holding.id;
    return Container(
      key: ValueKey('holdingRow-${h.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(
            color: isCurrent ? AppColors.accent : AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: typeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(h.securitySymbol,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTypography.tabularFigures)),
                    if (typeLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(typeLabel,
                          style:
                              TextStyle(fontSize: 10.5, color: typeColor)),
                    ],
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('当前',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentHover)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(h.securityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtRaw(h.marketValueCents, code),
                  key: ValueKey('holdingRowMv-${h.id}'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures)),
              Text(code,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ④ 实现说明 ─────────────────────────

  /// 实现说明(对齐 A-od api-note,改 account 级口径)。
  Widget _implNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        key: const ValueKey('apiNote'),
        children: [
          const Icon(LucideIcons.info, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('account 级',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'goal.linked_account_id 关联投资账户,progress 由 server 按 Σ 该账户 holdings mv 计算;贡献占比 = holding.mv / goal.target。',
              style: TextStyle(fontSize: 11.5, color: AppColors.fg),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 错误空态 ─────────────────────────

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertCircle,
                size: 40, color: AppColors.negative),
            const SizedBox(height: 12),
            const Text('加载失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── helpers ─────────────────────────

  /// 金额 cents 格式化(千分位 + 2 位小数 + 货币符号)。
  String _fmtRaw(int cents, String currencyCode) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign${currencySymbol(currencyCode)}$buf.$fen';
  }
}

/// goal 区 loading 占位(对齐 A-od trades-loading)。
class _GoalLoading extends StatelessWidget {
  const _GoalLoading();

  @override
  Widget build(BuildContext context) {
    return const DataCard(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                key: ValueKey('goalLoading'), strokeWidth: 2.5),
            SizedBox(height: 10),
            Text('加载投资目标…',
                key: ValueKey('goalLoadingText'),
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
