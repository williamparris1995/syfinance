import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/demo/demo_seed.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/notifications_bootstrap.dart';
import 'package:yucai_client/core/notifications/window_state.dart';

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
  // F30 窗口状态记忆(S1,组合根接线注):控制器在此手工构造而非 injectable
  // 图 —— 恢复须发生在下方 waitUntilReadyToShow 回调内,而该回调与
  // configureDependencies 的完成**无时序保证**,getIt 此时可能尚未建图;
  // restore 内部以 memo future 等待 secure_storage 读完成,竞态安全。
  // const FlutterSecureStorage() 与 injection.dart 1a 注册的为同一 const
  // 规范实例,共享同一后端。
  final windowState = WindowStateController(const FlutterSecureStorage());
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
      // F30 恢复(S1,排序依据 window_manager 0.5.2 lib/src/window_manager
      // .dart waitUntilReadyToShow 源码):`if (await isMaximized()) await
      // unmaximize();` 等启动副作用全部 await 决议**之后**才调用本回调
      // —— 故回调内的恢复 maximize() 不会被插件启动期 unmaximize 覆盖
      // (AppTitleBar initState P1 暗桩注释所指「F30 恢复最大化须在
      // isMaximized?unmaximize 副作用决议后恢复」即落位于此)。回调内
      // 顺序:restore(先 setBounds 后 maximize,内部已定序)→ show →
      // focus —— 恢复先于 show,避免窗口可见后的几何跳变;出屏/异常
      // 尺寸时 restore 零调用,走 runner 默认(10,10 左上 1280×720,非居中——既有 runner 行为)(S2 安全回退)。
      await windowState.restore();
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
  // F30 挂窗口几何保存监听(组合根接线;挂 main 而非 bootstrapNotifications
  // —— 后者仅 Windows 生效,而 main 的 windowManager 用法是无平台门的):
  // move/resize/maximize/unmaximize → 防抖 500ms 落盘 secure_storage。
  // F22「关闭=hide 到托盘」与真 exit 均天然覆盖 —— 保存不依赖关闭时机,
  // 几何每次变更后即持久化,关闭时无需补存。
  windowState.start();
  runApp(const YuCaiApp());
}
