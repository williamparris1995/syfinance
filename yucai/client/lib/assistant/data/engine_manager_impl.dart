/// F66 引擎边车 —— EngineManagerImpl 生命周期编排(FR-1/FR-3;ADR-1..5)。
///
/// 照 design LLD 编排:懒启动(端口扫描→拉起→/health 轮询→Ready)、
/// 幂等 ensureReady(Starting→等待既有 Future;Ready→即返)、模型缺失
/// 前置检查(不起进程)、退避重启(1s/3s/9s,上限 3 次,按失败点定
/// crashed/startFailed)、闲置 10min 回收(活跃计数顺延)、shutdown 强杀
/// 进程树。全缝注入(NFR-2):延时/健康探测/端口扫描/exe 路径/闲置
/// Timer/日志 —— 单测零真进程零真等待。
///
/// 日志全 English 结构化(NFR-3):`engine start port=<n>` /
/// `engine ready ms=<n>` / `engine idle-stop` / `engine crash pid=<n>` /
/// `engine restart attempt=<n>` / `engine error reason=<r>`。
///
/// 生产 DI:手工注册(injection.dart 1m 段;构造携带函数类型参数,
/// @LazySingleton 注解进不了生成图 —— 同 F64 缘由)。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../domain/assistant_settings.dart';
import '../domain/engine_port.dart';
import '../domain/engine_state.dart';
import '../domain/model_store_port.dart';
import 'audit_log.dart';
import 'process_launcher.dart';

/// 延时缝(退避/健康轮询间隔;缺省 Future.delayed,单测即时)。
typedef EngineDelayFn = Future<void> Function(Duration delay);

/// 健康探测缝(缺省真 HTTP GET /health,dart:io)。
typedef EngineHealthProbeFn = Future<bool> Function(Uri healthUrl);

/// 空闲端口扫描缝(缺省 ServerSocket bind(0) 试探,ADR-2)。
typedef EnginePortScanFn = Future<int> Function();

/// 边车 exe 路径缝(缺省固定相对名,T5 捆绑后随包调整)。
typedef EngineExePathFn = String Function();

/// 闲置 Timer 工厂缝(单测手动快进 10min)。
typedef EngineIdleTimerFactory = Timer Function(
  Duration duration,
  void Function() onFire,
);

/// 引擎管理生产实现(DI 手工绑定见 injection.dart 1m 段)。
@LazySingleton(as: EngineManager)
class EngineManagerImpl implements EngineManager {
  /// 命名缝参数可空 + `?? 生产缺省`(照 NFR-2 注入面;null = 走缺省)。
  EngineManagerImpl(
    this._launcher,
    this._models,
    this._config, {
    this.healthInterval = defaultHealthInterval,
    this.healthAttempts = defaultHealthAttempts,
    this.idleTimeout = defaultIdleTimeout,
    EngineDelayFn? delay,
    EngineHealthProbeFn? healthProbe,
    EnginePortScanFn? portScan,
    EngineExePathFn? exePath,
    EngineIdleTimerFactory? idleTimerFactory,
    AssistantLogFn? log,
  })  : _delay = delay ?? _defaultDelay,
        _healthProbe = healthProbe ?? _defaultHealthProbe,
        _portScan = portScan ?? _defaultPortScan,
        _exePath = exePath ?? _defaultExePath,
        _idleTimerFactory = idleTimerFactory ?? _defaultIdleTimer,
        _log = log ?? _defaultEngineLog;

  /// 健康轮询间隔(ADR-4:500ms)。
  static const Duration defaultHealthInterval = Duration(milliseconds: 500);

  /// 健康轮询次数(ADR-4:500ms x 60 = 30s 就绪超时)。
  static const int defaultHealthAttempts = 60;

  /// 闲置回收窗口(FR-1:10 分钟无请求终止进程)。
  static const Duration defaultIdleTimeout = Duration(minutes: 10);

  /// 退避重启上限(FR-1:单次会话最多 3 次重试,超限进 error 不再自试)。
  static const int maxRestartAttempts = 3;

  /// 退避序列(design LLD:1s/3s/9s)。
  static const List<Duration> restartBackoffDelays = [
    Duration(seconds: 1),
    Duration(seconds: 3),
    Duration(seconds: 9),
  ];

  /// 随包边车 exe 名(T5 捆绑工程落位前的固定相对名;spawn 失败自然落
  /// startFailed 退避路径)。
  static const String bundledExeName = 'llama-server.exe';

  /// llama-server 启动参数(ADR-6;flag 名冒烟测钉死):
  /// `--jinja`=GGUF 内置模板原生 tool calling;`-ngl 999`=GPU 尽力,
  /// CPU 回落由 llama.cpp 自身处理。
  static const String _host = '127.0.0.1';
  static const int _ctxSize = 4096;
  static const int _gpuLayers = 999;

  final ProcessLauncher _launcher;
  final ModelStore _models;
  final AssistantConfig Function() _config;
  final EngineDelayFn _delay;
  final EngineHealthProbeFn _healthProbe;
  final EnginePortScanFn _portScan;
  final EngineExePathFn _exePath;
  final EngineIdleTimerFactory _idleTimerFactory;
  final AssistantLogFn _log;

  /// 健康轮询间隔(可注入缩短;缺省 [defaultHealthInterval])。
  final Duration healthInterval;

  /// 健康轮询次数(缺省 [defaultHealthAttempts] = 30s 就绪预算)。
  final int healthAttempts;

  /// 闲置回收窗口(缺省 [defaultIdleTimeout] = 10min)。
  final Duration idleTimeout;

  final ValueNotifier<EngineState> _stateNotifier =
      ValueNotifier<EngineState>(const EngineStopped());

  /// 当前边车进程(null = 无 —— 闲置回收/shutdown/崩溃清理后)。
  LaunchedProcess? _process;

  /// 进行中启动序列的 Future(ensureReady 并发 join 依据;null = 无)。
  Future<void>? _starting;

  /// 当前序列内连续失败次数(成功清零;超 [maxRestartAttempts] 进 Error)。
  int _failedAttempts = 0;

  /// 进行中请求数(T3 的 beginActivity/endActivity 维护;闲置回收依据)。
  int _activeRequests = 0;

  Timer? _idleTimer;

  @override
  ValueListenable<EngineState> get state => _stateNotifier;

  @override
  Future<void> ensureReady() async {
    _touchIdleTimer();
    final current = _stateNotifier.value;
    // 幂等热路径:Ready 且进程仍在(崩溃竞态漏报时 _process 已清,走冷启)。
    if (current is EngineReady && _process != null) return;
    final inFlight = _starting;
    if (inFlight != null) {
      // Starting:等待既有启动 Future(并发三连调一个进程)。
      await inFlight;
      return;
    }
    // 冷启动(Stopped)或重新干预(Error):重试预算复位
    // (engine_state 契约「重新干预后走 ensureReady 复位」)。
    _failedAttempts = 0;
    await _ownStartSequence();
  }

  /// 停止引擎并终结进程树(app 退出钩子/强杀共用;ADR-3)。
  @override
  Future<void> shutdown() async {
    _idleTimer?.cancel();
    _idleTimer = null;
    final process = _process;
    // 先解除崩溃监听(_process 清空 + 状态转移)再杀:killTree 触发的
    // exitCode 完成不得误判为崩溃重启。
    _process = null;
    _setState(const EngineStopped());
    if (process != null) {
      try {
        await _launcher.killTree(process.pid);
      } catch (_) {
        // Tree kill best effort: shutdown must complete regardless.
      }
    }
  }

  /// 请求开始标记(T3 stream client 包夹 chat 用;FR-1 活跃计数)。
  ///
  /// 同时重置闲置窗口(design LLD「每次 ensureReady/请求 touch」)。
  void beginActivity() {
    _activeRequests++;
    _touchIdleTimer();
  }

  /// 请求结束标记(以流关闭为界;归零后闲置回收恢复生效)。
  void endActivity() {
    if (_activeRequests > 0) _activeRequests--;
  }

  // -- 启动序列 ---------------------------------------------------------------

  /// 独占持有启动序列(_starting 赋值在首个 await 前,单线程下并发调用
  /// 确定性 join)。
  Future<void> _ownStartSequence() async {
    final sequence = _runStartSequence();
    _starting = sequence;
    try {
      await sequence;
    } finally {
      _starting = null;
    }
  }

  /// 全流程:模型前置检查 → [maxRestartAttempts]+1 次尝试,每次重扫端口;
  /// 失败按退避延时重试,计数到顶按最后失败点定 Error 终态。
  Future<void> _runStartSequence() async {
    // 模型缺失前置检查(FR-2):不起进程,直接终态。
    bool modelReady;
    try {
      modelReady = await _models.isReady();
    } catch (_) {
      modelReady = false;
    }
    if (!modelReady) {
      _setState(const EngineError(EngineFailureReason.modelMissing));
      return;
    }
    while (true) {
      final failure = await _attemptStart();
      if (failure == null) {
        _failedAttempts = 0; // 成功清零(「连续」失败才计退避上限)。
        return;
      }
      if (failure == EngineFailureReason.modelMissing) {
        // isReady 通过但路径缺失的撕裂态:重试无意义,直接终态。
        _setState(const EngineError(EngineFailureReason.modelMissing));
        return;
      }
      _failedAttempts++;
      if (_failedAttempts > maxRestartAttempts) {
        _log('engine error reason=${failure.name}');
        _setState(EngineError(failure));
        return;
      }
      _log('engine restart attempt=$_failedAttempts');
      await _delay(restartBackoffDelays[_failedAttempts - 1]);
    }
  }

  /// 单次尝试:扫端口 → Starting → 拉起 → 健康轮询;成功置 Ready 返
  /// null,失败返原因(中途退出=crashed,其余=startFailed)并清理子进程。
  Future<EngineFailureReason?> _attemptStart() async {
    // 每次尝试重扫端口(端口竞态风险由重扫+退避兜住,design Risks)。
    final int port;
    try {
      port = await _portScan();
    } catch (_) {
      return EngineFailureReason.startFailed;
    }
    _setState(const EngineStarting());
    final String? modelPath;
    try {
      modelPath = await _models.modelPath();
    } catch (_) {
      return EngineFailureReason.modelMissing;
    }
    if (modelPath == null) return EngineFailureReason.modelMissing;
    final LaunchedProcess process;
    try {
      process = await _launcher.start(
        exe: _exePath(),
        args: _argsFor(port, modelPath),
      );
    } catch (_) {
      // Spawn refused (exe missing etc.) -> start failure point.
      return EngineFailureReason.startFailed;
    }
    _process = process;
    _log('engine start port=$port model=${_config().model}');

    final stopwatch = Stopwatch()..start();
    var exited = false;
    final exitWatcher = process.exitCode.then((_) => exited = true);
    var ready = false;
    for (var attempt = 0; attempt < healthAttempts; attempt++) {
      if (exited) break; // child died mid-poll -> crashed
      bool healthy;
      try {
        healthy = await _healthProbe(
          Uri.parse('http://$_host:$port/health'),
        );
      } catch (_) {
        healthy = false;
      }
      if (healthy) {
        ready = true;
        break;
      }
      if (exited) break; // died while probing
      // Wait only between polls: the last attempt falls straight through to
      // its failure point (timeout budget = interval x attempts).
      if (attempt + 1 < healthAttempts) {
        await _delay(healthInterval);
      }
    }
    if (ready) {
      _setState(EngineReady(Uri.parse('http://$_host:$port/v1')));
      _log('engine ready ms=${stopwatch.elapsedMilliseconds}');
      // 崩溃监听:Ready 后 exitCode 意外完成 -> 自动退避重启(FR-1)。
      // intentional 停止(闲置回收/shutdown)先清 _process/转移状态,
      // 监听守卫据此放行不重启。
      unawaited(exitWatcher.whenComplete(() => _onUnexpectedExit(process)));
      return null;
    }
    // 失败清理:拆掉本次子进程再交还重试循环(健康超时/中途退出)。
    _process = null;
    try {
      await _launcher.killTree(process.pid);
    } catch (_) {
      // Best effort teardown; the retry loop relaunches regardless.
    }
    return exited ? EngineFailureReason.crashed : EngineFailureReason.startFailed;
  }

  /// Ready 态进程意外退出回调(非有意停止):自动重启序列。
  void _onUnexpectedExit(LaunchedProcess process) {
    if (!identical(_process, process)) return; // superseded/intentional stop
    if (_stateNotifier.value is! EngineReady) return;
    _log('engine crash pid=${process.pid}');
    _process = null;
    unawaited(_ownStartSequence());
  }

  // -- 闲置回收 ---------------------------------------------------------------

  /// 重置闲置窗口(每次 ensureReady/beginActivity 触发;design LLD)。
  void _touchIdleTimer() {
    _idleTimer?.cancel();
    _armIdleTimer();
  }

  void _armIdleTimer() {
    _idleTimer = _idleTimerFactory(idleTimeout, _onIdleTimeout);
  }

  void _onIdleTimeout() {
    _idleTimer = null;
    if (_activeRequests > 0) {
      // 请求进行中不回收:顺延重置整窗(FR-1)。
      _armIdleTimer();
      return;
    }
    final process = _process;
    if (process == null || _stateNotifier.value is! EngineReady) return;
    // 先解除崩溃监听再杀(killTree 触发的退出不得误判崩溃)。
    _process = null;
    _setState(const EngineStopped());
    _log('engine idle-stop');
    // Graceful kill -> 2s 宽限 -> taskkill 兜底(ADR-3);无人等待此果。
    unawaited(_launcher.killTree(process.pid).catchError((_) {}));
  }

  void _setState(EngineState next) => _stateNotifier.value = next;

  /// llama-server 参数(ADR-6)。
  static List<String> _argsFor(int port, String modelPath) => [
        '--host', _host,
        '--port', '$port',
        '-m', modelPath,
        '-c', '$_ctxSize',
        '-ngl', '$_gpuLayers',
        '--jinja',
        '--no-webui',
      ];
}

// -- 生产缺省缝(dart:io 真实现;单测全部注入 fake) ---------------------------

Future<void> _defaultDelay(Duration delay) => Future<void>.delayed(delay);

void _defaultEngineLog(String line) => debugPrint(line);

Timer _defaultIdleTimer(Duration duration, void Function() onFire) =>
    Timer(duration, onFire);

/// ADR-2:bind 试探取 OS 分配的空闲临时端口后立即释放给 llama-server;
/// 试探与引擎 bind 间的竞态由启动失败退避+重扫兜住(design Risks)。
Future<int> _defaultPortScan() async {
  const attempts = 10;
  Object? lastError;
  for (var i = 0; i < attempts; i++) {
    try {
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      return port;
    } catch (e) {
      lastError = e;
    }
  }
  throw StateError('no free port available: $lastError');
}

/// ADR-4:GET /health;llama-server 模型加载完成返回 200,加载中 503,
/// 未起为连接拒绝 —— 非 200/异常一律视为未就绪。
Future<bool> _defaultHealthProbe(Uri healthUrl) async {
  final client = HttpClient();
  try {
    final request = await client
        .getUrl(healthUrl)
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    return response.statusCode == HttpStatus.ok;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

String _defaultExePath() => EngineManagerImpl.bundledExeName;
