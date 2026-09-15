import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/demo/demo_seed.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/notifications_bootstrap.dart';

/// 全局错误落盘(用户验收辅助):release 无控制台,报错写
/// AppData/com.yucai/yucai_client/error.log(单文件追加,cap 64KB 截断)。
Future<void> _logError(String line) async {
  try {
    final dir = await getApplicationSupportDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}error.log');
    var prev = await f.exists() ? await f.readAsString() : '';
    if (prev.length > 65536) prev = prev.substring(prev.length - 32768);
    final nl = String.fromCharCode(10); // 避免源码内转义歧义
    await f.writeAsString(
        '$prev$nl[${DateTime.now().toIso8601String()}] $line',
        flush: true);
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    _logError('FLUTTER ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    _logError('UNCAUGHT $e');
    return true; // 已处理:避免 release 下静默丢失
  };

  // 单实例守卫(FR-4):次实例写信号唤起既有窗口后退出。
  // Windows runner 在 Dart main 前已建窗口,return 不终止引擎 → 必须 exit。
  if (!await acquireSingleInstance()) {
    exit(0);
  }
  await windowManager.ensureInitialized();
  // F29 自定义标题栏(FR-1):TitleBarStyle.hidden 只隐藏系统标题栏,原生
  // 窗口边框/阴影/Snap 贴靠/拖边缩放/Win 快捷键全保留(NFR-1)——标题栏
  // 内容由 AppTitleBar(app.dart builder 层)接管。照 window_manager 文档
  // 以 waitUntilReadyToShow 应用 WindowOptions(不 await,不阻塞后续
  // bootstrap/runApp;回调内 show+focus 为文档最小接线,与 runner 已显窗
  // 幂等)。F22 启动期 hide(关闭到托盘)与本处 hidden 无冲突(ADR-1)。
  windowManager.waitUntilReadyToShow(
    // review S1:与 builder 挂栏同门(仅 Windows hidden),防 linux/macos
    // 构建得到无栏无钮窗口;Platform 非 const,故 WindowOptions 去 const。
    WindowOptions(
      titleBarStyle:
          Platform.isWindows ? TitleBarStyle.hidden : TitleBarStyle.normal,
    ),
    () async {
      await windowManager.show();
      await windowManager.focus();
    },
  );

  await configureDependencies();
  // 演示种子(R7 用户验收):--dart-define=YUCAI_DEMO_SEED=1 时向空库注入
  // 跨模块演示数据(走真实数据源路径)。默认构建恒不执行。
  if (const bool.fromEnvironment('YUCAI_DEMO_SEED')) {
    await seedDemoData(getIt<AppDatabase>());
  }
  // 托盘常驻 + 到期提醒 + 自启(仅 Windows;R7-B)。
  await bootstrapNotifications(getIt<AppDatabase>());
  runApp(const YuCaiApp());
}
