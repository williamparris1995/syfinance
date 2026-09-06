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
/// [points] 已按时间升序(调用方负责);内部按 value **rebase 100**(起点=100,
/// 相对增长)后绘制 —— 量纲归一化:portfolio 元 vs benchmark 点位 rebase 后斜率
/// 可比(同一起点对比相对增长,而非 min-max 自归一)。少于 2 点 → 空态。
/// [benchmarkPoints] 可选基准(如 CSI300)曲线,非空时绘制第二线(灰虚线),
/// 并渲染图例(组合/基准名);[benchmarkName] 基准名(默认「沪深300」)。
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
    this.benchmarkPoints = const [],
    this.benchmarkName = '沪深300',
  });

  final List<PerfPoint> points;
  final PerfRange range;
  final PerfCurveFoot? foot;
  final ValueChanged<PerfRange>? onRangeChange;
  final double height;
  /// 空态提示文案(默认 ⏳ 降级,Task 9 可覆盖)。
  final String emptyHint;
  /// 可选基准曲线点(如 CSI300)。length >= 2 才绘制第二线 + 图例;< 2 视为无基准。
  final List<PerfPoint> benchmarkPoints;
  /// 基准名(图例「┄ {benchmarkName}」)。默认「沪深300」。
  final String benchmarkName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context),
        if (_hasBenchmark) ...[
          const SizedBox(height: 8),
          _legend(context),
        ],
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          child: points.length < 2 ? _empty(context) : _chart(context),
        ),
        if (foot != null) ...[
          const SizedBox(height: 12),
          _foot(context),
        ],
      ],
    );
  }

  /// 是否渲染基准线 + 图例(benchmarkPoints >= 2;1 点 _rebase100 退化为平线无意义)。
  bool get _hasBenchmark => benchmarkPoints.length >= 2;

  // ───────────────────────── head ─────────────────────────

  Widget _head(BuildContext context) {
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
                style: TextStyle(
                    fontSize: 11.5, color: context.yucai.muted)),
          ],
        ),
        _rangeTabs(context),
      ],
    );
  }

  /// 日/月/年 segmented(对齐 A-od range-tabs)。
  Widget _rangeTabs(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        // 原 v1 米白 #EFECE5 轨道底 → surfaceAlt(暗色随卡面浅一档)。
        color: context.yucai.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in PerfRange.values) _rangeTab(context, r),
        ],
      ),
    );
  }

  Widget _rangeTab(BuildContext context, PerfRange r) {
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
          color: active ? context.yucai.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          // 深灰黑阴影豁免(暗底不可见 = v2 暗色无阴影),保原值。
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
            // accentHover(亮 #047857)= accentDeep;未激活原 #54585F 深灰
            // → muted(暗色提亮档)。
            color: active ? context.yucai.accentDeep : context.yucai.muted,
          ),
        ),
      ),
    );
  }

  // ───────────────────────── chart ─────────────────────────

  Widget _chart(BuildContext context) {
    final portSpots = _rebase100(points);
    final benchSpots = _hasBenchmark ? _rebase100(benchmarkPoints) : const <FlSpot>[];
    // Y range:两 series 合并 min/max(100 附近,而非固定 0-1)。
    // 退化(空 series)→ fallback 0-200(_rebase100 至少返回 2 个 100 平线点,
    // 故实际不会触发,但保持防零除的稳健兜底)。
    final all = [...portSpots, ...benchSpots];
    final ys = all.map((s) => s.y).toList()..sort();
    final minY = ys.isEmpty ? 0.0 : ys.first;
    final maxY = ys.isEmpty ? 200.0 : ys.last;
    return LineChart(
      LineChartData(
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        clipData: const FlClipData.all(),
        minX: 0,
        // maxX = max(portLen, benchLen)-1:benchmark 是 raw price_history(~250 行),
        // portfolio 是 granularity bucket(~12 月)→ benchLen > portLen 时若只取
        // portSpots.length-1 会 clip 掉基准曲线尾部 spots。
        maxX: ((portSpots.length > benchSpots.length ? portSpots.length : benchSpots.length) - 1)
            .toDouble()
            .clamp(0, double.infinity),
        minY: minY,
        maxY: maxY == minY ? minY + 1 : maxY,
        lineBarsData: [
          // 组合金实线(rebase 100,起点=100,相对增长)。
          LineChartBarData(
            spots: portSpots,
            isCurved: true,
            color: context.yucai.accent,
            barWidth: 1.8,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: context.yucai.accent.withValues(alpha: 0.16),
            ),
          ),
          // 基准灰虚线(rebase 100,与组合同起点对比相对增长)。
          if (_hasBenchmark)
            LineChartBarData(
              spots: benchSpots,
              isCurved: true,
              // 基准灰 → muted(暗色提亮档;原 #8A8A8A 中灰在墨黑底偏闷)。
              color: context.yucai.muted,
              barWidth: 1.4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: [4, 3],
            ),
        ],
      ),
    );
  }

  /// points → rebase 100(起点=100,相对增长)。startPoint=0 → 100 平线(防除零)。
  /// 量纲归一化:portfolio 元 vs benchmark 点位 都 rebase 后斜率可比。
  /// <=1 点 → 2 个 100 平线点(避免 LineChart 单点不可绘;调用方已 < 2 显空态)。
  List<FlSpot> _rebase100(List<PerfPoint> pts) {
    if (pts.length <= 1) {
      return const [FlSpot(0, 100), FlSpot(1, 100)];
    }
    final start = pts.first.value;
    if (start == 0) {
      return [
        for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), 100),
      ];
    }
    return [
      for (var i = 0; i < pts.length; i++)
        FlSpot(i.toDouble(), pts[i].value / start * 100),
    ];
  }

  /// 图例:━ 组合(金)/ ┄ {benchmarkName}(灰虚线)。
  /// 仅 _hasBenchmark 时渲染(head 下方,chart 上方)。
  Widget _legend(BuildContext context) {
    return Padding(
      key: const ValueKey('perfCurveLegend'),
      padding: const EdgeInsets.only(top: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _legendItem(
            context,
            color: context.yucai.accent,
            label: '组合',
            dashed: false,
          ),
          const SizedBox(width: 14),
          _legendItem(
            context,
            color: context.yucai.muted,
            label: benchmarkName,
            dashed: true,
          ),
        ],
      ),
    );
  }

  Widget _legendItem(
    BuildContext context, {
    required Color color,
    required String label,
    required bool dashed,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 2,
          child: CustomPaint(
            painter: _LegendLinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: context.yucai.muted)),
      ],
    );
  }

  // ───────────────────────── empty ─────────────────────────

  /// 空态:⏳ 行情快照待后端(对齐 A-od trades-empty + brief 降级)。
  Widget _empty(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // 原 v1 米白 #FBFAF6 空态底 → surfaceAlt(暗色随卡面浅一档)。
        color: context.yucai.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
            color: context.yucai.border.withValues(alpha: 0.7)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.trendingUp,
                size: 22, color: context.yucai.muted),
            const SizedBox(height: 6),
            Text(emptyHint,
                style: TextStyle(
                    fontSize: 12.5, color: context.yucai.muted)),
            const SizedBox(height: 2),
            Text('该证券尚未接入行情源',
                style: TextStyle(
                    fontSize: 11, color: context.yucai.muted)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── foot ─────────────────────────

  /// foot:浮动(绿/红) / 已实现(金) / 总收益(绿/红)(对齐 A-od curve-foot)。
  Widget _foot(BuildContext context) {
    final f = foot!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        // 原 v1 米白 #FBFAF6 foot 底 → surfaceAlt(暗色随卡面浅一档)。
        color: context.yucai.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.yucai.border),
      ),
      child: Row(
        children: [
          if (f.unrealizedCents != null)
            Expanded(
              child: _footCell(
                context,
                label: '浮动',
                swatch: context.yucai.positive,
                value: _fmtSigned(f.unrealizedCents!, f.currency),
                valueColor: f.unrealizedCents! >= 0
                    ? context.yucai.positive
                    : context.yucai.negative,
              ),
            ),
          if (f.realizedCents != null)
            Expanded(
              child: _footCell(
                context,
                label: '已实现',
                swatch: context.yucai.accent,
                value: _fmtRaw(f.realizedCents!, f.currency),
              ),
            ),
          if (f.totalCents != null)
            Expanded(
              child: _footCell(
                context,
                label: '总收益',
                swatch: context.yucai.fg,
                value: _fmtSigned(f.totalCents!, f.currency),
                valueColor: f.totalCents! >= 0
                    ? context.yucai.positive
                    : context.yucai.negative,
              ),
            ),
        ],
      ),
    );
  }

  Widget _footCell(
    BuildContext context, {
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
                style: TextStyle(
                    fontSize: 11, color: context.yucai.muted)),
          ],
        ),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? context.yucai.fg,
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

/// 图例线段 painter:实线(组合金)/ 虚线(基准灰)。
/// 18×2 的小线段,与 chart LineChartBarData 视觉一致(dashed=true 时 4-3 dash)。
class _LegendLinePainter extends CustomPainter {
  const _LegendLinePainter({required this.color, required this.dashed});
  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!dashed) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      return;
    }
    // 虚线:4 on / 3 off(对齐 LineChartBarData dashArray: [4, 3] 视觉)。
    const on = 4.0, off = 3.0;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + on).clamp(0.0, size.width);
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
      x += on + off;
    }
  }

  @override
  bool shouldRepaint(_LegendLinePainter old) =>
      old.color != color || old.dashed != dashed;
}
