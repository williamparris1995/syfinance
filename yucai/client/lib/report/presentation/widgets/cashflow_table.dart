/// 现金流三活动表(T5,04 章节,原型 .cf-table):经营/投资/融资 三行 +
/// 合计行(surfaceAlt 强调)+ 勾稽脚注(.recon)。
///
/// 视觉对齐批次(2026-09-29):补「明细」列(原型 v9 五列
/// `.9fr .8fr .8fr .8fr 1.7fr`)—— 经营活动 = 分类器矩阵语义文案
/// (income/expense 科目两侧,按流入/流出在场的侧自适应);投资/融资
/// 活动 = 对手方分类净额([ActivityFlow.counterpartyCents],按绝对额
/// 降序,「标签 ¥金额 + …」措辞照原型 fixture 风格);合计行 = '—'。
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/widgets/category_bars.dart'
    show categoryLabelOf;
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
        _row(context, '经营活动', section.operating, _operatingDetail),
        _row(context, '投资活动', section.investing, _breakdownDetail),
        _row(context, '融资活动', section.financing, _breakdownDetail),
        _total(context, '合计', totalIn, totalOut, section.netDeltaCents),
        const SizedBox(height: AppSpacing.sm),
        _reconFoot(context),
      ],
    );
  }

  /// 经营活动明细:分类器矩阵语义(对手 = income/expense 科目),按在场
  /// 侧自适应 —— 双侧「工资等日常收入 · 日常消费支出」,单侧只出该侧,
  /// 零流量 '—'(原型 fixture「工资等日常收入 · 日常消费支出」措辞)。
  String _operatingDetail(ActivityFlow f) {
    final hasIn = f.inflowCents > 0;
    final hasOut = f.outflowCents > 0;
    if (hasIn && hasOut) return '工资等日常收入 · 日常消费支出';
    if (hasIn) return '工资等日常收入';
    if (hasOut) return '日常消费支出';
    return '—';
  }

  /// 投资/融资活动明细:对手分类净额 → 「标签 ¥金额」按绝对额降序,
  /// ' + ' 连接(原型「基金定投 ¥2,000.00 + 定期存入 ¥3,000.00」风格;
  /// 流出侧取绝对值 —— 「定期存入 ¥3,000.00」同为正数呈现)。
  String _breakdownDetail(ActivityFlow flow) {
    final parts = flow.counterpartyCents.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));
    if (parts.isEmpty) return '—';
    return [
      for (final p in parts) '${categoryLabelOf(p.key)} ${fmtCents(p.value.abs())}',
    ].join(' + ');
  }

  Widget _head(BuildContext context) => _gridRow(
        context,
        cells: [
          _cell(context, '活动', header: true),
          _num(context, null, header: true, text: '流入'),
          _num(context, null, header: true, text: '流出'),
          _num(context, null, header: true, text: '净额'),
          _cell(context, '明细', header: true),
        ],
      );

  Widget _row(
    BuildContext context,
    String name,
    ActivityFlow flow,
    String Function(ActivityFlow) detailOf,
  ) =>
      _gridRow(
        context,
        cells: [
          _cell(context, name),
          _num(context, flow.inflowCents),
          _num(context, flow.outflowCents),
          _num(context, flow.netCents, signed: true),
          _detail(context, detailOf(flow)),
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
            _detail(context, '—'),
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

  /// 五列栅格(原型 .9/.8/.8/.8/1.7fr;明细列最宽承载解释文本)。
  Widget _gridRow(BuildContext context,
      {bool emphasize = false, required List<Widget> cells}) {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: emphasize ? 6 : 0, vertical: emphasize ? 8 : 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: 9, child: cells[0]),
          Expanded(flex: 8, child: cells[1]),
          Expanded(flex: 8, child: cells[2]),
          Expanded(flex: 8, child: cells[3]),
          Expanded(flex: 17, child: cells[4]),
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

  /// 明细单元格(原型 .cf-det:12px muted,超宽省略)。
  Widget _detail(BuildContext context, String text) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: context.yucai.muted),
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
