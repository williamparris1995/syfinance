// F66 集成帽石测:引擎管理 × 流客户端 × 状态流 模块级 wiring 证明。
//
// 定位(与既有两极互补):
// - engine_manager_impl_test —— 全缝 fake(健康探测/端口扫描/launcher 全替),
//   生命周期编排语义的单元级;
// - engine_smoke_test —— 真 llama-server.exe 真进程(NFR-1,skip-by-env);
// - 本文件 —— 中间层「真组件组装」:三件生产件按真实形态手工组装,
//   唯一替换的是「exe 本体」——fake launcher 在真端口扫描给出的端口上
//   绑一个本机 loopback 假 llama 服务(HttpServer 模拟 /health 200 与
//   /v1/chat/completions SSE),**不真拉进程**(NFR-2 缝内)。
//
// 真件清单:
//   _FixtureModelStore(F67-T2 起生产实现 = ModelManagerImpl 下载管理,
//   本 wiring 测不涉下载面 —— 以最小 fake 保「固定路径存在性」同语义,
//   真 gguf 命名文件 + 真存在性检查)→ EngineManagerImpl(健康探测/
//   端口扫描/退避延时全走生产缺省 —— 真 ServerSocket bind(0) 扫端口 +
//   真 HTTP GET /health;launcher/exe 为假)→ LlmStreamClientImpl(真
//   openai_dart 客户端,baseUrl 从 Ready 端点流入,打向假服务随机端口)。
//
// 断言链(FR-1/FR-3/FR-4 wiring 级):未就绪 Stopped → chat() 内置
// ensureReady 懒拉起(经 fake launcher,ADR-6 参数+fixture 模型路径)→
// 真健康探测转 Ready(状态流不漏转移)→ 请求真实落在假服务的扫描端口
// (/health → /v1/chat/completions 顺序)→ SSE 应答解析为 LlmChunk 流 →
// begin/endActivity 经 port 配对(透明记录器代持,内联真 impl 副作用可
// 观测:begin 触摸重挂闲置窗)→ shutdown 树杀假边车(端口真释放、崩溃
// 监听解除不复活)。附:模型缺失 wiring 路径(Error(modelMissing) 前置
// 不起进程 + 流客户端自解释 StateError + finally 配对)。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/data/engine_manager_impl.dart';
import 'package:yucai_client/assistant/data/llm_stream_client_impl.dart';
import 'package:yucai_client/assistant/data/process_launcher.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_store_port.dart';

/// 假边车 SSE 最小应答(与 llm_stream_client_impl_test 同款、已证可被
/// openai_dart 11.x createStream 解析):一颗 content 增量 + 一颗 stop 终包。
const _sseBody =
    'data: {"id":"c1","object":"chat.completion.chunk","created":0,'
    '"model":"${AssistantConfig.defaultModel}","choices":[{"index":0,'
    '"delta":{"content":"engine wired"},"finish_reason":null}]}\n\n'
    'data: {"id":"c1","object":"chat.completion.chunk","created":0,'
    '"model":"${AssistantConfig.defaultModel}","choices":[{"index":0,'
    '"delta":{},"finish_reason":"stop"}]}\n\n'
    'data: [DONE]\n\n';

void main() {
  test(
    'wiring capstone: stopped -> chat() lazy start (fake launcher) -> real '
    'probe/scan -> Ready on scanned port -> SSE -> LlmChunks -> begin/end '
    'paired -> shutdown releases the sidecar port',
    () async {
      // -- fixture:固定路径存在性 ModelStore 落位 <tmp>/yucai/models/<default>.gguf --
      final tmpRoot = await Directory.systemTemp.createTemp('f66_wiring');
      addTearDown(() async => tmpRoot.delete(recursive: true));
      final modelFile = File(
        [
          tmpRoot.path,
          'yucai',
          'models',
          '${AssistantConfig.defaultModel}.gguf',
        ].join(Platform.pathSeparator),
      )
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final models = _FixtureModelStore(modelFile.path);
      // 注入缝 → fixture 文件的 wiring 前置断言(ADR-7 固定落位)。
      expect(await models.modelPath(), modelFile.path);
      expect(await models.isReady(), isTrue);

      // -- 组装:真 EngineManagerImpl(healthProbe/portScan/delay 全生产缺省)--
      final launcher = _FakeSidecarLauncher();
      final idleTimers = <_RecordingIdleTimer>[];
      final engineLog = <String>[];
      // 假 exe:supportDirFn 缝同目录下的固定名(fake launcher 不触文件系统,
      // 区别于 smoke 测试的真 exe)。
      final fakeExe = [
        tmpRoot.path,
        EngineManagerImpl.bundledExeName,
      ].join(Platform.pathSeparator);
      final manager = EngineManagerImpl(
        launcher,
        models,
        () => const AssistantConfig(enabled: true),
        exePath: () => fakeExe,
        // 闲置 Timer 缝 = 透明记录包装(真 Timer 真时序,只加观测;10min
        // 窗口在测试生命周期内不触发)。
        idleTimerFactory: (duration, onFire) {
          final timer = _RecordingIdleTimer(duration, onFire);
          idleTimers.add(timer);
          return timer;
        },
        log: engineLog.add,
      );
      addTearDown(manager.shutdown);
      // 透明记录器:begin/end/ensureReady 经 port 协议全部内联转发到真
      // manager(副作用真实发生),只记调用序供配对断言。
      final recorder = _RecordingEngine(manager);
      final client = LlmStreamClientImpl(recorder);

      // 1) 未就绪:Stopped;订阅先于请求(FR-3 当前值+转移不漏)。
      expect(manager.state.value, const EngineStopped());
      final seen = <EngineState>[manager.state.value];
      manager.state.addListener(() => seen.add(manager.state.value));

      // 2) chat() 自 stopped 懒拉起(客户端内置 ensureReady 兜底,ADR-1)。
      final chunks = await client.chat(const LlmChatRequest(
        model: AssistantConfig.defaultModel,
        messages: [
          {'role': 'user', 'content': 'wiring check'},
        ],
        toolsSchema: [],
      )).toList();

      // 3) 状态流:Stopped -> Starting -> Ready(FR-1 懒启动全转移 wiring)。
      expect(seen, hasLength(3), reason: 'observed: $seen');
      expect(seen[1], const EngineStarting());
      final ready = seen[2] as EngineReady;
      final port = ready.endpoint.port;
      expect(
        ready.endpoint,
        Uri.parse('http://127.0.0.1:$port/v1'),
        reason: 'FR-4 端点形状(loopback + 扫描端口 + /v1)',
      );
      expect(manager.state.value, ready);

      // 4) fake launcher 被真拉起一次:ADR-6 参数逐项 + --port 即扫描端口
      //    + -m 即 fixture 模型真路径(FR-4「启动参数含模型路径」)。
      final start = launcher.starts.single;
      expect(start.exe, fakeExe);
      expect(start.args, [
        '--host', '127.0.0.1',
        '--port', '$port',
        '-m', modelFile.path,
        '-c', '4096',
        '-ngl', '999',
        '--jinja',
        '--no-webui',
      ]);

      // 5) 端点真实贯通:真健康探测(/health)与真 openai_dart 流请求
      //    (/v1/chat/completions)都落在假边车的同一随机端口,顺序即生命线。
      expect(launcher.servedPaths, ['/health', '/v1/chat/completions']);

      // 6) SSE 应答被解析为 LlmChunk 流(content 增量 + stop 终包)。
      expect(chunks, hasLength(2));
      expect((chunks[0] as TextChunk).delta, 'engine wired');
      expect((chunks[1] as Finish).reason, 'stop');

      // 7) begin/endActivity 配对:port 协议上恰一次、序为 begin ->
      //    ensureReady -> end;begin 的真实副作用可见(闲置窗被触摸重挂)。
      expect(recorder.activityLog, ['begin', 'ensureReady', 'end']);
      expect(idleTimers, hasLength(2)); // begin 触摸 + ensureReady 触摸
      expect(
        idleTimers.every((t) => t.duration == const Duration(minutes: 10)),
        isTrue,
        reason: 'FR-1 10min 窗口按生产缺省装配',
      );
      expect(idleTimers.first.cancelled, isTrue); // 旧窗被触摸取消
      expect(idleTimers.last.isActive, isTrue); // 请求后新窗在挂

      // 8) English 结构化日志(NFR-3 顺带钉死:启动/就绪行 + 全 ASCII)。
      expect(
        engineLog.first,
        'engine start port=$port model=${AssistantConfig.defaultModel}',
      );
      expect(
        engineLog.any((line) => line.startsWith('engine ready ms=')),
        isTrue,
        reason: 'ready log line missing: $engineLog',
      );
      for (final line in engineLog) {
        expect(
          line,
          matches(RegExp(r'^[\x20-\x7E]*$')),
          reason: 'non-ASCII log line: $line',
        );
      }

      // 9) shutdown 树杀假边车:killTree 到 pid、端口真释放(新连接被拒)、
      //    崩溃监听解除(killTree 触发的 exitCode 完成不引发复活拉起)。
      final pid = launcher.processes.single.pid;
      await manager.shutdown();
      expect(manager.state.value, const EngineStopped());
      expect(launcher.killTreeCalls, [pid]);
      expect(launcher.processes.single.killed, isTrue);
      expect(idleTimers.last.cancelled, isTrue); // shutdown 取消闲置窗
      await Future<void>.delayed(Duration.zero); // 让 exit watcher 跑一轮
      expect(launcher.starts, hasLength(1), reason: 'watcher must not respawn');
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(seconds: 2),
        );
        socket.destroy();
        fail('port $port still accepting connections after shutdown');
      } on SocketException {
        // expected: fake sidecar released the scanned port
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  test(
    'wiring: model missing -> Error(modelMissing) with zero spawn, '
    'self-explaining StateError from the stream client, begin/end still paired',
    () async {
      // 空 support 目录:存在性检查得 null(FR-2 源)。
      final tmpRoot = await Directory.systemTemp.createTemp('f66_wiring_mm');
      addTearDown(() async => tmpRoot.delete(recursive: true));
      final models = _FixtureModelStore(
        [
          tmpRoot.path,
          'yucai',
          'models',
          '${AssistantConfig.defaultModel}.gguf',
        ].join(Platform.pathSeparator),
      );
      expect(await models.modelPath(), isNull);

      final launcher = _FakeSidecarLauncher();
      final engineLog = <String>[];
      final manager = EngineManagerImpl(
        launcher,
        models,
        () => const AssistantConfig(enabled: true),
        exePath: () => 'nowhere/llama-server.exe',
        log: engineLog.add,
      );
      addTearDown(manager.shutdown);
      final recorder = _RecordingEngine(manager);
      final client = LlmStreamClientImpl(recorder);

      final seen = <EngineState>[manager.state.value];
      manager.state.addListener(() => seen.add(manager.state.value));

      // FR-4 未就绪错误语义 wiring:自解释 StateError(reason 名),零网络。
      await expectLater(
        client.chat(const LlmChatRequest(
          model: AssistantConfig.defaultModel,
          messages: [
            {'role': 'user', 'content': 'q'},
          ],
          toolsSchema: [],
        )),
        emitsError(isA<StateError>().having(
          (e) => e.message,
          'message',
          'engine not ready: modelMissing',
        )),
      );

      expect(manager.state.value, const EngineError(EngineFailureReason.modelMissing));
      expect(seen.last, const EngineError(EngineFailureReason.modelMissing));
      expect(launcher.starts, isEmpty); // 前置检查先于 spawn(FR-2)
      expect(launcher.servedPaths, isEmpty); // 零网络往返
      // 抛错路径 finally 兜底:port 协议 begin/end 仍严格配对。
      expect(recorder.activityLog, ['begin', 'ensureReady', 'end']);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

/// 固定路径存在性 ModelStore(F67-T2 前为生产 ModelStoreImpl 真件;
/// 简版退役后本测不涉下载面,以最小 fake 保 ADR-7 路径存在性同语义,
/// 文件本身仍是真件)。
class _FixtureModelStore implements ModelStore {
  _FixtureModelStore(this._path);

  final String _path;

  @override
  Future<String?> modelPath() async =>
      await File(_path).exists() ? _path : null;

  @override
  Future<bool> isReady() async => await modelPath() != null;
}

/// 透明 port 记录器:全部调用内联转发真 [EngineManager](副作用真实发生),
/// 仅记录 begin/end/ensureReady 调用序 —— 流客户端 × 引擎管理 port 协议的
/// 配对观测缝(区别于 llm_stream_client_impl_test 的全 fake:此处 ensureReady
/// 真的拉起了引擎、begin 真的触摸了闲置窗)。
class _RecordingEngine implements EngineManager {
  _RecordingEngine(this._inner);

  final EngineManager _inner;
  final activityLog = <String>[];

  @override
  ValueListenable<EngineState> get state => _inner.state;

  @override
  Future<void> ensureReady() async {
    activityLog.add('ensureReady');
    await _inner.ensureReady();
  }

  @override
  Future<void> shutdown() => _inner.shutdown();

  @override
  void beginActivity() {
    activityLog.add('begin');
    _inner.beginActivity();
  }

  @override
  void endActivity() {
    activityLog.add('end');
    _inner.endActivity();
  }
}

/// 假边车 launcher:start 即在 `--port <n>`(真端口扫描刚释放的口)上绑
/// 本机 loopback 假 llama 服务 —— 模拟真 exe「占端口+应答 /health 与
/// /v1/chat/completions」的行为面,**零真进程**(NFR-2:与 smoke 测的
/// 分界线)。killTree = 关服务 + 记 pid + exitCode(0) 完成(守护由
/// EngineManager 的 identical 检查兜住,与真杀进程同口径)。
class _FakeSidecarLauncher implements ProcessLauncher {
  final starts = <({String exe, List<String> args})>[];
  final processes = <_FakeSidecarProcess>[];
  final killTreeCalls = <int>[];
  final servedPaths = <String>[];

  @override
  Future<LaunchedProcess> start({
    required String exe,
    required List<String> args,
  }) async {
    starts.add((exe: exe, args: List<String>.of(args)));
    final portFlag = args.indexOf('--port');
    final port = int.parse(args[portFlag + 1]);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _serve(server);
    final process = _FakeSidecarProcess(7000 + processes.length, server);
    processes.add(process);
    return process;
  }

  @override
  Future<void> killTree(int pid) async {
    killTreeCalls.add(pid);
    final match = processes.where((p) => p.pid == pid).toList();
    if (match.isNotEmpty) await match.single.kill();
  }

  void _serve(HttpServer server) {
    () async {
      await for (final request in server) {
        servedPaths.add(request.uri.path);
        await request.drain<void>();
        final response = request.response;
        response.statusCode = HttpStatus.ok;
        if (request.uri.path == '/health') {
          await response.close();
        } else {
          // /v1/chat/completions:最小 SSE 应答(openai_dart 可解析形状)。
          response.headers.contentType =
              ContentType('text', 'event-stream', charset: 'utf-8');
          response.write(_sseBody);
          await response.close();
        }
      }
    }().ignore();
  }
}

/// 假边车进程句柄:pid + 永不完成的 exitCode(未崩溃)+ kill 即关服务。
class _FakeSidecarProcess implements LaunchedProcess {
  _FakeSidecarProcess(this.pid, this._server);

  @override
  final int pid;

  final HttpServer _server;
  final Completer<int> _exitCode = Completer<int>();
  bool killed = false;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Future<void> kill() async {
    if (killed) return;
    killed = true;
    await _server.close(force: true);
    if (!_exitCode.isCompleted) _exitCode.complete(0);
  }
}

/// 闲置 Timer 透明记录包装:真 Timer 真回调(10min 窗口测试期内不触发),
/// 只加 duration/cancelled 观测 —— begin 触摸重挂窗口的真实副作用在
/// wiring 级可见。
class _RecordingIdleTimer implements Timer {
  _RecordingIdleTimer(this.duration, void Function() onFire)
      : _real = Timer(duration, onFire);

  final Duration duration;
  final Timer _real;
  bool cancelled = false;

  @override
  void cancel() {
    cancelled = true;
    _real.cancel();
  }

  @override
  bool get isActive => _real.isActive;

  @override
  int get tick => _real.tick;
}
