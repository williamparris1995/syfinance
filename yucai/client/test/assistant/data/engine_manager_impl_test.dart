import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/data/engine_manager_impl.dart';
import 'package:yucai_client/assistant/data/process_launcher.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_store_port.dart';

/// F66 T2:EngineManagerImpl 生命周期编排单测(FR-1/FR-3;ADR-1..5)。
///
/// 全注入缝(NFR-2):FakeLauncher / FakeModelStore / 即时延时缝 / 假健康
/// 探测 / 假端口扫描 / 假闲置 Timer —— 零真进程、零真等待(10min 时钟由
/// FakeTimer.elapse 手动快进)。状态断言用 ValueListenable 收集器(家法:
/// 当前值缓存 + 转移即通知,同形值去重)。
void main() {
  test('cold start walks Stopped->Starting->Ready; ADR-6 args; English logs',
      () async {
    final sut = _Sut();
    expect(sut.manager.state.value, const EngineStopped());

    final seen = sut.collectStates();
    await sut.manager.ensureReady();

    final port = sut.scannedPorts.single;
    expect(
      seen,
      [const EngineStarting(), EngineReady(Uri.parse('http://127.0.0.1:$port/v1'))],
    );
    final start = sut.launcher.starts.single;
    expect(start.exe, _exeName);
    expect(start.args, [
      '--host', '127.0.0.1',
      '--port', '$port',
      '-m', _modelFile,
      '-c', '4096',
      '-ngl', '999',
      '--jinja',
      '--no-webui',
    ]);
    expect(sut.probes.single, Uri.parse('http://127.0.0.1:$port/health'));
    expect(
      sut.logs.first,
      'engine start port=$port model=${AssistantConfig.defaultModel}',
    );
    expect(
      sut.logs.any((line) => line.startsWith('engine ready ms=')),
      isTrue,
      reason: 'ready log line missing: ${sut.logs}',
    );
  });

  test('three concurrent ensureReady calls share one start (idempotent join)',
      () async {
    final gate = Completer<bool>();
    final sut = _Sut(isReadyFn: () => gate.future);

    final calls = [
      sut.manager.ensureReady(),
      sut.manager.ensureReady(),
      sut.manager.ensureReady(),
    ];
    await Future<void>.delayed(Duration.zero);
    // Still gated inside the model precheck: no state move yet.
    expect(sut.manager.state.value, const EngineStopped());

    gate.complete(true);
    await Future.wait(calls);

    expect(sut.launcher.processes, hasLength(1));
    expect(sut.manager.state.value, isA<EngineReady>());
  });

  test('ensureReady on Ready returns immediately and re-arms the idle window',
      () async {
    final sut = _Sut();
    await sut.manager.ensureReady();

    await sut.manager.ensureReady();

    expect(sut.launcher.processes, hasLength(1)); // no second spawn
    expect(sut.models.isReadyCalls, 1); // hot path skips the precheck
    expect(sut.timers, hasLength(2)); // touch re-armed a fresh window
    expect(sut.timers.first.cancelled, isTrue); // old window was cancelled
  });

  test('missing model short-circuits to Error(modelMissing), no process spawned',
      () async {
    final sut = _Sut(modelPath: null);
    final seen = sut.collectStates();

    await sut.manager.ensureReady();

    expect(seen, const [EngineError(EngineFailureReason.modelMissing)]);
    expect(sut.launcher.starts, isEmpty);
    expect(sut.scannedPorts, isEmpty); // precheck precedes the port scan

    // Re-intervention (engine_state contract) re-checks the store.
    await sut.manager.ensureReady();
    expect(sut.models.isReadyCalls, 2);
  });

  test('disabled config: ensureReady is a no-op, engine never spawns (T2-L3)',
      () async {
    final sut = _Sut(enabled: false);
    final seen = sut.collectStates();

    await sut.manager.ensureReady();

    expect(sut.manager.state.value, const EngineStopped()); // 状态不动
    expect(sut.launcher.starts, isEmpty); // 零进程
    expect(sut.scannedPorts, isEmpty); // 连端口扫描都不进
    expect(seen, isEmpty); // F65 预热在 disabled 时不得拉起引擎
    expect(sut.models.isReadyCalls, 0); // 模型前置检查也跳过
  });

  test('health timeout retries with 1s/3s/9s backoff, then Error(startFailed)',
      () async {
    final sut = _Sut(healthRule: (_) => false, healthAttempts: 1);
    final seen = sut.collectStates();

    await sut.manager.ensureReady();

    expect(
      seen,
      [const EngineStarting(), const EngineError(EngineFailureReason.startFailed)],
    );
    // 冷启口径(T2-M1):初试不计重启预算 → 1 初试 + 3 次重试 = 4 进程。
    expect(sut.launcher.processes, hasLength(4));
    expect(sut.scannedPorts, hasLength(4)); // fresh port scan per attempt
    expect(
      sut.delays,
      const [Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 9)],
    );
    expect(
      sut.logs.where((l) => l.startsWith('engine restart attempt=')),
      ['engine restart attempt=1', 'engine restart attempt=2', 'engine restart attempt=3'],
    );
    // Every failed child is torn down before the retry relaunches.
    expect(sut.launcher.killTreeCalls, [1000, 1001, 1002, 1003]);
  });

  test('spawn failure (exe missing) counts as startFailed toward the same cap',
      () async {
    final sut = _Sut()..launcher.throwOnStart = true;

    await sut.manager.ensureReady();

    expect(sut.manager.state.value, const EngineError(EngineFailureReason.startFailed));
    expect(sut.launcher.startAttempts, 4);
  });

  test('unexpected process exit after Ready triggers auto-restart to Ready',
      () async {
    final sut = _Sut();
    await sut.manager.ensureReady();
    expect(sut.manager.state.value, isA<EngineReady>());

    sut.launcher.processes.first.crash();

    await _until(() =>
        sut.launcher.processes.length == 2 && sut.manager.state.value is EngineReady);
    final second = sut.manager.state.value as EngineReady;
    expect(second.endpoint, Uri.parse('http://127.0.0.1:${sut.scannedPorts[1]}/v1'));
    expect(sut.logs, contains('engine crash pid=1000'));
    expect(sut.launcher.killTreeCalls, isEmpty); // clean crash: nothing to tree-kill
  });

  test(
      'crash loop: respawns capped at 3 (first counts, T2-M1) -> Error(crashed), no self-heal',
      () async {
    var grantFirst = true;
    final sut = _Sut(healthRule: (_) {
      if (grantFirst) {
        grantFirst = false;
        return true;
      }
      return false;
    });
    await sut.manager.ensureReady();

    sut.launcher.crashNewProcesses = true; // every respawn dies mid health poll
    sut.launcher.processes.first.crash();

    await _until(() => sut.manager.state.value is EngineError);
    expect(sut.manager.state.value, const EngineError(EngineFailureReason.crashed));
    // 崩溃重入口径(T2-M1 修 off-by-one):首重生计入预算 → 总重生 ≤3,
    // 即 Ready 进程 + 3 次重生 = 4(此前首重生免费,5 个进程才 Error)。
    expect(sut.launcher.processes, hasLength(4));
    expect(
      sut.logs.where((l) => l.startsWith('engine restart attempt=')),
      ['engine restart attempt=1', 'engine restart attempt=2'],
    );

    // Capped: no further spawns without re-intervention.
    final spawns = sut.launcher.processes.length;
    await _pumpEventLoop();
    expect(sut.launcher.processes.length, spawns);
  });

  test(
      'shutdown during a backoff delay aborts the ladder: no respawn after teardown (T2-L2)',
      () async {
    // Gate the first backoff delay: hold it until shutdown() has completed,
    // then release — the sequence must NOT spawn again (generation check).
    final gate = Completer<void>();
    var delayCalls = 0;
    final sut = _Sut(
      healthRule: (_) => false,
      healthAttempts: 1,
      delayFn: (d) async {
        delayCalls++;
        if (delayCalls == 1) await gate.future; // hold the 1s backoff
      },
    );
    final starting = sut.manager.ensureReady();
    await _until(() => delayCalls == 1); // first attempt failed into the gate

    await sut.manager.shutdown(); // tears down while the delay is pending
    gate.complete(); // backoff resolves after shutdown
    await starting;
    await _pumpEventLoop();

    expect(sut.launcher.processes, hasLength(1)); // no respawn post-shutdown
    expect(sut.manager.state.value, const EngineStopped());
    expect(delayCalls, 1); // ladder aborted, no further backoffs scheduled
  });

  test('idle timeout (10min fast-forward) with no activity tree-kills -> Stopped',
      () async {
    final sut = _Sut();
    await sut.manager.ensureReady();

    expect(sut.timers, hasLength(1));
    expect(sut.timers.single.duration, const Duration(minutes: 10));

    sut.timers.single.elapse();
    await _pumpEventLoop();

    expect(sut.manager.state.value, const EngineStopped());
    expect(sut.launcher.killTreeCalls, [1000]); // graceful kill -> taskkill tree
    expect(sut.logs, contains('engine idle-stop'));
  });

  test('idle timeout defers while a request is active, recycles once idle again',
      () async {
    final sut = _Sut();
    await sut.manager.ensureReady();

    sut.manager.beginActivity(); // in-flight request (T3 brackets chat with these)
    expect(sut.timers, hasLength(2)); // begin touched a fresh window

    sut.timers.last.elapse(); // fires mid-request
    await _pumpEventLoop();
    expect(sut.manager.state.value, isA<EngineReady>()); // not recycled
    expect(sut.launcher.killTreeCalls, isEmpty);
    expect(sut.timers, hasLength(3)); // deferred: full window re-armed
    expect(sut.timers.last.duration, const Duration(minutes: 10));

    sut.manager.endActivity(); // stream closed
    sut.timers.last.elapse(); // next expiry with zero active requests
    await _pumpEventLoop();
    expect(sut.manager.state.value, const EngineStopped());
    expect(sut.launcher.killTreeCalls, [1000]);
  });

  test('shutdown tree-kills, cancels the idle timer, disarms the crash watcher',
      () async {
    final sut = _Sut();
    await sut.manager.ensureReady();

    await sut.manager.shutdown();

    expect(sut.manager.state.value, const EngineStopped());
    expect(sut.launcher.killTreeCalls, [1000]);
    expect(sut.timers.single.cancelled, isTrue);

    // Exit completing after shutdown must NOT trigger an auto-restart.
    sut.launcher.processes.single.crash();
    await _pumpEventLoop();
    expect(sut.launcher.processes, hasLength(1));
    expect(sut.manager.state.value, const EngineStopped());
  });

  test('lifecycle log lines stay printable ASCII across paths (NFR-3)', () async {
    final failer = _Sut(healthRule: (_) => false, healthAttempts: 1);
    await failer.manager.ensureReady(); // walks the full retry ladder

    final happy = _Sut();
    await happy.manager.ensureReady();
    happy.manager.beginActivity();
    happy.manager.endActivity();
    await happy.manager.shutdown();

    final lines = [...failer.logs, ...happy.logs];
    expect(lines, isNotEmpty);
    final ascii = RegExp(r'^[\x20-\x7E]*$');
    for (final line in lines) {
      expect(line, matches(ascii), reason: 'non-ASCII log line: $line');
    }
  });
}

const _modelFile = r'C:\models\qwen3-4b-instruct-q4_k_m.gguf';
const _exeName = 'llama-server.exe';

/// Pumps the event loop without any real waiting (seams resolve instantly).
Future<void> _pumpEventLoop() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Pumps until [done] holds (bounded), then asserts it actually held.
Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(done(), isTrue, reason: 'condition not reached after pumping');
}

/// Fully-faked manager assembly (NFR-2): every production seam swapped.
class _Sut {
  _Sut({
    String? modelPath = _modelFile,
    Future<bool> Function()? isReadyFn,
    bool Function(Uri health)? healthRule,
    int healthAttempts = 60,
    bool enabled = true,
    EngineDelayFn? delayFn,
  }) : models = _FakeModelStore(path: modelPath, isReadyFn: isReadyFn) {
    _healthRule = healthRule ?? (_) => true;
    manager = EngineManagerImpl(
      launcher,
      models,
      () => AssistantConfig(enabled: enabled),
      delay: delayFn ?? _recordDelay,
      healthProbe: _probe,
      portScan: _scanPort,
      exePath: () => _exeName,
      idleTimerFactory: _makeTimer,
      healthAttempts: healthAttempts,
      log: logs.add,
    );
  }

  final launcher = _FakeLauncher();
  final _FakeModelStore models;
  final logs = <String>[];
  final delays = <Duration>[];
  final timers = <_FakeTimer>[];
  final scannedPorts = <int>[];
  final probes = <Uri>[];

  late final EngineManagerImpl manager;
  late bool Function(Uri) _healthRule;

  /// ValueListenable collector: records every notified transition.
  List<EngineState> collectStates() {
    final seen = <EngineState>[];
    manager.state.addListener(() => seen.add(manager.state.value));
    return seen;
  }

  Future<void> _recordDelay(Duration d) async => delays.add(d);

  Future<bool> _probe(Uri uri) async {
    probes.add(uri);
    return _healthRule(uri);
  }

  Future<int> _scanPort() async {
    final port = 9100 + scannedPorts.length;
    scannedPorts.add(port);
    return port;
  }

  Timer _makeTimer(Duration duration, void Function() onFire) {
    final timer = _FakeTimer(duration, onFire);
    timers.add(timer);
    return timer;
  }
}

class _FakeModelStore implements ModelStore {
  _FakeModelStore({this.path, this.isReadyFn});

  final String? path;
  final Future<bool> Function()? isReadyFn;
  int isReadyCalls = 0;

  @override
  Future<String?> modelPath() async => path;

  @override
  Future<bool> isReady() async {
    isReadyCalls++;
    final fn = isReadyFn;
    if (fn != null) return fn();
    return path != null;
  }
}

class _FakeLauncher implements ProcessLauncher {
  final starts = <({String exe, List<String> args})>[];
  final processes = <_FakeProcess>[];
  final killTreeCalls = <int>[];
  int startAttempts = 0;
  bool throwOnStart = false;
  bool crashNewProcesses = false;

  @override
  Future<LaunchedProcess> start({
    required String exe,
    required List<String> args,
  }) async {
    startAttempts++;
    if (throwOnStart) {
      throw ProcessException(exe, args, 'spawn refused (test)');
    }
    final process = _FakeProcess(1000 + processes.length);
    processes.add(process);
    starts.add((exe: exe, args: List<String>.of(args)));
    if (crashNewProcesses) scheduleMicrotask(process.crash);
    return process;
  }

  @override
  Future<void> killTree(int pid) async => killTreeCalls.add(pid);
}

class _FakeProcess implements LaunchedProcess {
  _FakeProcess(this.pid);

  @override
  final int pid;

  final Completer<int> _exitCode = Completer<int>();
  bool killCalled = false;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Future<void> kill() async => killCalled = true;

  /// Simulates an abnormal engine exit (exitCode future completes).
  void crash([int code = 1]) {
    if (!_exitCode.isCompleted) _exitCode.complete(code);
  }
}

/// Fake idle Timer: 10min elapse is a manual [elapse] call (zero real wait).
class _FakeTimer implements Timer {
  _FakeTimer(this.duration, this.onFire);

  final Duration duration;
  final void Function() onFire;
  bool cancelled = false;
  bool fired = false;

  @override
  void cancel() => cancelled = true;

  @override
  bool get isActive => !cancelled && !fired;

  @override
  int get tick => fired ? 1 : 0;

  /// Fast-forwards the clock to the timeout point.
  void elapse() {
    if (cancelled || fired) return;
    fired = true;
    onFire();
  }
}
