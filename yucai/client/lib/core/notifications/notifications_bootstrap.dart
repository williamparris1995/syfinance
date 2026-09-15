import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yucai_client/app/router.dart' show rootNavigatorKey;
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/app_exit_port.dart';
import 'package:yucai_client/core/notifications/app_updater.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/notifications/local_notifier_adapter.dart';
import 'package:yucai_client/core/notifications/single_instance_guard.dart';
import 'package:yucai_client/core/notifications/tray_controller.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/di/injection.dart';
// 组合根豁免(core→settings/transaction 禁向在本文件豁免):bootstrap 是
// 唯一接线点 —— 首关对话框组件(settings 模块)在此映射为 core 侧
// FirstCloseChoice;transaction 本地 DS 在此映射为托盘数据头(F25 ADR-1,
// core/notifications 不 import transaction 模块,缝 = TrayHeadProvider)。
import 'package:yucai_client/settings/widgets/first_close_dialog.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart'
    show SummaryScope;

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

  // F25 ADR-1 接线(组合根):托盘数据头摘要 provider —— 本地 DS
  // `summary(year, month, {scope})` 单一查询点,day+month 两次调用映射
  // TrayHeadData(spec FR-1 复用第一,不新造口径);数据头恒本地口径
  // (design NonGoals:绑定态远程口径差不引入)。查询失败 → null →
  // 控制器渲染「--」占位(NFR-1;controller 侧还有防御性 try)。
  final txnLocal = getIt<TransactionLocalDataSource>();
  Future<TrayHeadData?> trayHead() async {
    try {
      final now = DateTime.now();
      final day = await txnLocal.summary(now.year, now.month,
          scope: SummaryScope.day, day: now.day);
      final month = await txnLocal.summary(now.year, now.month,
          scope: SummaryScope.month);
      return TrayHeadData(
        todayIncomeCents: day.incomeCents,
        todayExpenseCents: day.expenseCents,
        monthBalanceCents: month.netCents,
      );
    } catch (_) {
      return null;
    }
  }

  // F25 ADR-4 接线:「记一笔」导航闭包 —— contextResolver 同源 context
  // (rootNavigatorKey)→ GoRouter push;无 context(极端时序)→ no-op,
  // 控制器侧已 show/focus 兜底(降级不炸)。
  Future<void> navigateNewTransaction() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push('/transactions/new');
  }

  // F24 FR-6 接线(组合根):托盘「御财 vX.Y.Z」版本提供者 ——
  // PackageInfo.version 自构建注入(pubspec 单源派生 NFR-2,零构建耦合,
  // design LLD 二选一定案);查询失败由控制器降级纯「御财」。
  Future<String?> trayVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  // F22 接线(T4,各注入对应 FR 见行尾;无注入不炸由构造默认值保证,
  // 单测覆盖参数组合,bootstrap 手工接线以 code review 承接):
  // - settings: FR-2/3/5 关闭行为/首关标记/扫描间隔(TraySettings.load
  //   在 injection.dart 2c 同位 ThemeSettings 完成);
  // - changeTriggers: FR-4/ADR-1 drift watch → 变更即扫
  //   (paymentScheduleEntries=债务期次,transactionTemplates=自动记账规则,
  //   transactions=F25 数据头刷新面 —— 交易增删改即重设托盘菜单);
  // - closePrompt/contextResolver: FR-3/ADR-4 首关对话框(组合根把
  //   settings 模块的 FirstCloseDialogResult 映射为 core 侧
  //   FirstCloseChoice;context 取自 router.rootNavigatorKey,取不到 →
  //   controller 兜底 hide);
  // - headProvider/newTransactionNav: F25 FR-1/2 数据头 + 记一笔(上方
  //   两个闭包,组合根跨模块接线)。
  final tray = TrayController(
    scan: () => scanner.scan(DateTime.now()),
    autoRecord: runAutoRecord,
    settings: getIt<TraySettings>(),
    changeTriggers: [
      db.select(db.paymentScheduleEntries).watch().map((_) {}),
      db.select(db.transactionTemplates).watch().map((_) {}),
      db.select(db.transactions).watch().map((_) {}),
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
    headProvider: trayHead,
    versionProvider: trayVersion,
    newTransactionNav: navigateNewTransaction,
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

  // F24 FR-4/5 + ADR-4:auto_updater 初始化(WinSparkle)挂末尾 ——
  // setFeedURL 即启动默认 1 天后台自动检查;验签公钥烤于 Runner.rc 的
  // DSAPub/DSAPEM 资源(占位状态与替换流程见 app_updater.dart)。
  // 附属降级:任一环节失败仅 print 英文,不阻断 app 启动(NFR-1;
  // 手动「检查更新」菜单项不受初始化成败影响,恒可用)。
  await bootstrapAppUpdater();
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
