import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';

import 'package:yucai_client/assistant/data/http_downloader.dart';
import 'package:yucai_client/assistant/data/model_manager_impl.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';

/// F67-T2:ModelManagerImpl 双面实现(ModelManagerPort + ModelStore)。
///
/// 全缝注入(NFR-1):mock [ModelHttpClient] 零真网络、fake EngineManager
/// (shutdown 记录)、supportDirFn 指 temp、测试 manifest(小字节 sha 可
/// 预计算 —— 生产 [kModelManifest] 的 sha 对应 2.5GB 真件,单测不可复现,
/// 经构造缺省参数缝注入同形 fake,生产缺省不变)。
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('f67_model_manager_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  // -- fixture ---------------------------------------------------------------

  /// 测试清单:小字节内容可预计算 sha;URL 模板/路径语义与生产同构。
  final fullBody = utf8.encode('yucai model fixture bytes 0123456789');
  final fakeManifest = ModelManifest(
    repo: 'test/repo',
    file: 'test-model.gguf',
    sha256: sha256.convert(fullBody).toString(),
    totalBytes: fullBody.length,
  );

  File targetFile() => File(
        [temp.path, 'yucai', 'models', fakeManifest.file]
            .join(Platform.pathSeparator),
      );

  File partFile() => File('${targetFile().path}.part');

  _Harness makeHarness({
    List<Object> plan = const [],
    int throttleMs = 0,
    bool diskHasModel = false,
    List<int> diskPart = const [],
  }) {
    if (diskHasModel) {
      targetFile()
        ..createSync(recursive: true)
        ..writeAsBytesSync(fullBody, flush: true);
    }
    if (diskPart.isNotEmpty) {
      partFile()
        ..createSync(recursive: true)
        ..writeAsBytesSync(diskPart, flush: true);
    }
    return _Harness(
      httpClient: _MockHttpClient(plan),
      temp: temp,
      manifest: fakeManifest,
      throttleMs: throttleMs,
    );
  }

  /// 轮询等待条件成立(真文件 IO flush 的完成时机不定,零 delay 泵不够)。
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 200 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(condition(), isTrue, reason: 'condition not met before timeout');
  }

  test('首下全流程:200 全量流 → ready + 文件内容正确 + ModelStore 面一致',
      () async {
    final h = makeHarness(plan: [_Resp.ok(fullBody)]);
    expect(h.manager.state.value, const ModelNotDownloaded());
    expect(await h.manager.modelPath(), isNull); // 未下载面
    expect(await h.manager.isReady(), isFalse);

    await h.manager.download();

    expect(h.manager.state.value, const ModelReady());
    expect(targetFile().readAsBytesSync(), fullBody);
    expect(await partFile().exists(), isFalse); // rename 落地,.part 消失
    expect(await h.manager.modelPath(), targetFile().path);
    expect(await h.manager.isReady(), isTrue);
    // 首下不带 Range。
    expect(h.http.calls.single.rangeFrom, isNull);
    expect(h.http.calls.single.url.toString(),
        'https://huggingface.co/${fakeManifest.repo}/resolve/main/${fakeManifest.file}');
    expect(h.logs.any((l) => l.startsWith('model ready')), isTrue);
  });

  test('续传:.part 预置 100 字节 → 请求带 rangeFrom=100 且拼接正确', () async {
    final head = List<int>.generate(100, (i) => i); // 0..99
    final tail = List<int>.generate(50, (i) => 200 + i);
    final whole = [...head, ...tail];
    partFile()..createSync(recursive: true)..writeAsBytesSync(head, flush: true);
    final h = _Harness(
      httpClient: _MockHttpClient([
        _Resp.ok(tail, statusCode: 206, totalLength: whole.length),
      ]),
      temp: temp,
      manifest: ModelManifest(
        repo: fakeManifest.repo,
        file: fakeManifest.file,
        sha256: sha256.convert(whole).toString(),
        totalBytes: whole.length,
      ),
    );

    await h.manager.download();

    expect(h.manager.state.value, const ModelReady());
    expect(targetFile().readAsBytesSync(), whole);
    expect(h.http.calls.single.rangeFrom, 100);
    expect(h.http.calls.single.url.host, 'huggingface.co');
  });

  test('暂停:pause 后状态 paused(received/total)+ .part 在;恢复走 Range 完成',
      () async {
    final h = makeHarness();
    final controller = StreamController<List<int>>();
    h.http.plan = [
      _Resp.stream(totalLength: fullBody.length, body: controller.stream),
    ];

    final downloading = h.manager.download();
    controller.add(fullBody.sublist(0, 10));
    await until(() => h.manager.state.value is ModelDownloading);

    h.manager.pause();
    await downloading;

    expect(
      h.manager.state.value,
      ModelPaused(receivedBytes: 10, totalBytes: fullBody.length),
    );
    expect(await partFile().exists(), isTrue);
    expect(partFile().lengthSync(), 10);
    expect(targetFile().existsSync(), isFalse);

    // 恢复:Range 请求从 10 续,剩余内容完成 → ready(断点续传场景 FR-1)。
    h.http.plan = [
      _Resp.ok(fullBody.sublist(10), statusCode: 206),
    ];
    await h.manager.download();
    expect(h.manager.state.value, const ModelReady());
    expect(targetFile().readAsBytesSync(), fullBody);
    expect(h.http.calls.last.rangeFrom, 10);
    await controller.close();
  });

  test('取消:cancel → notDownloaded + .part 无', () async {
    final h = makeHarness();
    final controller = StreamController<List<int>>();
    h.http.plan = [
      _Resp.stream(totalLength: fullBody.length, body: controller.stream),
    ];

    final downloading = h.manager.download();
    controller.add(fullBody.sublist(0, 8));
    await until(() => partFile().existsSync() && partFile().lengthSync() == 8);

    h.manager.cancel();
    await downloading;

    expect(h.manager.state.value, const ModelNotDownloaded());
    expect(await partFile().exists(), isFalse);
    expect(targetFile().existsSync(), isFalse);
    await controller.close();
  });

  test('sha 不符:corrupt + 无落地 + .part 留', () async {
    final wrong = utf8.encode('tampered content, sha mismatch');
    final h = makeHarness(plan: [_Resp.ok(wrong)]);

    await h.manager.download();

    expect(h.manager.state.value,
        const ModelError(ModelFailureReason.corrupt));
    expect(targetFile().existsSync(), isFalse); // 不落地(ADR-3)
    expect(await partFile().exists(), isTrue); // .part 保留可整段重下
    expect(h.logs.any((l) => l.startsWith('model verify failed')), isTrue);
  });

  test('corrupt 后重试:删 .part 从零整段重下(ADR-3)', () async {
    final wrong = utf8.encode('bad first attempt');
    final h = makeHarness(plan: [_Resp.ok(wrong)]);
    await h.manager.download();
    expect(h.manager.state.value,
        const ModelError(ModelFailureReason.corrupt));

    h.http.plan = [_Resp.ok(fullBody)];
    await h.manager.download();

    expect(h.manager.state.value, const ModelReady());
    expect(targetFile().readAsBytesSync(), fullBody);
    expect(h.http.calls.last.rangeFrom, isNull); // 从零,非续传
  });

  test('官方失败回落镜像:第一源抛 → 第二源成功,两次请求,状态无感 ready',
      () async {
    final h = makeHarness(plan: [
      Exception('official source unreachable'),
      _Resp.ok(fullBody),
    ]);

    await h.manager.download();

    expect(h.manager.state.value, const ModelReady());
    expect(targetFile().readAsBytesSync(), fullBody);
    expect(h.http.calls, hasLength(2));
    expect(h.http.calls.first.url.host, 'huggingface.co');
    expect(h.http.calls.last.url.host, 'hf-mirror.com');
  });

  test('双源皆败:ModelError(network)(.part 留可续传)', () async {
    final h = makeHarness(plan: [
      const SocketException('official down'),
      const SocketException('mirror down'),
    ]);

    await h.manager.download();

    expect(h.manager.state.value,
        const ModelError(ModelFailureReason.network));
  });

  test('删除三态之一 notDownloaded:直过,文件面无残留,回 notDownloaded',
      () async {
    final h = makeHarness();

    await h.manager.delete();

    expect(h.manager.state.value, const ModelNotDownloaded());
    expect(targetFile().existsSync(), isFalse);
    expect(partFile().existsSync(), isFalse);
  });

  test('删除三态之二 downloading:先 cancel(断流删 .part)+ shutdown 联动',
      () async {
    final h = makeHarness();
    final controller = StreamController<List<int>>();
    h.http.plan = [
      _Resp.stream(totalLength: fullBody.length, body: controller.stream),
    ];

    final downloading = h.manager.download();
    controller.add(fullBody.sublist(0, 6));
    await until(() => partFile().existsSync());

    await h.manager.delete();
    await downloading;

    expect(h.manager.state.value, const ModelNotDownloaded());
    expect(partFile().existsSync(), isFalse); // cancel 语义:删 .part
    expect(h.engine.shutdownCalls, 1); // ADR-5 联动
    await controller.close();
  });

  test('删除三态之三 ready:shutdown 被调 + .gguf 删除 + 回 notDownloaded(F65 消费)',
      () async {
    final h = makeHarness(diskHasModel: true);
    await h.manager.diskUsageBytes(); // 等 init 完成
    expect(h.manager.state.value, const ModelReady());

    await h.manager.delete();

    expect(h.manager.state.value, const ModelNotDownloaded());
    expect(targetFile().existsSync(), isFalse);
    expect(h.engine.shutdownCalls, 1);
    expect(h.logs.any((l) => l.startsWith('model delete')), isTrue);
    expect(await h.manager.modelPath(), isNull); // ModelStore 面同步翻转
    expect(await h.manager.isReady(), isFalse);
  });

  test('磁盘重启初始化:目标文件在 → 构造即 ready(F66 引擎侧无缝衔接)',
      () async {
    final h = makeHarness(diskHasModel: true);

    expect(await h.manager.isReady(), isTrue);
    expect(await h.manager.modelPath(), targetFile().path);
    expect(h.manager.state.value, const ModelReady());
    expect(h.http.calls, isEmpty); // 零网络
  });

  test('磁盘重启初始化:.part 在 → 构造即 paused(断点续传基数)', () async {
    final h = makeHarness(diskPart: fullBody.sublist(0, 12));
    await until(() => h.manager.state.value is ModelPaused);

    expect(
      h.manager.state.value,
      ModelPaused(receivedBytes: 12, totalBytes: fakeManifest.totalBytes),
    );
    expect(h.http.calls, isEmpty);
  });

  test('diskUsage 四口径:notDownloaded=0 / downloading=.part / paused=.part / ready=文件长',
      () async {
    // 未下载。
    var h = makeHarness();
    expect(await h.manager.diskUsageBytes(), 0);

    // downloading → paused(.part 长同口径,FR-3 已收字节)。
    h = makeHarness();
    final controller = StreamController<List<int>>();
    h.http.plan = [
      _Resp.stream(totalLength: fullBody.length, body: controller.stream),
    ];
    final downloading = h.manager.download();
    controller.add(fullBody.sublist(0, 15));
    await until(() => partFile().existsSync() && partFile().lengthSync() == 15);
    expect(await h.manager.diskUsageBytes(), 15);
    h.manager.pause();
    await downloading;
    expect(h.manager.state.value,
        ModelPaused(receivedBytes: 15, totalBytes: fullBody.length));
    expect(await h.manager.diskUsageBytes(), 15);

    // ready = 文件长。
    h = makeHarness(diskHasModel: true);
    expect(await h.manager.diskUsageBytes(), fullBody.length);
    await controller.close();
  });

  test('进度节流:节流缝=0 时每块更新 downloading(含首块强制)', () async {
    final h = makeHarness(throttleMs: 0);
    // 三块拼成完整 fullBody(EOF 后 sha 必须可校验通过)。
    final chunks = [
      fullBody.sublist(0, 10),
      fullBody.sublist(10, 20),
      fullBody.sublist(20),
    ];
    h.http.plan = [
      _Resp.stream(
        totalLength: fullBody.length,
        body: Stream.fromIterable(chunks),
      ),
    ];

    final seen = <ModelState>[h.manager.state.value];
    h.manager.state.addListener(() => seen.add(h.manager.state.value));

    await h.manager.download();

    // notDownloaded → downloading(0,首块前强制)→ 10 → 20 → 38 → ready。
    final downloadingStates =
        seen.whereType<ModelDownloading>().map((s) => s.receivedBytes).toList();
    expect(downloadingStates, [0, 10, 20, fullBody.length]);
    expect(seen.last, const ModelReady());
    // 进度分母 = totalLength(响应),received 含续传基数口径一致。
    expect(
      seen.whereType<ModelDownloading>().map((s) => s.totalBytes).toSet(),
      {fullBody.length},
    );
  });

  test('进度节流:默认 200ms 时快速块被合并(中间块不触发通知)', () async {
    final h = makeHarness(throttleMs: 200);
    final chunks = [
      fullBody.sublist(0, 10),
      fullBody.sublist(10, 20),
      fullBody.sublist(20),
    ];
    h.http.plan = [
      _Resp.stream(
        totalLength: fullBody.length,
        body: Stream.fromIterable(chunks),
      ),
    ];

    final seen = <ModelState>[h.manager.state.value];
    h.manager.state.addListener(() => seen.add(h.manager.state.value));

    await h.manager.download();

    // 测试内三块同毫秒级到达:只有首块强制发射 + EOF 后终态,无中间块。
    final downloadingStates =
        seen.whereType<ModelDownloading>().map((s) => s.receivedBytes).toList();
    expect(downloadingStates, [0]);
    expect(seen.last, const ModelReady());
  });

  test('日志全 English 结构化(ASCII 门禁)', () async {
    final h = makeHarness(plan: [_Resp.ok(fullBody)]);
    await h.manager.download();
    await h.manager.delete();

    expect(h.logs.any((l) => l.startsWith('model download host=')), isTrue);
    for (final line in h.logs) {
      expect(line, matches(RegExp(r'^[\x20-\x7E]*$')),
          reason: 'non-ASCII log line: $line');
    }
  });

  test('manifest getter 直通构造清单(生产缺省 = kModelManifest)', () async {
    final h = makeHarness();
    expect(h.manager.manifest, fakeManifest);
    final bare = ModelManagerImpl(
      _MockHttpClient(const []),
      _FakeEngineManager(),
    );
    expect(bare.manifest, kModelManifest);
  });

  test('状态守卫:downloading 中再 download() 不发起新请求', () async {
    final h = makeHarness();
    final controller = StreamController<List<int>>();
    h.http.plan = [
      _Resp.stream(totalLength: fullBody.length, body: controller.stream),
    ];

    final first = h.manager.download();
    await until(() => h.manager.state.value is ModelDownloading);
    final second = h.manager.download();
    await controller.addStream(Stream.value(fullBody));
    await controller.close();
    await Future.wait([first, second]);

    expect(h.http.calls, hasLength(1)); // downloading 守卫:零重复请求
    expect(h.manager.state.value, const ModelReady());
  });
}

// -- 测试替身 -----------------------------------------------------------------

/// 单次调用计划:异常(抛给管理器)或 [_Resp](成功响应)。
class _MockHttpClient implements ModelHttpClient {
  _MockHttpClient(List<Object> plan) : plan = List<Object>.of(plan);

  List<Object> plan;
  final calls = <({Uri url, int? rangeFrom})>[];

  @override
  Future<ModelHttpResponse> get(Uri url, {int? rangeFrom}) async {
    calls.add((url: url, rangeFrom: rangeFrom));
    if (plan.isEmpty) {
      throw StateError('unexpected http call: $url rangeFrom=$rangeFrom');
    }
    final next = plan.removeAt(0);
    if (next is ModelHttpResponse) {
      return next;
    }
    throw next; // Exception/Error/任意对象按抛错计划处理
  }
}

/// 成功响应计划项构造。
class _Resp {
  /// 全量/Range 段字节一次性流(默认 200;Range 用 [statusCode] 206)。
  static ModelHttpResponse ok(
    List<int> bytes, {
    int statusCode = 200,
    int? totalLength,
  }) =>
      ModelHttpResponse(
        statusCode: statusCode,
        contentLength: bytes.length,
        totalLength: totalLength ?? bytes.length,
        body: Stream.value(List<int>.of(bytes)),
      );

  /// 受控流(pause/cancel 测试用 StreamController 驱动)。
  static ModelHttpResponse stream({
    required int totalLength,
    required Stream<List<int>> body,
  }) =>
      ModelHttpResponse(
        statusCode: 200,
        totalLength: totalLength,
        body: body,
      );
}

/// shutdown 记录 fake(ADR-5 联动断言)。
class _FakeEngineManager implements EngineManager {
  int shutdownCalls = 0;

  @override
  ValueListenable<EngineState> get state =>
      ValueNotifier<EngineState>(const EngineStopped());

  @override
  Future<void> ensureReady() async {}

  @override
  Future<void> shutdown() async => shutdownCalls++;

  @override
  void beginActivity() {}

  @override
  void endActivity() {}
}

/// 组装好的被测系统(manager + 双 fake 观测面)。
class _Harness {
  _Harness({
    required _MockHttpClient httpClient,
    required Directory temp,
    required ModelManifest manifest,
    int throttleMs = 0,
  })  : http = httpClient,
        engine = _FakeEngineManager(),
        logs = <String>[] {
    manager = ModelManagerImpl(
      http,
      engine,
      supportDirFn: () async => temp,
      manifest: manifest,
      throttleMs: throttleMs,
      log: logs.add,
    );
  }

  final _MockHttpClient http;
  final _FakeEngineManager engine;
  final List<String> logs;
  late final ModelManagerImpl manager;
}
