// 预算列表页(budget 模块入口)。消费 Task 7 BudgetBloc + Task 6 BudgetView。
//
// 对齐御财设计语言 + 照搬 holding/debt 列表页范式(顶栏 + 卡片列表 + AppBar 新建):
//  - AppColors:御财金 #b08d57(accent)/ 盈绿 #2d8a6e(positive)/ 亏红 #c4544d
//    (negative);超支用 negative;brief 指定 #c0392b(更暗红,故 over-budget 单独
//    取 overBudget 红常量)。
//  - 卡片:DataCard(白底 14 圆角 + 极淡阴影,统一内边距);顶部 Name + Month +
//    UsagePct% + 进度条(超支红 / 正常金);底部 TotalActual/TotalAmount + 剩余。
//  - 月份切换:← yyyy-MM → 客户端 filter budgets by month(budget.month == selected)。
//    默认当月(DateTime.now() → yyyy-MM,无 intl 依赖手格式化)。
//  - 无 i18n(中文硬编码,御财惯例)。
//
// 路由:本页由路由层(Task 11)注入 BlocProvider<BudgetBloc>;此处
// context.watch<BudgetBloc>()。点击预算卡 → context.push('/budgets/${id}')
// (路由 Task 11 接,这里先写导航调用);AppBar 新建 action → push '/budgets/new'。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

/// 超支红(brief 指定 #c0392b,比 AppColors.negative 更暗,区分"超预算")。
const Color _overBudgetRed = Color(0xFFC0392B);

/// 预算列表页。对齐御财 list 卡片范式(顶栏 + 卡片 + 新建入口)。
class BudgetListPage extends StatefulWidget {
  const BudgetListPage({super.key});

  @override
  State<BudgetListPage> createState() => _BudgetListPageState();
}

class _BudgetListPageState extends State<BudgetListPage> {
  /// 选中的月份(yyyy-MM),默认当月。客户端 filter budgets by month。
  late String _selectedMonth = _monthOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    // 拉取全部预算(activeOnly=false);月份过滤为前端二次过滤(对齐 brief:
    // budget.month == selected)。
    context.read<BudgetBloc>().add(const LoadListRequested());
  }

  /// 当前选中月份下的预算(bloc 已拉取全部;前端 filter by month)。
  List<BudgetView> _filtered(List<BudgetView> all) =>
      all.where((b) => b.month == _selectedMonth).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text('预算',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
      ),
      // 创建预算 FAB(对齐 debts/receivables/holdings 等其他 list 页范式:
      // 金色背景 + 白色 add icon,heroTag: null 禁 Hero —— indexedStack 保活多
      // branch 时避免与其它 branch FAB 共用默认 Hero tag 冲突)。
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => context.push('/budgets/new'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocBuilder<BudgetBloc, BudgetState>(
        builder: (context, state) {
          if (state is BudgetLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is BudgetError) {
            return _errorState(state.message);
          }
          if (state is BudgetListLoaded) {
            final filtered = _filtered(state.budgets);
            return Column(
              children: [
                _MonthSwitcher(
                  month: _selectedMonth,
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? _emptyState()
                      : _list(filtered),
                ),
              ],
            );
          }
          // BudgetInitial / BudgetDetailLoaded(详情态,不应出现在列表页)
          // → 兜底 loading。
          return const Center(child: CircularProgressIndicator());
        },
      ),
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
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.wallet,
                size: 30, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('暂无预算，点击新建',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text(
            '切换月份或点右上角「+」创建本月预算',
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
            const Text('加载失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: () => context
                  .read<BudgetBloc>()
                  .add(const LoadListRequested()),
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

  // ───────────────────────── 列表 ─────────────────────────

  Widget _list(List<BudgetView> budgets) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < budgets.length; i++) ...[
                _BudgetCard(budget: budgets[i]),
                if (i < budgets.length - 1) const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 月份切换器 ─────────────────────────

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
            style: const TextStyle(
              fontSize: 15,
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
    );
  }
}

// ───────────────────────── 预算卡 ─────────────────────────

/// 单预算卡:Name + Month + 进度条(超支红 / 正常金)+ UsagePct% +
/// TotalActual/TotalAmount + 剩余。点击 → 详情页(路由 Task 11)。
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});
  final BudgetView budget;

  @override
  Widget build(BuildContext context) {
    final over = budget.isOverBudget;
    final progressColor = over ? _overBudgetRed : AppColors.accent;
    // LinearProgressIndicator value 限定 [0,1];超支时满格(1.0)显红色。
    final rawPct = budget.totalAmountCents == 0
        ? 0.0
        : budget.totalActualCents / budget.totalAmountCents;
    final progressValue = rawPct.clamp(0.0, 1.0);
    final pctLabel = '${budget.usagePct.toStringAsFixed(1)}%';
    final remaining = budget.totalRemainingCents;

    return DataCard(
      onTap: () => context.push('/budgets/${budget.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部:Name + Month pill。
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
                    Text(budget.month,
                        style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted,
                            fontFeatures: AppTypography.tabularFigures)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // UsagePct% pill(超支红 / 正常金)。
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: progressColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  pctLabel,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: progressColor,
                      fontFeatures: AppTypography.tabularFigures),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // 进度条(超支红 / 正常金)。
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              key: const ValueKey('budgetProgressBar'),
              value: progressValue,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // 底部:实际/总额 + 剩余(超支红)。
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              _MetaKV(
                k: '实际',
                v:
                    '${_fmtSymbol(budget.totalActualCents, budget.currencyCode)} / ${_fmtSymbol(budget.totalAmountCents, budget.currencyCode)}',
              ),
              _MetaKV(
                k: remaining >= 0 ? '剩余' : '超支',
                v: _fmtSymbol(remaining.abs(), budget.currencyCode),
                vColor: over ? _overBudgetRed : AppColors.positive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

// ───────────────────────── helpers ─────────────────────────

/// DateTime → yyyy-MM(无 intl 依赖,手格式化)。
String _monthOf(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}';

/// 千分位 + 两位小数 + 货币符号前缀(对齐 holding/debt 页 _fmtSymbol,
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
