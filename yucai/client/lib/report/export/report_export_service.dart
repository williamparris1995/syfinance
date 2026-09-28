/// F45 报告导出 —— 编排服务(ADR-3/ADR-4)。
///
/// 纯 Dart 编排:`doc + format(pdf|md)` → bytes/string → 默认文件名 →
/// 保存/打开。IO 全走注入缝([FileSavePickerFn]/[WriteBytesFn]/
/// [LaunchUrlFn])—— 本文件零 FilePicker/url_launcher/flutter 依赖
/// (硬约束:service 可被 presentation 调;具体平台实现由 T2 的页面
/// handler 注入,照 settings `_showExportArchive` / feedback_launcher
/// `LaunchUrlFn` 先例)。
///
/// 依赖方向:仅 report domain + 本域布局树/两渲染器。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/export/markdown_report_renderer.dart';
import 'package:yucai_client/report/export/pdf_report_renderer.dart';
import 'package:yucai_client/report/export/report_export_layout.dart';

/// 保存对话框缝(FilePicker.saveFile 同形;返回路径,null = 用户取消)。
typedef FileSavePickerFn =
    Future<String?> Function({
      String? dialogTitle,
      String? fileName,
      Uint8List? bytes,
    });

/// 字节落盘缝(dart:io File.writeAsBytes 同形)。
typedef WriteBytesFn = Future<void> Function(String path, List<int> bytes);

/// 打开文件缝(url_launcher.launchUrl(Uri.file) 同形,照 feedback_launcher
/// LaunchUrlFn 范式;返回是否成功,失败由调用方 toast 兜底)。
typedef LaunchUrlFn = Future<bool> Function(Uri url);

/// Noto 字体字节源缝(生产 = rootBundle.load;测试 = dart:io 直读)。
typedef FontSourceFn = Future<ByteData> Function();

/// 导出格式(FR-1:.pdf / .md 切换)。
enum ReportExportFormat {
  pdf('pdf'),
  markdown('md');

  const ReportExportFormat(this.ext);

  /// 文件扩展名(不含点)。
  final String ext;
}

/// 导出编排服务:渲染 + 默认文件名 + 保存/打开(经注入缝)。
class ReportExportService {
  const ReportExportService({
    required this.savePicker,
    required this.writeBytes,
    required this.launchUrl,
    required this.fontSource,
  });

  /// 保存对话框缝(生产 = FilePicker.saveFile 包装)。
  final FileSavePickerFn savePicker;

  /// 字节落盘缝(生产 = File.writeAsBytes 包装)。
  final WriteBytesFn writeBytes;

  /// 打开文件缝(生产 = url_launcher.launchUrl 包装)。
  final LaunchUrlFn launchUrl;

  /// Noto 字体字节源缝(生产 = rootBundle.load)。
  final FontSourceFn fontSource;

  /// 默认文件名:「御财财务报告-{期标签安全化}.{ext}」(FR-1,如
  /// 「御财财务报告-2026年08月.pdf」;安全化见 [safeFileStem])。
  String defaultFileName(ReportDocument doc, ReportExportFormat format) =>
      '御财财务报告-${safeFileStem(doc.period)}.${format.ext}';

  /// 导出并保存:渲染 → 保存对话框(默认名)→ 落盘。
  ///
  /// 返回落盘路径;**用户取消 → null,零文件写入零状态变化**(FR-1)。
  Future<String?> exportAndSave(
    ReportDocument doc,
    ReportExportFormat format,
  ) async {
    final layout = ReportExportLayout.build(doc);
    final fileName = defaultFileName(doc, format);
    final Uint8List bytes;
    switch (format) {
      case ReportExportFormat.pdf:
        bytes = await renderPdf(layout, fontSource: fontSource);
      case ReportExportFormat.markdown:
        // F46 LLM 输入友好:纯 UTF-8 文本。
        bytes = Uint8List.fromList(utf8.encode(renderMarkdown(layout)));
    }
    final path = await savePicker(
      dialogTitle: '导出财务报告',
      fileName: fileName,
      bytes: bytes,
    );
    if (path == null) return null; // 取消:不落盘。
    await writeBytes(path, bytes);
    return path;
  }

  /// 打开已导出文件(launchUrl(Uri.file);失败 false 由调用方兜底,
  /// 照 debt_detail 先例)。
  Future<bool> openExported(String path) => launchUrl(Uri.file(path));
}
