/// F45 T1 PDF 渲染器 smoke 单测(ADR-5:bytes 层断言非空+页数+字体嵌入,
/// 不做 byte-golden —— pdf 元数据含时间戳不稳定)。
///
/// 「pdf 包回读」= 字节级解析:页数(对象字典非压缩,数 `/Type /Page`)
/// + 字体(`/FontFile2`)+ 文本片段(内容流 FlateDecode 压缩且 TTF 文本
/// 用字形 id 书写,文本以 ToUnicode CMap 的 UTF-16BE 十六进制出现 ——
/// 解压小流后按码点断言)。
library;


import 'dart:typed_data';
import 'dart:io' show File, ZLibDecoder;

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/export/pdf_report_renderer.dart';
import 'package:yucai_client/report/export/report_export_layout.dart';

import 'export_fixture.dart';

/// 字体资产路径(测试以 dart:io 直读 —— 生产经注入缝 rootBundle)。
const fontPath =
    'assets/fonts/NotoSansSC-Regular.ttf'; // 测试 CWD = client 包根。

Future<ByteData> _loadFont() async {
  final bytes = await File(fontPath).readAsBytes();
  return ByteData.sublistView(bytes);
}

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

/// 汉字 → ToUnicode CMap 里的 UTF-16BE 十六进制形式(独立推导:码点查表,
/// 非被测代码逻辑)。
String _u16hex(String ch) =>
    ch.codeUnitAt(0).toRadixString(16).toUpperCase().padLeft(4, '0');

void main() {
  test('renderPdf_bytes非空且PDF头_页数不小于章节数', () async {
    final bytes =
        await renderPdf(ReportExportLayout.build(fullDocument()), fontSource: _loadFont);
    expect(bytes, isNotEmpty);
    // 对象字典未压缩:latin1 头与 /Type /Page 计数可行。
    final latin1 = String.fromCharCodes(bytes);
    expect(latin1.startsWith('%PDF-'), isTrue);
    final pageCount =
        '/Type/Page'.allMatches(latin1).length - '/Type/Pages'.allMatches(latin1).length;
    expect(pageCount, greaterThanOrEqualTo(7), reason: '七章节至少每章一页');
  });

  test('renderPdf_嵌入字体与文本字形回读', () async {
    final bytes = await renderPdf(
        ReportExportLayout.build(fullDocument()),
        fontSource: _loadFont);
    final latin1 = String.fromCharCodes(bytes);
    // TrueType 字体程序作为 FontFile2 流嵌入。
    expect(latin1, contains('/FontFile2'));
    // ToUnicode CMap 中含冒烟字形(御财务报告/储蓄率/资产负债,及诊断文案)。
    final inflated = _inflateStreams(latin1);
    for (final ch in ['御', '财', '务', '报', '告', '储', '蓄', '率', '资', '产', '负', '债']) {
      expect(inflated, contains(_u16hex(ch)), reason: '字形 $ch 未映射(空/tofu 风险)');
    }
  });

  test('renderPdf_闲置订阅冒烟文本渲染无异常', () async {
    // 风险集样本字(用户数据动态字):R4 闲置订阅结论文案用字 —— 手工
    // 布局注入冒烟串「御财务报告储蓄率资产负债闲置订阅」,验证渲染不抛
    // 异常且字形全部映射(零 tofu)。
    const smoke = '御财务报告储蓄率资产负债闲置订阅';
    const layout = ReportExportLayout(
      title: '御财财务报告 2026 年 8 月',
      periodLabel: '2026 年 8 月',
      sections: [
        ReportExportSection(title: '冒烟', blocks: [
          ReportTextBlock(text: smoke),
        ]),
      ],
    );
    final bytes = await renderPdf(layout, fontSource: _loadFont);
    final inflated = _inflateStreams(String.fromCharCodes(bytes));
    for (final ch in smoke.runes) {
      expect(inflated, contains(_u16hex(String.fromCharCode(ch))),
          reason: '字形 ${String.fromCharCode(ch)} 未映射(tofu 风险)');
    }
  });

  test('字体资产_static实例非variable_fvar缺席', () async {
    final bd = await _loadFont();
    // sfnt 目录:offset 0 版本、4 numTables、12 起表记录(tag+checksum+
    // offset+length 各 4B)。
    expect(bd.getUint32(0), 0x00010000, reason: 'TrueType 轮廓(非 OTTO/CFF)');
    final numTables = bd.getUint16(4);
    expect(numTables, greaterThan(0), reason: '表目录非空(简单解析)');
    final tags = <String>{
      for (var i = 0; i < numTables; i++)
        String.fromCharCodes(
            Uint8List.sublistView(bd.buffer.asUint8List(), 12 + i * 16, 12 + i * 16 + 4)),
    };
    expect(tags, containsAll(['glyf', 'cmap', 'head']));
    expect(tags, isNot(contains('fvar')), reason: 'variable font 标记不得存在');
    expect(bd.lengthInBytes, greaterThan(9 * 1024 * 1024), reason: '全量 CJK(~10MB)');
  });
}
