import 'dart:async';
import 'dart:io';

import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:path_provider/path_provider.dart';

/// 单实例守卫(FR-4):检测 + 信号文件唤起。
/// flutter_single_instance 只提供 isFirstInstance 检测;次实例→首实例的
/// "显示主窗口"信号用轻量信号文件(首实例 500ms 轮询消费)。
class SingleInstanceGuard {
  /// 次实例:写信号文件后返回 true(调用方应退出进程)。
  static Future<bool> signalExistingAndExit() async {
    final f = await _signalFile();
    try {
      await f.writeAsString('${DateTime.now().millisecondsSinceEpoch}\n',
          flush: true);
    } catch (_) {/* 首实例目录不可达也得退出,不阻塞 */}
    return true;
  }

  /// 首实例:启动信号监听;收到信号 → [onShowSignal](show+focus 主窗口)。
  static Timer startWatching(void Function() onShowSignal) {
    Timer? t;
    t = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final f = await _signalFile();
      if (!await f.exists()) return;
      final content = await f.readAsString();
      // 消费后立即删除,防止重复触发。
      try {
        await f.delete();
      } catch (_) {}
      if (content.trim().isNotEmpty) onShowSignal();
    });
    return t;
  }

  static Future<File> _signalFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}yucai.show.signal');
  }

  /// 首实例判定(平台不支持时恒 true,单实例语义退化但不阻断启动)。
  static Future<bool> isFirst() async {
    try {
      return await FlutterSingleInstance().isFirstInstance();
    } catch (_) {
      return true;
    }
  }
}
