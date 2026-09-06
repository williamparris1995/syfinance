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
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// 报表分析页（sidebar「工具 › 报表分析」）。
///
/// 顶层路由 /reports（StatefulShellRoute 之外，与 /login /register 同级），
/// 故无 shell sidebar/topbar —— 本页自带顶栏（返回 chevronLeft + 标题 +
/// 日期选择按钮 + 月/年 period segmented）。body 用 FutureBuilder 拉
/// [TransactionRepository.summary]（[MonthlySummary]：income/expense/net/
/// dailyAvg + byDay + byCategory），为 Task 3 三图表预留 section 占位：
///   1. 收支趋势（LineChart，byDay）   — 占位「趋势图待实现」
///   2. 分类占比（PieChart，byCategory）— 占位「分类图待实现」
///   3. 月度对比（BarChart，多月）      — 占位「对比图待实现」
///
/// period 切换：[SummaryScope.month]（默认，按日聚合当月）↔
/// [SummaryScope.year]（按月聚合当年）。切换时重建 Future 重新拉取。
///
/// **历史日期切换**（P0-2）：[_selectedDate]（默认 `DateTime.now()`）作为
/// summary 与近 6 月对比的「锚点」月份/年份。顶栏日期按钮触发
/// [showDatePicker]：month scope 取年月（日忽略 → `'YYYY 年 M 月'`）；
/// year scope 以 [DatePickerMode.year] 起步（取年 → `'YYYY 年'`）。选日期后
/// 同时重载 summary 与月度对比，让两图对齐到同一锚点。
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  SummaryScope _scope = SummaryScope.month;
  /// 当前选中的「锚点」日期。月 scope 只用年月;年 scope 只用年。
  /// 默认 `DateTime.now()`(当月/当年),用户可通过顶栏 picker 切到历史。
  DateTime _selectedDate = DateTime.now();
  /// 标签口径筛选(F8 FR-4/ADR-5):null = 全部(现状);非 null → summary
  /// 聚合仅含带该标签的交易(T1 管道聚合前按 junction 关联集过滤)。
  String? _selectedTagId;
  late Future<Either<Failure, MonthlySummary>> _future;
  /// 近 6 月月度对比数据(锚点月份 `_selectedDate` 往前 6 个月)。
  late Future<List<MonthlySummary>> _monthlyComparison;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _monthlyComparison = _loadMonthlyComparison();
  }

  Future<Either<Failure, MonthlySummary>> _load() {
    return getIt<TransactionRepository>().summary(_selectedDate.year,
        _selectedDate.month,
        scope: _scope, tagId: _selectedTagId);
  }

  /// 并发拉取以 [_selectedDate] 为终点的近 6 个月 summary(month scope)。
  /// 各月独立 Either;任一失败折叠为跳过(drop),全失败 → 空列表 →
  /// 月度对比 chart 自身空态。tagId(F8 FR-4)随锚月同口径透传,两图不脱节。
  Future<List<MonthlySummary>> _loadMonthlyComparison() async {
    final futures = <Future<Either<Failure, MonthlySummary>>>[];
    for (var i = 5; i >= 0; i--) {
      // DateTime(y, m-i) 自动处理跨年（month<=0 → 前一年 12 月等）。
      final d = DateTime(_selectedDate.year, _selectedDate.month - i);
      futures.add(getIt<TransactionRepository>().summary(d.year, d.month,
          scope: SummaryScope.month, tagId: _selectedTagId));
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

  /// F8 FR-4/ADR-5:标签筛选变化 → summary 与近 6 月对比一起重查(锚点日期
  /// 不动,只换口径)。同值不重查(避免空刷新)。「全部」(null)= 现状零变化。
  void _setTag(String? tagId) {
    if (tagId == _selectedTagId) return;
    setState(() {
      _selectedTagId = tagId;
      _future = _load();
      _monthlyComparison = _loadMonthlyComparison();
    });
  }

  /// 弹出 date picker 让用户选历史日期。month scope 默认日历模式（取年月,
  /// 日忽略）;year scope 以 year 模式起步（取年）。pick 到与当前相同的日期
  /// 不重载（避免空刷新）。`lastDate = now` 禁选未来（报表无未来数据）。
  Future<void> _pickDate() async {
    final today = DateTime.now();
    // 防 initialDate > lastDate 边界（_selectedDate 可能晚于 today 几毫秒）。
    final initial =
        _selectedDate.isAfter(today) ? today : _selectedDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: today,
      initialDatePickerMode: _scope == SummaryScope.year
          ? DatePickerMode.year
          : DatePickerMode.day,
      helpText: _scope == SummaryScope.year ? '选择年份' : '选择月份',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _future = _load();
        _monthlyComparison = _loadMonthlyComparison();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: Column(
        children: [
          _ReportTopBar(
            scope: _scope,
            selectedDate: _selectedDate,
            // F8 FR-4/ADR-5:头部标签下拉(复用 ADR-3 TxnTagPicker)。boundRemote
            // 态整体不挂载(交付物 4:外层定宽 SizedBox 一并条件化,控件自身
            // 也兜底自隐藏,避免空白占位)。
            tagPicker: tagFilterAvailable()
                ? SizedBox(
                    width: 170,
                    child: TxnTagPicker(
                        value: _selectedTagId, onChanged: _setTag),
                  )
                : null,
            onScopeChanged: _switchScope,
            onPickDate: _pickDate,
            onBack: () => context.go('/home'),
          ),
          Divider(height: 1, color: context.yucai.border),
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
          return Center(
            child: CircularProgressIndicator(color: context.yucai.muted),
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
                      return SizedBox(
                        height: 220,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: context.yucai.muted),
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

// ───────────────────────── 顶栏（返回 + 标题 + 日期按钮 + period segmented）

class _ReportTopBar extends StatelessWidget {
  const _ReportTopBar({
    required this.scope,
    required this.selectedDate,
    required this.onScopeChanged,
    required this.onPickDate,
    required this.onBack,
    this.tagPicker,
  });

  final SummaryScope scope;
  final DateTime selectedDate;
  final ValueChanged<SummaryScope> onScopeChanged;
  final VoidCallback onPickDate;
  final VoidCallback onBack;

  /// 标签筛选下拉槽位(F8 FR-4;null = boundRemote 态隐藏,不占位)。
  final Widget? tagPicker;

  /// 日期按钮文案。month scope → `'YYYY 年 M 月'`;year scope → `'YYYY 年'`。
  String get _dateLabel => scope == SummaryScope.year
      ? '${selectedDate.year} 年'
      : '${selectedDate.year} 年 ${selectedDate.month} 月';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      // 对齐 shell _TopBar 底色（OD .topbar rgba(247,246,242,.85)）。
      color: context.yucai.bg.withValues(alpha: 0.85),
      child: Row(children: [
        IconButton(
          tooltip: '返回',
          icon: Icon(LucideIcons.chevronLeft,
              size: 20, color: context.yucai.fg),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: context.yucai.accentSoft.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
          ),
          onPressed: onBack,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '报表分析',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.yucai.fg,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
          ),
        ),
        const Spacer(),
        // 标签口径筛选(F8 FR-4):置于日期按钮左侧,与日期/period 同属
        // 「口径」控件组。null(boundRemote 隐藏)时整体不渲染。
        if (tagPicker != null) ...[
          tagPicker!,
          const SizedBox(width: AppSpacing.sm),
        ],
        _DateButton(
          key: const ValueKey('reportDateButton'),
          label: _dateLabel,
          onTap: onPickDate,
        ),
        const SizedBox(width: AppSpacing.sm),
        _PeriodSegmented(scope: scope, onChanged: onScopeChanged),
      ]),
    );
  }
}

/// 顶栏日期选择按钮：日历图标 + 当前选中日期文案 + 下拉箭头，点击触发
/// [onTap]（页面弹 showDatePicker）。对齐 [_PeriodSegmented] 的 pill 风格
/// （surface 底 + border + sm 圆角）以读作同一组控件。
class _DateButton extends StatelessWidget {
  const _DateButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '选择日期',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.yucai.surface,
              borderRadius: AppRadius.smBorder,
              border: Border.all(color: context.yucai.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.calendar,
                    size: 14, color: context.yucai.muted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.yucai.fg,
                    )),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown,
                    size: 14, color: context.yucai.muted),
              ],
            ),
          ),
        ),
      ),
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
        color: context.yucai.bg,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, '月', scope == SummaryScope.month,
              () => onChanged(SummaryScope.month)),
          _segment(context, '年', scope == SummaryScope.year,
              () => onChanged(SummaryScope.year)),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? context.yucai.accent : Colors.transparent,
            borderRadius: AppRadius.smBorder,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              // 选中字 = onAccent(亮=白 / 暗=鎏金深墨,随 accent 双板)。
              color: selected ? context.yucai.onAccent : context.yucai.muted,
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
              style: TextStyle(
                  color: context.yucai.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 620;
            final stats = <_Stat>[
              _Stat('收入', summary.incomeCents, context.yucai.positive),
              _Stat('支出', summary.expenseCents, context.yucai.negative),
              _Stat(
                  '结余', summary.netCents, _netColor(context, summary.netCents)),
              _Stat('日均', summary.dailyAvgCents, context.yucai.fg),
            ];
            if (wide) {
              return Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(child: _StatTile(stat: stats[i])),
                    if (i < stats.length - 1)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                            height: 32,
                            child: VerticalDivider(
                                width: 1, color: context.yucai.border)),
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

  Color _netColor(BuildContext context, int cents) =>
      cents >= 0 ? context.yucai.positive : context.yucai.negative;
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
                TextStyle(color: context.yucai.muted, fontSize: 12)),
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
          Divider(height: 1, color: context.yucai.border),
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
          Icon(icon, size: 32, color: context.yucai.muted.withValues(alpha: 0.6)),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: TextStyle(color: context.yucai.muted)),
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
