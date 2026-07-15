// 收支趋势（fl_chart 1.x LineChart）。报表分析页 §1。
//
// 数据：[MonthlySummary.byDay] → 逐日收入/支出双折线。
//   - 收入(绿 AppColors.positive) + 支出(红 AppColors.negative)，
//     颜色沿用 app 既有语义（与 _SummaryStrip / 交易列表一致），非任意配色。
//   - 逐日金额由 byDay[].byCategory 按 accountType("income"/"expense") 拆分；
//     income 缺失时回退 DailySummary.totalIncomeCents（服务端 denormalized）。
//
// fl_chart 1.x API（对齐 perf_curve_chart.dart，**非 0.69**）：
//   LineChartData(lineBarsData, titlesData(FlTitlesData)，gridData，borderData，
//   lineTouchData，minX/maxX/minY/maxY)。
//   LineChartBarData(spots, color 单色，isCurved，barWidth，dotData，belowBarData)。
//   withValues(alpha:) **非** withOpacity。公开类 `LineChart`。
//
// 可访问性：≥2 series 必带图例（颜色 + 文字），非仅靠颜色辨识（CVD）。
// X 轴 = 日期序号（month scope→日；year scope→月），Y 轴 = 实际元值（非归一化），
// 与 perf_curve_chart 的跨标的归一化不同——报表需读真实金额。
// 空态：byDay < 2 或全零 → 居中提示。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 收支趋势折线图。逐日收入 + 支出双线。
///
/// [byDay] 已按日期升序（服务端返回顺序）。[scope] 决定 X 轴标签
/// （month→日号；year→月份）。少于 2 个数据点或全零 → [empty] 空态。
class IncomeExpenseTrendChart extends StatelessWidget {
  const IncomeExpenseTrendChart({
    super.key,
    required this.byDay,
    this.scope = SummaryScope.month,
    this.height = 220,
  });

  final List<DailySummary> byDay;
  final SummaryScope scope;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints();
    final hasData = points.length >= 2 && points.any((p) => p.income + p.expense > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _legend(),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: height,
          child: hasData ? _chart(points) : _empty(),
        ),
      ],
    );
  }

  // ───────────────────────── 数据组装 ─────────────────────────

  List<_DayPoint> _buildPoints() {
    return [
      for (final d in byDay)
        _DayPoint(
          date: _tryParse(d.date),
          income: _incomeOf(d),
          expense: _expenseOf(d),
        ),
    ];
  }

  /// 逐日收入：优先由 byCategory 聚合（与支出同源，保持一致）；
  /// byCategory 无 income 项时回退 denormalized totalIncomeCents。
  int _incomeOf(DailySummary d) {
    var inc = 0;
    for (final c in d.byCategory) {
      if (c.accountType.toLowerCase() == 'income') inc += c.amountCents;
    }
    if (inc == 0 && d.totalIncomeCents > 0) return d.totalIncomeCents;
    return inc;
  }

  /// 逐日支出：byCategory 中 accountType == expense 之和。
  int _expenseOf(DailySummary d) {
    var exp = 0;
    for (final c in d.byCategory) {
      if (c.accountType.toLowerCase() == 'expense') exp += c.amountCents;
    }
    return exp;
  }

  DateTime? _tryParse(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  // ───────────────────────── 图例 ─────────────────────────

  Widget _legend() {
    return const Row(
      children: [
        _LegendDot(color: AppColors.positive, label: '收入'),
        SizedBox(width: AppSpacing.md),
        _LegendDot(color: AppColors.negative, label: '支出'),
      ],
    );
  }

  // ───────────────────────── chart ─────────────────────────

  Widget _chart(List<_DayPoint> points) {
    final maxY = _niceMax([
      for (final p in points) p.income.toDouble() / 100,
      for (final p in points) p.expense.toDouble() / 100,
    ]);
    final yInterval = (maxY / 4).clamp(1.0, double.infinity).toDouble();
    final incomeSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].income / 100),
    ];
    final expenseSpots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].expense / 100),
    ];
    final xStep = _xLabelStep(points.length);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.border.withValues(alpha: 0.7),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: xStep.toDouble(),
              getTitlesWidget: (value, meta) =>
                  _bottomTitle(value, points),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: yInterval,
              getTitlesWidget: (value, meta) => _leftTitle(value),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.sidebar,
            getTooltipItems: (touched) => _tooltipItems(touched, points),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
          ),
        ),
        lineBarsData: [
          _line(incomeSpots, AppColors.positive),
          _line(expenseSpots, AppColors.negative),
        ],
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.10),
      ),
    );
  }

  // ───────────────────────── 轴标题 ─────────────────────────

  Widget _bottomTitle(double value, List<_DayPoint> points) {
    final idx = value.round();
    if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
    // 稀疏化：仅首点、末点及 step 倍数处显示，避免拥挤。
    final step = _xLabelStep(points.length);
    final isEdge = idx == 0 || idx == points.length - 1;
    if (!isEdge && step > 1 && idx % step != 0) {
      return const SizedBox.shrink();
    }
    final dt = points[idx].date;
    final label = dt == null
        ? '${idx + 1}'
        : (scope == SummaryScope.year
            ? '${dt.month}月'
            : '${dt.day}');
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10.5, color: AppColors.muted)),
    );
  }

  Widget _leftTitle(double value) {
    if (value <= 0) return const SizedBox.shrink();
    return Text(_compactYuan(value),
        style: const TextStyle(
            fontSize: 10.5,
            color: AppColors.muted,
            fontFeatures: AppTypography.tabularFigures));
  }

  List<LineTooltipItem> _tooltipItems(
      List<LineBarSpot> touched, List<_DayPoint> points) {
    if (touched.isEmpty) return const [];
    final idx = touched.first.spotIndex;
    String head;
    if (idx >= 0 && idx < points.length) {
      final dt = points[idx].date;
      head = dt == null ? '' : _dateLabel(dt);
    } else {
      head = '';
    }
    return [
      LineTooltipItem(
        '$head\n',
        const TextStyle(color: AppColors.sidebarFg, fontSize: 11),
        children: [
          for (final spot in touched) ...[
            TextSpan(
              text: spot.barIndex == 0 ? '收入 ' : '支出 ',
              style: TextStyle(
                color: spot.barIndex == 0
                    ? AppColors.positive
                    : AppColors.negative,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '¥${_fmtYuan(spot.y)}\n',
              style: const TextStyle(
                  color: AppColors.sidebarFg,
                  fontSize: 11,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ],
        ],
      ),
    ];
  }

  String _dateLabel(DateTime dt) {
    return scope == SummaryScope.year
        ? '${dt.month}月'
        : '${dt.month}/${dt.day}';
  }

  // ───────────────────────── 空态 ─────────────────────────

  Widget _empty() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.trendingUp, size: 22, color: AppColors.muted),
            SizedBox(height: 6),
            Text('所选区间暂无收支记录',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

class _DayPoint {
  const _DayPoint({this.date, required this.income, required this.expense});
  final DateTime? date;
  final int income; // 分
  final int expense; // 分
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.fg)),
      ],
    );
  }
}

/// X 轴标签稀疏步长（≤7 点全显；否则约 6 个标签）。
int _xLabelStep(int count) {
  if (count <= 7) return 1;
  return (count / 6).ceil();
}

/// 取数据最大值并向上取整到「好看」的刻度（1/2/5 × 10^n）。
double _niceMax(List<double> vals) {
  final max = vals.isEmpty || vals.reduce((a, b) => a > b ? a : b) <= 0
      ? 100.0
      : vals.reduce((a, b) => a > b ? a : b);
  if (max <= 0) return 100;
  final pow = mathPow10(max);
  final n = max / pow;
  final nice = n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10));
  return nice * pow;
}

double mathPow10(double v) {
  var p = 1.0;
  while (p * 10 <= v) {
    p *= 10;
  }
  return p;
}

/// Y 轴 / tooltip 紧凑金额（元）：<10000 直显千分位；≥10000 用「万」。
String _compactYuan(double yuan) {
  if (yuan >= 10000) {
    final wan = yuan / 10000;
    return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)}万';
  }
  return _groupInt(yuan.round());
}

String _fmtYuan(double yuan) {
  if (yuan >= 10000) {
    final wan = yuan / 10000;
    return '${wan.toStringAsFixed(2)}万';
  }
  return '${_groupInt(yuan.round())}.${((yuan * 100) % 100).round().toString().padLeft(2, '0')}';
}

String _groupInt(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
