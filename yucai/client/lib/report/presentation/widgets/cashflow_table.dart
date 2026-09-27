/// 现金流三活动表(T5,04 章节,原型 .cf-table):经营/投资/融资 三行 +
/// 合计行(surfaceAlt 强调)+ 勾稽脚注(.recon)。
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';

/// 三类活动现金流表(净额正负着色;合计行底色强调)。
class CashFlowTable extends StatelessWidget {
  const CashFlowTable({super.key, required this.section});

  final CashFlowSection section;

  @override
  Widget build(BuildContext context) {
    final totalIn = section.operating.inflowCents +
        section.investing.inflowCents +
        section.financing.inflowCents;
    final totalOut = section.operating.outflowCents +
        section.investing.outflowCents +
        section.financing.outflowCents;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _head(context),
        _row(context, '经营活动', section.operating),
        _row(context, '投资活动', section.investing),
        _row(context, '融资活动', section.financing),
        _total(context, '合计', totalIn, totalOut, section.netDeltaCents),
        const SizedBox(height: AppSpacing.sm),
        _reconFoot(context),
      ],
    );
  }

  Widget _head(BuildContext context) => _gridRow(
        context,
        cells: [
          _cell(context, '活动', header: true),
          _num(context, null, header: true, text: '流入'),
          _num(context, null, header: true, text: '流出'),
          _num(context, null, header: true, text: '净额'),
        ],
      );

  Widget _row(BuildContext context, String name, ActivityFlow flow) =>
      _gridRow(
        context,
        cells: [
          _cell(context, name),
          _num(context, flow.inflowCents),
          _num(context, flow.outflowCents),
          _num(context, flow.netCents, signed: true),
        ],
      );

  Widget _total(
    BuildContext context,
    String name,
    int inflow,
    int outflow,
    int net,
  ) =>
      Container(
        decoration: BoxDecoration(
          color: context.yucai.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: _gridRow(
          context,
          emphasize: true,
          cells: [
            _cell(context, name, strong: true),
            _num(context, inflow),
            _num(context, outflow),
            _num(context, net, signed: true),
          ],
        ),
      );

  /// 勾稽脚注:三类净额合计与「期末−期初现金」一致由 classifier assert 钉死
  /// (走不到 false),渲染层只作显式表达;false 兜底中性警示文案。
  Widget _reconFoot(BuildContext context) {
    final ok = section.reconciled;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          ok ? LucideIcons.link : LucideIcons.triangleAlert,
          size: 14,
          color: ok ? context.yucai.accent : context.yucai.warn,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                  fontSize: 12.5, color: context.yucai.muted, height: 1.7),
              children: [
                TextSpan(
                  text: '勾稽 ',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: context.yucai.fg),
                ),
                TextSpan(
                  text: ok
                      ? '三类活动净额合计 ${fmtCentsSigned(section.netDeltaCents)},与期末−期初现金余额一致。'
                      : '三类净额与期末−期初现金余额不一致,请检查账本数据。',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gridRow(BuildContext context,
      {bool emphasize = false, required List<Widget> cells}) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: emphasize ? 6 : 0, vertical: emphasize ? 8 : 7),
      child: Row(
        children: [
          Expanded(flex: 2, child: cells[0]),
          Expanded(flex: 2, child: cells[1]),
          Expanded(flex: 2, child: cells[2]),
          Expanded(flex: 2, child: cells[3]),
        ],
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    String text, {
    bool header = false,
    bool strong = false,
  }) =>
      Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: header || strong ? FontWeight.w600 : FontWeight.w500,
          color: header ? context.yucai.muted : context.yucai.fg,
        ),
      );

  Widget _num(
    BuildContext context,
    int? cents, {
    bool header = false,
    bool signed = false,
    String? text,
  }) {
    if (header) {
      return Text(
        text ?? '',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: context.yucai.muted,
        ),
      );
    }
    final value = cents ?? 0;
    final color = signed
        ? (value >= 0 ? context.yucai.positive : context.yucai.negative)
        : context.yucai.fg;
    return Text(
      signed ? fmtCentsSigned(value) : fmtCents(value),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
        fontFeatures: AppTypography.tabularFigures,
      ),
    );
  }
}
