/// F45 T3 —— NFR-2 性能门:典型报告(全章节 fixture)PDF 全链渲染
/// wall clock ≤ 2s(spec NFR-2「含字体加载,测试环境计时」;阈值即 spec
/// 值,不另留余量)。
///
/// 计时窗口 = 生产导出链全量:布局树 build → 字体真实 bytes 读入
/// (dart:io 直读,生产经 rootBundle 同源)→ Font.ttf 解析(~10MB 全量
/// Noto)→ pw 布局渲染 → doc.save()(含字体程序 zlib 压缩)。fixture
/// 构造不计入窗口,只计导出链。
///
/// **独立文件 = 冷字体前提**:renderPdf 的 `_cachedFont` 是进程级单例,
/// flutter test 每文件独立 isolate —— 本文件单测试即保证计时窗含字体
/// 解析(放既有 smoke 文件内会被先跑的测试预热,计时失真)。
///
/// 防空调转(照 mda_engine_perf 范式:证明计时链路算的是真数据):
/// 页数/锚点断言复用 pdf_report_renderer_test 既有 oracle(七章节至少
/// 每章一页 + 净资产锚点);字节级 helper 为该文件同款拷贝(测试私有
/// helper 跨文件不可共享)。
library;

import 'dart:io' show File, ZLibDecoder;
import 'dart:typed_data' show ByteData;

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/export/pdf_report_renderer.dart';
import 'package:yucai_client/report/export/report_export_layout.dart';

import 'export_fixture.dart';

/// 字体资产路径(测试以 dart:io 直读 —— 生产经注入缝 rootBundle)。
const _fontPath = 'assets/fonts/NotoSansSC-Regular.ttf'; // 测试 CWD = client 包根。

/// 字体真实 bytes 注入(计时窗含磁盘读 + Font.ttf 解析)。
Future<ByteData> _loadFont() async {
  final bytes = await File(_fontPath).readAsBytes();
  return ByteData.sublistView(bytes);
}

// —— 以下字节级 helper 与 pdf_report_renderer_test.dart 同款(拷贝,
//    独立文件保冷字体单例;推导见原文件注释)——

/// 解压 PDF 内全部小流(ToUnicode/内容流;跳过 >2MB 的字体程序流)。
String _inflateStreams(String latin1) {
  final out = StringBuffer();
  for (final m in RegExp(r'stream\r?\n(.*?)endstream', dotAll: true)
      .allMatches(latin1)) {
    final data = m.group(1)!;
    if (data.length > 2 * 1024 * 1024) continue;
    try {
      final inflated = ZLibDecoder().convert(data.codeUnits);
      out.write(String.fromCharCodes(inflated));
    } on FormatException {
      // 非压缩流(图片等):跳过。
    }
  }
  return out.toString();
}

/// 汉字 → ToUnicode CMap 里的 UTF-16BE 十六进制形式。
String _u16hex(String ch) =>
    ch.codeUnitAt(0).toRadixString(16).toUpperCase().padLeft(4, '0');

/// UTF-16BE 十六进制串 → 字符串(码点解析,与 _u16hex 互逆)。
String _fromU16Hex(String hex) {
  final units = <int>[];
  for (var i = 0; i + 4 <= hex.length; i += 4) {
    units.add(int.parse(hex.substring(i, i + 4), radix: 16));
  }
  return String.fromCharCodes(units);
}

/// 字节级文本抽取:内容流字形 id 经 ToUnicode bfchar 反查重建(空格以
/// 定位指令绘制,重建结果无空格)。
String _extractDrawnText(String latin1) {
  final streams = <String>[];
  for (final m
      in RegExp(r'stream\r?\n(.*?)endstream', dotAll: true).allMatches(latin1)) {
    final data = m.group(1)!;
    if (data.length > 2 * 1024 * 1024) continue;
    try {
      streams.add(String.fromCharCodes(ZLibDecoder().convert(data.codeUnits)));
    } on FormatException {
      // 非压缩流(图片等):跳过。
    }
  }
  final gidToText = <String, String>{};
  for (final s in streams) {
    if (!s.contains('beginbfchar')) continue;
    for (final m in RegExp(r'<([0-9A-Fa-f]{4})>\s*<([0-9A-Fa-f]{4})>').allMatches(s)) {
      gidToText[m.group(1)!.toUpperCase()] = m.group(2)!;
    }
  }
  final text = StringBuffer();
  for (final s in streams) {
    if (s.contains('beginbfchar')) continue;
    for (final m in RegExp(r'<([0-9A-Fa-f]{4}(?:[0-9A-Fa-f]{4})*)>').allMatches(s)) {
      final hex = m.group(1)!;
      for (var i = 0; i + 4 <= hex.length; i += 4) {
        final dst = gidToText[hex.substring(i, i + 4).toUpperCase()];
        if (dst != null) text.write(_fromU16Hex(dst));
      }
    }
  }
  return text.toString();
}

void main() {
  test('NFR-2:全章节报告 PDF 全链渲染(含字体加载)≤ 2s(wall clock)', () async {
    // —— 种子(不计入计时):全章节 fixture(预算+投资+诊断齐备)——
    final doc = fullDocument();

    // —— 计时窗口:build → 字体 bytes 读入+解析 → 渲染 → save ——
    final sw = Stopwatch()..start();
    final layout = ReportExportLayout.build(doc);
    final bytes = await renderPdf(layout, fontSource: _loadFont);
    sw.stop();
    // ignore: avoid_print
    print(
      'NFR-2 pdf full chain: ${layout.sections.length} sections, '
      '${bytes.length} bytes, ${sw.elapsedMilliseconds}ms (budget 2000ms)',
    );

    // —— 门:≤ 2s(spec NFR-2)——
    expect(sw.elapsedMilliseconds, lessThanOrEqualTo(2000));

    // —— 防空调转:真数据非空转(页数/锚点复用既有 oracle)——
    final latin1 = String.fromCharCodes(bytes);
    expect(latin1.startsWith('%PDF-'), isTrue, reason: 'PDF 头');
    final pageCount =
        '/Type/Page'.allMatches(latin1).length - '/Type/Pages'.allMatches(latin1).length;
    expect(pageCount, greaterThanOrEqualTo(7), reason: '七章节至少每章一页');
    final text = _extractDrawnText(latin1);
    expect(text, contains('期末净资产'), reason: '净资产锚点(总览 hero)');
    // 字形映射在位(tofu 防回归;smoke 集合首二字)。
    final inflated = _inflateStreams(latin1);
    expect(inflated, contains(_u16hex('御')), reason: '字形映射非空');
  });
}
