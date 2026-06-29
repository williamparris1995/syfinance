// 收益曲线(fl_chart 1.x LineChart)。Task 8 详情页 + Task 9 统计页 复用。
//
// 对齐 A-od `holding-detail-*.html` `.curve-card`:
//   head (近 N 天/月/年 + 日/月/年 range-tabs) + body (SVG 折线 + 渐变面积 +
//   首末轴标) + foot (浮动/已实现/总收益 swatch)。
//
// fl_chart 1.x API(与 holding_sparkline.dart 一致,**非 0.69**):
//   LineChartData(lineBarsData, titlesData(FlTitlesData 全关), gridData(关),
//   borderData(关), lineTouchData, clipData, minX/maxX/minY/maxY)。
//   LineChartBarData(spots, color: 单色 **非 colors**, isCurved, barWidth,
//   dotData: FlDotData(show:false), belowBarData: BarAreaData(show:true,color:))。
//   withValues(alpha:) **非** withOpacity。公开类 `LineChart`(非 LineChartWidget)。
//
// ⏳ proto 无 price history RPC:曲线数据由调用方传入(holding_detail_page 从
// trades 前端重建成本基础曲线;Task 9 接 ⏳C snapshot)。空 spots → 空态
// 「⏳ 行情快照待后端」,对齐 brief 降级策略。
//
// 复用接口(Task 9 performance_page 直接消费):
//   - [PerfRange] 区间枚举(day/month/year) + label/rangeSub 文案。
//   - [PerfPoint] 数据点(DateTime + 数值,任意单位;调用方负责聚合/折算)。
//   - [PerfCurveChart] widget:接收 points / range / optional foot(盈亏明细)。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

/// 收益曲线区间(日/月/年)。对齐 A-od range-tabs。
enum PerfRange {
  /// 近 30 天(日线)。
  day,
  /// 近 12 月(月线)。
  month,
  /// 近 5 年(年线)。
  year;

  /// tab 短标签(对齐 A-od "日/月/年")。
  String get label {
    switch (this) {
      case PerfRange.day:
        return '日';
      case PerfRange.month:
        return '月';
      case PerfRange.year:
        return '年';
    }
  }

  /// 区间副文案(对齐 A-od ch-sub "近 30 天/近 12 月/近 5 年")。
  String get rangeSub {
    switch (this) {
      case PerfRange.day:
        return '近 30 天';
      case PerfRange.month:
        return '近 12 月';
      case PerfRange.year:
        return '近 5 年';
    }
  }
}

/// 单个曲线数据点。value 任意单位(价格/市值/累计收益,由调用方决定);
/// time 用于排序与首末轴标显示。
class PerfPoint {
  const PerfPoint({required this.time, required this.value});
  final DateTime time;
  final double value;

  @override
  bool operator ==(Object other) =>
      other is PerfPoint && time == other.time && value == other.value;
  @override
  int get hashCode => Object.hash(time, value);
}

/// 曲线脚注盈亏明细(对齐 A-od curve-foot:浮动/已实现/总收益)。
/// 调用方计算后传入;null 项不渲染该 cell。
class PerfCurveFoot {
  const PerfCurveFoot({
    this.unrealizedCents,
    this.realizedCents,
    this.totalCents,
    this.currency = 'CNY',
  });
  final int? unrealizedCents; // 浮动盈亏(分,可负)
  final int? realizedCents; // 已实现(分)
  final int? totalCents; // 总收益(分)
  final String currency;
}

/// 收益曲线 widget。
///
/// [points] 已按时间升序(调用方负责);内部按 value 归一化到 [0,1] 后绘制
/// (与 holding_sparkline 同策略,保证跨标的视觉可比)。少于 2 点 → 空态。
/// [onRangeChange] 区间 tab 切换回调(详情页内联切换 + Task 9 复用)。
class PerfCurveChart extends StatelessWidget {
  const PerfCurveChart({
    super.key,
    required this.points,
    this.range = PerfRange.day,
    this.foot,
    this.onRangeChange,
    this.height = 168,
    this.emptyHint = '⏳ 行情快照待后端',
  });

  final List<PerfPoint> points;
  final PerfRange range;
  final PerfCurveFoot? foot;
  final ValueChanged<PerfRange>? onRangeChange;
  final double height;
  /// 空态提示文案(默认 ⏳ 降级,Task 9 可覆盖)。
  final String emptyHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: points.length < 2 ? _empty() : _chart(),
        ),
        if (foot != null) ...[
          const SizedBox(height: 12),
          _foot(),
        ],
      ],
    );
  }

  // ───────────────────────── head ─────────────────────────

  Widget _head() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '收益曲线',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
              ),
            ),
            const SizedBox(height: 2),
            Text(range.rangeSub,
                style: const TextStyle(
                    fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
        _rangeTabs(),
      ],
    );
  }

  /// 日/月/年 segmented(对齐 A-od range-tabs)。
  Widget _rangeTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECE5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in PerfRange.values) _rangeTab(r),
        ],
      ),
    );
  }

  Widget _rangeTab(PerfRange r) {
    final active = r == range;
    final onTap = onRangeChange;
    return InkWell(
      key: ValueKey('perfRange-${r.name}'),
      onTap: onTap == null ? null : () => onTap(r),
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active
              ? const [
                  BoxShadow(
                      color: Color(0x0F1C1E21),
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ]
              : const [],
        ),
        child: Text(
          r.label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.accentHover : const Color(0xFF54585F),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── chart ─────────────────────────

  /// 涨跌色:末值 >= 首值 → 盈绿;否则亏红(对齐 A-od curve.up ? up : down)。
  bool get _up {
    if (points.length < 2) return true;
    return points.last.value >= points.first.value;
  }

  Widget _chart() {
    final color = _up ? AppColors.positive : AppColors.negative;
    final spots = _spots();
    return LineChart(
      LineChartData(
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        minX: 0,
        maxX: (spots.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: 1,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 1.8,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }

  /// points → 归一化 [0,1] FlSpot(x=索引)。全相等退化为 0.5 平线(避免除零)。
  List<FlSpot> _spots() {
    if (points.length <= 1) {
      return const [FlSpot(0, 0.5), FlSpot(1, 0.5)];
    }
    final vals = points.map((p) => p.value).toList(growable: false);
    final min = vals.reduce((a, b) => a < b ? a : b);
    final max = vals.reduce((a, b) => a > b ? a : b);
    final span = max - min;
    return [
      for (var i = 0; i < vals.length; i++)
        FlSpot(i.toDouble(), span == 0 ? 0.5 : (vals[i] - min) / span),
    ];
  }

  // ───────────────────────── empty ─────────────────────────

  /// 空态:⏳ 行情快照待后端(对齐 A-od trades-empty + brief 降级)。
  Widget _empty() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.trendingUp, size: 22, color: AppColors.muted),
            const SizedBox(height: 6),
            Text(emptyHint,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 2),
            const Text('该证券尚未接入行情源',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── foot ─────────────────────────

  /// foot:浮动(绿/红) / 已实现(金) / 总收益(绿/红)(对齐 A-od curve-foot)。
  Widget _foot() {
    final f = foot!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAF6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (f.unrealizedCents != null)
            Expanded(
              child: _footCell(
                label: '浮动',
                swatch: AppColors.positive,
                value: _fmtSigned(f.unrealizedCents!, f.currency),
                valueColor: f.unrealizedCents! >= 0
                    ? AppColors.positive
                    : AppColors.negative,
              ),
            ),
          if (f.realizedCents != null)
            Expanded(
              child: _footCell(
                label: '已实现',
                swatch: AppColors.accent,
                value: _fmtRaw(f.realizedCents!, f.currency),
              ),
            ),
          if (f.totalCents != null)
            Expanded(
              child: _footCell(
                label: '总收益',
                swatch: AppColors.fg,
                value: _fmtSigned(f.totalCents!, f.currency),
                valueColor: f.totalCents! >= 0
                    ? AppColors.positive
                    : AppColors.negative,
              ),
            ),
        ],
      ),
    );
  }

  Widget _footCell({
    required String label,
    required Color swatch,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.muted)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.fg,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

/// 千分位 + 货币符号 + 2 位小数(无符号,对齐 A-od fmtRaw)。
String _fmtRaw(int cents, String currency) {
  return '${currencySymbol(currency)}${_grouped(cents)}.${(cents.abs() % 100).toString().padLeft(2, '0')}';
}

/// 带符号金额(对齐 A-od fmtSigned):盈 + / 亏 -。
String _fmtSigned(int cents, String currency) {
  final sign = cents < 0 ? '-' : '+';
  return '$sign${_fmtRaw(cents.abs(), currency)}';
}

/// 整数元部分加千分位。
String _grouped(int cents) {
  final yuan = cents.abs() ~/ 100;
  final s = yuan.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
