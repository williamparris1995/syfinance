import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';

/// 摊还预览数据(debt / receivable form 共享)。
///
/// 由各 form 的 `_computePreview()` 构造,驱动 [AmortizationPreview] 渲染。
/// `label` 描述每期金额的语义(debt:「月供」/「首月供」/「到期总额」;
/// receivable:「每期收款」/「首期收款」/「到期总额」)。
class AmortizationPreviewData {
  const AmortizationPreviewData({
    required this.label,
    required this.headlineAmount,
    required this.rows,
    required this.n,
    required this.totalInterest,
    required this.totalPayment,
    required this.annualRate,
  });

  /// 每期金额的语义标签(debt:月供 / 首月供 / 到期总额;receivable:每期收款 / …)。
  final String label;

  /// 头条金额(月供 / 首月供 / 到期总额),与 [label] 配对展示。
  final double headlineAmount;

  /// 前 5 期排程(lumpSum 仅 1 行)。
  final List<AmortizationPreviewRow> rows;

  /// 总期数。
  final int n;

  /// 总利息。
  final double totalInterest;

  /// 总还款(本息合计)。
  final double totalPayment;

  /// 年化利率(footer 展示)。
  final double annualRate;
}

/// 单期排程数据。
class AmortizationPreviewRow {
  const AmortizationPreviewRow({
    required this.index,
    required this.date,
    required this.principal,
    required this.interest,
    this.isDue = false,
  });

  final int index;
  final DateTime date;
  final double principal;
  final double interest;

  /// 是否到期一次性结清(lumpSum 仅 1 行,index 显示「到期」)。
  final bool isDue;
}

/// 深色实时预览卡(debt / receivable form 共享)。
///
/// 对齐 OD `.preview` 深色 gradient 卡:header(LIVE PREVIEW · sectionLabel +
/// title + headline label + headlineAmount 26 大字 + tags 期数 / 总利息 /
/// 总还款)+ table(前 5 期 schedule)+ foot。
///
/// 参数化点(让 debt / receivable 共享同一组件):
/// - [title]:头条主标题(debt:counterparty · subtypeLabel;receivable:同结构)。
/// - [sectionLabel]:header 小标签(debt:`LIVE PREVIEW · 还款计划预览`;
///   receivable:`LIVE PREVIEW · 收款计划预览`)。
/// - [dateColumnLabel] / [principalColumnLabel] / [totalColumnLabel]:table 三列
///   表头(debt:`期次 / 还款日`、`本金 / 利息`、`合计`;
///   receivable:`期次 / 收款日`、`收回本金 / 利息`、`合计`)。
/// - [interestRowLabel]:row 利息子行前缀(默认「利息」,两端共用)。
/// - [currencyCode]:多币种 ISO 4217 code(默认 CNY),通过 [currencySymbol]
///   渲染符号 —— 禁硬编码 ¥。
/// - [emptyHint] / [footNote]:空态文案 / footer 文案(两端可定制)。
///
/// preview == null → 空态。
///
/// **F4-P2 色彩豁免清单**:本卡是 OD 原型刻意的固定深色渐变面(两主题一致),
/// 卡内自带的固定内景色(卡面渐变 #1F2228/#262A31、白系文本、表头 #6F747C、
/// tag 底 #12FFFFFF、行分隔 #0DFFFFFF、金额金 #E8C894 等)**不随主题迁**——
/// 固定深底上亮暗两态均可辨识且不刺眼;辅助说明文字走 context.yucai.muted
/// (暗色下自动提亮一档)。卡面投影 #17000000(黑 9%)系黑阴影——暗色墨黑
/// 底上天然不可见,恰好等效 v2 暗色「无阴影」设计,保原值不迁。
class AmortizationPreview extends StatelessWidget {
  const AmortizationPreview({
    super.key,
    required this.preview,
    required this.title,
    required this.sectionLabel,
    this.dateColumnLabel = '期次 / 还款日',
    this.principalColumnLabel = '本金 / 利息',
    this.totalColumnLabel = '合计',
    this.interestRowLabel = '利息',
    this.currencyCode = 'CNY',
    this.emptyHint = '填写本金与起止日期后\n实时生成还款计划',
    this.footNote = '前 5 期预览 · 实际以放款为准',
  });

  final AmortizationPreviewData? preview;
  final String title;
  final String sectionLabel;
  final String dateColumnLabel;
  final String principalColumnLabel;
  final String totalColumnLabel;
  final String interestRowLabel;
  final String currencyCode;
  final String emptyHint;
  final String footNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('amortizationPreview'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2228), Color(0xFF262A31)],
        ),
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
              color: Color(0x17000000), blurRadius: 34, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context),
          if (preview == null) _empty() else _table(context, preview!),
          _foot(context),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final p = preview;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sectionLabel,
              style: TextStyle(
                  color: context.yucai.muted,
                  fontSize: 10.5,
                  letterSpacing: 2,
                  fontFamily: AppTypography.displayFamily)),
          const SizedBox(height: 7),
          Text(title,
              key: const ValueKey('previewTitle'),
              style: const TextStyle(
                  color: Colors.white, // 深色预览卡固定深底白系(F4-P2/F15 豁免,见文件头)
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTypography.displayFamily)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(p == null ? '' : p.label,
                  style: TextStyle(
                      color: context.yucai.muted, fontSize: 11.5)),
              const SizedBox(width: 8),
              Text(
                p == null ? '—' : _fmtSymbol(p.headlineAmount, currencyCode),
                style: const TextStyle(
                    color: Colors.white, // 深色预览卡固定深底白系(F4-P2/F15 豁免,见文件头)
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 7,
              runSpacing: 4,
              children: [
                _tag('期数 ${p.n} 期'),
                _tag('总利息 ${_fmtSymbol(p.totalInterest, currencyCode)}'),
                _tag('总还款 ${_fmtSymbol(p.totalPayment, currencyCode)}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFC9CCD2),
                fontSize: 11,
                fontFeatures: AppTypography.tabularFigures)),
      );

  Widget _table(BuildContext context, AmortizationPreviewData p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          // header row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text(dateColumnLabel,
                        style: const TextStyle(
                            color: Color(0xFF6F747C),
                            fontSize: 10,
                            letterSpacing: 1,
                            fontFeatures: AppTypography.tabularFigures))),
                Expanded(
                    flex: 5,
                    child: Text(principalColumnLabel,
                        style: const TextStyle(
                            color: Color(0xFF6F747C),
                            fontSize: 10,
                            letterSpacing: 1))),
                Expanded(
                    flex: 4,
                    child: Text(totalColumnLabel,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            color: Color(0xFF6F747C),
                            fontSize: 10,
                            letterSpacing: 1))),
              ],
            ),
          ),
          for (final row in p.rows) _row(context, row),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, AmortizationPreviewRow r) {
    final idx = r.isDue ? '到期' : r.index.toString().padLeft(2, '0');
    final total = r.principal + r.interest;
    final date =
        '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
    return Container(
      key: ValueKey('previewRow-${r.index.toString().padLeft(2, '0')}'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0x0DFFFFFF)))),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(idx,
                    style: const TextStyle(
                        color: Color(0xFF6F747C),
                        fontSize: 11,
                        fontFeatures: AppTypography.tabularFigures)),
                Text(date,
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtSymbol(r.principal, currencyCode),
                    style: const TextStyle(
                        color: Colors.white, // 深色预览卡固定深底白系(F4-P2/F15 豁免,见文件头)
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppTypography.tabularFigures)),
                Text('$interestRowLabel ${_fmtSymbol(r.interest, currencyCode)}',
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 10.5)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(_fmtSymbol(total, currencyCode),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFFE8C894),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures)),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      key: const ValueKey('previewEmpty'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Center(
        child: Text(
          emptyHint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF7A7E85), fontSize: 12.5, height: 1.6),
        ),
      ),
    );
  }

  Widget _foot(BuildContext context) {
    final p = preview;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      decoration: const BoxDecoration(
          border:
              Border(top: BorderSide(color: Color(0x12FFFFFF)))),
      child: Row(
        children: [
          Expanded(
            child: Text(footNote,
                style: TextStyle(
                    color: context.yucai.muted, fontSize: 11.5)),
          ),
          Text('年化 ${p == null ? '—' : '${p.annualRate.toStringAsFixed(1)}%'}',
              style: const TextStyle(
                  color: Color(0xFFE8C894),
                  fontSize: 11.5,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// 元(double)→ currencySymbol(code) + 千分位 + 0 小数(对齐 OD fmt:
/// Math.round + toLocaleString)。多币种:符号来自 [currencySymbol],
/// 禁硬编码 ¥。code 默认 CNY(debt/receivable 创建假设原币 CNY,preview 显
/// 原币非折算 preferred —— 与 receivables_page._fmtSymbol 同源)。
String _fmtSymbol(double v, String currencyCode) {
  final n = v.round();
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  final s = abs.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$sign${currencySymbol(currencyCode)}$buf';
}
