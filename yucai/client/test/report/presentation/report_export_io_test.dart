/// F45 T2 生产缝 report_export_io 单测:唯一可测边界 = launchUrl 的
/// exists 前置(FR-4 spec:「打开」入口 launchUrl(Uri.file),exists 检查;
/// 文件被移动/删除 → 前置失败,不触平台通道,页面兜底 toast)。其余三缝
/// 为平台通道直通,行为经页面注入缝测试覆盖(financial_report_page_export_test)。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/report_export_io.dart';

void main() {
  test('launchUrl缝_目标文件不存在_返回失败不触平台(exists 前置)', () async {
    final service = createReportExportService();
    final missing =
        Uri.file('${Directory.systemTemp.path}/yucai-t2-not-exist.pdf');
    expect(File.fromUri(missing).existsSync(), isFalse,
        reason: '前置条件:目标确实不存在');
    final ok = await service.launchUrl(missing);
    expect(ok, isFalse, reason: '文件不存在 → 前置失败(FR-4),页面兜底 toast');
  });

/// 反馈③加固(2026-09-28):writeExportedBytesGuarded 三态——不存在→写;
/// 存在但长度不符(平台写半)→覆写完整字节;存在且等长→零触碰(幂等)。
group('writeExportedBytesGuarded 长度校验守卫', () {
  test('文件不存在 → 写入完整字节', () async {
    final dir = await Directory.systemTemp.createTemp('yucai_exp_io');
    final p = '${dir.path}${Platform.pathSeparator}a.pdf';
    await writeExportedBytesGuarded(p, [1, 2, 3, 4]);
    expect(File(p).lengthSync(), 4);
    await dir.delete(recursive: true);
  });

  test('存在但长度不符(平台写半) → 覆写完整字节', () async {
    final dir = await Directory.systemTemp.createTemp('yucai_exp_io');
    final p = '${dir.path}${Platform.pathSeparator}b.pdf';
    await File(p).writeAsBytes([9, 9]); // 模拟平台只写了两个字节
    await writeExportedBytesGuarded(p, [1, 2, 3, 4, 5, 6]);
    expect(File(p).lengthSync(), 6);
    expect(File(p).readAsBytesSync(), [1, 2, 3, 4, 5, 6]);
    await dir.delete(recursive: true);
  });

  test('存在且等长 → 零触碰(修改时间不变语义以内容为准,断言内容原样)', () async {
    final dir = await Directory.systemTemp.createTemp('yucai_exp_io');
    final p = '${dir.path}${Platform.pathSeparator}c.pdf';
    await File(p).writeAsBytes([1, 2, 3]);
    final before = File(p).lastModifiedSync();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await writeExportedBytesGuarded(p, [1, 2, 3]);
    // 等长跳过:文件未被重写(mtime 不前进)。
    expect(!File(p).lastModifiedSync().isAfter(before), isTrue,
        reason: '等长时应跳过写入(幂等)');
    await dir.delete(recursive: true);
  });
});
}
