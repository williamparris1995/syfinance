// F67-T3 loopback 集成测:真 IoModelHttpClient 打真 HttpServer(NFR-1)。
//
// 与 T2(model_manager_impl_test,mock ModelHttpClient 零真网络)互补:本
// 文件让生产 dart:io 客户端(真 socket/真 Range 请求头/真 Content-Range
// 解析/真流中断错误/真连接关闭)与 ModelManagerImpl 下载编排一起,打到
// `HttpServer.bind(loopback)` 假源上 —— ModelManagerImpl 的源 URL 模板
// 硬编码 huggingface.co/hf-mirror.com(ADR-4 单点),测试经 HttpOverrides
// 重定向 dart:io `HttpClient()` 工厂:官方域名 → 127.0.0.1:<officialPort>、
// hf-mirror → 127.0.0.1:<mirrorPort>(两端口双假源;生产码零改动,重定向
// 仅本装具)。清单注入 64KB 固定种子随机体+真 sha256(生产 2.5GB 钉死 sha
// 不可在测试复现),supportDir 指临时目录,EngineManager fake。
//
// 假源(_FakeSource)支持 Range(带 Range 头 → 206+Content-Range 对应
// 字节段;否则 200 全量)与四枚行为钮(failStatus/corrupt/truncateAt/
// gate),逐请求记 path+Range 头,跨源共享有序 log(FR-4 断言 URL 序)。
//
// 场景(spec NFR-1 四场景 + FR-4 回落 + Range 防御佐证):
//   ① 断点续传:官方中途截断+镜像 500 → error(network)+.part 保留 →
//      再 download() → 服务端收到 `Range: bytes=<n>-` → ready+文件 sha 对
//   ② 暂停恢复:门控首块后挂起 → pause() → paused+.part 在 → download()
//      → ready(全程状态流转移序列断言)
//   ③ 取消:downloading 中 cancel() → notDownloaded+.part 无
//   ④ 校验失败:同长度异内容 → ModelError(corrupt)+无落地+.part 留
//   ⑤ 官方源 500 → 回落镜像:URL 序 official→mirror,无感 ready
//   ⑥ Range 忽略防御:服务器对 Range 仍回 200 全量 → 客户端从零重写不
//      append 错位(T2 LLD 偏差「Range 防御」的真 HTTP 佐证)
import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/assistant/data/http_downloader.dart';
import 'package:yucai_client/assistant/data/model_manager_impl.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';

/// 64KB 固定种子随机体(简报:小体积清单在测试可复现,真 sha256 预计算)。
final Random _bodyRandom = Random(2507);
final List<int> kBody =
    List<int>.generate(64 * 1024, (_) => _bodyRandom.nextInt(256));

/// 同长度异内容(逐字节取反):校验失败场景的服务端作弊体。
final List<int> kTampered = [for (final b in kBody) b ^ 0xff];

/// 测试清单(repo/file 同生产语义,sha256/totalBytes 对应 64KB 夹具体)。
final ModelManifest kManifest = ModelManifest(
  repo: 'test/repo',
  file: 'qwen3-int-fixture.gguf',
  sha256: sha256.convert(kBody).toString(),
  totalBytes: kBody.length,
);

void main() {
  late _Harness h;

  setUp(() async {
    h = await _Harness.start();
  });

  tearDown(() => h.dispose());

  test(
      '断点续传:官方中途截断+镜像 500 → error(network)+.part 保留;'
      '再 download() 官方收到 Range: bytes=<n>- → ready+文件 sha 对', () async {
    h.official.truncateAt = 20000;
    h.mirror.failStatus = 500;

    await h.manager.download(); // 第一轮:两源皆败 → error(network)

    expect(h.manager.state.value,
        const ModelError(ModelFailureReason.network));
    expect(h.partFile.existsSync(), isTrue, reason: '断流后 .part 保留');
    expect(h.partFile.lengthSync(), 20000);
    expect(h.targetFile.existsSync(), isFalse);
    // 截断后回落的镜像请求已携带新断点基数(中断回落的 Range 新基数)。
    expect(h.mirror.records.single.rangeHeader, 'bytes=20000-');

    h.official.truncateAt = null; // 第二轮:官方源恢复健康
    await h.manager.download();

    expect(h.manager.state.value, const ModelReady());
    expect(h.official.records, hasLength(2));
    expect(h.official.records.last.rangeHeader, 'bytes=20000-',
        reason: '恢复请求以已收字节续传');
    expect(h.targetFile.readAsBytesSync(), kBody);
    expect(sha256.convert(h.targetFile.readAsBytesSync()).toString(),
        kManifest.sha256,
        reason: '最终落地文件 sha256 与钉死清单一致');
    expect(h.partFile.existsSync(), isFalse, reason: 'rename 落地,.part 消失');
    // 真路径日志(English 结构化,NFR-2/3)。
    expect(h.logs.any((l) => l.startsWith('model download source failed')),
        isTrue);
    for (final line in h.logs) {
      expect(line, matches(RegExp(r'^[\x20-\x7E]*$')),
          reason: 'non-ASCII log line: $line');
    }
  });

  test(
      '暂停恢复:门控假源首块后挂起 → pause()=paused+.part 在;'
      'download()=Range 续传 → ready(全程状态流转移序列)', () async {
    h.official.gate(4096);
    final seen = <ModelState>[h.manager.state.value];
    h.manager.state.addListener(() => seen.add(h.manager.state.value));

    final downloading = h.manager.download();
    await h.until(() =>
        h.partFile.existsSync() && h.partFile.lengthSync() == 4096);

    h.manager.pause();
    await downloading;
    await h.official.releaseGate();

    expect(
      h.manager.state.value,
      ModelPaused(receivedBytes: 4096, totalBytes: kBody.length),
    );
    expect(h.partFile.lengthSync(), 4096);
    expect(h.targetFile.existsSync(), isFalse);

    await h.manager.download(); // 恢复:自动走 Range 续传

    expect(seen.first, isA<ModelNotDownloaded>());
    final pauseIndex = seen.indexWhere((s) => s is ModelPaused);
    expect(pauseIndex, greaterThan(0));
    expect(seen.sublist(0, pauseIndex).whereType<ModelDownloading>(),
        isNotEmpty,
        reason: '暂停前有 downloading 态');
    expect(seen[pauseIndex],
        ModelPaused(receivedBytes: 4096, totalBytes: kBody.length));
    expect(seen.sublist(pauseIndex + 1).whereType<ModelDownloading>(),
        isNotEmpty,
        reason: '恢复后再入 downloading 态');
    expect(seen.last, const ModelReady());
    expect(seen.whereType<ModelError>(), isEmpty);
    expect(h.official.records.last.rangeHeader, 'bytes=4096-');
    expect(h.targetFile.readAsBytesSync(), kBody);
  });

  test('取消:downloading 中 cancel() → notDownloaded + .part 无', () async {
    h.official.gate(4096);
    final downloading = h.manager.download();
    await h.until(
        () => h.partFile.existsSync() && h.partFile.lengthSync() == 4096);

    h.manager.cancel();
    await downloading;
    await h.official.releaseGate();

    expect(h.manager.state.value, const ModelNotDownloaded());
    expect(h.partFile.existsSync(), isFalse, reason: 'cancel 删 .part');
    expect(h.targetFile.existsSync(), isFalse);
    expect(h.official.records, hasLength(1), reason: '取消不回落不恢复');
    expect(h.logs.any((l) => l.startsWith('model download host=')), isTrue);
  });

  test('校验失败:同长度异内容 → ModelError(corrupt) + 无落地 + .part 留',
      () async {
    h.official.corrupt = true;

    await h.manager.download();

    expect(h.manager.state.value,
        const ModelError(ModelFailureReason.corrupt));
    expect(h.targetFile.existsSync(), isFalse, reason: 'sha 不符不落地');
    expect(h.partFile.existsSync(), isTrue, reason: '.part 保留可整段重下');
    expect(h.partFile.lengthSync(), kBody.length, reason: '同长度');
    expect(h.partFile.readAsBytesSync(), kTampered, reason: '异内容原样落 .part');
    expect(h.mirror.records, isEmpty, reason: '校验失败非源故障,不回落');
    expect(
        h.logs.any((l) => l.startsWith('model verify failed')), isTrue);
  });

  test('官方源 500 → 回落镜像:双假源 URL 序 official→mirror,无感 ready(FR-4)',
      () async {
    h.official.failStatus = 500;

    final seen = <ModelState>[h.manager.state.value];
    h.manager.state.addListener(() => seen.add(h.manager.state.value));
    await h.manager.download();

    expect(h.manager.state.value, const ModelReady());
    expect(h.targetFile.readAsBytesSync(), kBody);
    expect(seen.whereType<ModelError>(), isEmpty, reason: '来源切换对状态无感');
    expect(h.log.entries.map((e) => e.source).toList(),
        ['official', 'mirror'],
        reason: 'URL 序:官方优先一次回落镜像(ADR-4)');
    expect(
      h.log.entries.map((e) => e.path).toSet(),
      {'/${kManifest.repo}/resolve/main/${kManifest.file}'},
      reason: '两源同构 URL 模板,仅域名差',
    );
    expect(h.log.entries.every((e) => e.rangeHeader == null), isTrue,
        reason: '首下不带 Range');
  });

  test(
      'Range 忽略防御:服务器对 Range 仍回 200 全量 → 从零重写不 append 错位'
      '(T2 LLD 偏差「Range 防御」真 HTTP 佐证)', () async {
    h.partFile
      ..createSync(recursive: true)
      ..writeAsBytesSync(kBody.sublist(0, 4096), flush: true); // 假重启残留
    expect(await h.manager.diskUsageBytes(), 4096); // 兼作 init 铲平等待
    expect(h.manager.state.value,
        ModelPaused(receivedBytes: 4096, totalBytes: kBody.length),
        reason: '构造期磁盘态恢复:残留 .part → paused(偏差三)');
    h.official.ignoreRange = true; // 对 Range 请求仍回 200 全量

    await h.manager.download();

    expect(h.official.records.single.rangeHeader, 'bytes=4096-',
        reason: '客户端确已发出 Range 续传请求');
    expect(h.manager.state.value, const ModelReady());
    expect(h.targetFile.readAsBytesSync(), kBody,
        reason: '从零重写全量,非 4096+65536 append 错位');
    expect(await h.manager.isReady(), isTrue);
  });
}

// -- 测试装具 -----------------------------------------------------------------

/// shutdown 记录 fake(ADR-5;与 T2 单测同形)。
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

/// 一次假源请求记录(path + Range 头;跨源共享 log 供 URL 序断言)。
class _RecordedRequest {
  _RecordedRequest({
    required this.source,
    required this.path,
    this.rangeHeader,
  });

  final String source;
  final String path;
  final String? rangeHeader;
}

/// 双源共享有序请求 log(official/mirror 到达序 = URL 序)。
class _RequestLog {
  final List<_RecordedRequest> entries = [];
}

/// loopback 假源:真 HttpServer,支持 Range(206+Content-Range)/200 全量,
/// 行为钮 failStatus / corrupt / truncateAt / gate,逐请求记录头序列。
class _FakeSource {
  _FakeSource({required this.source, required this.log});

  final String source;
  final _RequestLog log;
  final List<_RecordedRequest> records = [];

  /// >0:所有请求回该状态码(源故障)。
  int failStatus = 0;

  /// true:回同长度异内容体(sha 必不符,校验失败场景)。
  bool corrupt = false;

  /// 非空且小于应答段:只写前 N 字节后毁连接(中途断流;Content-Length
  /// 仍承诺全段长 → 客户端判流中断)。
  int? truncateAt;

  /// true:忽略请求 Range 头恒回 200 全量(Range 忽略防御场景)。
  bool ignoreRange = false;

  Completer<void>? _gate;
  int _gatedBytes = 0;

  HttpServer? _server;

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (Object _) {});
  }

  int get port => _server!.port;

  /// 门控下一请求:写 [bytes] 字节后挂起,直至 [releaseGate](暂停/取消的
  /// 确定性驱动:客户端必处于 downloading 且已收恰 [bytes] 字节)。
  void gate(int bytes) {
    _gate = Completer<void>();
    _gatedBytes = bytes;
  }

  Future<void> releaseGate() async {
    final gate = _gate;
    _gate = null;
    gate?.complete();
    // 给挂起连接的收尾写留时间(客户端多半已断,写失败由 handler 吞)。
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> stop() async => await _server?.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final record = _RecordedRequest(
      source: source,
      path: request.uri.path,
      rangeHeader: rangeHeader,
    );
    records.add(record);
    log.entries.add(record);
    final response = request.response;
    try {
      // bufferOutput=false:dart:io 服务端默认缓冲体数据,flush() 不下刷
      // 内部缓冲(实测 park 在 gate 时客户端收不到首块);关缓冲即逐块直送。
      response.bufferOutput = false;
      if (failStatus > 0) {
        response.statusCode = failStatus;
        await response.close();
        return;
      }
      var start = 0;
      final rangeMatch =
          rangeHeader == null ? null : RegExp(r'^bytes=(\d+)-').firstMatch(rangeHeader);
      if (!ignoreRange && rangeMatch != null) {
        start = int.parse(rangeMatch.group(1)!);
      }
      var segment = kBody.sublist(start);
      if (corrupt) {
        segment = [for (final b in segment) b ^ 0xff];
      }
      final gate = _gate;
      _gate = null;
      if (gate != null && _gatedBytes > 0 && _gatedBytes < segment.length) {
        response.statusCode = HttpStatus.ok;
        response.contentLength = segment.length;
        response.add(segment.sublist(0, _gatedBytes));
        await response.flush();
        await gate.future; // 挂起:客户端已收首块,等暂停/取消发生
        response.add(segment.sublist(_gatedBytes));
        await response.close();
        return;
      }
      if (start > 0) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-${kBody.length - 1}/${kBody.length}');
      } else {
        response.statusCode = HttpStatus.ok;
      }
      response.contentLength = segment.length;
      final cut = truncateAt;
      if (cut != null && cut < segment.length) {
        response.add(segment.sublist(0, cut));
        await response.flush();
        // 承诺全段只给前 cut 字节:卸下 socket 毁连接 → 客户端流中断。
        (await response.detachSocket()).destroy();
        return;
      }
      response.add(segment);
      await response.close();
    } catch (_) {
      // 客户端已断(pause/cancel 断流/截断对端):吞错毁连接。
      try {
        await response.close();
      } catch (_) {}
    }
  }
}

/// HttpOverrides 重定向装具:IoModelHttpClient 内部 `HttpClient()` 工厂经
/// [HttpOverrides.global] 落此 → huggingface.co/hf-mirror.com 两域重定向到
/// 两枚 loopback 假源(dart:io 栈其余部分 = 真)。
class _LoopbackOverrides extends HttpOverrides {
  _LoopbackOverrides({required this.officialPort, required this.mirrorPort});

  final int officialPort;
  final int mirrorPort;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _RewritingClient(super.createHttpClient(context),
          officialPort: officialPort, mirrorPort: mirrorPort);
}

/// 域名重定向 HttpClient 装饰器:仅改写目标 URL 的 scheme/host/port,
/// 其余(真连接/真流/真关闭)全数透传底层真 [HttpClient]。
///
/// 生产代码路径只触达 getUrl/connectionTimeout/close 三成员;未实现成员
/// 经 noSuchMethod 显式失败(防静默漏转)。
class _RewritingClient implements HttpClient {
  _RewritingClient(this._real,
      {required this.officialPort, required this.mirrorPort});

  final HttpClient _real;
  final int officialPort;
  final int mirrorPort;

  Uri _rewrite(Uri url) {
    var port = 0;
    if (url.host == 'huggingface.co') {
      port = officialPort;
    } else if (url.host == 'hf-mirror.com') {
      port = mirrorPort;
    } else {
      return url; // 非模型源域(防御):原样透传
    }
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: port,
      path: url.path,
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _real.getUrl(_rewrite(url));

  @override
  set connectionTimeout(Duration? value) => _real.connectionTimeout = value;

  @override
  void close({bool force = false}) => _real.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('unexpected HttpClient member: '
          '${invocation.memberName}');
}

/// 组装好的被测系统:双假源 + HttpOverrides + 真件 manager(真
/// IoModelHttpClient;manifest/supportDir/throttle/log 四缝注入)。
class _Harness {
  _Harness._({
    required this.temp,
    required this.official,
    required this.mirror,
    required this.log,
    required this.manager,
    required this.logs,
  });

  static Future<_Harness> start() async {
    final temp = await Directory.systemTemp.createTemp('f67_model_dl_it');
    final log = _RequestLog();
    final official = _FakeSource(source: 'official', log: log);
    final mirror = _FakeSource(source: 'mirror', log: log);
    await official.start();
    await mirror.start();
    // HttpOverrides.global 只设不读(setter-only):本仓测试套无其他使用
    // 方,dispose 复位 null 即还原(见类注释)。
    HttpOverrides.global = _LoopbackOverrides(
      officialPort: official.port,
      mirrorPort: mirror.port,
    );
    final logs = <String>[];
    final manager = ModelManagerImpl(
      IoModelHttpClient(), // 真生产件(T2 mock 单测的互补面)
      _FakeEngineManager(),
      supportDirFn: () async => temp,
      manifest: kManifest,
      throttleMs: 0, // 每块进度发射(状态序确定性)
      log: logs.add,
    );
    return _Harness._(
      temp: temp,
      official: official,
      mirror: mirror,
      log: log,
      manager: manager,
      logs: logs,
    );
  }

  final Directory temp;
  final _FakeSource official;
  final _FakeSource mirror;
  final _RequestLog log;
  final ModelManagerImpl manager;
  final List<String> logs;

  File get targetFile => File(
        [temp.path, 'yucai', 'models', kManifest.file]
            .join(Platform.pathSeparator),
      );

  File get partFile => File('${targetFile.path}.part');

  /// 轮询等待条件成立(真文件 IO flush 完成时机不定,零 delay 泵不够)。
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 500 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(condition(), isTrue, reason: 'condition not met before timeout');
  }

  Future<void> dispose() async {
    HttpOverrides.global = null;
    await official.stop();
    await mirror.stop();
    await temp.delete(recursive: true);
  }
}
