import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/drift_due_source.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/notifications/local_notifier_adapter.dart';
import 'package:yucai_client/core/notifications/single_instance_guard.dart';
import 'package:yucai_client/core/notifications/tray_controller.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/template/data/template_repository_impl.dart';

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

  final adapter = LocalNotifierAdapter(onNotificationClick: focusMainWindow);
  await adapter.initialize();
  final scanner = DueScanner(source: source, notifier: adapter, logStore: logStore);

  // autoRecord 调度(R7-C):双模式常跑,经模板双源 repo 写穿透。
  final autoScheduler = AutoRecordScheduler(
    templates: _TemplateRepoAutoRecord(getIt<TemplateRepositoryImpl>()),
    notifier: adapter,
  );

  final tray = TrayController(
    scan: () => scanner.scan(DateTime.now()),
    autoRecord: () async {
      await autoScheduler.run(DateTime.now());
    },
  );
  await tray.start();

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


/// AutoRecordTemplates 适配器:template 双源 repo(list/record)。
/// Template 实体的 nextDate/endDate 是 date-only String,在此解析为 DateTime。
class _TemplateRepoAutoRecord implements AutoRecordTemplates {
  _TemplateRepoAutoRecord(this._repo);
  final TemplateRepositoryImpl _repo;

  static DateTime? _parse(String? s) =>
      s == null || s.isEmpty ? null : DateTime.tryParse(s);

  @override
  Future<List<AutoRecordTemplate>> listAutoRecordDue() async {
    final res = await _repo.list();
    return res.fold(
      (l) => const [],
      (all) => [
        for (final t in all)
          if (t.autoRecord && !t.paused)
            AutoRecordTemplate(
              id: t.id,
              name: t.name,
              amountCents: t.amountCents,
              nextDate: _parse(t.nextDate) ?? DateTime.now(),
              endDate: _parse(t.endDate),
            ),
      ],
    );
  }

  @override
  Future<DateTime?> record(String templateId) async {
    final res = await _repo.record(templateId);
    return res.fold((l) => null, (r) => r.nextDate);
  }
}
