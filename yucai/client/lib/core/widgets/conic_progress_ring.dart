// Conic 进度环 —— 御财共享 widget(对齐 OD 原型 .progress-ring + conic-gradient)。
//
// 设计源:design-output/goal/styles.css `.progress-ring` / `.ring-lg|.ring-md|.ring-sm`
//  + mock-data.js `window.ringGradient(pct, statusColor)`:
//    conic-gradient(statusColor 0 pct%, var(--border) pct% 100%)
//
// Flutter 无原生 conic-gradient,用 CustomPainter 画一个 conic 风格的进度环:
//  - 从 12 点(顶部 -π/2)起,顺时针扫过 pct% 的弧,填 `color`。
//  - 剩余弧填 `trackColor`(默认 context.yucai.border)。
//  - 中心 hollow(留 `holeFraction` 直径的空白),放 pct 文本。
//  - `ringGradient` 非空时给进度弧加一段 SweepGradient(御财金渐变),
//    对齐原型 holding donut 风格。
//
// 三端尺寸(对齐原型):
//   - sm:60 / hole 44 / pct 13
//   - md:80 / hole 60 / pct 16  ← list 卡片用
//   - lg:120 / hole 92 / pct 22 ← detail hero 用
//
// 复用方:goal list 卡片 + goal detail hero。budget 对齐时也可直接复用。
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// Conic 风格进度环尺寸预设(对齐 OD 原型 .ring-lg|.ring-md|.ring-sm)。
enum ConicRingSize { sm, md, lg }

class ConicRingSpec {
  const ConicRingSpec(this.size, this.outer, this.hole, this.strokeWidth, this.pctFontSize);
  final ConicRingSize size;
  final double outer; // 外径
  final double hole; // 中心空白直径
  final double strokeWidth; // 环宽(外径 - 空心直径 的 一部分;原型用整环填充无 stroke 概念,
  // 此处用 stroke 表达更接近 conic-gradient 视觉)
  final double pctFontSize;

  static const _table = {
    ConicRingSize.sm: ConicRingSpec(ConicRingSize.sm, 60, 44, 8, 13),
    ConicRingSize.md: ConicRingSpec(ConicRingSize.md, 80, 60, 10, 16),
    ConicRingSize.lg: ConicRingSpec(ConicRingSize.lg, 120, 92, 14, 22),
  };
  static ConicRingSpec of(ConicRingSize s) => _table[s]!;
}

/// 御财金渐变(进度弧 SweepGradient,对齐原型 ringGradient 金色调)。
const List<Color> kRingGoldGradient = [
  Color(0xFFCBB387), // --gold-soft
  Color(0xFFB08D57), // --gold
  Color(0xFF94703C), // --gold-deep
];

/// Conic 进度环 widget。
///
/// [progress] 取值 0..1(自动 clamp);[color] 进度弧主色(完成绿/落后红/类型金);
/// [trackColor] 剩余弧底色(默认 context.yucai.border);
/// [pctLabel] 中心文本(调用方格式化,如 "40%" / "40.0%");留空则不显示;
/// [subLabel] 中心 pct 下的小字(如 detail hero 的 "已达成"),可空;
/// [gradient] 非空时给进度弧覆盖一段 SweepGradient(优先于 color)。
class ConicProgressRing extends StatelessWidget {
  const ConicProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.pctLabel,
    this.subLabel,
    this.size = ConicRingSize.md,
    this.trackColor = AppColors.border,
    this.gradient,
  });

  final double progress;
  final Color color;
  final String? pctLabel;
  final String? subLabel;
  final ConicRingSize size;
  final Color trackColor;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final spec = ConicRingSpec.of(size);
    return SizedBox(
      width: spec.outer,
      height: spec.outer,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            key: const ValueKey('conicRingBar'),
            size: Size.square(spec.outer),
            painter: _ConicRingPainter(
              progress: progress.clamp(0.0, 1.0),
              color: color,
              trackColor: trackColor,
              strokeWidth: spec.strokeWidth,
              gradient: gradient,
            ),
          ),
          if (pctLabel != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pctLabel!,
                  key: const ValueKey('conicRingPct'),
                  style: TextStyle(
                    fontSize: spec.pctFontSize,
                    fontWeight: FontWeight.w700,
                    color: context.yucai.fg,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                if (subLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subLabel!,
                    key: const ValueKey('conicRingSub'),
                    style: TextStyle(
                      fontSize: 9,
                      color: context.yucai.muted,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// 画 conic 风格进度环:track 满圈 + 进度弧(从 12 点顺时针)。
class _ConicRingPainter extends CustomPainter {
  _ConicRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    this.gradient,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final List<Color>? gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2; // 12 点钟方向
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);

    // track(满圈底色)。
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor,
    );

    // 进度弧。
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    if (gradient != null && gradient!.length >= 2) {
      paint.shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: gradient!,
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    } else {
      paint.color = color;
    }
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ConicRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.gradient != gradient;
}
