// 预算列表页(budget 模块入口)。消费 Task 7 BudgetBloc + Task 6 BudgetView。
//
// 设计源(OD 原型):design-output/budget/budget-list-{desktop,tablet,mobile}.html
//  + styles.css + mock-data.js。**大 UI 对齐原型**(2026-07,照 goal 对齐范式):
//   - topbar:title「预算管理」+ sub(月度预算 · 共 N 个)+ 月份切换(← yyyy-MM →,
//     budget 特有)+ 刷新 icon-btn + btn-gold「新建预算」(替 FAB)。
//   - 状态筛选 chips:全部 / 超支 / 正常(原型 nav-sec 状态筛选 + 计数)。
//   - 分组(超支 / 正常):ConicProgressRing 卡片(超支红 / 正常金)+ Name + Month +
//     UsagePct% pill + TotalActual/TotalAmount + 剩余/超支 + 左侧 status 色条。
//
// 御财设计语言(已语义令牌化(F15)/AppTypography/lucide):
//  - 御财金 #b08d57(btn-gold + 正常金);超支用 brief 指定 #c0392b(比
//    context.yucai.negative 更暗,区分「超预算」,单独取 overBudget 红常量)。
//  - 进度环:ConicProgressRing(progress=clamp[0,1],复用 core/widgets);超支色 overBudget
//    红、正常色 accent 金。
//  - ConicProgressRing 由 goal 对齐产出,此处直接 import 复用(不重写)。
//
// 路由:本页由路由层(Task 11)注入 BlocProvider<BudgetBloc>;此处
// context.read<BudgetBloc>()。卡片 tap → context.push('/budgets/:id');
// btn-gold 新建 → push '/budgets/new'。
//
// 无 i18n(中文硬编码,御财惯例;与 goal/holding 列表页一致)。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/conic_progress_ring.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

// F4-P2:超支红原 brief 色 #C0392B 已语义令牌化 → context.yucai.negative
// (v2 亮=玫红 / 暗=提亮红,与全应用支出红统一;顶层常量删除)。

/// 预算列表页。对齐 OD 原型:topbar + 月份切换 + 状态筛选 chips + conic 环卡片 +
/// btn-gold 新建。
class BudgetListPage extends StatefulWidget {
  const BudgetListPage({super.key});

  @override
  State<BudgetListPage> createState() => _BudgetListPageState();
}

/// 状态筛选枚举(对齐原型 nav-sec 状态筛选 + 全部)。
enum _StatusFilter { all, over, normal }

class _BudgetListPageState extends State<BudgetListPage> {
  /// 选中的月份(yyyy-MM),默认当月。客户端 filter budgets by month。
  late String _selectedMonth = _monthOf(DateTime.now());
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void initState() {
    super.initState();
    // 拉取全部预算(activeOnly=false);月份过滤为前端二次过滤(对齐 brief:
    // budget.month == selected)。
    context.read<BudgetBloc>().add(const LoadListRequested());
  }

  /// 当前选中月份下的预算(bloc 已拉取全部;前端 filter by month)。
  List<BudgetView> _filteredByMonth(List<BudgetView> all) =>
      all.where((b) => b.month == _selectedMonth).toList();

  /// 按状态筛选(在月份过滤之后)。
  List<BudgetView> _applyStatusFilter(List<BudgetView> monthBudgets) {
    switch (_statusFilter) {
      case _StatusFilter.all:
        return monthBudgets;
      case _StatusFilter.over:
        return monthBudgets.where((b) => b.isOverBudget).toList();
      case _StatusFilter.normal:
        return monthBudgets.where((b) => !b.isOverBudget).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, state) {
          // topbar 永远显示(标题 + sub + 月份切换 + 新建),body 三态切换。
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

  Widget _topbar(BudgetState state) {
    final monthBudgets = state is BudgetListLoaded ? _filteredByMonth(state.budgets) : const <BudgetView>[];
    final count = monthBudgets.length;
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
                      const Text('预算管理',
                          key: ValueKey('budgetListTitle'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTypography.displayFamily,
                              fontFamilyFallback:
                                  AppTypography.displayFallback)),
                      const SizedBox(height: 4),
                      Text(
                        '月度预算 · 按月切换 · 当前月份共 $count 个预算',
                        key: const ValueKey('budgetListSub'),
                        style: TextStyle(
                            fontSize: 12.5, color: context.yucai.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // actions:刷新 icon-btn + btn-gold 新建。
                IconButton(
                  key: const ValueKey('budgetListRefresh'),
                  tooltip: '刷新',
                  icon: const Icon(LucideIcons.refreshCw, size: 18),
                  color: context.yucai.muted,
                  onPressed: () => context
                      .read<BudgetBloc>()
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

  Widget _body(BudgetState state) {
    if (state is BudgetLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is BudgetError) {
      return _errorState(state.message);
    }
    if (state is BudgetListLoaded) {
      final monthBudgets = _filteredByMonth(state.budgets);
      return Column(
        children: [
          _MonthSwitcher(
            month: _selectedMonth,
            onPrev: _prevMonth,
            onNext: _nextMonth,
          ),
          if (monthBudgets.isEmpty)
            Expanded(child: _emptyState())
          else
            Expanded(
              child: _content(monthBudgets),
            ),
        ],
      );
    }
    // BudgetInitial / BudgetDetailLoaded(详情态,不应出现在列表页)→ 兜底 loading。
    return const Center(child: CircularProgressIndicator());
  }

  // ───────────────────────── 主内容(状态筛选 + 分组卡片) ─────────────────────────

  Widget _content(List<BudgetView> monthBudgets) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusFilterRow(monthBudgets),
              const SizedBox(height: AppSpacing.sm),
              _groups(_applyStatusFilter(monthBudgets)),
            ],
          ),
        ),
      ),
    );
  }

  /// 状态筛选 chips(对齐原型 nav-sec 状态筛选:全部 / 超支 / 正常)。
  Widget _statusFilterRow(List<BudgetView> monthBudgets) {
    final overCount = monthBudgets.where((b) => b.isOverBudget).length;
    final normalCount = monthBudgets.length - overCount;
    final chips = <_FilterChipData>[
      _FilterChipData(_StatusFilter.all, '全部', monthBudgets.length, null),
      _FilterChipData(
          _StatusFilter.over, '超支', overCount, context.yucai.negative, LucideIcons.alertTriangle),
      _FilterChipData(
          _StatusFilter.normal, '正常', normalCount, context.yucai.accent, LucideIcons.checkCircle2),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final c in chips)
          _FilterChip(
            data: c,
            selected: _statusFilter == c.value,
            onTap: () => setState(() => _statusFilter = c.value),
          ),
      ],
    );
  }

  /// 分组(对齐原型:超支组 + 正常组)。
  Widget _groups(List<BudgetView> budgets) {
    final overList = budgets.where((b) => b.isOverBudget).toList();
    final normalList = budgets.where((b) => !b.isOverBudget).toList();
    if (overList.isEmpty && normalList.isEmpty) {
      // 状态筛选下无匹配。
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text('该状态本月无预算',
              style: TextStyle(color: context.yucai.muted, fontSize: 13)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (overList.isNotEmpty) ...[
          _GroupHeader(
              title: '超支',
              icon: LucideIcons.alertTriangle,
              count: overList.length,
              color: context.yucai.negative),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < overList.length; i++) ...[
            _BudgetCard(budget: overList[i]),
            if (i < overList.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
          if (normalList.isNotEmpty) const SizedBox(height: AppSpacing.lg),
        ],
        if (normalList.isNotEmpty) ...[
          _GroupHeader(
              title: '正常',
              icon: LucideIcons.checkCircle2,
              count: normalList.length,
              color: context.yucai.accent),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < normalList.length; i++) ...[
            _BudgetCard(budget: normalList[i]),
            if (i < normalList.length - 1) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  // ───────────────────────── 月份切换 ─────────────────────────

  void _prevMonth() {
    setState(() {
      _selectedMonth = _shiftMonth(_selectedMonth, -1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = _shiftMonth(_selectedMonth, 1);
    });
  }

  /// yyyy-MM → DateTime(取 1 号)便于加减月。
  String _shiftMonth(String yyyyMm, int delta) {
    final parts = yyyyMm.split('-');
    if (parts.length != 2) return yyyyMm;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null) return yyyyMm;
    var ny = y;
    var nm = m + delta;
    while (nm < 1) {
      nm += 12;
      ny -= 1;
    }
    while (nm > 12) {
      nm -= 12;
      ny += 1;
    }
    return '$ny-${nm.toString().padLeft(2, '0')}';
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
            child: Icon(LucideIcons.wallet,
                size: 30, color: context.yucai.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('本月暂无预算',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            '切换月份或点击右上「新建预算」开始',
            style: TextStyle(color: context.yucai.muted, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          _GoldButton(
            icon: LucideIcons.plus,
            label: '新建本月预算',
            onPressed: () => context.push('/budgets/new'),
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
                  context.read<BudgetBloc>().add(const LoadListRequested()),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 月份切换器(对齐原型 month-switcher) ─────────────────────────

class _MonthSwitcher extends StatelessWidget {
  const _MonthSwitcher({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });
  final String month; // yyyy-MM
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('budgetPrevMonth'),
                tooltip: '上月',
                icon: const Icon(LucideIcons.chevronLeft, size: 20),
                onPressed: onPrev,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                month,
                key: const ValueKey('budgetMonthVal'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                key: const ValueKey('budgetNextMonth'),
                tooltip: '下月',
                icon: const Icon(LucideIcons.chevronRight, size: 20),
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 状态筛选 chip ─────────────────────────

class _FilterChipData {
  const _FilterChipData(this.value, this.label, this.count, this.color,
      [this.icon]);
  final _StatusFilter value;
  final String label;
  final int count;
  final Color? color; // null = all(无图标色)
  final IconData? icon;
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
    final chipColor = widget.data.color ?? context.yucai.accent;
    final bg = selected
        ? chipColor
        : (_hover ? context.yucai.surfaceAlt : context.yucai.surface);
    // F27 FR-1①:选中 chip 若落 accent 底(全部/正常)→ onAccent(暗=金底深墨);
    // FR-1②:超支 chip 的 negative 系类目身份彩底 → 固定白(豁免,双板可辨识)。
    final onBg = chipColor == context.yucai.accent
        ? context.yucai.onAccent
        : Colors.white; // 类目身份彩底固定白(F27 豁免)
    final fg = selected ? onBg : context.yucai.muted;
    final border = selected ? chipColor : context.yucai.border;

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
              if (widget.data.icon != null) ...[
                Icon(widget.data.icon,
                    size: 13, color: selected ? onBg : chipColor),
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
                      color: selected ? onBg : context.yucai.muted,
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

/// accent 背景按钮(对齐 OD 原型 .btn-gold;F27:前景迁 onAccent,暗=金底深墨)。
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
    // F27 FR-1①:btn-gold 为 accent 面主按钮 —— icon/label/前景全部 onAccent
    // (暗=金底深墨 #1A1408,亮=翡翠绿底白字,随主题)。
    final btn = ElevatedButton.icon(
      key: super.key,
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: context.yucai.onAccent),
      label: Text(label,
          key: ValueKey('goldBtnLabel_$label'),
          style: TextStyle(color: context.yucai.onAccent, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.yucai.accent,
        foregroundColor: context.yucai.onAccent,
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
  const _GroupHeader(
      {required this.title,
      required this.icon,
      required this.count,
      required this.color});
  final String title;
  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
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
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFeatures: AppTypography.tabularFigures)),
        ),
      ],
    );
  }
}

// ───────────────────────── 预算卡 ─────────────────────────

/// 单预算卡:左侧 status 色条 + Name + Month + ConicProgressRing(超支红 / 正常金)+
/// UsagePct% pill + TotalActual/TotalAmount + 剩余/超支。点击 → 详情页(路由 Task 11)。
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});
  final BudgetView budget;

  @override
  Widget build(BuildContext context) {
    final over = budget.isOverBudget;
    final ringColor = over ? context.yucai.negative : context.yucai.accent;
    final accentColor = over ? context.yucai.negative : context.yucai.accent;
    // ConicProgressRing progress 限定 [0,1];超支时满格(1.0)。
    final rawPct = budget.totalAmountCents == 0
        ? 0.0
        : budget.totalActualCents / budget.totalAmountCents;
    final ringValue = rawPct.clamp(0.0, 1.0);
    final pctLabel = '${budget.usagePct.toStringAsFixed(0)}%';
    final remaining = budget.totalRemainingCents;

    return DataCard(
      key: ValueKey('budgetCard_${budget.id}'),
      onTap: () => context.push('/budgets/${budget.id}'),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧 status 色条(对齐原型 .budget-card.over/.normal border-left)。
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
                  // 顶部:Name + Month(左)+ UsagePct% pill(右)。
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(budget.name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: AppTypography.displayFamily,
                                    fontFamilyFallback:
                                        AppTypography.displayFallback)),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(LucideIcons.calendar,
                                    size: 12, color: context.yucai.muted),
                                const SizedBox(width: 4),
                                Text(budget.month,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: context.yucai.muted,
                                        fontFeatures:
                                            AppTypography.tabularFigures)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // UsagePct% pill(超支红 / 正常金)。
                      Container(
                        key: const ValueKey('budgetPctPill'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: ringColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          pctLabel,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: ringColor,
                              fontFeatures: AppTypography.tabularFigures),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 中部:ConicProgressRing(左)+ TotalActual/TotalAmount(右)。
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ConicProgressRing(
                        key: const ValueKey('budgetCardRing'),
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
                              _fmtSymbol(budget.totalActualCents,
                                  budget.currencyCode),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: over ? context.yucai.negative : context.yucai.fg,
                                  fontFeatures:
                                      AppTypography.tabularFigures),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '预算 ${_fmtSymbol(budget.totalAmountCents, budget.currencyCode)}',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.yucai.muted,
                                  fontFeatures:
                                      AppTypography.tabularFigures),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 底部:剩余/超支。
                  Row(
                    children: [
                      Icon(
                          over
                              ? LucideIcons.alertTriangle
                              : LucideIcons.checkCircle2,
                          size: 13,
                          color: over ? context.yucai.negative : context.yucai.positive),
                      const SizedBox(width: 4),
                      Text(
                        over
                            ? '超支 ${_fmtSymbol(remaining.abs(), budget.currencyCode)}'
                            : '剩余 ${_fmtSymbol(remaining, budget.currencyCode)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: over
                                ? context.yucai.negative
                                : context.yucai.positive,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTypography.tabularFigures),
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

// ───────────────────────── helpers ─────────────────────────

/// DateTime → yyyy-MM(无 intl 依赖,手格式化)。
String _monthOf(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}';

/// 千分位 + 两位小数 + 货币符号前缀(对齐 goal/holding 页 _fmtSymbol,复用
/// currency_convert.dart 的 currencySymbol)。
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
