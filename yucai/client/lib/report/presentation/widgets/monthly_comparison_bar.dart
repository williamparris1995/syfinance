// 月度对比（fl_chart 1.x BarChart，本仓库首次使用）。报表分析页 §3。
//
// 数据：近 N（默认 6）个月 [MonthlySummary] 的 incomeCents / expenseCents，
// 每月两根并排柱：收入(绿 context.yucai.positive) + 支出(红 context.yucai.negative)。
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
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';
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
          _legend(context),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(height: height, child: _empty(context)),
        ],
      );
    }
    final maxY = niceMax([
      for (final m in months) m.incomeCents.toDouble() / 100,
      for (final m in months) m.expenseCents.toDouble() / 100,
    ]);
    final yInterval = (maxY / 4).clamp(1.0, double.infinity).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _legend(context),
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
                  color: context.yucai.border.withValues(alpha: 0.7),
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
                    getTitlesWidget: (value, meta) =>
                        _bottomTitle(context, value),
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) => _leftTitle(context, value),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  // F4-P2 豁免:tooltip 为固定深色面(两主题一致,原 v1
                  // sidebar 墨色),配固定浅灰字可辨识不刺眼,不随主题迁。
                  getTooltipColor: (_) => const Color(0xFF0E1219),
                  getTooltipItem: (group, gi, rod, ri) =>
                      _tooltipItem(context, group, ri),
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
                      _rod(months[i].incomeCents / 100,
                          context.yucai.positive),
                      _rod(months[i].expenseCents / 100,
                          context.yucai.negative),
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

  Widget _bottomTitle(BuildContext context, double value) {
    final idx = value.round();
    if (idx < 0 || idx >= months.length) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('${months[idx].month}月',
          style: TextStyle(
              fontSize: 10.5, color: context.yucai.muted)),
    );
  }

  Widget _leftTitle(BuildContext context, double value) {
    if (value <= 0) return const SizedBox.shrink();
    return Text(compactYuan(value),
        style: TextStyle(
            fontSize: 10.5,
            color: context.yucai.muted,
            fontFeatures: AppTypography.tabularFigures));
  }

  BarTooltipItem _tooltipItem(
      BuildContext context, BarChartGroupData group, int rodIndex) {
    final idx = group.x;
    if (idx < 0 || idx >= months.length) {
      return BarTooltipItem('', const TextStyle());
    }
    final m = months[idx];
    final isIncome = rodIndex == 0;
    final cents = isIncome ? m.incomeCents : m.expenseCents;
    final color = isIncome ? context.yucai.positive : context.yucai.negative;
    return BarTooltipItem(
      '${m.month}月  ',
      // tooltip 固定深色面上的固定浅灰字(见 build 豁免注释)。
      const TextStyle(color: Color(0xFFB8B5AD), fontSize: 11),
      children: [
        TextSpan(
          text: '${isIncome ? '收入' : '支出'}  ¥${fmtYuan(cents / 100)}',
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

  Widget _legend(BuildContext context) {
    return Row(
      children: [
        LegendDot(color: context.yucai.positive, label: '收入'),
        const SizedBox(width: AppSpacing.md),
        LegendDot(color: context.yucai.negative, label: '支出'),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        borderRadius: AppRadius.smBorder,
        border:
            Border.all(color: context.yucai.border.withValues(alpha: 0.7)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.barChart3,
                size: 22, color: context.yucai.muted),
            const SizedBox(height: 6),
            Text('暂无月度数据',
                style: TextStyle(
                    fontSize: 12.5, color: context.yucai.muted)),
          ],
        ),
      ),
    );
  }
}
