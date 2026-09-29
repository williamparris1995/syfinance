/// 总览 hero(T5,01 章节,原型 .hero):期初净资产 → 期末净资产 + 变动
/// chip(金额+百分比,正负着色)+ foot(储蓄率 / 现金净变动 / 本位币)。
///
/// 视觉对齐批次(2026-09-29,原型 v9):数字升档 期初 38px / 期末 46px
/// (w800,letterSpacing .5);整数段经 ShaderMask 做令牌渐变着色(暗 =
/// 金 accent→accentDeep 135°,亮 = 翡翠 accent 渐变同式,零裸色);小数
/// 「.00」以 24px 分段独立着色(暗 accentDeep / 亮 muted,原型 .cents)。
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';

/// 净资产变动 hero。期初 ≤ 0 时隐藏变动百分比(除法无意义)。
class OverviewHero extends StatelessWidget {
  const OverviewHero({super.key, required this.overview, this.periodLabel});

  final OverviewSection overview;
  final String? periodLabel;

  @override
  Widget build(BuildContext context) {
    final delta = overview.netWorthEndCents - overview.netWorthStartCents;
    final up = delta >= 0;
    final deltaColor = up ? context.yucai.positive : context.yucai.negative;
    // T5-R1:净资产变动 % 取 model 派生(构造期算好;期初 ≤ 0 → null
    // 隐藏 chip 的 % 部分),渲染层零现算。
    final pct = overview.netWorthChangePct;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.xlBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (periodLabel != null) ...[
            Text('净资产变动 · $periodLabel',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: context.yucai.muted,
                )),
            const SizedBox(height: AppSpacing.sm),
          ],
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 620;
            final Widget row = wide
                ? Row(
                    children: [
                      Flexible(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cap(context, '期初净资产'),
                              const SizedBox(height: 4),
                              amount(context,
                                  fmtCents(overview.netWorthStartCents), 38),
                            ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm),
                        child: Icon(LucideIcons.moveRight,
                            size: 20, color: context.yucai.muted),
                      ),
                      Flexible(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cap(context, '期末净资产'),
                              const SizedBox(height: 4),
                              amount(context,
                                  fmtCents(overview.netWorthEndCents), 46),
                            ]),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: _deltaChip(
                            context, deltaColor, fmtCentsSigned(delta), pct),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      cap(context, '期初净资产'),
                      amount(context,
                          fmtCents(overview.netWorthStartCents), 38),
                      const SizedBox(height: 4),
                      cap(context, '期末净资产'),
                      amount(context, fmtCents(overview.netWorthEndCents), 46),
                      const SizedBox(height: AppSpacing.sm),
                      _deltaChip(
                          context, deltaColor, fmtCentsSigned(delta), pct),
                    ],
                  );
            return row;
          }),
          const SizedBox(height: AppSpacing.sm),
          // hero-foot 三项(原型 v9):储蓄率 / 现金净变动 / 本位币 ——
          // 储蓄率移回顶部「一眼可见」位(四卡仍保留,双处呈现)。
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              _footItem(context, '储蓄率',
                  '${overview.savingsRate.toStringAsFixed(1)}%'),
              _footItem(context, '现金及等价物净变动',
                  fmtCentsSigned(overview.cashDeltaCents)),
              _footItem(context, '本位币', 'CNY'),
            ],
          ),
        ],
      ),
    );
  }

  Text cap(BuildContext context, String v) => Text(v,
      style: TextStyle(fontSize: 11.5, color: context.yucai.muted));

  /// 大数字(整数 + 小数分段,原型 .hero-amount + .cents):整数段
  /// ShaderMask 令牌渐变;小数段 24px 独立着色。FittedBox 防溢出(长金额/
  /// 测试等宽字体下自动缩排)。
  Widget amount(BuildContext context, String v, double size) {
    final t = context.yucai;
    final dot = v.lastIndexOf('.');
    final whole = dot < 0 ? v : v.substring(0, dot);
    final frac = dot < 0 ? null : v.substring(dot);
    // 135° 令牌渐变(暗 = 鎏金 accent→accentDeep,原型 linear-gradient
    // (135deg,#E8C07A,#C9964A) 同值;亮 = 翡翠 accent 渐变,任务拍板)。
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [t.accent, t.accentDeep],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => gradient.createShader(bounds),
            child: Text(
              whole,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w800,
                color: Colors.white, // srcIn 蒙版色,实色由渐变接管
                letterSpacing: 0.5,
                height: 1.05,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
          if (frac != null)
            Text(
              frac,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                // 暗金 deep / 亮 muted(原型 dark .cents #C9964A 同义)。
                color: Theme.of(context).brightness == Brightness.dark
                    ? t.accentDeep
                    : t.muted,
                height: 1.05,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
        ],
      ),
    );
  }

  Widget _deltaChip(
      BuildContext context, Color color, String amount, double? pct) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(amount,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: AppTypography.tabularFigures,
                )),
            if (pct != null) ...[
              const SizedBox(width: 6),
              Text(fmtPctSigned(pct),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    fontFeatures: AppTypography.tabularFigures,
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _footItem(BuildContext context, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style:
                TextStyle(fontSize: 12.5, color: context.yucai.muted)),
        Text(value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: value.startsWith('+')
                  ? context.yucai.positive
                  : context.yucai.fg,
              fontFeatures: AppTypography.tabularFigures,
            )),
      ],
    );
  }
}
