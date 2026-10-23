import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';

/// F67 T1:ModelManagerPort 契约 + ModelManifest 钉死清单(ADR-2/ADR-4)。
/// —— fake 实现可满足接口面;[ModelManagerPort.state] 为 [ValueListenable]
/// (EngineState 家法:当前态缓存,订阅即得当前值,转移不漏);
/// [kModelManifest] 四钉死(仓库/文件/sha256/字节数)= 下载源单点常量。
void main() {
  group('ModelManagerPort', () {
    test('state carries current value; transitions reach subscribers',
        () async {
      final manager = _FakeModelManager();

      // 当前态缓存:未下载即为 NotDownloaded,订阅即得。
      expect(manager.state.value, const ModelNotDownloaded());

      final seen = <ModelState>[];
      manager.state.addListener(() => seen.add(manager.state.value));

      await manager.download();
      manager.pause();

      // 转移可见且不漏:downloading(进度)→ paused(断流保 .part)。
      expect(
        seen,
        [
          const ModelDownloading(
            receivedBytes: 1024,
            totalBytes: 4096,
            bytesPerSec: 512,
          ),
          const ModelPaused(receivedBytes: 1024, totalBytes: 4096),
        ],
      );
      // 迟订阅者立即读到当前值(Paused)。
      expect(
        manager.state.value,
        const ModelPaused(receivedBytes: 1024, totalBytes: 4096),
      );

      await manager.delete();
      expect(manager.state.value, const ModelNotDownloaded());
    });

    test('equal state re-set does not notify (value semantics dedupe)', () {
      final manager = _FakeModelManager();
      var fired = 0;
      manager.state.addListener(() => fired++);

      // 同形 NotDownloaded 再置(值相等)→ ValueListenable 家法去重。
      manager.resetToNotDownloaded();
      expect(fired, 0);
    });

    test('diskUsageBytes/manifest contract roundtrips', () async {
      final manager = _FakeModelManager();
      expect(await manager.diskUsageBytes(), greaterThanOrEqualTo(0));
      expect(manager.manifest, same(kModelManifest));
    });
  });

  group('kModelManifest (pinned constants, ADR-4)', () {
    test('pins repo/file/sha256/totalBytes to the verified upstream', () {
      expect(kModelManifest.repo, 'unsloth/Qwen3-4B-Instruct-2507-GGUF');
      expect(kModelManifest.file, 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf');
      expect(
        kModelManifest.sha256,
        '3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597',
      );
      expect(kModelManifest.totalBytes, 2497281120);
    });

    test('sha256 is 64-char lowercase hex (streaming verify input shape)',
        () {
      expect(kModelManifest.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('totalBytes is positive (~2.5 GB Q4_K_M quant)', () {
      expect(kModelManifest.totalBytes, greaterThan(2 * 1024 * 1024 * 1024));
      expect(kModelManifest.totalBytes, lessThan(3 * 1024 * 1024 * 1024));
    });
  });
}

/// 契约 fake:ValueNotifier 直转 ValueListenable,转移照 download/pause
/// 语义(downloading 携进度 → paused);T2 ModelManagerImpl 将以下载编排
/// (Range 续传/sha256 校验/源回落)实现同一 port。
class _FakeModelManager implements ModelManagerPort {
  final ValueNotifier<ModelState> _state =
      ValueNotifier(const ModelNotDownloaded());

  @override
  ValueListenable<ModelState> get state => _state;

  @override
  Future<void> download() async {
    _state.value = const ModelDownloading(
      receivedBytes: 1024,
      totalBytes: 4096,
      bytesPerSec: 512,
    );
  }

  @override
  void pause() {
    _state.value = const ModelPaused(receivedBytes: 1024, totalBytes: 4096);
  }

  @override
  void cancel() {
    _state.value = const ModelNotDownloaded();
  }

  @override
  Future<void> delete() async {
    _state.value = const ModelNotDownloaded();
  }

  @override
  Future<int> diskUsageBytes() async => 0;

  @override
  ModelManifest get manifest => kModelManifest;

  /// 测试缝:重置为同形 NotDownloaded(验证值相等去重)。
  void resetToNotDownloaded() => _state.value = const ModelNotDownloaded();
}
