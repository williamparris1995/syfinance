import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';

/// 托盘常驻控制器(FR-3):托盘菜单 + 关闭=最小化 + 每日扫描调度 + 启动首扫。
///
/// 生命周期(user-acceptance 修复):start() 逐步骤容错 —— 任一步失败
/// (典型:打包版资产非磁盘文件)只降级托盘;[trayReady]=false 时窗口
/// 关闭改为**真退出**(绝不隐藏到不存在的托盘里变僵尸)。
class TrayController with TrayListener, WindowListener {
  TrayController({required this.scan, this.autoRecord});

  /// 扫描入口(注入到期提醒扫描)。
  final Future<ScanResult> Function() scan;

  /// autoRecord 调度入口(R7-C;null=未接线则跳过)。
  final Future<void> Function()? autoRecord;

  /// 托盘是否成功就绪。窗口关闭行为据此分支:
  /// true → 隐藏到托盘;false → 真退出。
  bool trayReady = false;

  DateTime? _lastScanDay;
  Timer? _tick;
  Timer? _firstScan;

  static const _kShow = 'show';
  static const _kCheck = 'check';
  static const _kQuit = 'quit';

  Future<void> start() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true); // 关闭 → onWindowClose 分支

    try {
      trayManager.addListener(this);
      // 打包版内 'assets/...' 不是磁盘文件 → 先落盘再设图标
      // (user-acceptance 修复:release 直接 setIcon 相对路径会抛错,
      //  此时 setPreventClose 已生效 → 隐形窗口僵尸)。
      final dir = await getApplicationSupportDirectory();
      final iconFile = File('${dir.path}${Platform.pathSeparator}tray_icon.ico');
      if (!await iconFile.exists()) {
        final data = await rootBundle.load('assets/tray_icon.ico');
        await iconFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }
      await trayManager.setIcon(iconFile.path);
      await trayManager.setToolTip('御财');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: _kShow, label: '显示御财'),
        MenuItem(key: _kCheck, label: '立即检查(提醒/记账)'),
        MenuItem(key: _kQuit, label: '退出'),
      ]));
      trayReady = true;
    } catch (_) {
      // 托盘失败:窗口关闭回退真退出,绝不隐藏成僵尸。
      trayReady = false;
    }

    _tick = Timer.periodic(const Duration(minutes: 30), (_) => _maybeScan());
    // 启动延迟首扫(design ADR-5:不阻塞 runApp 首帧;失败则当日稍后 tick 重试)。
    _firstScan = Timer(const Duration(seconds: 10), _scanAndMark);
  }

  Future<void> stop() async {
    _tick?.cancel();
    _firstScan?.cancel();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    if (trayReady) await trayManager.destroy();
  }

  /// 跨日触发:30 分钟 tick 发现"今天"还没扫过 → 扫(策略/日志保证幂等,
  /// 重扫无副作用,故以日为粒度即可)。
  Future<void> _maybeScan() async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    if (_lastScanDay == day) return;
    await _scanAndMark();
  }

  Future<void> _scanAndMark() async {
    // autoRecord 与到期提醒独立容错:一方失败不影响另一方(R7-C FR-3)。
    final auto = autoRecord;
    if (auto != null) {
      try {
        await auto();
      } catch (_) {}
    }
    try {
      await scan();
    } catch (_) {
      // 扫描失败不冒泡(Timer 回调里会变未捕获异步异常);当日不标记,
      // 30 分钟 tick 自然重试(review R2 polish)。
      return;
    }
    // 成功后才标记当日已扫(失败 → 30 分钟 tick 自然重试;review R1)。
    final now = DateTime.now();
    _lastScanDay = DateTime(now.year, now.month, now.day);
  }

  // ---- window_manager:关闭=隐藏到托盘,退出只走托盘菜单 ----
  @override
  void onWindowClose() async {
    if (trayReady) {
      await windowManager.hide();
    } else {
      // 托盘不可用:隐藏=用户无法找回的僵尸窗口,直接退出。
      exit(0);
    }
  }

  // ---- tray_manager ----
  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case _kShow:
        await windowManager.show();
        await windowManager.focus();
      case _kCheck:
        await _scanAndMark();
      case _kQuit:
        await stop();
        // 真正退出:dispose 托盘后结束进程(spec NFR:不留僵尸)。
        exit(0);
    }
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }
}
