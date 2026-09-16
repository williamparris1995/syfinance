// F24 结构守护:WinSparkle 版本字符串口径 —— exe 的 ProductVersion/FileVersion
// 字符串必须为 X.Y.Z(不含 +N)。WinSparkle 0.8.1 读 ProductVersion 字符串与
// appcast(sparkle:version=X.Y.Z)做 Sparkle 语义比较,「+N」的「+」被归为
// 字符串段 → 按「1.5 > 1.5b3」规则恒判已装版更旧 → 已装最新版仍弹可更新(死循环)。
// 实测依据:引擎 settings.h GetAppBuildVersion → GetVerInfoField("ProductVersion")
// + updatechecker.cpp CompareVersions;修复 = runner/CMakeLists.txt 注入
// FLUTTER_VERSION_XYZ、Runner.rc 版本字符串改用之(+N 只留数值 FILEVERSION 第 4 段)。
// CWD=包根(flutter test 惯例,app_icon_struct_test 同前提)。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runner/CMakeLists.txt 注入 FLUTTER_VERSION_XYZ = MAJOR.MINOR.PATCH(F24)', () {
    final cmake = File('windows/runner/CMakeLists.txt').readAsStringSync();
    expect(
      cmake,
      contains(
        r'FLUTTER_VERSION_XYZ=\"${FLUTTER_VERSION_MAJOR}.${FLUTTER_VERSION_MINOR}.${FLUTTER_VERSION_PATCH}\"',
      ),
      reason: '版本字符串宏必须由 MAJOR.MINOR.PATCH 拼接(不含 +N)',
    );
  });

  test('Runner.rc 版本字符串用 FLUTTER_VERSION_XYZ,不用含 +N 的原文 FLUTTER_VERSION(F24)', () {
    final rc = File('windows/runner/Runner.rc').readAsStringSync();
    expect(rc, contains('#if defined(FLUTTER_VERSION_XYZ)'));
    expect(rc, contains('#define VERSION_AS_STRING FLUTTER_VERSION_XYZ'));
    // 原文 FLUTTER_VERSION(非 _XYZ 后缀)不得再作为 VERSION_AS_STRING 来源。
    expect(
      rc,
      isNot(RegExp(r'#define VERSION_AS_STRING FLUTTER_VERSION(?!_XYZ)')),
      reason: 'FLUTTER_VERSION 原文含 +N,进字符串即复现更新死循环',
    );
  });
}
