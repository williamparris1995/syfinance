/// F67 端侧模型管理 —— ModelManagerImpl 双面实现(ADR-2/ADR-3/ADR-4/ADR-5/ADR-6)。
///
/// `@LazySingleton(as: ModelStore)` 双面:同时实现 F66 [ModelStore](port
/// 形状不变,引擎侧 ensureReady 的 modelMissing 前置语义无缝衔接)与
/// [ModelManagerPort](download/pause/cancel/delete/state/diskUsage/manifest,
/// F65 消费)。注:生成 DI 图在本仓不可 regen(build_runner 不可用),实际
/// 生产绑定在 core/di injection.dart 1m 段手工注册(照 EngineManagerImpl
/// 先例,注解仅作文档)。
///
/// 下载编排(design LLD + T2 简报定案):
/// - 状态守卫:ready/downloading → no-op;paused/error(network) → .part
///   续传;error(corrupt) → 删 .part 从零(ADR-3 重试语义);
/// - .part 协议:目标旁 `<file>.part`,恢复 stat 已收字节 n →
///   `Range: bytes=<n>-` 续传;服务器忽略 Range(仍 200)→ 从零重写
///   (append 会错位,防 corrupt 死循环);
/// - 源回落:官方 huggingface.co → hf-mirror 各一次(ADR-4,连接错/
///   >399/流中断 → 下一源;两源皆败 → error(network);源间挂起窗口的
///   用户干预不回落且落 pause/cancel 终态,防状态卡 Downloading 死锁);
/// - 校验:**下载完成后对完整 .part 单遍流式 sha256**(crypto;下载中不
///   增量算摘要 —— 续传段无前缀可续,单遍重算实现简单且正确,T2 简报
///   定案修正);比对 [ModelManifest.sha256] → 不符 error(corrupt) 且
///   .part 保留;通过 → rename 前复查 cancel(校验窗口干预不吞,L-1)
///   → rename 原子落地;
/// - 进度:ModelDownloading 节流发射(默认 200ms,0 = 每块;速度 = 相邻
///   发射间隔的 lastBytes/dt 简版滑动窗,ADR-6);
/// - 删除:在途先 cancel → await [EngineManager.shutdown](幂等,ADR-5)
///   → 删 .gguf 与 .part → notDownloaded(ready→notDownloaded 也发
///   state,F65 卡消费)。
///
/// 构造即从磁盘恢复状态(重启续传/已就绪:目标在 → ready;.part 在 →
/// paused 带断点基数;否则 notDownloaded),首个异步口(await 铲平)。
/// 日志全 English 结构化(NFR-3):`model download host=<h> bytes=<n>/<t>` /
/// `model ready` / `model verify failed` / `model delete` /
/// `model download source failed host=<h>` / `model download error reason=network`。
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/engine_port.dart';
import '../domain/model_manager_port.dart';
import '../domain/model_state.dart';
import '../domain/model_store_port.dart';
import 'audit_log.dart';
import 'http_downloader.dart';

/// 模型管理生产实现(DI 手工绑定见 injection.dart 1m 段,双口同实例)。
@LazySingleton(as: ModelStore)
class ModelManagerImpl implements ModelStore, ModelManagerPort {
  /// 命名缝参数可空 + `?? 生产缺省`(照 ModelStoreImpl/EngineManagerImpl
  /// 家法;null = 走缺省)。[manifest] 缺省 [kModelManifest] 直通(单测
  /// 注入小字节同形清单 —— 生产清单 sha 对应 2.5GB 真件不可在单测复现)。
  /// 不注入 AssistantConfig 取值缝:下载与 enabled 无关(T2 简报定案)。
  ModelManagerImpl(
    this._http,
    this._engine, {
    Future<Directory> Function()? supportDirFn,
    this.throttleMs = defaultThrottleMs,
    ModelManifest? manifest,
    AssistantLogFn? log,
  })  : _supportDir = supportDirFn ?? getApplicationSupportDirectory,
        _manifest = manifest ?? kModelManifest,
        _log = log ?? _defaultModelLog {
    _initFuture = _loadInitialState();
  }

  /// 进度节流窗口(ADR-6:200ms;0 = 每块更新,单测用)。
  static const int defaultThrottleMs = 200;

  /// 模型落位子路径(F66 ADR-7 固定 `yucai/models/` 不变;文件名单一
  /// 事实源 = [ModelManifest.file])。
  static const List<String> _segments = ['yucai', 'models'];

  final ModelHttpClient _http;

  /// deferred 打断 DI 构造环 2026-10-24:1m 段 ModelStore 工厂(→ 本构造)
  /// 若急取 EngineManager,对向工厂又急取 ModelStore,get_it 7.7.0 lazy
  /// 无重入保护 → 首消费者解析即 SOF(L-3 探针实证)。环断在本侧,
  /// EngineManagerImpl 持 ModelStore 直接引用不动;唯一消费点 delete()
  /// 的 shutdown(幂等)延迟到调用点取值,无时序影响。
  final EngineManager Function() _engine;
  final Future<Directory> Function() _supportDir;
  final AssistantLogFn _log;

  /// 清单(生产 = kModelManifest;单测注入缝)。
  final ModelManifest _manifest;

  /// 进度节流毫秒(可注入 0 = 关)。
  final int throttleMs;

  final ValueNotifier<ModelState> _stateNotifier =
      ValueNotifier<ModelState>(const ModelNotDownloaded());

  /// 磁盘状态恢复 Future(首个异步口 await 铲平竞态)。
  late final Future<void> _initFuture;

  /// 在途下载循环 Future(并发 download join / delete 等待清理)。
  Future<void>? _active;

  /// 当前响应体订阅(pause/cancel 断流柄;null = 无在途)。
  StreamSubscription<List<int>>? _sub;

  /// 当前流完成信号(pause/cancel 的 cancel() 不触发 onDone,由 abort
  /// 侧完成 —— 循环统一走 epilogue 单出口清理)。
  Completer<void>? _streamDone;

  bool _pauseRequested = false;
  bool _cancelRequested = false;

  // 进度节流/速度窗(相邻发射差分,简版滑动窗)。
  DateTime _lastEmitTime = DateTime.now();
  int _lastEmitBytes = 0;

  @override
  ValueListenable<ModelState> get state => _stateNotifier;

  @override
  ModelManifest get manifest => _manifest;

  // -- ModelManagerPort 面 ----------------------------------------------------

  @override
  Future<void> download() async {
    await _initFuture;
    final current = _stateNotifier.value;
    if (current is ModelReady || current is ModelDownloading) return;
    final inFlight = _active;
    if (inFlight != null) {
      await inFlight; // 并发调用 join 既有下载
      return;
    }
    final task = _runDownload();
    _active = task;
    try {
      await task;
    } finally {
      _active = null;
    }
  }

  @override
  void pause() {
    if (_stateNotifier.value is! ModelDownloading) return;
    _pauseRequested = true;
    _abortStream();
  }

  @override
  void cancel() {
    if (_stateNotifier.value is! ModelDownloading) return;
    _cancelRequested = true;
    _abortStream();
  }

  @override
  Future<void> delete() async {
    await _initFuture;
    if (_stateNotifier.value is ModelDownloading) {
      // ADR-5:在途下载先 cancel(断流 + 删 .part),等循环单出口清完。
      _cancelRequested = true;
      _abortStream();
      final task = _active;
      if (task != null) await task;
    }
    await _engine().shutdown(); // 幂等;运行中不裸删(FR-3)
    final target = await _targetFile();
    final part = await _partFile();
    if (await target.exists()) await target.delete();
    if (await part.exists()) await part.delete();
    _log('model delete');
    _setState(const ModelNotDownloaded());
  }

  @override
  Future<int> diskUsageBytes() async {
    await _initFuture;
    // port 契约「.gguf + .part 之和」按文件实查求和,与状态无关(M-2 修正:
    // 曾按状态分支,error(corrupt) 残留 .part 回 0 → corrupt 后占用少报)。
    // 正常路径 rename 落地后 .part 消失,和 = 目标长;任何残留组合如实上报。
    var usage = 0;
    final target = await _targetFile();
    if (await target.exists()) usage += await target.length();
    final part = await _partFile();
    if (await part.exists()) usage += await part.length();
    return usage;
  }

  // -- ModelStore 面(F66 port 形状不变) ---------------------------------------

  @override
  Future<String?> modelPath() async {
    await _initFuture;
    if (_stateNotifier.value is! ModelReady) return null;
    final target = await _targetFile();
    return await target.exists() ? target.path : null;
  }

  @override
  Future<bool> isReady() async => await modelPath() != null;

  // -- 下载编排 ---------------------------------------------------------------

  /// 完整下载循环:状态守卫 → .part 基数 → 源回落链 → 单源流泵。
  Future<void> _runDownload() async {
    _pauseRequested = false;
    _cancelRequested = false;
    final part = await _partFile();
    // corrupt 重试 = 删 .part 从零整段重下(ADR-3);network 重试 = 续传。
    final current = _stateNotifier.value;
    if (current is ModelError &&
        current.reason == ModelFailureReason.corrupt &&
        await part.exists()) {
      await part.delete();
    }
    var received = 0;
    if (await part.exists()) received = await part.length();
    for (final url in _sourceUrls()) {
      try {
        final response =
            await _http.get(url, rangeFrom: received > 0 ? received : null);
        await _pump(response, url, part, received);
        return; // 成功/pause/cancel 终态已在 _pump 内落定
      } catch (_) {
        // 连接错 / >399 / 流中断 → 下一源(续传基数 = .part 已增量)。
        _log('model download source failed host=${url.host}');
        if (_cancelRequested || _pauseRequested) {
          // 用户干预不回落,且须落终态:源间挂起窗口的干预断流柄已空,
          // 只 return 会卡 Downloading 且 _active 已清,download() 守卫
          // 短路死锁(M-3)。pause → Paused(断点基数 = .part 实长);
          // cancel → 删 .part + notDownloaded(与流中路径同语义)。
          if (_cancelRequested) {
            if (await part.exists()) await part.delete();
            _setState(const ModelNotDownloaded());
          } else {
            final received = await part.exists() ? await part.length() : 0;
            _setState(ModelPaused(
                receivedBytes: received, totalBytes: _manifest.totalBytes));
          }
          return;
        }
        if (await part.exists()) {
          received = await part.length(); // 中断回落的 Range 新基数
        } else {
          received = 0;
        }
      }
    }
    _log('model download error reason=network');
    _setState(const ModelError(ModelFailureReason.network));
  }

  /// 单源流泵:append 写 .part + 进度节流 → EOF 单遍 sha256 → 原子落地。
  ///
  /// 抛错 = 中途网络断(调用方回落下一源);pause/cancel/EOF 各自落态后
  /// 正常返回。
  Future<void> _pump(
    ModelHttpResponse response,
    Uri url,
    File part,
    int startBytes,
  ) async {
    var base = startBytes;
    var mode = FileMode.append;
    if (startBytes > 0 && response.statusCode == 200) {
      // 服务器忽略 Range 仍回全量:append 会错位 → 从零重写。
      base = 0;
      mode = FileMode.write;
    }
    final dir = part.parent;
    if (!await dir.exists()) await dir.create(recursive: true);
    final total = response.totalLength ?? _manifest.totalBytes;
    final receivedNow = base;
    _lastEmitBytes = receivedNow;
    _lastEmitTime = DateTime.now();
    _emitProgress(receivedNow, total, force: true);
    _log('model download host=${url.host} bytes=$receivedNow/$total');

    final sink = part.openWrite(mode: mode);
    var received = receivedNow;
    Object? streamError;
    final done = Completer<void>();
    _streamDone = done;
    try {
      _sub = response.body.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          _emitProgress(received, total);
        },
        onError: (Object e) {
          streamError = e;
          _completeStreamDone();
        },
        onDone: _completeStreamDone,
        cancelOnError: true,
      );
      await done.future;
    } finally {
      _sub = null;
      _streamDone = null;
      await sink.flush();
      await sink.close();
    }

    if (_cancelRequested) {
      // cancel 语义:断流 + 删 .part → notDownloaded(LLD)。
      if (await part.exists()) await part.delete();
      _setState(const ModelNotDownloaded());
      return;
    }
    if (_pauseRequested) {
      _setState(ModelPaused(receivedBytes: received, totalBytes: total));
      return;
    }
    if (streamError != null) {
      throw streamError!; // 中途断流 → 调用方回落下一源
    }

    // EOF:完整 .part 单遍流式 sha256(下载中不算,简报定案)。
    final actual = await _sha256OfFile(part);
    if (actual != _manifest.sha256) {
      _log('model verify failed');
      _setState(const ModelError(ModelFailureReason.corrupt));
      return; // .part 保留(ADR-3:可整段重下,排查依据)
    }
    if (_cancelRequested) {
      // sha 校验窗口到达的 cancel(流已尽,断流柄空仅剩旗标):同 cancel
      // 语义删 .part 落 notDownloaded,不得越过 rename 落 ready(L-1)。
      if (await part.exists()) await part.delete();
      _setState(const ModelNotDownloaded());
      return;
    }
    final target = await _targetFile();
    if (await target.exists()) await target.delete(); // rename 原子前置
    await part.rename(target.path);
    _log('model ready');
    _setState(const ModelReady());
  }

  /// 源回落链(ADR-4:官方优先,一次回落 hf-mirror;同构 URL 模板)。
  List<Uri> _sourceUrls() => [
        Uri.parse(
            'https://huggingface.co/${_manifest.repo}/resolve/main/${_manifest.file}'),
        Uri.parse(
            'https://hf-mirror.com/${_manifest.repo}/resolve/main/${_manifest.file}'),
      ];

  /// 进度节流发射(ADR-6):非 force 且距上次发射 < [throttleMs] 则吞;
  /// 速度 = 相邻发射的 received 差 / 实耗秒(简版滑动窗,首发 0)。
  void _emitProgress(int received, int total, {bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        throttleMs > 0 &&
        now.difference(_lastEmitTime) < Duration(milliseconds: throttleMs)) {
      return;
    }
    final elapsedUs = now.difference(_lastEmitTime).inMicroseconds;
    final delta = received - _lastEmitBytes;
    final bytesPerSec = (force || elapsedUs <= 0 || delta <= 0)
        ? 0
        : delta * Duration.microsecondsPerSecond ~/ elapsedUs;
    _lastEmitTime = now;
    _lastEmitBytes = received;
    _setState(ModelDownloading(
      receivedBytes: received,
      totalBytes: total,
      bytesPerSec: bytesPerSec,
    ));
  }

  /// pause/cancel 断流:取消订阅 + 完成循环信号(cancel() 不触发 onDone,
  /// 由本方法补 —— 循环 epilogue 单出口清理写句柄/文件/状态)。
  void _abortStream() {
    final sub = _sub;
    _sub = null;
    if (sub != null) {
      unawaited(sub.cancel().catchError((_) {}));
    }
    _completeStreamDone();
  }

  void _completeStreamDone() {
    final done = _streamDone;
    _streamDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// 构造期磁盘状态恢复(FR-1 断点续传的重启面):目标在 → ready;
  /// .part 在 → paused(断点基数);否则保持 notDownloaded。
  Future<void> _loadInitialState() async {
    try {
      final target = await _targetFile();
      if (await target.exists()) {
        _setState(const ModelReady());
        return;
      }
      final part = await _partFile();
      if (await part.exists()) {
        _setState(ModelPaused(
          receivedBytes: await part.length(),
          totalBytes: _manifest.totalBytes,
        ));
      }
    } catch (_) {
      // 路径解析失败(极端环境):保持 notDownloaded,fail-safe。
    }
  }

  Future<File> _targetFile() async {
    final root = await _supportDir();
    return File(
      [root.path, ..._segments, _manifest.file].join(Platform.pathSeparator),
    );
  }

  Future<File> _partFile() async =>
      File('${(await _targetFile()).path}.part');

  /// 完整文件单遍流式 sha256(crypto 增量 sink;2.5GB 不入内存)。
  Future<String> _sha256OfFile(File file) async {
    final sink = _DigestSink();
    final hasher = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      hasher.add(chunk);
    }
    hasher.close();
    return sink.value.toString();
  }

  void _setState(ModelState next) => _stateNotifier.value = next;
}

/// sha256 块式转换的摘要收集 Sink(crypto 不公开 DigestSink,自写三行)。
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}

void _defaultModelLog(String line) => debugPrint(line);
