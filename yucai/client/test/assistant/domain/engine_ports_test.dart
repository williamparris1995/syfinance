import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_store_port.dart';

/// F66 T1:EngineManager / ModelStore port 契约 —— fake 实现可满足接口面;
/// [EngineManager.state] 为 [ValueListenable](LlmSettings 家法响应式形态:
/// 当前态缓存,订阅即得当前值,转移不漏 = ADR-5 多播语义)。
void main() {
  group('EngineManager', () {
    test('state carries current value; transitions reach late subscribers',
        () async {
      final manager = _FakeEngineManager();

      // 当前态缓存:未启动即为 Stopped,订阅即得。
      expect(manager.state.value, const EngineStopped());

      final seen = <EngineState>[];
      manager.state.addListener(() => seen.add(manager.state.value));

      await manager.ensureReady();

      // 转移可见且不漏:starting → ready(FR-1 懒启动全转移)。
      expect(
        seen,
        [
          const EngineStarting(),
          EngineReady(Uri.parse('http://127.0.0.1:8123/v1')),
        ],
      );
      // 迟订阅者立即读到当前值(Ready),非空流不丢首帧。
      expect(
        manager.state.value,
        EngineReady(Uri.parse('http://127.0.0.1:8123/v1')),
      );

      await manager.shutdown();
      expect(manager.state.value, const EngineStopped());
    });

    test('equal state re-set does not notify (value semantics dedupe)', () {
      final manager = _FakeEngineManager();
      var fired = 0;
      manager.state.addListener(() => fired++);

      // 同形 Stopped 再置(值相等)→ ValueListenable 家法去重,零通知。
      manager.resetToStopped();
      expect(fired, 0);
    });
  });

  group('ModelStore', () {
    test('modelPath/isReady contract roundtrips (null = missing)', () async {
      final present = _FakeModelStore(
        r'C:\Users\me\AppData\Roaming\yucai\models\qwen3-4b-instruct-q4_k_m.gguf',
      );
      expect(await present.modelPath(), contains('.gguf'));
      expect(await present.isReady(), isTrue);

      final missing = _FakeModelStore(null);
      expect(await missing.modelPath(), isNull);
      expect(await missing.isReady(), isFalse);
    });
  });
}

/// 契约 fake:ValueNotifier 直转 ValueListenable,转移照 ensureReady 语义
/// (starting→ready);T2 EngineManagerImpl 将以真进程编排实现同一 port。
class _FakeEngineManager implements EngineManager {
  final ValueNotifier<EngineState> _state =
      ValueNotifier(const EngineStopped());

  @override
  ValueListenable<EngineState> get state => _state;

  @override
  Future<void> ensureReady() async {
    _state.value = const EngineStarting();
    _state.value = EngineReady(Uri.parse('http://127.0.0.1:8123/v1'));
  }

  @override
  Future<void> shutdown() async {
    _state.value = const EngineStopped();
  }

  /// 测试缝:重置为同形 Stopped(验证值相等去重)。
  void resetToStopped() => _state.value = const EngineStopped();
}

/// 契约 fake:path 非空即就绪;null = 模型缺失(FR-2 modelMissing 源)。
class _FakeModelStore implements ModelStore {
  _FakeModelStore(this._path);

  final String? _path;

  @override
  Future<String?> modelPath() async => _path;

  @override
  Future<bool> isReady() async => _path != null;
}
