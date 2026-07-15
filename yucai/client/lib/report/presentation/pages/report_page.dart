import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/report/presentation/widgets/category_breakdown_pie.dart';
import 'package:yucai_client/report/presentation/widgets/income_expense_trend_chart.dart';
import 'package:yucai_client/report/presentation/widgets/monthly_comparison_bar.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 报表分析页（sidebar「工具 › 报表分析」）。
///
/// 顶层路由 /reports（StatefulShellRoute 之外，与 /login /register 同级），
/// 故无 shell sidebar/topbar —— 本页自带顶栏（返回 chevronLeft + 标题 +
/// 月/年 period segmented）。body 用 FutureBuilder 拉
/// [TransactionRepository.summary]（[MonthlySummary]：income/expense/net/
/// dailyAvg + byDay + byCategory），为 Task 3 三图表预留 section 占位：
///   1. 收支趋势（LineChart，byDay）   — 占位「趋势图待实现」
///   2. 分类占比（PieChart，byCategory）— 占位「分类图待实现」
///   3. 月度对比（BarChart，多月）      — 占位「对比图待实现」
///
/// period 切换：[SummaryScope.month]（默认，当月按日聚合）↔
/// [SummaryScope.year]（当年按月聚合）。切换时重建 Future 重新拉取。
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  SummaryScope _scope = SummaryScope.month;
  late Future<Either<Failure, MonthlySummary>> _future;
  /// 近 6 月月度对比数据（与 period tab 无关，故独立加载一次，不复载）。
  late Future<List<MonthlySummary>> _monthlyComparison;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _monthlyComparison = _loadMonthlyComparison();
  }

  Future<Either<Failure, MonthlySummary>> _load() {
    final now = DateTime.now();
    return getIt<TransactionRepository>()
        .summary(now.year, now.month, scope: _scope);
  }

  /// 并发拉取近 6 个月 summary（month scope）。各月独立 Either；任一失败折叠为
  /// 跳过（drop），全失败 → 空列表 → 月度对比 chart 自身空态。
  Future<List<MonthlySummary>> _loadMonthlyComparison() async {
    final now = DateTime.now();
    final futures = <Future<Either<Failure, MonthlySummary>>>[];
    for (var i = 5; i >= 0; i--) {
      // DateTime(y, m-i) 自动处理跨年（month<=0 → 前一年 12 月等）。
      final d = DateTime(now.year, now.month - i);
      futures.add(getIt<TransactionRepository>()
          .summary(d.year, d.month, scope: SummaryScope.month));
    }
    final results = await Future.wait(futures);
    return [
      for (final r in results)
        r.fold<MonthlySummary?>((_) => null, (s) => s),
    ].whereType<MonthlySummary>().toList();
  }

  void _switchScope(SummaryScope s) {
    if (s == _scope) return;
    setState(() {
      _scope = s;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _ReportTopBar(
            scope: _scope,
            onScopeChanged: _switchScope,
            onBack: () => context.go('/home'),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    return FutureBuilder<Either<Failure, MonthlySummary>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.muted),
          );
        }
        if (!snap.hasData) {
          return _StateView(
            icon: LucideIcons.alertCircle,
            message: '加载失败',
            onRetry: () => setState(() => _future = _load()),
          );
        }
        return snap.data!.fold(
          (f) => _StateView(
            icon: LucideIcons.alertCircle,
            message: f.message.isEmpty ? '加载失败' : f.message,
            onRetry: () => setState(() => _future = _load()),
          ),
          (summary) => _content(summary),
        );
      },
    );
  }

  Widget _content(MonthlySummary summary) {
    final periodLabel = _scope == SummaryScope.year
        ? '${summary.year} 年'
        : '${summary.year} 年 ${summary.month} 月';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SummaryStrip(summary: summary, periodLabel: periodLabel),
              const SizedBox(height: AppSpacing.md),
              _ChartSection(
                title: '收支趋势',
                child: IncomeExpenseTrendChart(
                  byDay: summary.byDay,
                  scope: summary.scope ?? _scope,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartSection(
                title: '支出分类占比',
                child: CategoryBreakdownPie(
                  slices: aggregateCategorySlices(summary),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ChartSection(
                title: '近 6 月对比',
                child: FutureBuilder<List<MonthlySummary>>(
                  future: _monthlyComparison,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.muted),
                        ),
                      );
                    }
                    final months = snap.data ?? const [];
                    return MonthlyComparisonBar(months: months);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 顶栏（返回 + 标题 + period segmented） ──────────

class _ReportTopBar extends StatelessWidget {
  const _ReportTopBar({
    required this.scope,
    required this.onScopeChanged,
    required this.onBack,
  });

  final SummaryScope scope;
  final ValueChanged<SummaryScope> onScopeChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      // 对齐 shell _TopBar 底色（OD .topbar rgba(247,246,242,.85)）。
      color: const Color(0xFFF7F6F2).withValues(alpha: 0.85),
      child: Row(children: [
        IconButton(
          tooltip: '返回',
          icon: const Icon(LucideIcons.chevronLeft,
              size: 20, color: AppColors.fg),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: AppColors.accentSoft.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
          ),
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.sm),
        const Text(
          '报表分析',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.fg,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
          ),
        ),
        const Spacer(),
        _PeriodSegmented(scope: scope, onChanged: onScopeChanged),
      ]),
    );
  }
}

/// 月/年 period 切换（pill segmented，对齐 app 圆角/配色 token）。
class _PeriodSegmented extends StatelessWidget {
  const _PeriodSegmented({required this.scope, required this.onChanged});

  final SummaryScope scope;
  final ValueChanged<SummaryScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('月', scope == SummaryScope.month,
              () => onChanged(SummaryScope.month)),
          _segment('年', scope == SummaryScope.year,
              () => onChanged(SummaryScope.year)),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: AppRadius.smBorder,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 汇总条（income/expense/net/dailyAvg） ──────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary, required this.periodLabel});

  final MonthlySummary summary;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(periodLabel,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 620;
            final stats = <_Stat>[
              _Stat('收入', summary.incomeCents, AppColors.positive),
              _Stat('支出', summary.expenseCents, AppColors.negative),
              _Stat(
                  '结余', summary.netCents, _netColor(summary.netCents)),
              _Stat('日均', summary.dailyAvgCents, AppColors.fg),
            ];
            if (wide) {
              return Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: _StatTile(stat: stats[i])),
                    if (i < stats.length - 1)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                            height: 32,
                            child: VerticalDivider(
                                width: 1, color: AppColors.border)),
                      ),
                  ],
                ],
              );
            }
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [for (final s in stats) _StatTile(stat: s)],
            );
          }),
        ],
      ),
    );
  }

  Color _netColor(int cents) =>
      cents >= 0 ? AppColors.positive : AppColors.negative;
}

class _Stat {
  const _Stat(this.label, this.cents, this.valueColor);
  final String label;
  final int cents;
  final Color valueColor;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});
  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(stat.label,
            style:
                const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _formatCents(stat.cents),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: stat.valueColor,
              letterSpacing: -0.3,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCents(int cents) {
    final neg = cents < 0;
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final grouped = _groupThousands(yuan);
    return '${neg ? '-' : ''}¥ $grouped.$fen';
  }

  String _groupThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ───────────────────────── 图表 section（DataCard 包标题 + child） ─────────

/// 单个图表 section：DataCard 包标题 + 分隔线 + 任意 chart widget。
class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

// ───────────────────────── 三态：错误/空（带重试） ────────────────────────

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.muted.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
