// 目标列表页(goal 模块入口)。消费 Task 11 GoalBloc + Task 10 GoalView。
//
// 设计源(OD 原型):design-output/goal/goal-list-{desktop,tablet,mobile}.html
//  + styles.css + mock-data.js。**大 UI 对齐原型**(2026-07):
//   - topbar:title + sub(共 N 个)+ 刷新 icon-btn + btn-gold「新建目标」。
//   - 类型筛选 chips:全部 / 储蓄 / 债务清偿 / 投资(原型 nav-sec 类型筛选)。
//   - 完成/进行中 分组(原型 section-group)+ 计数 badge。
//   - ConicProgressRing 卡片(原型 progress-ring conic-gradient)+ 类型徽章 +
//     current/target + deadline 倒计时 + 左侧 status 色条(原型 goal-card 左 border)。
//
// 御财设计语言(复用 AppColors/AppTypography/lucide):
//  - 御财金 #b08d57(savings + btn-gold)/ 盈绿 #2d8a6e(investment + completed)/
//    亏红 #c4544d(debtPayoff + 落后/紧急)。
//  - 类型徽章(GOAL_TYPES 对齐 mock-data.js):
//      savings    → 储蓄目标 / piggyBank  / accent(金)
//      debtPayoff → 债务清偿 / creditCard / negative(红)
//      investment → 投资目标 / trendingUp / positive(绿)
//  - 进度环:ConicProgressRing(progress=clamp[0,1]);完成色 positive、进行中按
//    type 色、落后(daysLeft≤90 且 pct<70%)色 negative。
//  - 倒计时:deadline - now 天数;>365 显「X 个月」;完成显「已达成」。
//
// 路由:本页由路由层注入 BlocProvider<GoalBloc>;卡片 tap →
//  context.push('/goals/:id');新建 → push '/goals/new'。
//
// 无 i18n(中文硬编码,御财惯例;与 budget/holding 列表页一致)。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/conic_progress_ring.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_state.dart';

/// 目标列表页。对齐 OD 原型:topbar + 类型筛选 chips + 分组卡片 + btn-gold 新建。
class GoalListPage extends StatefulWidget {
  const GoalListPage({super.key});

  @override
  State<GoalListPage> createState() => _GoalListPageState();
}

/// 类型筛选枚举(对齐原型 nav-sec 类型筛选 + 全部)。
enum _TypeFilter { all, savings, debtPayoff, investment }

class _GoalListPageState extends State<GoalListPage> {
  _TypeFilter _typeFilter = _TypeFilter.all;

  @override
  void initState() {
    super.initState();
    context.read<GoalBloc>().add(const LoadListRequested());
  }

  /// 按 `_typeFilter` 过滤 goals(all = 不过滤)。
  List<GoalView> _applyTypeFilter(List<GoalView> goals) {
    switch (_typeFilter) {
      case _TypeFilter.all:
        return goals;
      case _TypeFilter.savings:
        return goals.where((g) => g.type == GoalType.savings).toList();
      case _TypeFilter.debtPayoff:
        return goals.where((g) => g.type == GoalType.debtPayoff).toList();
      case _TypeFilter.investment:
        return goals.where((g) => g.type == GoalType.investment).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: BlocBuilder<GoalBloc, GoalState>(
        builder: (context, state) {
          // topbar 永远显示(标题 + sub + 刷新 + 新建),body 三态切换。
          return Column(
            children: [
              _topbar(state),
              Expanded(child: _body(state)),
            ],
          );
        },
      ),
    );
  }

  // ───────────────────────── topbar(对齐原型 topbar-d) ─────────────────────────

  Widget _topbar(GoalState state) {
    final count = state is GoalListLoaded ? state.goals.length : 0;
    return Material(
      color: context.yucai.bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // left:title + sub。
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('目标',
                          key: ValueKey('goalListTitle'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTypography.displayFamily,
                              fontFamilyFallback:
                                  AppTypography.displayFallback)),
                      const SizedBox(height: 4),
                      Text(
                        '储蓄 / 债务清偿 / 投资 · 共 $count 个目标',
                        key: const ValueKey('goalListSub'),
                        style: TextStyle(
                            fontSize: 12.5, color: context.yucai.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // actions:刷新 icon-btn + btn-gold 新建。
                IconButton(
                  key: const ValueKey('goalListRefresh'),
                  tooltip: '刷新',
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  color: context.yucai.muted,
                  onPressed: () => context
                      .read<GoalBloc>()
                      .add(const LoadListRequested()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── body(loading/error/loaded) ─────────────────────────

  Widget _body(GoalState state) {
    if (state is GoalLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is GoalError) {
      return _errorState(state.message);
    }
    if (state is GoalListLoaded) {
      final goals = state.goals;
      if (goals.isEmpty) return _emptyState();
      return _content(goals);
    }
    return const Center(child: CircularProgressIndicator());
  }

  // ───────────────────────── 主内容(类型筛选 + 分组) ─────────────────────────

  Widget _content(List<GoalView> allGoals) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _typeFilterRow(allGoals),
              const SizedBox(height: AppSpacing.sm),
              _groups(_applyTypeFilter(allGoals)),
            ],
          ),
        ),
      ),
    );
  }

  /// 类型筛选 chips(对齐原型 nav-sec 类型筛选:全部 / 储蓄 / 债务 / 投资)。
  Widget _typeFilterRow(List<GoalView> allGoals) {
    int count(GoalType t) =>
        allGoals.where((g) => g.type == t).length;
    final chips = <_FilterChipData>[
      _FilterChipData(_TypeFilter.all, '全部', allGoals.length, null),
      _FilterChipData(
          _TypeFilter.savings, '储蓄', count(GoalType.savings), GoalType.savings),
      _FilterChipData(_TypeFilter.debtPayoff, '债务清偿',
          count(GoalType.debtPayoff), GoalType.debtPayoff),
      _FilterChipData(_TypeFilter.investment, '投资',
          count(GoalType.investment), GoalType.investment),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final c in chips)
          _FilterChip(
            data: c,
            selected: _typeFilter == c.value,
            onTap: () => setState(() => _typeFilter = c.value),
          ),
      ],
    );
  }

  /// 分组(对齐原型 section-group:进行中 + 已完成)。
  Widget _groups(List<GoalView> goals) {
    final inProgress = goals.where((g) => !g.isCompleted).toList()
      ..sort(_byDeadlineAsc);
    final completed = goals.where((g) => g.isCompleted).toList();
    if (inProgress.isEmpty && completed.isEmpty) {
      // 类型筛选下无匹配。
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text('该类型下无目标',
              style: TextStyle(color: context.yucai.muted, fontSize: 13)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (inProgress.isNotEmpty) ...[
          _GroupHeader(
              title: '进行中',
              icon: LucideIcons.clock,
              count: inProgress.length),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < inProgress.length; i++) ...[
            _GoalCard(goal: inProgress[i]),
            if (i < inProgress.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
          if (completed.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        ],
        if (completed.isNotEmpty) ...[
          _GroupHeader(
              title: '已完成',
              icon: LucideIcons.checkCircle2,
              count: completed.length),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < completed.length; i++) ...[
            _GoalCard(goal: completed[i]),
            if (i < completed.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  // ───────────────────────── 分组排序 ─────────────────────────

  int _byDeadlineAsc(GoalView a, GoalView b) {
    final da = a.deadline;
    final db = b.deadline;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  }

  // ───────────────────────── 空态 / 错误态 ─────────────────────────

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
            child: Icon(LucideIcons.target, size: 30, color: context.yucai.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('还没有目标',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '点击右上「新建目标」开始攒钱 / 还债 / 投资',
            style: TextStyle(color: context.yucai.muted, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          _GoldButton(
            icon: LucideIcons.plus,
            label: '新建第一个目标',
            onPressed: () => context.push('/goals/new'),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle, size: 40, color: context.yucai.negative),
            const SizedBox(height: 12),
            const Text('加载失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.yucai.muted, fontSize: 13)),
            const SizedBox(height: AppSpacing.md),
            _GoldButton(
              icon: LucideIcons.refreshCw,
              label: '重试',
              onPressed: () =>
                  context.read<GoalBloc>().add(const LoadListRequested()),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 类型筛选 chip ─────────────────────────

class _FilterChipData {
  const _FilterChipData(this.value, this.label, this.count, this.type);
  final _TypeFilter value;
  final String label;
  final int count;
  final GoalType? type; // null = all;非空 → 用于 chip icon
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.data,
    required this.selected,
    required this.onTap,
  });
  final _FilterChipData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final typeMeta = widget.data.type != null ? _typeMeta(widget.data.type!) : null;
    final iconColor = typeMeta?.color ?? context.yucai.accent;
    final bg = selected
        ? context.yucai.accent
        : (_hover ? context.yucai.surfaceAlt : context.yucai.surface);
    final fg = selected ? Colors.white : context.yucai.muted;
    final border = selected ? context.yucai.accent : context.yucai.border;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (typeMeta != null) ...[
                Icon(typeMeta.icon,
                    size: 13, color: selected ? Colors.white : iconColor),
                const SizedBox(width: 5),
              ],
              Text(widget.data.label,
                  style: TextStyle(
                      color: fg,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 5),
              Text('${widget.data.count}',
                  style: TextStyle(
                      color: selected ? Colors.white : context.yucai.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── btn-gold(对齐原型 .btn-gold) ─────────────────────────

/// 金色背景 + 白文字 + 圆角按钮(对齐 OD 原型 .btn-gold)。
class _GoldButton extends StatelessWidget {
  const _GoldButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tooltip,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton.icon(
      key: super.key,
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label,
          key: ValueKey('goldBtnLabel_$label'),
          style: const TextStyle(color: Colors.white, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.yucai.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ───────────────────────── 分组头 ─────────────────────────

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.title, required this.icon, required this.count});
  final String title;
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.yucai.muted),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: context.yucai.accentSoft,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.yucai.accent,
                  fontFeatures: AppTypography.tabularFigures)),
        ),
      ],
    );
  }
}

// ───────────────────────── 目标卡 ─────────────────────────

/// 单目标卡:Name + 类型徽章 + ConicProgressRing + target/current + deadline 倒计时 +
/// 左侧 status 色条(对齐原型 .goal-card.ontrack/.behind/.completed border-left)。
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final GoalView goal;

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta(goal.type);
    final pct = goal.progressPct;
    final ringValue = (pct / 100).clamp(0.0, 1.0);
    final pctLabel = '${pct.toStringAsFixed(0)}%';

    final daysLeft = _daysLeft(goal.deadline);
    final isUrgent = !goal.isCompleted &&
        daysLeft != null &&
        daysLeft <= 90 &&
        ringValue < 0.7;

    final ringColor = goal.isCompleted
        ? context.yucai.positive
        : (isUrgent ? context.yucai.negative : meta.color);
    // 左侧 status 色条(对齐原型 .goal-card border-left)。
    final accentColor = goal.isCompleted
        ? context.yucai.positive
        : (isUrgent ? context.yucai.negative : context.yucai.accent);

    return DataCard(
      key: ValueKey('goalCard_${goal.id}'),
      onTap: () => context.push('/goals/${goal.id}'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧 status 色条。
            Container(
              width: 3,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部:Name + 类型徽章。
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(goal.name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: AppTypography.displayFamily,
                                    fontFamilyFallback:
                                        AppTypography.displayFallback)),
                            if (goal.notes != null &&
                                goal.notes!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(goal.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: context.yucai.muted)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypeChip(meta: meta),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 中部:ConicProgressRing(左)+ current/target(右)。
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConicProgressRing(
                        key: const ValueKey('goalRing'),
                        progress: ringValue,
                        color: ringColor,
                        pctLabel: pctLabel,
                        size: ConicRingSize.md,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fmtSymbol(
                                  goal.currentAmountCents, goal.currencyCode),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: AppTypography.tabularFigures),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '目标 ${_fmtSymbol(goal.targetAmountCents, goal.currencyCode)}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.yucai.muted,
                                  fontFeatures: AppTypography.tabularFigures),
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
                      Icon(LucideIcons.calendar,
                          size: 13, color: context.yucai.muted),
                      const SizedBox(width: 4),
                      Text(
                        _deadlineText(goal, daysLeft),
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                isUrgent ? context.yucai.negative : context.yucai.muted,
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
}

// ───────────────────────── 类型徽章 ─────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.meta});
  final _TypeMeta meta;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('goalTypeChip_${meta.key}'),
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

// ───────────────────────── 类型元数据 ─────────────────────────

class _TypeMeta {
  const _TypeMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

/// 类型 → 徽章元数据。对齐 OD 原型 mock-data.js GOAL_TYPES:
/// savings(金 piggyBank)/ debtPayoff(红 creditCard)/ investment(绿 trendingUp)。
_TypeMeta _typeMeta(GoalType type) {
  switch (type) {
    case GoalType.savings:
      return const _TypeMeta(
        key: 'savings',
        label: '储蓄目标',
        icon: LucideIcons.piggyBank,
        color: AppColors.accent,
      );
    case GoalType.debtPayoff:
      return const _TypeMeta(
        key: 'debtPayoff',
        label: '债务清偿',
        icon: LucideIcons.creditCard,
        color: AppColors.negative,
      );
    case GoalType.investment:
      return const _TypeMeta(
        key: 'investment',
        label: '投资目标',
        icon: LucideIcons.trendingUp,
        color: AppColors.positive,
      );
  }
}

// ───────────────────────── deadline 倒计时 ─────────────────────────

int? _daysLeft(DateTime? deadline) {
  if (deadline == null) return null;
  final now =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final d = DateTime(deadline.year, deadline.month, deadline.day);
  return d.difference(now).inDays;
}

String _deadlineText(GoalView goal, int? daysLeft) {
  if (goal.isCompleted) return '已达成';
  if (daysLeft == null) return '无截止日期';
  if (daysLeft < 0) return '已逾期 ${-daysLeft} 天';
  if (daysLeft > 365) return '剩 ${(daysLeft / 30).round()} 个月';
  return '剩 $daysLeft 天';
}

// ───────────────────────── helpers ─────────────────────────

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
