/// 投资绩效五数值卡(T5,06 章节,原型 .metric-five)。
///
/// 期初市值 / 期末市值 / 当期净买入 / 估算收益(正负着色)/ 区间 TWR
/// (正负着色;端点零 sentinel → null → '—')。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';

/// 五数值卡(宽屏 5 列;窄屏 Wrap 2 列)。
class PerfCards extends StatelessWidget {
  const PerfCards({super.key, required this.section});

  final InvestmentSection section;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 760;
      final cards = <Widget>[
        _card(context, '期初市值', fmtCents(section.mvStartCents), null,
            '报告期起点持仓价值'),
        _card(context, '期末市值', fmtCents(section.mvEndCents), null,
            '报告期终点持仓价值'),
        _card(context, '当期净买入', fmtCents(section.netBuyCents), null,
            '买入 − 卖出'),
        _card(
          context,
          '估算收益',
          fmtCentsSigned(section.estGainCents),
          section.estGainCents >= 0
              ? context.yucai.positive
              : context.yucai.negative,
          '= 期末 − 期初 − 净买入',
        ),
        _card(
          context,
          '区间 TWR',
          section.twr == null ? '—' : fmtPctSigned(section.twr!),
          section.twr == null
              ? context.yucai.muted
              : (section.twr! >= 0
                  ? context.yucai.positive
                  : context.yucai.negative),
          '剔除现金流影响的收益率',
        ),
      ];
      if (wide) {
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      }
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [for (final card in cards) SizedBox(width: 240, child: card)],
      );
    });
  }

  Widget _card(
    BuildContext context,
    String label,
    String value,
    Color? valueColor,
    String foot,
  ) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.yucai.surface,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(color: context.yucai.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.yucai.muted)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 22, // 视觉对齐批次:19 → 22(原型 .mini-big)
                  fontWeight: FontWeight.w800,
                  color: valueColor ?? context.yucai.fg,
                  letterSpacing: -0.3,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(foot,
                style:
                    TextStyle(fontSize: 11.5, color: context.yucai.muted)),
          ],
        ),
      );
}
