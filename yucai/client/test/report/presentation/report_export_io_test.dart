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
}
