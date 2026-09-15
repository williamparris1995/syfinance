// F23 FR-2/FR-3 结构守护:ICO 目录头解析,断言档位齐全。
// 解析依据:ICO = 6 字节头(reserved 2/type 2/count 2)+ 每帧 16 字节目录项
// (宽 1[0=256]/高 1/色彩数 1/保留 1/平面 2/位深 2/字节长 4/偏移 4)。
// CWD=包根(flutter test 惯例,first_close_dialog_test 同前提)。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 返回 {宽度: 帧字节长度}。
Map<int, int> icoEntries(String path) {
  final b = File(path).readAsBytesSync();
  expect(b[0], 0, reason: 'ICO reserved 高位=0');
  expect(b[1], 0, reason: 'ICO reserved 低位=0');
  expect(b[2] | (b[3] << 8), 1, reason: 'type=1(icon)');
  final count = b[4] | (b[5] << 8);
  expect(count, greaterThan(0), reason: '至少一帧');
  final sizes = <int, int>{};
  for (var i = 0; i < count; i++) {
    final o = 6 + i * 16;
    var w = b[o];
    if (w == 0) w = 256; // 256px 以 0 编码
    sizes[w] = b[o + 8] | (b[o + 9] << 8) | (b[o + 10] << 16) | (b[o + 11] << 24);
  }
  return sizes;
}

void main() {
  test('runner app_icon.ico 六档 16/24/32/48/64/256 且非空(F23 FR-2)', () {
    final e = icoEntries('windows/runner/resources/app_icon.ico');
    expect(e.keys.toSet(), {16, 24, 32, 48, 64, 256});
    for (final entry in e.entries) {
      expect(entry.value, greaterThan(0), reason: '${entry.key}px 帧非空');
    }
  });

  test('tray_icon.ico 为 16/24 简化形专用档(F23 FR-3)', () {
    final e = icoEntries('assets/tray_icon.ico');
    expect(e.keys.toSet(), {16, 24});
    for (final entry in e.entries) {
      expect(entry.value, greaterThan(0), reason: '${entry.key}px 帧非空');
    }
  });

  test('tray 16px 帧为 PNG 编码且非空(F23 FR-1 结构层)', () {
    // 帧=PNG(管线经 PIL 合成;魔法数 89 50 4E 47),颜色细样由管线常量
    // +人工验收承载;圆角遮罩下四角透明属预期,不做角落像素断言。
    final b = File('assets/tray_icon.ico').readAsBytesSync();
    final off = b[6 + 12] | (b[6 + 13] << 8) | (b[6 + 14] << 16) | (b[6 + 15] << 24);
    expect(b[off], 0x89, reason: 'PNG magic[0]');
    expect(b[off + 1], 0x50, reason: 'PNG magic[1]=P');
    expect(b[off + 2], 0x4E, reason: 'PNG magic[2]=N');
    expect(b[off + 3], 0x47, reason: 'PNG magic[3]=G');
    expect(b.length - off, greaterThan(100), reason: '16px 帧有实际数据');
  });
}
