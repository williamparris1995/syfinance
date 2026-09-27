/// 总览 hero(T5,01 章节,原型 .hero):期初净资产 → 期末净资产 + 变动
/// chip(金额+百分比,正负着色)+ foot(现金净变动 / 本位币)。
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.yucai.muted,
                )),
            const SizedBox(height: AppSpacing.sm),
          ],
          LayoutBuilder(builder: (context, c) {
            // FittedBox 防溢出(长金额/测试等宽字体下自动缩排)。
            Widget amount(String v, double size) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    v,
                    style: TextStyle(
                      fontSize: size,
                      fontWeight: FontWeight.w800,
                      color: context.yucai.fg,
                      letterSpacing: -0.5,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                );
            Text cap(String v) => Text(v,
                style: TextStyle(
                    fontSize: 11.5, color: context.yucai.muted));
            final wide = c.maxWidth > 620;
            final Widget row = wide
                ? Row(
                    children: [
                      Flexible(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              cap('期初净资产'),
                              const SizedBox(height: 4),
                              amount(fmtCents(overview.netWorthStartCents), 20),
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
                              cap('期末净资产'),
                              const SizedBox(height: 4),
                              amount(fmtCents(overview.netWorthEndCents), 28),
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
                      cap('期初净资产'),
                      amount(fmtCents(overview.netWorthStartCents), 20),
                      const SizedBox(height: 4),
                      cap('期末净资产'),
                      amount(fmtCents(overview.netWorthEndCents), 28),
                      const SizedBox(height: AppSpacing.sm),
                      _deltaChip(
                          context, deltaColor, fmtCentsSigned(delta), pct),
                    ],
                  );
            return row;
          }),
          const SizedBox(height: AppSpacing.sm),
          // hero-foot:现金净变动 + 本位币(储蓄率在四卡之列,不重复)。
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: 4,
            children: [
              _footItem(context, '现金及等价物净变动',
                  fmtCentsSigned(overview.cashDeltaCents)),
              _footItem(context, '本位币', 'CNY'),
            ],
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
