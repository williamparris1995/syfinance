import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
// F66-T3 退出钩子(组合根豁免区):仅 import domain port —— core/
// notifications 不触 assistant/data,引擎生产实现经 getIt 解析。
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/app/router.dart' show rootNavigatorKey;
import 'package:yucai_client/core/connectivity/connectivity_gateway.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/app_exit_port.dart';
import 'package:yucai_client/core/notifications/app_updater.dart';
import 'package:yucai_client/core/notifications/credit_card_due_source.dart';
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_store.dart';
import 'package:yucai_client/core/notifications/inbox/inbox_syncer.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';
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
  // 催办配置 provider:每次扫描实时读 TraySettings —— 设置页改提前天数/
  // 重复间隔即时生效,不重建接线(2026-09 催办模式)。
  final settings = getIt<TraySettings>();
  DueReminderConfig reminderConfig() => DueReminderConfig(
        advanceDays: settings.reminderAdvanceDays,
        repeatHours: settings.reminderRepeatInterval.hours,
      );

  // 双源:债务期次(既有)+ 信用卡还款日(有欠款才提醒)。
  // T5 注(2026-09 到期常显提醒):本局部实例即「既有那份」MultiDueSource
  // —— scanner 与读侧 provider 两处共用同一实例(NFR-1 候选零新源,
  // design ADR-1 分叉仅在去重/发送),scanner 装配零变化。
  final source = MultiDueSource([
    DriftDueSource(db, configProvider: reminderConfig),
    CreditCardDueSource(db, configProvider: reminderConfig),
  ]);
  final logStore = DriftReminderLogStore(db);
  final dismissalStore = ReminderDismissalStore(db);

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
  final scanner = DueScanner(
    source: source,
    notifier: adapter,
    logStore: logStore,
    policyProvider: () => DueReminderPolicy(reminderConfig()),
    dismissalStore: dismissalStore,
  );

  // ── T5 读侧候选流装配(2026-09 到期常显提醒,design ADR-1/ADR-5)──
  // banner / 托盘待还行 / 收件箱三消费方共此一流;与写侧 scanner 共享
  // 同一 MultiDueSource 实例与挂失存储(NFR-1),分叉仅在去重/发送。
  // guest 全链本地:drift watch + 本地表 + getIt,无 server/绑定依赖,
  // 免任何门控(NFR-5;bootstrapNotifications 本身双模式都进 —— 平台门
  // 是 Windows 而非会话模式)。须先于 TrayController 构造:trayHead 闭包
  // 消费 provider.latest,且 getIt 注册先于 runApp 首帧(T3 banner 守卫 /
  // T4 收件箱兜底自建在注册后自动切共享实例)。
  final dueCandidateProvider = await assembleDueCandidatePipeline(
    db: db,
    source: source,
    dismissalStore: dismissalStore,
    configProvider: reminderConfig,
  );

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
      // T5 待还行数据(FR-4/ADR-5)并入同一查询点:读侧 provider 的最近
      // 候选快照(latest 同步取值,不另查库 —— 托盘三触发刷新时 provider
      // 已随 watch 防抖先行刷新)。空集 → dueCount=0 → 行不显示;取值
      // 异常 → null 字段 → 行消失(fail-safe,NFR-1)。
      int? dueCount;
      int? dueNearestDays;
      try {
        final candidates = dueCandidateProvider.latest;
        if (candidates.isNotEmpty) {
          dueCount = candidates.length;
          final future = [
            for (final c in candidates)
              if (c.daysLeft >= 0) c.daysLeft,
          ];
          // 语义钉死(TrayHeadData.dueNearestDays):有非逾期候选 → 最小
          // 非负 daysLeft(0=今日到期);全逾期 → 最小 daysLeft(负,最重
          // 逾期档),渲染层 formatTrayDueLabel 判 < 0 → 「已逾期 M 天」。
          dueNearestDays = future.isEmpty
              ? candidates
                  .map((c) => c.daysLeft)
                  .reduce((a, b) => a < b ? a : b)
              : future.reduce((a, b) => a < b ? a : b);
        }
      } catch (_) {}
      return TrayHeadData(
        todayIncomeCents: day.incomeCents,
        todayExpenseCents: day.expenseCents,
        monthBalanceCents: month.netCents,
        dueCount: dueCount,
        dueNearestDays: dueNearestDays,
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

  // T5 FR-7 接线:「提醒中心」导航闭包 —— 照 navigateNewTransaction 同
  // 范式,但用 go 而非 push:从托盘直达是全新任务上下文,无返回栈诉求
  // (与收件箱「查看全部」的 context.go('/inbox') 同语义);无 context →
  // no-op,控制器侧已 show/focus 兜底。
  Future<void> navigateInbox() async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go('/inbox');
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
  // F66 引擎边车退出杀(ADR-3):EngineManager 由 injection.dart 1m 无条件
  // 注册(F66-T2 已合入,恒在)—— 过渡期 isRegistered 守卫已死分支,按
  // 评审 T3-L2 简化为直调。同一闭包两处注入(同源杀):TrayController
  // (engineShutdown,盖不经 AppExitPort 的托盘/关闭退出路径,评审
  // T3-H1)+ TrayAppExit(设置页退出按钮)。两路径均容忍清理失败仍
  // exit(TrayAppExit try/finally / TrayController fail-open)。
  Future<void> engineShutdown() async {
    try {
      await getIt<EngineManager>().shutdown();
    } catch (e) {
      // ignore: avoid_print — 引擎清理降级不得阻断退出。
      print('engine shutdown degraded: $e');
    }
  }

  final tray = TrayController(
    scan: () => scanner.scan(DateTime.now()),
    autoRecord: runAutoRecord,
    settings: getIt<TraySettings>(),
    changeTriggers: [
      db.select(db.paymentScheduleEntries).watch().map((_) {}),
      db.select(db.transactionTemplates).watch().map((_) {}),
      db.select(db.transactions).watch().map((_) {}),
      // 信用卡余额/还款日变更与「不再提醒」挂失即扫(催办停得及时)。
      db.select(db.accounts).watch().map((_) {}),
      db.select(db.reminderDismissals).watch().map((_) {}),
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
    inboxNav: navigateInbox,
    engineShutdown: engineShutdown,
  );
  await tray.start();

  // F22:控制器与退出 port 进 getIt(照 injection.dart 手工注册先例;
  // TrayAppExit.onExit=tray.stop 是函数注入,不在 injectable 图内)。
  // 设置页经 AppExitPort.exitApp 消费;退出清理失败由其 try/finally
  // 保证仍 exit(0)。
  getIt.registerSingleton<TrayController>(tray);
  getIt.registerSingleton<AppExitPort>(TrayAppExit(() async {
    await tray.stop();
    await engineShutdown();
  }));

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

/// T5 装配核心(2026-09 到期常显提醒,design ADR-1/ADR-5,组合根豁免区):
/// 读侧候选管线组装 + getIt 注册。拆出为独立函数供装配冒烟测试;生产入口
/// [_bootstrap] 内联调用同一函数(单一装配路径,测试即生产)。guest 全链
/// 本地:drift watch + 本地表,无 server/绑定依赖,免门控(NFR-5)。
///
/// - [source] 须与写侧 scanner 共享同一 MultiDueSource 实例(NFR-1);
/// - changeTriggers = TrayController 变更即扫的既有 5 流照抄(独立 watch
///   实例,与 tray 订阅互不干扰)+ debts 表 watch(债务名/归属变更 →
///   候选 title 跟随刷新,期次表 watch 不到 Debts 行改名);
/// - [syncer] 可注入(冒烟测试假件断言 diff 被调);缺省构造真实
///   InboxSyncer(InboxStore + 挂失存储,ADR-1 寄宿管道尾);
/// - 注册先行(T3 banner 守卫 / T4 收件箱兜底自建在注册后自动切共享
///   实例),启动后即发初始值,晚来的消费方经 latest 同步取值。
@visibleForTesting
Future<DueCandidateProvider> assembleDueCandidatePipeline({
  required AppDatabase db,
  required DueScheduleSource source,
  required ReminderDismissalStore dismissalStore,
  required DueReminderConfig Function() configProvider,
  InboxSyncer? syncer,
}) async {
  final inboxStore = InboxStore(db);
  final provider = DueCandidateProvider(
    changeTriggers: [
      // 既有 5 流照抄(与 TrayController 变更即扫同一批表)。
      db.select(db.paymentScheduleEntries).watch().map((_) {}),
      db.select(db.transactionTemplates).watch().map((_) {}),
      db.select(db.transactions).watch().map((_) {}),
      db.select(db.accounts).watch().map((_) {}),
      db.select(db.reminderDismissals).watch().map((_) {}),
      // 债务名变更刷新:候选 title 取 Debts.counterparty(join),期次表
      // watch 不到 Debts 行改名 → 追加 debts 流。
      db.select(db.debts).watch().map((_) {}),
    ],
    source: source,
    dismissalStore: dismissalStore,
    configProvider: configProvider,
    syncer: syncer ??
        InboxSyncer(store: inboxStore, dismissalStore: dismissalStore),
  );
  getIt.registerSingleton<InboxStore>(inboxStore);
  getIt.registerSingleton<DueCandidateProvider>(provider);
  await provider.start();
  return provider;
}

// ignore: unused_element — 回网订阅持有(防 GC;生命周期=进程)。
StreamSubscription<bool>? _netSub;
