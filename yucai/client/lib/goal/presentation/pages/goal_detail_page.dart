// 目标详情页(Task 14)。消费 Task 11 GoalBloc(LoadDetailRequested by id →
// GoalDetailLoaded(goal))/ Task 10 GoalView。
//
// 设计源(OD 原型):design-output/goal/goal-detail-desktop.html
//  + styles.css + mock-data.js。对齐御财设计语言 + 照搬 budget BudgetDetailPage /
//  holding_detail_page / debt_detail_page 范式(StatefulWidget(id) + initState dispatch
//  LoadDetail + BlocBuilder 三态:loading/error/loaded):
//   ① 头部 hero 卡:大进度环(UsagePct clamp[0,1])+ Name + 类型徽章 + 状态 pill +
//      current/target + 还差 + deadline 倒计时。
//   ② 关联实体卡:linkedAccountIds / linkedDebtIds 列表(account/debt name lookup
//      defer,显占位「账户 #id」/「债务 #id」;空则显「暂无关联」)。
//   ③ 手动记贡献卡:入口按钮 → dialog 输金额 → RecordContributionRequested(id, amount)。
//      (Savings/DebtPayoff 兜底,即使有自动贡献也允许手动记一笔。)
//   ④ 趋势曲线占位卡:Text「趋势曲线 Phase 2」(本 task 不画曲线,Phase 2 接 snapshot
//      + fl_chart,对齐 OD 原型 trendCard 占位)。
//   ⑤ AppBar actions:完成(CompleteGoalRequested)+ 删除(确认 dialog →
//      DeleteGoalRequested → pop 回列表)+ 复制(CloneGoalRequested)+ 编辑
//      (push '/goals/:id/edit')。
//
// 账户/债务 name lookup 简化(brief:account name lookup defer):显 id 占位,真名
// lookup 后续接入。
//
// 路由:本页由路由层注入 BlocProvider<GoalBloc>;此处
// context.read<GoalBloc>().add(LoadDetailRequested(id))。
//
// 无 i18n(中文硬编码,御财惯例;与 budget/holding 列表页一致)。
import 'package:dartz/dartz.dart' as dartz;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/conic_progress_ring.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_state.dart';

/// 目标详情页。对齐 budget BudgetDetailPage / holding_detail_page 范式。
class GoalDetailPage extends StatefulWidget {
  const GoalDetailPage({super.key, required this.id});

  final String id;

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  /// account/debt id→name 映射(Phase 1.5:真名 lookup 替 #id 占位)。
  /// FutureBuilder 包关联卡 region;best-effort(lookup fail/未命中 → #id 回退)。
  /// 在 initState 启动,与 GoalBloc 并行(不阻塞 goal 渲染)。
  late final Future<_NameMaps> _nameMapsFuture = _lookupNames();

  /// 目标进度历史(近 30 天,server scheduler 每日 actuals 快照)。
  /// FutureBuilder 包趋势卡 region;best-effort(失败/空 → 空态),不阻塞 goal 渲染。
  late final Future<dartz.Either<Failure, List<GoalProgressPoint>>> _historyFuture =
      GetIt.instance<GoalRepository>().getProgressHistory(
    goalId: widget.id,
    from: DateTime.now().subtract(const Duration(days: 30)),
    to: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    context.read<GoalBloc>().add(LoadDetailRequested(widget.id));
  }

  /// 并行 fetch account + debt list → 返 (accountMap, debtMap)。
  /// 任一失败 → 对应 map 为空(关联卡回退 #id)。永不 throw。
  Future<_NameMaps> _lookupNames() async {
    Map<String, String> accountMap = const {};
    Map<String, String> debtMap = const {};
    try {
      final results = await Future.wait([
        GetIt.instance<AccountRepository>().list(),
        GetIt.instance<DebtRepository>().list(),
      ]);
      final accountResult =
          results[0] as dartz.Either<Failure, List<Account>>;
      final debtResult = results[1] as dartz.Either<Failure, List<Debt>>;
      accountMap = accountResult.fold(
        (_) => const <String, String>{},
        (accounts) => {
          for (final a in accounts) a.id: a.name,
        },
      );
      debtMap = debtResult.fold(
        (_) => const <String, String>{},
        (debts) => {
          for (final d in debts) d.id: d.counterparty,
        },
      );
    } catch (_) {
      // best-effort:保持空 map,关联卡回退 #id。
    }
    return _NameMaps(accountMap: accountMap, debtMap: debtMap);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('目标详情'),
        actions: [
          // 编辑(lucide pencil)→ push '/goals/:id/edit'。
          IconButton(
            key: const ValueKey('goalEditAction'),
            tooltip: '编辑',
            icon: const Icon(LucideIcons.pencil, size: 18),
            onPressed: () => context.push('/goals/${widget.id}/edit'),
          ),
          // 复制(lucide copy)→ CloneGoalRequested。
          IconButton(
            key: const ValueKey('goalCloneAction'),
            tooltip: '复制目标',
            icon: const Icon(LucideIcons.copy, size: 18),
            onPressed: _onClone,
          ),
          // 删除(lucide trash2)→ confirm dialog → dispatch + pop。
          IconButton(
            key: const ValueKey('goalDeleteAction'),
            tooltip: '删除',
            icon: const Icon(LucideIcons.trash2, size: 18),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: BlocBuilder<GoalBloc, GoalState>(
        builder: (context, state) {
          if (state is GoalLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GoalDetailLoaded) {
            return _body(state.goal);
          }
          if (state is GoalError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted)),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      // 底部操作栏(对齐 OD 原型 actionRow):完成 + 手动记贡献。
      // 完成按钮仅在未完成时显示;完成后禁用。
      bottomNavigationBar: BlocBuilder<GoalBloc, GoalState>(
        builder: (context, state) {
          if (state is! GoalDetailLoaded) return const SizedBox.shrink();
          final g = state.goal;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('goalContributeBtn'),
                      onPressed: _openContributionDialog,
                      icon: const Icon(LucideIcons.coins, size: 16),
                      label: const Text('记一笔贡献'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!g.isCompleted)
                    FilledButton.icon(
                      key: const ValueKey('goalCompleteBtn'),
                      onPressed: _onComplete,
                      icon: const Icon(LucideIcons.checkCircle2, size: 16),
                      label: const Text('标记完成'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.positive,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: null,
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: const Text('已完成'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── body(① 头部 + ② 关联 + ④ 趋势占位) ─────────────────────────

  Widget _body(GoalView g) {
    final isMobile = MediaQuery.of(context).size.width <= 720;
    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 32)
          : const EdgeInsets.fromLTRB(36, 24, 36, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _headerCard(g),
                const SizedBox(height: AppSpacing.sm),
                _linkedCard(g),
                const SizedBox(height: AppSpacing.sm),
                _trendCard(g),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── ① 头部 hero 卡 ─────────────────────────

  /// Name + 类型徽章 + 状态 pill + 大 ConicProgressRing + current/target + 还差 +
  /// deadline 倒计时。对齐 OD 原型 .detail-hero:大进度环(lg)+ 左 status 色条。
  Widget _headerCard(GoalView g) {
    final meta = _typeMeta(g.type);
    final pct = g.progressPct;
    final ringValue = (pct / 100).clamp(0.0, 1.0);
    final pctLabel = '${pct.toStringAsFixed(1)}%';
    final currency = g.currencyCode;

    final daysLeft = _daysLeft(g.deadline);
    final isUrgent = !g.isCompleted &&
        daysLeft != null &&
        daysLeft <= 90 &&
        ringValue < 0.7;
    final ringColor = g.isCompleted
        ? AppColors.positive
        : (isUrgent ? AppColors.negative : meta.color);
    final accentColor = g.isCompleted
        ? AppColors.positive
        : (isUrgent ? AppColors.negative : AppColors.accent);

    final remaining = g.remainingCents > 0 ? g.remainingCents : 0;

    return DataCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧 status 色条(对齐原型 .detail-hero border-left 4px)。
            Container(
              width: 4,
              margin: const EdgeInsets.only(right: AppSpacing.md),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部:Name + 类型徽章 + 状态 pill。
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(g.name,
                          key: const ValueKey('goalDetailName'),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTypography.displayFamily,
                              fontFamilyFallback: AppTypography.displayFallback)),
                      _TypeChip(meta: meta),
                      _StatusPill(
                          isCompleted: g.isCompleted, isUrgent: isUrgent),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 中部:大 ConicProgressRing(左)+ current/target + 还差(右)。
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConicProgressRing(
                        key: const ValueKey('goalDetailRing'),
                        progress: ringValue,
                        color: ringColor,
                        pctLabel: pctLabel,
                        subLabel: g.isCompleted ? '已达成' : null,
                        size: ConicRingSize.lg,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MetaKV(
                              k: '当前 / 目标',
                              v:
                                  '${_fmtSymbol(g.currentAmountCents, currency)} / ${_fmtSymbol(g.targetAmountCents, currency)}',
                            ),
                            const SizedBox(height: 8),
                            _MetaKV(
                              k: g.isCompleted ? '已达成' : '还差',
                              v: g.isCompleted
                                  ? _fmtSymbol(g.targetAmountCents, currency)
                                  : _fmtSymbol(remaining, currency),
                              vColor: g.isCompleted
                                  ? AppColors.positive
                                  : AppColors.fg,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 底部:deadline 倒计时。
                  Row(
                    children: [
                      const Icon(LucideIcons.calendar,
                          size: 13, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        _deadlineText(g, daysLeft),
                        key: const ValueKey('goalDetailDeadline'),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                isUrgent ? AppColors.negative : AppColors.muted,
                            fontWeight: isUrgent
                                ? FontWeight.w600
                                : FontWeight.w400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── ② 关联实体卡 ─────────────────────────

  /// 关联账户/债务列表(Phase 1.5:FutureBuilder 查 account/debt name → 真名;
  /// best-effort(lookup fail/未命中 → `账户 #id`/`债务 #id` 回退,不崩);
  /// 空显「暂无关联」)。lookup 与 GoalBloc 并行,不阻塞 goal 渲染。
  Widget _linkedCard(GoalView g) {
    final accounts = g.linkedAccountIds;
    final debts = g.linkedDebtIds;
    final empty = accounts.isEmpty && debts.isEmpty;
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('关联实体',
              key: ValueKey('goalDetailLinkedTitle'),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback)),
          const SizedBox(height: AppSpacing.xs),
          if (empty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('暂无关联',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              ),
            )
          else
            FutureBuilder<_NameMaps>(
              future: _nameMapsFuture,
              builder: (context, snapshot) {
                final maps = snapshot.data;
                final accountMap = maps?.accountMap ?? const <String, String>{};
                final debtMap = maps?.debtMap ?? const <String, String>{};
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final id in accounts)
                      _LinkedRow(
                        key: ValueKey('goalDetailLinkedAccount_$id'),
                        icon: LucideIcons.wallet,
                        label: '关联账户',
                        name: accountMap[id] ?? '账户 #$id',
                        iconColor: AppColors.accent,
                      ),
                    for (final id in debts)
                      _LinkedRow(
                        key: ValueKey('goalDetailLinkedDebt_$id'),
                        icon: LucideIcons.creditCard,
                        label: '关联债务',
                        name: debtMap[id] ?? '债务 #$id',
                        iconColor: AppColors.negative,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // ───────────────────────── ④ 趋势曲线卡(fl_chart LineChart) ─────────────────────────

  /// 目标进度趋势卡(替 Phase 1 占位):FutureBuilder 包 getProgressHistory(近
  /// 30 天)→ fl_chart LineChart(御财金 current_amount_cents 曲线 + target 虚线
  /// 基线)。loading/error/empty 三态,不阻塞 goal 主体渲染。
  Widget _trendCard(GoalView g) {
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.trendingUp, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              const Text('目标进度趋势',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text('近 30 天',
                    key: ValueKey('goalDetailTrendBadge'),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FutureBuilder<dartz.Either<Failure, List<GoalProgressPoint>>>(
            future: _historyFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const _TrendLoading();
              }
              // 加载失败 → 空态(空态文案区分「错误」/「无数据」,统一空态 UI)。
              final result = snap.data;
              final points = result?.fold(
                    (_) => const <GoalProgressPoint>[],
                    (pts) => pts,
              ) ??
                  const <GoalProgressPoint>[];
              if (points.isEmpty) {
                return const _TrendEmpty(
                    key: ValueKey('goalDetailTrendEmpty'));
              }
              return _TrendChart(
                key: const ValueKey('goalDetailTrendChart'),
                points: points,
                targetCents: g.targetAmountCents,
              );
            },
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ③ 手动记贡献 dialog ─────────────────────────

  /// 手动记贡献 dialog:输入金额(元)→ RecordContributionRequested(id, amountCents)。
  /// Savings/DebtPayoff 兜底(即使有自动贡献也允许手动记一笔)。
  void _openContributionDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('记一笔贡献'),
        content: TextField(
          key: const ValueKey('goalContributionInput'),
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: false),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '金额(元)',
            prefixText: '¥',
            hintText: '2000',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: const Text('取消')),
          TextButton(
            key: const ValueKey('goalContributionSubmit'),
            onPressed: () {
              final yuan = double.tryParse(ctrl.text.trim());
              if (yuan == null || yuan <= 0) return;
              final cents = (yuan * 100).round();
              Navigator.pop(dctx);
              context
                  .read<GoalBloc>()
                  .add(RecordContributionRequested(id: widget.id, amount: cents));
            },
            child: const Text('记一笔'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── actions:完成 / 删 / 复制 ─────────────────────────

  void _onComplete() {
    context.read<GoalBloc>().add(CompleteGoalRequested(widget.id));
  }

  void _onClone() {
    context.read<GoalBloc>().add(CloneGoalRequested(sourceId: widget.id));
  }

  /// 删除确认 dialog(对齐 budget detail _confirmDelete):showDialog<bool> →
  /// 确认 → dispatch DeleteGoalRequested + pop 回列表。
  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除目标'),
        content: const Text('确定删除此目标？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              key: const ValueKey('goalDeleteConfirm'),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('删除')),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        context.read<GoalBloc>().add(DeleteGoalRequested(widget.id));
        context.pop();
      }
    });
  }
}

// ───────────────────────── 私有 widgets ─────────────────────────

/// 目标进度趋势曲线(fl_chart 1.x LineChart,照 holding perf_curve_chart API)。
///
/// 横轴 = points 索引(0..n-1,按 date 升序),纵轴 = current_amount_cents(分,
/// 映射到 chart Y)。御财金主曲线 + 半透明面积填充;target 虚线基线(若提供且 > 0)。
///
/// fl_chart 1.x API(非 0.69):公开 `LineChart` 类、`LineChartBarData(color:` 单数、
/// `.withValues(alpha:)`、`LineChartData(extraLinesData:)`。
class _TrendChart extends StatelessWidget {
  const _TrendChart({
    super.key,
    required this.points,
    this.targetCents,
  });

  /// 已按 date 升序的进度点(调用方保证 length >= 1)。
  final List<GoalProgressPoint> points;

  /// 目标金额(分),>0 时画虚线基线。null/0 不画。
  final int? targetCents;

  @override
  Widget build(BuildContext context) {
    // 仅 1 点:画不出曲线 → 退化为空态(对齐 brief「snapshot 数据稀疏」)。
    if (points.length < 2) {
      return const SizedBox(
        height: 168,
        child: _TrendEmpty(key: ValueKey('goalDetailTrendEmpty')),
      );
    }
    return SizedBox(
      height: 168,
      child: LineChart(
        LineChartData(
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          clipData: const FlClipData.all(),
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: _minY(),
          maxY: _maxY(),
          extraLinesData: _targetLine(),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(),
                      points[i].currentAmountCents.toDouble()),
              ],
              isCurved: true,
              color: AppColors.accent, // 御财金
              barWidth: 1.8,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.accent.withValues(alpha: 0.16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Y 轴下界:取 points 最小值(留少量 padding),与 0 取小,避免负值溢出。
  double _minY() {
    final minVal = points
        .map((p) => p.currentAmountCents.toDouble())
        .reduce((a, b) => a < b ? a : b);
    final padded = minVal - (minVal.abs() * 0.04 + 1);
    return padded < 0 ? 0 : padded;
  }

  /// Y 轴上界:取 points 最大值与 target 的较大值,留 8% padding 顶端呼吸。
  double _maxY() {
    final maxVal = points
        .map((p) => p.currentAmountCents.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final top = (targetCents != null && targetCents! > maxVal)
        ? targetCents!.toDouble()
        : maxVal;
    return top + (top.abs() * 0.08 + 1);
  }

  /// target 虚线基线(对齐 OD 原型 .target-line dashed)。
  /// 仅 targetCents > 0 时绘制,横跨 [0, maxX]。
  ExtraLinesData? _targetLine() {
    if (targetCents == null || targetCents! <= 0) return null;
    return ExtraLinesData(
      extraLinesOnTop: true,
      horizontalLines: [
        HorizontalLine(
          y: targetCents!.toDouble(),
          color: AppColors.muted.withValues(alpha: 0.6),
          strokeWidth: 1,
          dashArray: [5, 4],
        ),
      ],
    );
  }
}

/// 趋势空态:「暂无趋势数据(scheduler 每日记录)」。加载失败 + 无数据共用。
class _TrendEmpty extends StatelessWidget {
  const _TrendEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border:
            Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.trendingUp, size: 22, color: AppColors.muted),
            SizedBox(height: 6),
            Text('暂无趋势数据',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            SizedBox(height: 2),
            Text('(scheduler 每日记录)',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// 趋势 loading 占位(固定高度 SizedBox,保持卡尺寸不抖动)。
class _TrendLoading extends StatelessWidget {
  const _TrendLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 168,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// 关联实体 name lookup 结果(Phase 1.5):id→name 映射。
/// accountMap:accountId → Account.name;debtMap:debtId → Debt.counterparty。
/// lookup 失败/未命中时 map 为空,关联卡回退 `账户 #id`/`债务 #id`。
class _NameMaps {
  const _NameMaps({required this.accountMap, required this.debtMap});
  final Map<String, String> accountMap;
  final Map<String, String> debtMap;
}

/// 「key value」一行 meta 文字(vColor 非空时高亮加粗)。
class _MetaKV extends StatelessWidget {
  const _MetaKV({required this.k, required this.v, this.vColor});
  final String k;
  final String v;
  final Color? vColor;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        children: [
          TextSpan(text: '$k '),
          TextSpan(
            text: v,
            style: TextStyle(
                color: vColor ?? AppColors.fg,
                fontWeight: vColor != null ? FontWeight.w600 : FontWeight.w400,
                fontFeatures: AppTypography.tabularFigures),
          ),
        ],
      ),
    );
  }
}

/// 类型徽章。对齐 goal_list_page _TypeChip 样式。
class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.meta});
  final _TypeMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 12, color: meta.color),
          const SizedBox(width: 4),
          Text(meta.label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: meta.color)),
        ],
      ),
    );
  }
}

/// 状态 pill(已完成 / 进行中 / 落后紧急)。
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isCompleted, required this.isUrgent});
  final bool isCompleted;
  final bool isUrgent;

  @override
  Widget build(BuildContext context) {
    final color =
        isCompleted ? AppColors.positive : (isUrgent ? AppColors.negative : AppColors.accent);
    final icon =
        isCompleted ? LucideIcons.checkCircle2 : (isUrgent ? LucideIcons.alertTriangle : LucideIcons.trendingUp);
    final label = isCompleted ? '已完成' : (isUrgent ? '落后' : '进行中');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// 关联实体行(icon + label + name)。
class _LinkedRow extends StatelessWidget {
  const _LinkedRow({
    super.key,
    required this.icon,
    required this.label,
    required this.name,
    required this.iconColor,
  });
  final IconData icon;
  final String label;
  final String name;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted)),
                Text(name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 类型元数据 ─────────────────────────

class _TypeMeta {
  const _TypeMeta({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;
}

/// 类型 → 徽章元数据。对齐 goal_list_page _typeMeta:
/// savings(金 piggyBank)/ debtPayoff(红 creditCard)/ investment(绿 trendingUp)。
_TypeMeta _typeMeta(GoalType type) {
  switch (type) {
    case GoalType.savings:
      return const _TypeMeta(
          label: '储蓄目标', icon: LucideIcons.piggyBank, color: AppColors.accent);
    case GoalType.debtPayoff:
      return const _TypeMeta(
          label: '债务清偿', icon: LucideIcons.creditCard, color: AppColors.negative);
    case GoalType.investment:
      return const _TypeMeta(
          label: '投资目标', icon: LucideIcons.trendingUp, color: AppColors.positive);
  }
}

// ───────────────────────── deadline 倒计时 helpers ─────────────────────────

/// deadline 距今天数(截至当日 0 点;null = 无 deadline)。与 goal_list_page 同形。
int? _daysLeft(DateTime? deadline) {
  if (deadline == null) return null;
  final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final d = DateTime(deadline.year, deadline.month, deadline.day);
  return d.difference(now).inDays;
}

/// 倒计时文案(对齐 goal_list_page _deadlineText)。
String _deadlineText(GoalView goal, int? daysLeft) {
  if (goal.isCompleted) return '已达成';
  if (daysLeft == null) return '无截止日期';
  if (daysLeft < 0) return '已逾期 ${-daysLeft} 天';
  if (daysLeft > 365) return '剩 ${(daysLeft / 30).round()} 个月';
  return '剩 $daysLeft 天';
}

// ───────────────────────── 货币格式 helper ─────────────────────────

/// 千分位 + 两位小数 + 货币符号前缀(对齐 budget/holding 页 _fmtSymbol,
/// 复用 currency_convert.dart 的 currencySymbol)。
String _fmtSymbol(int cents, String currencyCode) {
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
