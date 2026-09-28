/// F45 T1 导出编排服务单测(ADR-4):IO 全走注入缝(FileSavePickerFn/
/// WriteBytes/LaunchUrl),零 FilePicker/url_launcher 直接依赖 —— 测试以
/// fake 缝断言编排行为(默认文件名/取消零副作用/字节落盘/打开)。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/export/report_export_service.dart';

import 'export_fixture.dart';

/// 字体资产路径(测试以 dart:io 直读 —— 生产经注入缝 rootBundle)。
const fontAssetPath = 'assets/fonts/NotoSansSC-Regular.ttf';

void main() {
  late List<(String?, String?, Uint8List?)> picked;
  late List<(String, List<int>)> written;
  late List<Uri> launched;

  late ReportExportService service;

  setUp(() {
    picked = [];
    written = [];
    launched = [];
    service = ReportExportService(
      savePicker: ({dialogTitle, fileName, bytes}) async {
        picked.add((dialogTitle, fileName, bytes));
        return fileName == null ? null : 'C:/out/$fileName';
      },
      writeBytes: (path, bytes) async => written.add((path, bytes)),
      launchUrl: (url) async {
        launched.add(url);
        return true;
      },
      fontSource: () async =>
          ByteData.sublistView(await File(fontAssetPath).readAsBytes()),
    );
  });

  test('defaultFileName_期标签安全化加扩展名', () {
    expect(
      service.defaultFileName(
          fullDocument(), ReportExportFormat.pdf),
      '御财财务报告-2026年08月.pdf',
    );
    expect(
      service.defaultFileName(
          fullDocument(), ReportExportFormat.markdown),
      '御财财务报告-2026年08月.md',
    );
    final yearly = yearlyDocument();
    expect(
      service.defaultFileName(
          yearly, ReportExportFormat.pdf),
      '御财财务报告-2025年度.pdf',
    );
  });

  test('exportAndSave_pdf_渲染落盘并返回路径', () async {
    final path =
        await service.exportAndSave(fullDocument(), ReportExportFormat.pdf);
    expect(path, 'C:/out/御财财务报告-2026年08月.pdf');
    // 缝收到的默认名与字节同页(渲染在编排内完成)。
    expect(picked.single.$2, '御财财务报告-2026年08月.pdf');
    expect(picked.single.$3, isNotNull);
    expect(written, hasLength(1));
    expect(written.single.$1, path);
    expect(written.single.$2, isNotEmpty);
    // 落盘字节为 PDF(头标记)。
    expect(String.fromCharCodes(written.single.$2.take(5)), '%PDF-');
  });

  test('exportAndSave_markdown_utf8字符串落盘', () async {
    final path = await service.exportAndSave(
        fullDocument(), ReportExportFormat.markdown);
    expect(path, 'C:/out/御财财务报告-2026年08月.md');
    final text = utf8.decode(List<int>.from(written.single.$2));
    expect(text, startsWith('# 御财财务报告 2026 年 8 月'));
    expect(text, contains('## 诊断与建议'));
  });

  test('exportAndSave_取消_零副作用', () async {
    final cancelled = ReportExportService(
      savePicker: ({dialogTitle, fileName, bytes}) async => null,
      writeBytes: (path, bytes) async => written.add((path, bytes)),
      launchUrl: (url) async => true,
      fontSource: () async =>
          ByteData.sublistView(await File(fontAssetPath).readAsBytes()),
    );
    final path =
        await cancelled.exportAndSave(fullDocument(), ReportExportFormat.pdf);
    expect(path, isNull);
    expect(written, isEmpty, reason: '取消 = 零文件写入零状态变化(FR-1)');
  });

  test('openExported_经launch缝以file Uri打开', () async {
    final ok = await service.openExported('C:/out/御财财务报告-2026年08月.pdf');
    expect(ok, isTrue);
    expect(launched.single, Uri.file('C:/out/御财财务报告-2026年08月.pdf'));
  });
}
