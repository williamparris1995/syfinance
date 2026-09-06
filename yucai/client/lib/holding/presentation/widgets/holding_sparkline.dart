// 持仓迷你走势线(fl_chart 1.x LineChart)。
//
// 对齐 A-od holdings-mobile.html `.acc-spark`(sparkSVG):无轴、无网格、无 tooltip
// 的迷你曲线,盈绿(context.yucai.positive) / 亏红(context.yucai.negative)。
//
// fl_chart 1.x API(非 0.69):LineChartBarData(spots, color, ...) 接收 List<FlSpot>;
// LineChartData(lineBarsData, titlesData/gridData/borderData 全关 + clipData + minX/maxX/minY/maxY)。
// 原型 mock 的 sparkline 是固定采样点数组;此处 points 为相对走势(单位无关),
// 自动按 min/max 归一化到 [0,1] 后绘制,保证不同标的视觉可比。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 迷你走势 sparkline(无轴)。points 为历史采样(原始数值,任意单位);
/// 内部归一化。少于 2 个点时退化为一根直线(避免 fl_chart 单点报错)。
class HoldingSparkline extends StatelessWidget {
  const HoldingSparkline({
    super.key,
    required this.points,
    required this.up,
    this.width = 96,
    this.height = 30,
  });

  final List<double> points; // 历史采样(首=最早)
  final bool up; // true=盈绿 / false=亏红
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = up ? context.yucai.positive : context.yucai.negative;
    return SizedBox(
      width: width,
      height: height,
      child: LineChart(
        LineChartData(
          // 全关:无标题 / 无网格 / 无边框 / 无触摸。
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          clipData: const FlClipData.all(),
          minX: 0,
          maxX: (_spots().length - 1).toDouble().clamp(0, double.infinity),
          minY: 0,
          maxY: 1,
          lineBarsData: [
            LineChartBarData(
              spots: _spots(),
              isCurved: true,
              color: color,
              barWidth: 1.6,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  /// points → 归一化 [0,1] 的 FlSpot 列(x=索引)。
  /// 全相等(平线)时归一到 0.5 中位,避免除零。
  List<FlSpot> _spots() {
    if (points.length <= 1) {
      // 单点/空:退化为两端平线(0.5,0.5)。
      return const [FlSpot(0, 0.5), FlSpot(1, 0.5)];
    }
    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final span = max - min;
    return [
      for (var i = 0; i < points.length; i++)
        FlSpot(
          i.toDouble(),
          span == 0 ? 0.5 : (points[i] - min) / span,
        ),
    ];
  }
}
