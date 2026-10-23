import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';

/// F66 T1(FR-2,MODIFIES F64 FR-4):AssistantConfig 收窄为 {enabled, model}
/// —— provider/baseUrl/apiKey/端点派生全数退役(R22 纯内嵌定案:助手只跑
/// 随包 llama-server,端点由引擎供给);ready 只管字段完整,模型文件在位
/// 归 ModelStore/引擎侧组合,本层零文件系统。
void main() {
  group('defaults', () {
    test('defaults to disabled with the pinned default model id', () {
      const config = AssistantConfig();
      expect(config.enabled, isFalse);
      expect(config.model, AssistantConfig.defaultModel);
      expect(config.model, 'qwen3-4b-instruct-q4_k_m');
      expect(config.ready, isFalse);
    });
  });

  group('ready (FR-2 narrowed semantics)', () {
    test('not ready when disabled even if model set', () {
      const config = AssistantConfig(model: 'qwen3-4b-instruct-q4_k_m');
      expect(config.enabled, isFalse);
      expect(config.ready, isFalse);
    });

    test('not ready when model empty', () {
      const config = AssistantConfig(enabled: true, model: '');
      expect(config.model, '');
      expect(config.ready, isFalse);
    });

    test('not ready when model whitespace-only', () {
      const config = AssistantConfig(enabled: true, model: '   ');
      expect(config.ready, isFalse);
    });

    test('ready when enabled and model non-empty (config completeness only)',
        () {
      const config = AssistantConfig(enabled: true);
      expect(config.model, isNotEmpty);
      expect(config.ready, isTrue);
    });
  });

  group('copyWith', () {
    test('copies only provided fields, keeps the rest', () {
      const base = AssistantConfig(enabled: true, model: 'legacy-model-id');

      final flipped = base.copyWith(enabled: false);
      expect(flipped.enabled, isFalse);
      expect(flipped.model, 'legacy-model-id');

      final remodeled = base.copyWith(model: AssistantConfig.defaultModel);
      expect(remodeled.enabled, isTrue);
      expect(remodeled.model, AssistantConfig.defaultModel);

      // 原实例不可变,不受影响。
      expect(base.enabled, isTrue);
      expect(base.model, 'legacy-model-id');
    });
  });
}
