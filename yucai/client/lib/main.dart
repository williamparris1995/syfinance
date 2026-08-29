import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/notifications_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 单实例守卫(FR-4):次实例写信号唤起既有窗口后退出。
  // Windows runner 在 Dart main 前已建窗口,return 不终止引擎 → 必须 exit。
  if (!await acquireSingleInstance()) {
    exit(0);
  }
  await windowManager.ensureInitialized();

  await configureDependencies();
  // 托盘常驻 + 到期提醒 + 自启(仅 Windows;R7-B)。
  await bootstrapNotifications(getIt<AppDatabase>());
  runApp(const YuCaiApp());
}
