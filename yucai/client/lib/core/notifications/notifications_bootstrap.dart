import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import 'package:yucai_client/app/router.dart' show rootNavigatorKey;
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/app_exit_port.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/notifications/local_notifier_adapter.dart';
import 'package:yucai_client/core/notifications/single_instance_guard.dart';
import 'package:yucai_client/core/notifications/tray_controller.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/di/injection.dart';
// 组合根豁免(core→settings 禁向在本文件豁免):bootstrap 是唯一接线点,
// 首关对话框组件(settings 模块)在此映射为 core 侧 FirstCloseChoice。
import 'package:yucai_client/settings/widgets/first_close_dialog.dart';
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

  // F22 接线(T4,各注入对应 FR 见行尾;无注入不炸由构造默认值保证,
  // 单测覆盖参数组合,bootstrap 手工接线以 code review 承接):
  // - settings: FR-2/3/5 关闭行为/首关标记/扫描间隔(TraySettings.load
  //   在 injection.dart 2c 同位 ThemeSettings 完成);
  // - changeTriggers: FR-4/ADR-1 两张表 drift watch → 变更即扫
  //   (paymentScheduleEntries=债务期次,transactionTemplates=自动记账规则);
  // - closePrompt/contextResolver: FR-3/ADR-4 首关对话框(组合根把
  //   settings 模块的 FirstCloseDialogResult 映射为 core 侧
  //   FirstCloseChoice;context 取自 router.rootNavigatorKey,取不到 →
  //   controller 兜底 hide)。
  final tray = TrayController(
    scan: () => scanner.scan(DateTime.now()),
    autoRecord: runAutoRecord,
    settings: getIt<TraySettings>(),
    changeTriggers: [
      db.select(db.paymentScheduleEntries).watch().map((_) {}),
      db.select(db.transactionTemplates).watch().map((_) {}),
    ],
    closePrompt: (context) async {
      final result = await showFirstCloseDialog(context);
      return switch (result) {
        FirstCloseDialogResult.minimize => FirstCloseChoice.minimize,
        FirstCloseDialogResult.quit => FirstCloseChoice.quit,
        null => null,
      };
    },
    contextResolver: () => rootNavigatorKey.currentContext,
  );
  await tray.start();

  // F22:控制器与退出 port 进 getIt(照 injection.dart 手工注册先例;
  // TrayAppExit.onExit=tray.stop 是函数注入,不在 injectable 图内)。
  // 设置页经 AppExitPort.exitApp 消费;退出清理失败由其 try/finally
  // 保证仍 exit(0)。
  getIt.registerSingleton<TrayController>(tray);
  getIt.registerSingleton<AppExitPort>(TrayAppExit(tray.stop));

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
