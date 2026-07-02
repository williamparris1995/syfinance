// 目标列表页(goal 模块入口)。消费 Task 11 GoalBloc + Task 10 GoalView。
//
// 设计源(OD 原型 Task 1):design-output/goal/goal-list-{desktop,tablet,mobile}.html
//  + styles.css + mock-data.js。布局对齐原型:3 type 混合卡片 + 类型徽章 +
//  进度环 + deadline 倒计时 + 完成/进行中分组 + AppBar 新建。
//
// 对齐御财设计语言 + 照搬 budget BudgetListPage / holding 列表页范式(顶栏 +
// 卡片列表 + AppBar 新建):
//  - AppColors:御财金 #b08d57(accent,savings)/ 盈绿 #2d8a6e(positive,
//    investment + completed)/ 亏红 #c4544d(negative,debtPayoff + 落后/紧急)。
//  - 类型徽章(GOAL_TYPES 对齐 mock-data.js):
//      savings    → 储蓄目标 / piggyBank  / accent(金)
//      debtPayoff → 债务清偿 / creditCard / negative(红)
//      investment → 投资目标 / trendingUp / positive(绿)
//  - 进度环:CircularProgressIndicator(value=progressPct clamp[0,1]),
//    完成色 positive、进行中按 type 色、落后(剩余天数≤90 且 pct<70%)色 negative。
//  - 倒计时:deadline - now 天数;>365 显示"X 个月";完成显"已达成";无 deadline
//    显"无截止"。
//  - 分组:进行中(未完成,deadline 升序)+ 已完成(isCompleted,按完成近度)。
//
// 路由:本页由路由层(Task 11)注入 BlocProvider<GoalBloc>;此处
// context.watch<GoalBloc>()。卡片 tap → context.push('/goals/:id');
// AppBar 新建 → push '/goals/new'。
//
// 无 i18n(中文硬编码,御财惯例;与 budget/holding 列表页一致)。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_state.dart';

/// 目标列表页。对齐御财 list 卡片范式(顶栏 + 分组卡片 + 新建入口)。
class GoalListPage extends StatefulWidget {
  const GoalListPage({super.key});

  @override
  State<GoalListPage> createState() => _GoalListPageState();
}

class _GoalListPageState extends State<GoalListPage> {
  @override
  void initState() {
    super.initState();
    // 拉取全部目标(type=null 不过滤)。对齐 brief:列表页混合展示 3 type。
    context.read<GoalBloc>().add(const LoadListRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text('目标',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
      ),
      // 创建目标 FAB(对齐 debts/receivables/holdings 等其他 list 页范式:
      // 金色背景 + 白色 add icon,heroTag: null 禁 Hero —— indexedStack 保活多
      // branch 时避免与其它 branch FAB 共用默认 Hero tag 冲突)。
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => context.push('/goals/new'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocBuilder<GoalBloc, GoalState>(
        builder: (context, state) {
          if (state is GoalLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is GoalError) {
            return _errorState(state.message);
          }
          if (state is GoalListLoaded) {
            final goals = state.goals;
            if (goals.isEmpty) return _emptyState();
            // 分组:进行中(未完成)+ 已完成。对齐 OD 原型 groups 渲染。
            final inProgress = goals.where((g) => !g.isCompleted).toList()
              ..sort(_byDeadlineAsc);
            final completed = goals.where((g) => g.isCompleted).toList();
            return _groups(inProgress, completed);
          }
          // GoalInitial / GoalDetailLoaded(详情态,不应出现在列表页)→ 兜底 loading。
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  // ───────────────────────── 分组排序 ─────────────────────────

  /// 按 deadline 升序(无 deadline 排末尾)。用于进行中分组:紧迫的在前。
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
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.target, size: 30, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('还没有目标', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            '点击右上角「+」开始攒钱 / 还债 / 投资',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
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
            const Icon(Icons.error_outline, size: 40, color: AppColors.negative),
            const SizedBox(height: 12),
            const Text('加载失败', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () =>
                  context.read<GoalBloc>().add(const LoadListRequested()),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('重试'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 分组列表 ─────────────────────────

  Widget _groups(List<GoalView> inProgress, List<GoalView> completed) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (inProgress.isNotEmpty) ...[
                _GroupHeader(
                  title: '进行中',
                  icon: LucideIcons.clock,
                  count: inProgress.length,
                ),
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
                  count: completed.length,
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < completed.length; i++) ...[
                  _GoalCard(goal: completed[i]),
                  if (i < completed.length - 1) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          ),
        ),
      ),
    );
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
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.accentSoft,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  fontFeatures: AppTypography.tabularFigures)),
        ),
      ],
    );
  }
}

// ───────────────────────── 目标卡 ─────────────────────────

/// 单目标卡:Name + 类型徽章 + 进度环(UsagePct)+ target/current + deadline 倒计时。
/// 点击 → 详情页('/goals/:id',路由 Task 11 接)。
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final GoalView goal;

  @override
  Widget build(BuildContext context) {
    final meta = _typeMeta(goal.type);
    final pct = goal.progressPct; // 0..100(可能 >100,超目标)
    final ringValue = (pct / 100).clamp(0.0, 1.0);
    final pctLabel = '${pct.toStringAsFixed(0)}%';

    final daysLeft = _daysLeft(goal.deadline);
    final isUrgent = !goal.isCompleted &&
        daysLeft != null &&
        daysLeft <= 90 &&
        ringValue < 0.7;

    // 进度环色:完成 → positive;落后紧急 → negative;否则按 type 色。
    final ringColor = goal.isCompleted
        ? AppColors.positive
        : (isUrgent ? AppColors.negative : meta.color);

    return DataCard(
      key: ValueKey('goalCard_${goal.id}'),
      onTap: () => context.push('/goals/${goal.id}'),
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
                            fontFamilyFallback: AppTypography.displayFallback)),
                    if (goal.notes != null && goal.notes!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(goal.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _TypeChip(meta: meta),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 中部:进度环(左)+ current/target(右)。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ProgressRing(value: ringValue, pctLabel: pctLabel, color: ringColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fmtSymbol(goal.currentAmountCents, goal.currencyCode),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFeatures: AppTypography.tabularFigures),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '目标 ${_fmtSymbol(goal.targetAmountCents, goal.currencyCode)}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
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
              const Icon(LucideIcons.calendar, size: 13, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                _deadlineText(goal, daysLeft),
                style: TextStyle(
                    fontSize: 12,
                    color: isUrgent ? AppColors.negative : AppColors.muted,
                    fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w400),
              ),
            ],
          ),
        ],
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

// ───────────────────────── 进度环 ─────────────────────────

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({
    required this.value,
    required this.pctLabel,
    required this.color,
  });
  final double value; // clamp[0,1]
  final String pctLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('goalRing'),
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              key: const ValueKey('goalRingBar'),
              value: value,
              strokeWidth: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(pctLabel,
              key: const ValueKey('goalRingPct'),
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: AppTypography.tabularFigures)),
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

/// deadline 距今天数(截至当日 0 点;null = 无 deadline)。负数表示已过。
int? _daysLeft(DateTime? deadline) {
  if (deadline == null) return null;
  final now = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final d = DateTime(deadline.year, deadline.month, deadline.day);
  return d.difference(now).inDays;
}

/// 倒计时文案。对齐 OD 原型:
///  - 完成 → "已达成"
///  - 无 deadline → "无截止日期"
///  - >365 天 → "X 个月"
///  - ≤0(已过)→ "已逾期 X 天"
///  - 否则 → "剩 X 天"
String _deadlineText(GoalView goal, int? daysLeft) {
  if (goal.isCompleted) return '已达成';
  if (daysLeft == null) return '无截止日期';
  if (daysLeft < 0) return '已逾期 ${-daysLeft} 天';
  if (daysLeft > 365) return '剩 ${(daysLeft / 30).round()} 个月';
  return '剩 $daysLeft 天';
}

// ───────────────────────── helpers ─────────────────────────

/// 千分位 + 两位小数 + 货币符号前缀(对齐 budget/holding/debt 页 _fmtSymbol,
/// 复用 currency_currency_convert.dart 的 currencySymbol)。
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
