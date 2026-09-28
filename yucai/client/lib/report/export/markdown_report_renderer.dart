/// F45 报告导出 —— Markdown 渲染器(ADR-2):布局树 → UTF-8 字符串。
///
/// 与 PDF 渲染器共吃同一 [ReportExportLayout](同源保证);本文件零数字
/// 计算,仅做结构映射(LLD 契约):
/// - `#` 文档标题 / `##` 章节 / `###` 块标题;
/// - 表格 `| | |` + `---` 分隔行,emphasized 行 `**…**` 加粗;
/// - bars → `- label:amount (pct%)`,预算 showMax 行 `actual / limit`,
///   severity 符号前缀(🔴 risk / ⚠ warn / ℹ info);
/// - 附注 → `> ` 引用块(标题加粗 + `· ` 行);
/// - 诊断发现两段(结论 + 缩进建议行)。
///
/// 纯 Dart(仅 dart 标准库 + 本域布局树);F46 LLM 输入友好。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/export/report_export_layout.dart';

/// severity → Markdown 符号前缀(设计 LLD:🔴/⚠/ℹ;null → 无前缀)。
String _severityPrefix(MdaSeverity? severity) => switch (severity) {
      MdaSeverity.risk => '🔴 ',
      MdaSeverity.warn => '⚠ ',
      MdaSeverity.info => 'ℹ ',
      null => '',
    };

/// 布局树 → Markdown 文档字符串。
String renderMarkdown(ReportExportLayout layout) {
  final out = StringBuffer();
  out.writeln('# ${layout.title}');

  for (final section in layout.sections) {
    out.writeln();
    out.writeln('## ${section.title}');
    for (final block in section.blocks) {
      switch (block) {
        case ReportTextBlock(:final text, :final severity):
          if (severity == null) {
            // 普通文本(脚注/分组头/健康行):单行直出。
            out.writeln(text);
          } else {
            // 诊断发现:结论行带符号前缀,「建议:」段缩进续行。
            final lines = text.split('\n');
            out.writeln('- ${_severityPrefix(severity)}${lines.first}');
            for (final rest in lines.skip(1)) {
              out.writeln('  $rest');
            }
          }
        case ReportKvBlock(:final title, :final rows):
          if (title != null) out.writeln('### $title');
          for (final row in rows) {
            out.writeln('- ${row.label}:${row.value}');
          }
        case ReportTableBlock(:final title, :final header, :final rows):
          if (title != null) out.writeln('### $title');
          out.writeln('| ${header.join(' | ')} |');
          out.writeln('| ${List.filled(header.length, '---').join(' | ')} |');
          for (final row in rows) {
            final cells = row.emphasized
                ? [for (final c in row.cells) '**$c**']
                : row.cells;
            out.writeln('| ${cells.join(' | ')} |');
          }
        case ReportBarsBlock(
            :final title,
            :final totalCents,
            :final showMax,
            :final bars
          ):
          if (title != null) out.writeln('### $title');
          for (final bar in bars) {
            final amount = showMax && bar.maxCents != null
                ? '${fmtExportCents(bar.amountCents)} / ${fmtExportCents(bar.maxCents!)}'
                : fmtExportCents(bar.amountCents);
            out.writeln('- ${_severityPrefix(bar.severity)}'
                '${bar.label}:$amount(${bar.sharePct.toStringAsFixed(1)}%)');
          }
          if (totalCents != null) {
            out.writeln('- 合计:${fmtExportCents(totalCents)}');
          }
        case ReportNoteBlock(:final title, :final lines):
          out.writeln('> **$title**');
          for (final line in lines) {
            out.writeln('> · $line');
          }
      }
    }
  }
  return out.toString();
}
