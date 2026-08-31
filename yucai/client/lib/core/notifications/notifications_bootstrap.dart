import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/notifications/local_notifier_adapter.dart';
import 'package:yucai_client/core/notifications/single_instance_guard.dart';
import 'package:yucai_client/core/notifications/tray_controller.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';

/// 通知/托盘/自启 bootstrap(FR-1..FR-5 接线;仅 Windows)。
/// main 在 runApp 前调用 [bootstrapNotifications](单实例守卫在更早处)。
/// 错误隔离:通知是附属功能,任一环节失败只降级不阻断 app 启动(review R1)。
Future<void> bootstrapNotifications(AppDatabase db) async {
  if (!notificationsSupported()) return;
  try {
    await _bootstrap(db);
  } catch (e) {
    // ignore: avoid_print — 附属功能降级,不阻断主程序。
    print('notifications bootstrap degraded: $e');
  }
}

Future<void> _bootstrap(AppDatabase db) async {
  final source = DriftDueSource(db);
  final logStore = DriftReminderLogStore(db);

  void focusMainWindow() {
    // fire-and-forget:void 回调内不 await(通知点击的聚焦不阻塞发送)。
    windowManager.show();
    windowManager.focus();
  }

  // 通知 adapter 独立隔离:失败只丢 toast,托盘/调度照常
  // (user-acceptance 修复:此前整段一个 catch,一步失败全栈消失)。
  final adapter = LocalNotifierAdapter(onNotificationClick: focusMainWindow);
  try {
    await adapter.initialize();
  } catch (e) {
    // ignore: avoid_print
    print('notifications: adapter init degraded: $e');
  }
  final scanner = DueScanner(source: source, notifier: adapter, logStore: logStore);

  // autoRecord 调度(R7-C):双模式常跑,经模板双源 repo 写穿透。
  final autoScheduler = AutoRecordScheduler(
    templates: TemplateRepoAutoRecord(getIt<TemplateRepository>()),
    notifier: adapter,
  );

  Future<void> runAutoRecord() async {
    await autoScheduler.run(DateTime.now());
  }

  final tray = TrayController(
    scan: () => scanner.scan(DateTime.now()),
    autoRecord: runAutoRecord,
  );
  await tray.start();

  // 回网触发(review R2 polish):绑定模式断网期间的 autoRecord 延迟落账,
  // 网络恢复即刻补齐(spec grill #0「回网后一次性补齐」的完整语义;
  // tick 日门控会让日内回网等到次日)。
  StreamSubscription<bool>? netSub;
  netSub = getIt<ConnectivityGateway>().online.listen((online) {
    if (online) {
      runAutoRecord().catchError((Object _) {});
    }
  });
  _netSub = netSub;

  // 次实例信号:唤起主窗口(FR-4)。
  SingleInstanceGuard.startWatching(focusMainWindow);

  // 开机自启默认开(spec FR-3;appName 与 Inno 卸载清理段一致)。
  // ignore: unawaited_futures
  LaunchAtStartup.instance.setup(
    appName: 'yucai_client',
    appPath: Platform.resolvedExecutable,
  );
  await LaunchAtStartup.instance.enable();
}

/// 单实例判定 + 次实例信号。返回 false = 本进程是次实例,main 应直接退出。
Future<bool> acquireSingleInstance() async {
  if (!notificationsSupported()) return true;
  if (await SingleInstanceGuard.isFirst()) return true;
  await SingleInstanceGuard.signalExistingAndExit();
  return false;
}

// ignore: unused_element — 回网订阅持有(防 GC;生命周期=进程)。
StreamSubscription<bool>? _netSub;
