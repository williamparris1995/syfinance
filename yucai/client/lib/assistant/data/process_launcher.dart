/// F66 引擎边车 —— 进程启动/终结 port(NFR-2 注入缝;ADR-3)。
///
/// dart:io 生产实现唯一落点:[ProcessLauncherImpl]。单测经 fake 注入
/// (零真进程);真 exe 冒烟走 test/assistant/integration(T4)。
///
/// 进程树终结(ADR-3):dart `Process.kill` 不递归,故 [ProcessLauncher.killTree]
/// 先 graceful(`Process.killPid`)等 2s,仍在则 Windows
/// `taskkill /PID <pid> /T /F`(`Process.runSync`)兜底 —— 闲置回收与
/// app 退出钩子共用。
library;

import 'dart:io';

import 'package:injectable/injectable.dart';

/// llama-server 进程启动 port(EngineManager 经此缝拉起/终结边车)。
abstract class ProcessLauncher {
  /// 启动 [exe] 并返回其句柄;失败(如 exe 缺失)抛 [ProcessException]。
  Future<LaunchedProcess> start({
    required String exe,
    required List<String> args,
  });

  /// 终结进程树(graceful kill → 2s 宽限 → taskkill /T /F 兜底;ADR-3)。
  Future<void> killTree(int pid);
}

/// 已启动进程句柄(pid + 退出码 + graceful kill;NFR-2 fake 友好形状)。
abstract class LaunchedProcess {
  /// OS 进程 id(日志/树杀用)。
  int get pid;

  /// 进程退出码 Future(异常退出=提前完成 —— 崩溃探测依据,FR-1)。
  Future<int> get exitCode;

  /// Graceful 终结本进程(不递归子进程;树终结走 killTree)。
  Future<void> kill();
}

/// 生产实现:dart:io `Process.start` + Windows taskkill 树终结。
@LazySingleton()
class ProcessLauncherImpl implements ProcessLauncher {
  const ProcessLauncherImpl();

  /// Graceful 退出宽限:killPid 后轮询存活性至多 2s 再强杀(design LLD)。
  static const Duration _graceWait = Duration(seconds: 2);

  /// 宽限期内存活轮询间隔。
  static const Duration _alivePollInterval = Duration(milliseconds: 200);

  @override
  Future<LaunchedProcess> start({
    required String exe,
    required List<String> args,
  }) async {
    // Window visibility note: dart:io Process.start exposes no Win32
    // STARTF_USESHOWWINDOW equivalent, and ProcessStartMode.detached would
    // orphan the child (no exitCode/kill handle for crash detection and
    // tree kill), so it must NOT be used here. We keep normal mode and
    // accept the console surface; the bundled runner subsystem (F66-T5)
    // owns final window behavior.
    final process = await Process.start(
      exe,
      args,
      mode: ProcessStartMode.normal,
    );
    return _LiveLaunchedProcess(process);
  }

  @override
  Future<void> killTree(int pid) async {
    // 1) Graceful: ask the process to exit on its own.
    try {
      Process.killPid(pid);
    } catch (_) {
      // Already gone (or signal refused) — the liveness poll decides.
    }
    // 2) Grace window: poll aliveness for up to 2s.
    final deadline = DateTime.now().add(_graceWait);
    while (DateTime.now().isBefore(deadline)) {
      if (!_isAlive(pid)) return;
      await Future<void>.delayed(_alivePollInterval);
    }
    // 3) Still alive: forceful Windows tree kill (/T = children, /F = force).
    //    Windows-only by design (llama-server sidecar ships for Windows,
    //    ADR-9); a non-Windows taskkill absence surfaces as an error that
    //    EngineManagerImpl tolerates.
    Process.runSync('taskkill', ['/PID', '$pid', '/T', '/F']);
  }

  /// Whether [pid] is still running, via `tasklist` exact-PID filter.
  /// Token compare avoids substring false positives (23 vs 1234).
  static bool _isAlive(int pid) {
    try {
      final result = Process.runSync(
        'tasklist',
        ['/FI', 'PID eq $pid', '/NH'],
      );
      final tokens = (result.stdout as String).split(RegExp(r'\s+'));
      return tokens.contains('$pid');
    } catch (_) {
      // tasklist unavailable -> assume dead: nothing left to kill, return
      // WITHOUT the taskkill fallback (the graceful kill above already did
      // its best; reporting alive here would force-run taskkill on every
      // killTree call). Review T2-L1: comment now matches the behavior.
      return false;
    }
  }
}

/// [LaunchedProcess] 生产句柄:包装 dart:io [Process]。
class _LiveLaunchedProcess implements LaunchedProcess {
  _LiveLaunchedProcess(this._process);

  final Process _process;

  @override
  int get pid => _process.pid;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  Future<void> kill() async {
    // Process.kill returns whether the signal was delivered (bool, sync) —
    // discarded; aliveness is re-checked by the caller's own poll/watch.
    _process.kill();
  }
}
