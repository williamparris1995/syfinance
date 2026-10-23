// F66-T4 真引擎集成冒烟(NFR-1):真 llama-server.exe + tiny gguf fixture。
//
// 与 engine_manager_impl_test(全 fake 缝,零真进程)互补 —— 本测把生产件
// 按真实形态组装起来跑通一条最小生命线:
//   ProcessLauncherImpl(真 dart:io 进程 + taskkill 树杀)
//   + tool/engines/llama-server.exe(tool/fetch_engine.py 钉死 b11669 下载,
//     不入 git)+ test/fixtures/models/stories15M-q4_0.gguf(入 git 的测试
//   资产)经固定路径 ModelStore 注入 + EngineManagerImpl 其余缝全走生产
//   缺省(真 /health 探测/真端口扫描/真退避延时)。
//
// 断言序列(design LLD 冒烟段):state 转移 Stopped→Starting→Ready →
// 一次最小推理往返(fixture 为 base LM,无 chat 模板 —— 走 /v1/completions
// 降级断言,design Open Question 回填注明;模板面 sprint 真模型门验)→
// shutdown() → 进程真不存在(tasklist pid 探测)→ Stopped。
//
// 不断言(ADR-6/design 记档):具体 GPU/CPU 后端(Vulkan 不可用回落 CPU
// 是 llama.cpp 自身行为);工具调用面(tiny fixture 无工具模板)。
//
// skip-by-env:exe/fixture 任一缺失或非 Windows 自动跳过(有资产必跑 ——
// 本机验证门即真跑);60s 用例级预算 = 引擎内部 30s 健康预算 × CI 慢机
// 余量(model 加载 + 进程拉起 + 推理往返)。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/data/engine_manager_impl.dart';
import 'package:yucai_client/assistant/data/process_launcher.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_store_port.dart';

// flutter test 的 cwd = 包根(yucai/client);exe/fixture 相对路径由此锚定。
final String _engineExe =
    '${Directory.current.path}/tool/engines/llama-server.exe';
final String _fixtureModel =
    '${Directory.current.path}/test/fixtures/models/stories15M-q4_0.gguf';

/// skip-by-env 判定(套件加载时同步探资产):非 Windows / exe 缺失 /
/// fixture 缺失 → 跳过;null = 资产在位必跑。
String? _skipReason() {
  if (!Platform.isWindows) {
    return 'engine smoke is Windows-only (Vulkan build + taskkill tree kill)';
  }
  if (!File(_engineExe).existsSync() ||
      !File(_fixtureModel).existsSync()) {
    return 'engine assets not present — run tool/fetch_engine';
  }
  return null;
}

/// fixture 固定路径 ModelStore(brief 指定形状:生产 ModelStoreImpl 指向
/// %APPDATA% 用户模型位,冒烟以 fake 实现改指仓内 fixture 文件 —— 文件
/// 本身是真件,存在性语义与生产一致)。
class _FixtureModelStore implements ModelStore {
  @override
  Future<String?> modelPath() async => _fixtureModel;

  @override
  Future<bool> isReady() async => true;
}

/// pid 捕获装饰器:包着**生产** [ProcessLauncherImpl](start/killTree 全部
/// 真实现),仅记录最后拉起进程的 pid 供「shutdown 后进程不存在」断言 ——
/// EngineManager 不外露 pid,tasklist 按映像名查会误伤并行跑的同类进程。
class _PidCapturingLauncher implements ProcessLauncher {
  _PidCapturingLauncher(this._inner);

  final ProcessLauncher _inner;
  int? lastPid;

  @override
  Future<LaunchedProcess> start({
    required String exe,
    required List<String> args,
  }) async {
    final process = await _inner.start(exe: exe, args: args);
    lastPid = process.pid;
    return process;
  }

  @override
  Future<void> killTree(int pid) => _inner.killTree(pid);
}

/// tasklist 精确 pid 存活探测(与 ProcessLauncherImpl._isAlive 同口径;
/// token 比较避免 23 vs 1234 子串误报)。
bool _pidAlive(int pid) {
  final result = Process.runSync(
    'tasklist',
    ['/FI', 'PID eq $pid', '/NH'],
  );
  final tokens = (result.stdout as String).split(RegExp(r'\s+'));
  return tokens.contains('$pid');
}

void main() {
  test(
    'real engine smoke: start -> ready -> completion roundtrip -> shutdown',
    () async {
      final engineLog = <String>[];
      final launcher = _PidCapturingLauncher(const ProcessLauncherImpl());
      final manager = EngineManagerImpl(
        launcher,
        _FixtureModelStore(),
        () => const AssistantConfig(enabled: true, model: 'stories15M-q4_0'),
        // 唯一非生产缺省缝:exe 路径指 tool/engines(T5 捆绑前生产件落位
        // 前的过渡口径,见 EngineManagerImpl.exePath 文档);其余(健康
        // 探测/端口扫描/退避延时/闲置 Timer)全真。
        exePath: () => _engineExe,
        log: engineLog.add,
      );
      addTearDown(manager.shutdown);

      // 1) 状态转移:Stopped -> Starting -> Ready(订阅先于 ensureReady,
      //    不漏首转移)。
      final observed = <String>[manager.state.value.toString()];
      manager.state.addListener(
        () => observed.add(manager.state.value.toString()),
      );
      await manager.ensureReady();

      expect(observed, containsAllInOrder(['EngineStopped', 'EngineStarting']));
      final ready = manager.state.value;
      expect(ready, isA<EngineReady>(), reason: 'log: $engineLog');
      // endpoint 即 /v1 端点(FR-4 调用面形状)。
      final endpoint = (ready as EngineReady).endpoint;
      expect(endpoint.host, '127.0.0.1');

      // 2) 一次最小推理往返:fixture=base LM 无 chat 模板 → /v1/completions
      //    降级断言(design Open Question 回填;chat 端点=sprint 真模型门)。
      final completion = await _minimalCompletion(endpoint);
      expect(
        completion,
        isNotEmpty,
        reason: 'engine replied with empty text, log: $engineLog',
      );
      if (engineLog.isNotEmpty) {
        debugPrint('engine log: $engineLog');
      }
      debugPrint('smoke completion: "$completion"');

      // 3) shutdown → 进程树真终结(pid 探测轮询;taskkill 的 2s 宽限已含
      //    在 killTree 内,这里只兜底等 IO 视角可见)→ Stopped。
      final pid = launcher.lastPid;
      expect(pid, isNotNull, reason: 'launcher never captured a pid');
      await manager.shutdown();
      var gone = !_pidAlive(pid!);
      for (var i = 0; !gone && i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        gone = !_pidAlive(pid);
      }
      expect(gone, isTrue, reason: 'pid $pid still alive after shutdown');
      expect(manager.state.value, isA<EngineStopped>());
    },
    timeout: const Timeout(Duration(seconds: 60)), // CI 慢机余量(内部健康预算 30s)
    skip: _skipReason(),
  );
}

/// POST /v1/completions 一次短 prompt 往返,返回首 choice 文本(空=失败)。
Future<String> _minimalCompletion(Uri v1Endpoint) async {
  // 注意 Uri.resolve 的 last-segment 语义:base path 以 /v1 结尾时
  // resolve('completions') 会丢掉 v1 段 —— 直接字符串拼接钉死全路径。
  final completionsUrl = Uri.parse('$v1Endpoint/completions');
  final client = HttpClient();
  try {
    final request = await client.postUrl(completionsUrl);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'prompt': 'Once upon a time',
        // OpenAI 兼容形状(max_tokens;fixture 训练上下文 128,server 端
        // 自动 cap,显式限长不依赖引擎默认)。
        'max_tokens': 16,
      }),
    );
    final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != HttpStatus.ok) {
      throw StateError('completions HTTP ${response.statusCode}: $body');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw StateError('completions response missing choices: $body');
    }
    return ((choices.first as Map)['text'] ?? '') as String;
  } finally {
    client.close(force: true);
  }
}
