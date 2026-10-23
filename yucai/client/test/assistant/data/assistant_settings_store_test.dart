import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/core/llm/llm_settings.dart'
    show LlmConfig, LlmProvider;

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// F64 T2:AssistantSettings secure storage(LlmSettings 家法逐条镜像,ADR-4)。
///
/// 覆盖:缺省关闭态、assistant.* key 全量落盘、新实例往返、非法存储回落、
/// load 幂等(mock 计数)、ready 放宽 localhost 免云端 Key —— 与 F46 语义的
/// 关键差异断言。
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
    test('value defaults to disabled minimal config before load', () {
      expect(settings.value.enabled, isFalse);
      expect(settings.value.provider, LlmProvider.zhipu);
      expect(settings.value.baseUrl, '');
      expect(settings.value.apiKey, '');
      expect(settings.value.model, '');
      expect(settings.ready, isFalse);
    });

    test('empty storage loads to disabled config (ready stays false)',
        () async {
      stubRead(const {});

      await settings.load();

      expect(settings.value.enabled, isFalse);
      expect(settings.ready, isFalse);
    });
  });

  group('setConfig', () {
    test('persists every field under its assistant.* key', () async {
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await settings.setConfig(const AssistantConfig(
        enabled: true,
        provider: LlmProvider.openai,
        baseUrl: 'https://llm.internal/v1',
        apiKey: 'sk-prod',
        model: 'gpt-4o-mini',
      ));

      verify(() => backend.write(key: 'assistant.enabled', value: 'true'))
          .called(1);
      verify(() => backend.write(key: 'assistant.provider', value: 'openai'))
          .called(1);
      verify(() =>
              backend.write(key: 'assistant.base_url', value: 'https://llm.internal/v1'))
          .called(1);
      verify(() => backend.write(key: 'assistant.api_key', value: 'sk-prod'))
          .called(1);
      verify(() => backend.write(key: 'assistant.model', value: 'gpt-4o-mini'))
          .called(1);
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

      const next = AssistantConfig(
        enabled: true,
        provider: LlmProvider.zhipu,
        apiKey: 'sk-x',
        model: 'glm-4-plus',
      );
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

      await settings.setConfig(const AssistantConfig(
        enabled: true,
        provider: LlmProvider.deepseek,
        baseUrl: 'https://llm.internal/v1',
        apiKey: 'sk-prod',
        model: 'deepseek-chat',
      ));

      final fresh = AssistantSettings(storage: backend);
      when(() => backend.read(key: any(named: 'key'))).thenAnswer(
        (inv) async => written[inv.namedArguments[#key] as String],
      );
      await fresh.load();

      expect(fresh.value.enabled, isTrue);
      expect(fresh.value.provider, LlmProvider.deepseek);
      expect(fresh.value.baseUrl, 'https://llm.internal/v1');
      expect(fresh.value.apiKey, 'sk-prod');
      expect(fresh.value.model, 'deepseek-chat');
      expect(fresh.value.ready, isTrue);
    });
  });

  group('load fallbacks', () {
    test('invalid stored provider falls back to zhipu', () async {
      stubRead({
        'assistant.enabled': 'true',
        'assistant.provider': 'gptx', // 未知商
      });

      await settings.load();

      expect(settings.value.provider, LlmProvider.zhipu);
      // 回落只影响非法字段本身,其余合法存储值不受牵连。
      expect(settings.value.enabled, isTrue);
    });
  });

  group('load idempotency', () {
    test('second load does not re-read storage', () async {
      var reads = 0;
      when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async {
        reads++;
        return null;
      });

      await settings.load();
      await settings.load();

      expect(reads, 5); // 5 个 assistant.* key,各读一次
    });
  });

  group('ready (ADR-4 relaxed rule)', () {
    test('localhost endpoint is ready without an api key (differs from F46)',
        () async {
      stubRead({
        'assistant.enabled': 'true',
        'assistant.provider': 'custom',
        'assistant.base_url': 'http://localhost:11434/v1',
        'assistant.api_key': '',
        'assistant.model': 'qwen3:latest',
      });

      await settings.load();

      expect(settings.value.ready, isTrue);
      expect(settings.ready, isTrue);
      // 对照:F46 同形状配置(强制 apiKey 非空)→ false。
      expect(
        const LlmConfig(
          enabled: true,
          provider: LlmProvider.custom,
          baseUrl: 'http://localhost:11434/v1',
          model: 'qwen3:latest',
        ).ready,
        isFalse,
      );
    });
  });
}
