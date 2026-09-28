import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/core/llm/llm_settings.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// F46 T1:LlmSettings(ThemeSettings 家法镜像,ADR-2)。
///
/// 覆盖:缺省/非法回落、load 幂等、ready 派生、provider→预设端点映射、
/// llm.* key 持久化与 listenable 通知。
void main() {
  late _MockSecureStorage backend;
  late LlmSettings settings;

  setUp(() {
    backend = _MockSecureStorage();
    settings = LlmSettings(storage: backend);
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
      expect(settings.value.cityTier, LlmCityTier.tier1);
      expect(settings.value.includeNames, isFalse);
      expect(settings.value.disclaimerAck, isFalse);
      expect(settings.ready, isFalse);
    });
  });

  group('load', () {
    test('load falls back to defaults on missing/invalid stored values', () async {
      stubRead({
        'llm.provider': 'gptx', // 未知商
        'llm.tier': 'tier9', // 未知档位
        'llm.enabled': 'maybe', // 非法布尔
        'llm.include_names': 'yes', // 非法布尔
      });

      await settings.load();

      expect(settings.value.provider, LlmProvider.zhipu);
      expect(settings.value.cityTier, LlmCityTier.tier1);
      expect(settings.value.enabled, isFalse);
      expect(settings.value.includeNames, isFalse);
      expect(settings.value.disclaimerAck, isFalse);
      expect(settings.value.apiKey, '');
    });

    test('load syncs the persisted config into value', () async {
      stubRead({
        'llm.enabled': 'true',
        'llm.provider': 'deepseek',
        'llm.base_url': 'https://llm.internal/v1',
        'llm.api_key': 'sk-test',
        'llm.model': 'deepseek-chat',
        'llm.tier': 'tier2',
        'llm.include_names': 'true',
        'llm.disclaimer_ack': 'true',
      });

      await settings.load();

      expect(settings.value.enabled, isTrue);
      expect(settings.value.provider, LlmProvider.deepseek);
      expect(settings.value.baseUrl, 'https://llm.internal/v1');
      expect(settings.value.apiKey, 'sk-test');
      expect(settings.value.model, 'deepseek-chat');
      expect(settings.value.cityTier, LlmCityTier.tier2);
      expect(settings.value.includeNames, isTrue);
      expect(settings.value.disclaimerAck, isTrue);
    });

    test('load is idempotent (second call does not re-read storage)', () async {
      var reads = 0;
      when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async {
        reads++;
        return null;
      });

      await settings.load();
      await settings.load();

      expect(reads, 8); // 8 个 llm.* key,各读一次
    });
  });

  group('setConfig', () {
    test('setConfig persists every field under its llm.* key', () async {
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      await settings.setConfig(const LlmConfig(
        enabled: true,
        provider: LlmProvider.openai,
        baseUrl: 'https://llm.internal/v1',
        apiKey: 'sk-prod',
        model: 'gpt-4o-mini',
        cityTier: LlmCityTier.tier3,
        includeNames: true,
        disclaimerAck: true,
      ));

      verify(() => backend.write(key: 'llm.enabled', value: 'true')).called(1);
      verify(() => backend.write(key: 'llm.provider', value: 'openai'))
          .called(1);
      verify(() =>
          backend.write(key: 'llm.base_url', value: 'https://llm.internal/v1'))
          .called(1);
      verify(() => backend.write(key: 'llm.api_key', value: 'sk-prod'))
          .called(1);
      verify(() => backend.write(key: 'llm.model', value: 'gpt-4o-mini'))
          .called(1);
      verify(() => backend.write(key: 'llm.tier', value: 'tier3')).called(1);
      verify(() => backend.write(key: 'llm.include_names', value: 'true'))
          .called(1);
      verify(() => backend.write(key: 'llm.disclaimer_ack', value: 'true'))
          .called(1);
    });

    test('setConfig notifies listeners with the new config', () async {
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      final fired = <LlmConfig>[];
      settings.listenable.addListener(() => fired.add(settings.value));

      const next = LlmConfig(
        enabled: true,
        provider: LlmProvider.zhipu,
        apiKey: 'sk-x',
        model: 'glm-4-plus',
      );
      await settings.setConfig(next);

      expect(settings.value, next);
      expect(fired, [next]);
    });
  });

  group('provider preset endpoints', () {
    test('resolvedBaseUrl maps preset providers to their default endpoints',
        () {
      expect(
        const LlmConfig(provider: LlmProvider.zhipu).resolvedBaseUrl,
        'https://open.bigmodel.cn/api/paas/v4',
      );
      expect(
        const LlmConfig(provider: LlmProvider.openai).resolvedBaseUrl,
        'https://api.openai.com/v1',
      );
      expect(
        const LlmConfig(provider: LlmProvider.deepseek).resolvedBaseUrl,
        'https://api.deepseek.com/v1',
      );
    });

    test('resolvedBaseUrl uses the user-filled url only for custom provider',
        () {
      // 预设商:stored baseUrl 被忽略(预设端点钉死)
      expect(
        const LlmConfig(
          provider: LlmProvider.openai,
          baseUrl: 'https://evil.example/v1',
        ).resolvedBaseUrl,
        'https://api.openai.com/v1',
      );
      // custom:用户填写(去首尾空白)
      expect(
        const LlmConfig(
          provider: LlmProvider.custom,
          baseUrl: '  https://llm.internal/v1  ',
        ).resolvedBaseUrl,
        'https://llm.internal/v1',
      );
      // custom 未填 → 空(不 ready)
      expect(
        const LlmConfig(provider: LlmProvider.custom).resolvedBaseUrl,
        '',
      );
    });
  });

  group('ready derivation', () {
    test('ready requires enabled + endpoint + api key + model', () {
      // 全空 → false
      expect(const LlmConfig().ready, isFalse);
      // 启用但缺 Key → false
      expect(
        const LlmConfig(
          enabled: true,
          provider: LlmProvider.zhipu,
          model: 'glm-4-plus',
        ).ready,
        isFalse,
      );
      // 启用但缺模型 → false
      expect(
        const LlmConfig(
          enabled: true,
          provider: LlmProvider.zhipu,
          apiKey: 'sk-x',
        ).ready,
        isFalse,
      );
      // custom 未填端点 → false
      expect(
        const LlmConfig(
          enabled: true,
          provider: LlmProvider.custom,
          apiKey: 'sk-x',
          model: 'm',
        ).ready,
        isFalse,
      );
      // 齐备(预设端点来自 provider,baseUrl 存储值可空)→ true
      expect(
        const LlmConfig(
          enabled: true,
          provider: LlmProvider.zhipu,
          apiKey: 'sk-x',
          model: 'glm-4-plus',
        ).ready,
        isTrue,
      );
    });

    test('settings.ready tracks the current config', () async {
      stubRead(const {});
      await settings.load();
      expect(settings.ready, isFalse);

      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      await settings.setConfig(const LlmConfig(
        enabled: true,
        provider: LlmProvider.zhipu,
        apiKey: 'sk-x',
        model: 'glm-4-plus',
      ));
      expect(settings.ready, isTrue);
    });
  });
}
