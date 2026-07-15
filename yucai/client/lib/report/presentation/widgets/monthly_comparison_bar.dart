// 月度对比（fl_chart 1.x BarChart，本仓库首次使用）。报表分析页 §3。
//
// 数据：近 N（默认 6）个月 [MonthlySummary] 的 incomeCents / expenseCents，
// 每月两根并排柱：收入(绿 AppColors.positive) + 支出(红 AppColors.negative)。
// 数据由 ReportPage 调用方并发拉取（Future.wait N 次 summary RPC）后传入。
//
// fl_chart 1.x BarChart API：
//   BarChartData(barGroups, alignment, groupsSpace, titlesData(FlTitlesData),
//     gridData, borderData, minY/maxY, barTouchData)。
//   BarChartGroupData(x:int, barRods:List<BarChartRodData>, barsSpace)。
//   BarChartRodData(toY, color, width, borderRadius)。
//   注意 FlTitlesData 用 leftTitles/topTitles/rightTitles/bottomTitles（带 Titles 后缀）。
//
// 可访问性：≥2 series 必带图例；颜色沿用 app 收入/支出语义（与 _SummaryStrip 一致）。
// X 轴 = 月份序号 → "${month}月" 标签；Y 轴 = 实际元值。空态：months 为空。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 月度对比柱状图。每月收入 + 支出两根并排柱。
///
/// [months] 已按时间升序（oldest → newest），调用方负责拉取与排序。
/// 空列表 → 空态提示。
class MonthlyComparisonBar extends StatelessWidget {
  const MonthlyComparisonBar({
    super.key,
    required this.months,
    this.height = 220,
  });

  final List<MonthlySummary> months;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _legend(),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(height: height, child: _empty()),
        ],
      );
    }
    final maxY = _niceMax([
      for (final m in months) m.incomeCents.toDouble() / 100,
      for (final m in months) m.expenseCents.toDouble() / 100,
    ]);
    final yInterval = (maxY / 4).clamp(1.0, double.infinity).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _legend(),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceEvenly,
              groupsSpace: 18,
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
                    getTitlesWidget: (value, meta) => _bottomTitle(value),
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
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppColors.sidebar,
                  getTooltipItem: (group, gi, rod, ri) => _tooltipItem(group, ri),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                ),
              ),
              barGroups: [
                for (var i = 0; i < months.length; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 2,
                    barRods: [
                      _rod(months[i].incomeCents / 100, AppColors.positive),
                      _rod(months[i].expenseCents / 100, AppColors.negative),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BarChartRodData _rod(double yuan, Color color) {
    return BarChartRodData(
      toY: yuan,
      color: color,
      width: 12,
      borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(3), topRight: Radius.circular(3)),
    );
  }

  // ───────────────────────── 轴标题 ─────────────────────────

  Widget _bottomTitle(double value) {
    final idx = value.round();
    if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('${months[idx].month}月',
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

  BarTooltipItem _tooltipItem(BarChartGroupData group, int rodIndex) {
    final idx = group.x;
    if (idx < 0 || idx >= months.length) {
      return BarTooltipItem('', const TextStyle());
    }
    final m = months[idx];
    final isIncome = rodIndex == 0;
    final cents = isIncome ? m.incomeCents : m.expenseCents;
    final color = isIncome ? AppColors.positive : AppColors.negative;
    return BarTooltipItem(
      '${m.month}月  ',
      const TextStyle(color: AppColors.sidebarFg, fontSize: 11),
      children: [
        TextSpan(
          text: '${isIncome ? '收入' : '支出'}  ¥${_fmtYuan(cents / 100)}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── 图例 / 空态 ─────────────────────────

  Widget _legend() {
    return const Row(
      children: [
        _LegendDot(color: AppColors.positive, label: '收入'),
        SizedBox(width: AppSpacing.md),
        _LegendDot(color: AppColors.negative, label: '支出'),
      ],
    );
  }

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
            Icon(LucideIcons.barChart3, size: 22, color: AppColors.muted),
            SizedBox(height: 6),
            Text('暂无月度数据',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

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

/// 向上取整到 1/2/5 × 10^n 的好看刻度。
double _niceMax(List<double> vals) {
  final max = vals.isEmpty || vals.reduce((a, b) => a > b ? a : b) <= 0
      ? 100.0
      : vals.reduce((a, b) => a > b ? a : b);
  if (max <= 0) return 100;
  final pow = _pow10(max);
  final n = max / pow;
  final nice = n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 5 ? 5 : 10));
  return nice * pow;
}

double _pow10(double v) {
  var p = 1.0;
  while (p * 10 <= v) {
    p *= 10;
  }
  return p;
}

String _compactYuan(double yuan) {
  if (yuan >= 10000) {
    final wan = yuan / 10000;
    return '${wan.toStringAsFixed(wan >= 100 ? 0 : 1)}万';
  }
  return _groupInt(yuan.round());
}

String _fmtYuan(double yuan) {
  if (yuan >= 10000) {
    return '${(yuan / 10000).toStringAsFixed(2)}万';
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
