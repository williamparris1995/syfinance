/// F45 报告导出 —— PDF 渲染器(ADR-1/ADR-2):布局树 → Uint8List。
///
/// pdf 包直绘(纯 Dart,零原生):A4 [pw.MultiPage] 分页、页脚
/// 「御财财务报告-{label} · 第 N 页」、Noto Sans SC 单例字体
/// ([_notoFont],字体字节经 [fontSource] 注入 —— 本域不 import
/// flutter/services,生产侧由 presentation 以 rootBundle 提供)、
/// 章节起新页([pw.NewPage],总览除外)、表格/条形与页面同构
/// (severity 色深:risk 红 / warn 琥珀 / info 蓝灰;粗细层次用字号+
/// 颜色区分,只带 Regular 一支字体 —— ADR-1 财报素净风格)。
///
/// 硬约束:仅 import pdf 包 + report domain/export 域 + dart 标准库;
/// 零数字计算(金额/占比文本由布局树 [fmtExportCents] 单点格式化)。
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/export/report_export_layout.dart';

/// Noto 字体单例(进程级一份;10MB 全量解析一次,重复导出零重载)。
pw.Font? _cachedFont;

Future<pw.Font> _notoFont(Future<ByteData> Function() source) async {
  return _cachedFont ??= pw.Font.ttf(await source());
}

/// severity → PDF 语义色(页面 negative/warn/info 的素净近似;粗细
/// 层次用色深区分 —— ADR-1 只带 Regular 一支)。
PdfColor _severityColor(MdaSeverity? severity) => switch (severity) {
      MdaSeverity.risk => PdfColors.red700,
      MdaSeverity.warn => PdfColors.amber700,
      MdaSeverity.info => PdfColors.blueGrey,
      null => PdfColors.black,
    };

PdfColor _toneColor(ReportExportTone tone) => switch (tone) {
      ReportExportTone.positive => PdfColors.green700,
      ReportExportTone.negative => PdfColors.red700,
      ReportExportTone.neutral => PdfColors.black,
    };

/// 布局树 → PDF bytes([fontSource] 注入 Noto ttf 字节)。
Future<Uint8List> renderPdf(
  ReportExportLayout layout, {
  required Future<ByteData> Function() fontSource,
}) async {
  final font = await _notoFont(fontSource);
  final theme = pw.ThemeData.withFont(base: font, bold: font);
  final doc = pw.Document(theme: theme, title: layout.title);

  final children = <pw.Widget>[
    pw.Header(level: 0, text: layout.title),
  ];
  for (var i = 0; i < layout.sections.length; i++) {
    final section = layout.sections[i];
    // 新章节起新页;总览随文档大标题同页(设计 LLD)。
    if (i > 0) children.add(pw.NewPage());
    children.add(pw.Header(level: 1, text: section.title));
    children.addAll([for (final block in section.blocks) _widgetOf(block)]);
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 56),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        child: pw.Text(
          '御财财务报告-${layout.periodLabel} · 第 ${context.pageNumber} 页',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ),
      build: (_) => children,
    ),
  );
  return doc.save();
}

/// 单块 → pw.Widget 同构映射。
pw.Widget _widgetOf(ReportExportBlock block) {
  switch (block) {
    case ReportTextBlock(:final text, :final severity):
      return pw.Paragraph(
        text: text,
        style: pw.TextStyle(
          fontSize: 9.5,
          color: _severityColor(severity),
        ),
      );
    case ReportKvBlock(:final title, :final rows):
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (title != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Header(level: 2, text: title),
            ),
          pw.Table(
            border: null,
            children: [
              for (final row in rows)
                pw.TableRow(children: [
                  pw.Container(
                    width: 160,
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Text(row.label,
                        style: const pw.TextStyle(
                            fontSize: 9.5, color: PdfColors.blueGrey)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                    child: pw.Text(row.value,
                        style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: _toneColor(row.tone))),
                  ),
                ]),
            ],
          ),
        ],
      );
    case ReportTableBlock(:final title, :final header, :final rows):
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (title != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Header(level: 2, text: title),
            ),
          _textTable(header, rows),
        ],
      );
    case ReportBarsBlock(
        :final title,
        :final totalCents,
        :final showMax,
        :final bars
      ):
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (title != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Header(
                level: 2,
                text: totalCents == null
                    ? title
                    : '$title(合计 ${fmtExportCents(totalCents)})',
              ),
            ),
          for (final bar in bars) _barRow(bar, showMax: showMax),
        ],
      );
    case ReportNoteBlock(:final title, :final lines):
      return pw.Container(
        margin: const pw.EdgeInsets.only(top: 6, bottom: 6),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title,
                style: const pw.TextStyle(
                    fontSize: 10, fontWeight: pw.FontWeight.bold)),
            for (final line in lines)
              pw.Text('· $line',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.blueGrey)),
          ],
        ),
      );
  }
}

/// 文本表格:深色表头行 + emphasized 行加粗(页面 CashFlowTable/_ChangesTable
/// 的素净同构;首列左对齐,数值列右对齐)。
pw.Widget _textTable(List<String> header, List<ReportExportTableRow> rows) {
  pw.Widget cell(String text,
      {bool bold = false, pw.TextAlign align = pw.TextAlign.right, color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color),
      ),
    );
  }

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    columnWidths: const {0: pw.FlexColumnWidth(1.4)},
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
        children: [
          for (var c = 0; c < header.length; c++)
            cell(header[c],
                bold: true,
                color: PdfColors.white,
                align: c == 0 ? pw.TextAlign.left : pw.TextAlign.right),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          decoration: row.emphasized
              ? const pw.BoxDecoration(color: PdfColors.grey100)
              : null,
          children: [
            for (var c = 0; c < row.cells.length; c++)
              cell(row.cells[c],
                  bold: row.emphasized,
                  align: c == 0 ? pw.TextAlign.left : pw.TextAlign.right),
          ],
        ),
    ],
  );
}

/// 单条形行:label + 填充条(flex 比例 = amount/max)+ 金额(+额度)+
/// 占比(页面 CategoryBars/BudgetRows 同构;条色按 severity 色深)。
pw.Widget _barRow(ReportExportBar bar, {required bool showMax}) {
  final filled = bar.maxCents == null || bar.maxCents! <= 0
      ? 0
      : ((bar.amountCents * 1000) / bar.maxCents!).round().clamp(0, 1000);
  final amountText = showMax && bar.maxCents != null
      ? '${fmtExportCents(bar.amountCents)} / ${fmtExportCents(bar.maxCents!)}'
      : fmtExportCents(bar.amountCents);
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(children: [
      pw.SizedBox(
        width: 96,
        child: pw.Text(bar.label,
            style: const pw.TextStyle(fontSize: 9.5)),
      ),
      pw.Expanded(
        child: pw.Container(
          height: 6,
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          child: pw.Row(children: [
            if (filled > 0)
              pw.Expanded(
                flex: filled,
                child: pw.Container(
                    height: 6,
                    color: _severityColor(bar.severity) == PdfColors.black
                        ? PdfColors.blueGrey700
                        : _severityColor(bar.severity)),
              ),
            pw.Expanded(
              flex: 1000 - filled,
              child: pw.SizedBox(height: 6),
            ),
          ]),
        ),
      ),
      pw.SizedBox(
        width: 150,
        child: pw.Text(amountText,
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(
                fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(
        width: 48,
        child: pw.Text('${bar.sharePct.toStringAsFixed(1)}%',
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.blueGrey)),
      ),
    ]),
  );
}
