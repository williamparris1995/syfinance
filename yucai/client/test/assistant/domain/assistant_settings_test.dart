import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/core/llm/llm_settings.dart';

/// F64 T1:AssistantConfig(ADR-4 助手档,ready 规则放宽于 F46——
/// localhost 端点免 Key;复用 core/llm 的 LlmProvider/LlmEndpoints 单源)。
void main() {
  group('defaults', () {
    test('defaults to disabled minimal config', () {
      const config = AssistantConfig();
      expect(config.enabled, isFalse);
      expect(config.provider, LlmProvider.zhipu);
      expect(config.baseUrl, '');
      expect(config.apiKey, '');
      expect(config.model, '');
      expect(config.ready, isFalse);
    });
  });

  group('resolvedBaseUrl', () {
    test('custom trims user input', () {
      const config = AssistantConfig(
        provider: LlmProvider.custom,
        baseUrl: '  http://localhost:11434/v1  ',
      );
      expect(config.resolvedBaseUrl, 'http://localhost:11434/v1');
    });

    test('preset provider pins the preset URL (stored baseUrl ignored)',
        () {
      const config = AssistantConfig(
        provider: LlmProvider.zhipu,
        baseUrl: 'https://ignored.example.com/v1',
      );
      expect(config.resolvedBaseUrl, 'https://open.bigmodel.cn/api/paas/v4');
    });

    test('preset covers openai and deepseek', () {
      const openai = AssistantConfig(provider: LlmProvider.openai);
      expect(openai.resolvedBaseUrl, 'https://api.openai.com/v1');
      const deepseek = AssistantConfig(provider: LlmProvider.deepseek);
      expect(deepseek.resolvedBaseUrl, 'https://api.deepseek.com/v1');
    });
  });

  group('ready (ADR-4)', () {
    test('not ready when disabled even if endpoint complete', () {
      const config = AssistantConfig(
        provider: LlmProvider.custom,
        baseUrl: 'http://localhost:11434/v1',
        apiKey: 'sk-x',
        model: 'glm-4-plus',
      );
      expect(config.enabled, isFalse);
      expect(config.ready, isFalse);
    });

    test('not ready when custom endpoint empty', () {
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        model: 'glm-4-plus',
        apiKey: 'sk-x',
      );
      expect(config.resolvedBaseUrl, '');
      expect(config.ready, isFalse);
    });

    test('not ready when model empty', () {
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'http://localhost:11434/v1',
      );
      expect(config.model, '');
      expect(config.ready, isFalse);
    });

    test('localhost endpoint ready without key (FR-4 免 Key 路)', () {
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'http://localhost:11434/v1',
        model: 'qwen3:latest',
      );
      expect(config.apiKey, '');
      expect(config.ready, isTrue);
    });

    test('127.0.0.1 endpoint ready without key', () {
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'http://127.0.0.1:11434/v1',
        model: 'qwen3:latest',
      );
      expect(config.ready, isTrue);
    });

    test('IPv6 loopback endpoint ready without key', () {
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'http://[::1]:11434/v1',
        model: 'qwen3:latest',
      );
      expect(config.ready, isTrue);
    });

    test('localhost endpoint ready with key as well', () {
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'http://localhost:11434/v1',
        apiKey: 'local-gateway-key',
        model: 'qwen3:latest',
      );
      expect(config.ready, isTrue);
    });

    test('remote endpoint without key not ready', () {
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'https://llm.example.com/v1',
        model: 'glm-4-plus',
      );
      expect(config.ready, isFalse);
    });

    test('preset provider endpoint needs key (remote)', () {
      const noKey = AssistantConfig(
        enabled: true,
        provider: LlmProvider.zhipu,
        model: 'glm-4-plus',
      );
      expect(noKey.ready, isFalse);

      const withKey = AssistantConfig(
        enabled: true,
        provider: LlmProvider.zhipu,
        apiKey: 'sk-zhipu',
        model: 'glm-4-plus',
      );
      expect(withKey.ready, isTrue);
    });

    test('unparseable endpoint without key falls back to not ready', () {
      // 非法 host(IPv6 字面量未闭合)→ Uri.parse 抛 FormatException
      // → _isLocalhost 判 false。
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'http://[',
        model: 'qwen3:latest',
      );
      expect(config.ready, isFalse);
    });

    test('localhost-looking path without scheme is not localhost host', () {
      // 无 scheme 时 host 为空,不得误判免 Key。
      const config = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'localhost:11434/v1',
        model: 'qwen3:latest',
      );
      expect(config.ready, isFalse);
    });
  });

  group('copyWith', () {
    test('copies only provided fields, keeps the rest', () {
      const base = AssistantConfig(
        enabled: true,
        provider: LlmProvider.custom,
        baseUrl: 'http://localhost:11434/v1',
        apiKey: 'sk-old',
        model: 'qwen3:latest',
      );

      final flipped = base.copyWith(enabled: false, model: 'glm-4-plus');
      expect(flipped.enabled, isFalse);
      expect(flipped.provider, LlmProvider.custom);
      expect(flipped.baseUrl, 'http://localhost:11434/v1');
      expect(flipped.apiKey, 'sk-old');
      expect(flipped.model, 'glm-4-plus');

      // 原实例不可变,不受影响。
      expect(base.enabled, isTrue);
      expect(base.model, 'qwen3:latest');
    });
  });
}
