/// F66 助手配置(FR-2,收窄返工 F64 FR-4;2026-10-23)。
///
/// R22 纯内嵌定案:助手只跑随包 llama-server + Qwen3-4B,端点由引擎侧
/// (F66 EngineManager)供给 —— provider/baseUrl/apiKey 字段与
/// `assistant.provider/.base_url/.api_key` storage keys 全数退役;F64
/// 形态未随任何 tag 发版,直改零迁移。不再 import core/llm:助手档与
/// F46 报告 BYOK 从此彻底解耦(顺带消掉 F64 评审 parked 的 L-1「domain
/// 传递 Flutter 依赖」之一,本文件现为纯 Dart)。
///
/// ready 语义分工(FR-2):本层 [ready] 只管配置字段完整(enabled &&
/// model 非空);运行期就绪 = enabled && ModelStore.isReady(模型文件在位)
/// 由引擎侧组合判定,本层零文件系统触碰。
library;

/// 助手配置快照(不可变;secure storage 持久化由 AssistantSettingsStore
/// 承担)。
class AssistantConfig {
  /// v1 钉死的随包模型 id(gguf 文件名主干)。默认值常量 = 单一事实源:
  /// F67 多模型管理在此扩展(模型清单/切换),store 与设置面零散改。
  static const String defaultModel = 'qwen3-4b-instruct-q4_k_m';

  const AssistantConfig({
    this.enabled = false,
    this.model = defaultModel,
  });

  /// 启用开关(默认关:零行为变化)。
  final bool enabled;

  /// 模型 id(如 qwen3-4b-instruct-q4_k_m;文件在位检查归 ModelStore)。
  final String model;

  /// 配置完整性(FR-2 收窄语义):enabled && model 非空。模型文件是否
  /// 在位由 ModelStore.isReady 判定,运行期就绪由引擎侧组合,不在此层。
  bool get ready => enabled && model.trim().isNotEmpty;

  /// 字段级拷贝(设置卡草稿态编辑用)。
  AssistantConfig copyWith({bool? enabled, String? model}) => AssistantConfig(
        enabled: enabled ?? this.enabled,
        model: model ?? this.model,
      );
}
