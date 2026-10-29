import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// F66 T1(FR-2):AssistantSettings keys 收窄为 assistant.enabled/model
/// 两键 —— 往返/幂等/通知;F64 遗留键(provider/base_url/api_key)残留
/// 无害:读取端只读两键,不抛错不迁移(FR-2 旧键残留容忍场景)。
void main() {
  late _MockSecureStorage backend;
  late AssistantSettings settings;

  setUp(() {
    backend = _MockSecureStorage();
    settings = AssistantSettings(storage: backend);
    registerFallbackValue('');
  });

  /// [read] 桩:按 [table] 返回存储值(未列出 key → null)。
  void stubRead(Map<String, String> table) {
    when(() => backend.read(key: any(named: 'key'))).thenAnswer(
      (inv) async => table[inv.namedArguments[#key] as String],
    );
  }

  group('defaults', () {
    test('value defaults to disabled + default model before load', () {
      expect(settings.value.enabled, isFalse);
      expect(settings.value.model, AssistantConfig.defaultModel);
      expect(settings.ready, isFalse);
    });

    test('empty storage loads to disabled config (model falls back to '
        'default id)', () async {
      stubRead(const {});

      await settings.load();

      expect(settings.value.enabled, isFalse);
      expect(settings.value.model, AssistantConfig.defaultModel);
      expect(settings.ready, isFalse);
    });
  });

  group('setConfig', () {
    test('persists exactly the two narrowed keys, never legacy ones',
        () async {
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await settings.setConfig(const AssistantConfig(enabled: true));

      verify(() => backend.write(key: 'assistant.enabled', value: 'true'))
          .called(1);
      verify(() => backend.write(
              key: 'assistant.model', value: AssistantConfig.defaultModel))
          .called(1);
      // 退役键不再落盘(F64 形态未发版零迁移;旧值任其残留)。
      verifyNever(
          () => backend.write(key: 'assistant.provider', value: any(named: 'value')));
      verifyNever(
          () => backend.write(key: 'assistant.base_url', value: any(named: 'value')));
      verifyNever(
          () => backend.write(key: 'assistant.api_key', value: any(named: 'value')));
    });

    test('notifies listeners with the new config', () async {
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      final fired = <AssistantConfig>[];
      settings.listenable.addListener(() => fired.add(settings.value));

      const next = AssistantConfig(enabled: true, model: 'alt-model-id');
      await settings.setConfig(next);

      expect(settings.value, same(next));
      expect(fired, [next]);
    });

    test('roundtrips through storage into a fresh instance', () async {
      final written = <String, String>{};
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        written[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String;
      });

      await settings.setConfig(
          const AssistantConfig(enabled: true, model: 'alt-model-id'));

      final fresh = AssistantSettings(storage: backend);
      when(() => backend.read(key: any(named: 'key'))).thenAnswer(
        (inv) async => written[inv.namedArguments[#key] as String],
      );
      await fresh.load();

      expect(fresh.value.enabled, isTrue);
      expect(fresh.value.model, 'alt-model-id');
      expect(fresh.value.ready, isTrue);
    });

    test('serializes writes — model key untouched until enabled write '
        'completes (Windows full-file read-modify-write parallel-write '
        'regression, 2026-10-29)', () async {
      final enabledGate = Completer<void>();
      var modelWrites = 0;
      when(() => backend.write(key: 'assistant.enabled', value: 'true'))
          .thenAnswer((_) => enabledGate.future);
      when(() => backend.write(
              key: 'assistant.model', value: any(named: 'value')))
          .thenAnswer((_) async {
        modelWrites++;
      });

      final pending = settings.setConfig(const AssistantConfig(enabled: true));
      // 让事件循环转一圈:旧 Future.wait 形态下 model 键会立即被调。
      await Future<void>.delayed(Duration.zero);
      expect(modelWrites, 0, reason: 'enabled 键写完成前不得碰 model 键');

      enabledGate.complete();
      await pending;

      // 门闩放行后两键都落盘(enabled 不再随批丢失)。
      expect(modelWrites, 1);
      verify(() => backend.write(key: 'assistant.enabled', value: 'true'))
          .called(1);
    });
  });

  group('load', () {
    test('legacy F64 keys are ignored; known keys still load (FR-2)', () async {
      stubRead({
        'assistant.enabled': 'true',
        'assistant.model': 'qwen3-4b-instruct-q4_k_m',
        // F64 期遗留键:读取端天然忽略,不抛错不迁移。
        'assistant.provider': 'openai',
        'assistant.base_url': 'https://llm.internal/v1',
        'assistant.api_key': 'sk-prod',
      });

      await settings.load();

      expect(settings.value.enabled, isTrue);
      expect(settings.value.model, 'qwen3-4b-instruct-q4_k_m');
      expect(settings.value.ready, isTrue);
    });

    test('invalid stored enabled falls back to false', () async {
      stubRead({
        'assistant.enabled': 'yes', // 非法布尔
        'assistant.model': 'qwen3-4b-instruct-q4_k_m',
      });

      await settings.load();

      expect(settings.value.enabled, isFalse);
      expect(settings.value.ready, isFalse);
    });

    test('second load does not re-read storage', () async {
      var reads = 0;
      when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async {
        reads++;
        return null;
      });

      await settings.load();
      await settings.load();

      expect(reads, 2); // 收窄后 2 个 assistant.* key,各读一次
    });
  });
}
