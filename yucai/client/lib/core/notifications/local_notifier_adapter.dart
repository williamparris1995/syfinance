import 'dart:io';

import 'package:local_notifier/local_notifier.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';

/// local_notifier 插件 adapter(design ADR-2:插件依赖隔离在此)。
/// AUMID/appName 与 Inno 安装器快捷方式对齐(toast 显示的前提)。
class LocalNotifierAdapter implements ReminderNotifier {
  LocalNotifierAdapter({this.onNotificationClick});

  /// 点击通知回调(bootstrap 接 window_manager.show 聚焦主窗口)。
  final void Function()? onNotificationClick;

  Future<void> initialize() async {
    // appName 即 Windows AUMID 身份;requireCreate(缺省)确保开始菜单
    // 快捷方式存在(toast 显示前提,与 Inno 已建的快捷方式幂等共存)。
    await localNotifier.setup(appName: '御财');
  }

  @override
  Future<void> show(DueNotificationCopy copy) async {
    final n = LocalNotification(title: copy.title, body: copy.body)
      ..onClick = onNotificationClick;
    await n.show();
  }
}

/// 桌面平台守卫:通知/托盘仅 Windows 接线(R8 扩移动端)。
bool notificationsSupported() => Platform.isWindows;
