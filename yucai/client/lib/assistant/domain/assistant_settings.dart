/// F64 助手地基 —— 助手端点配置值类型(FR-4/ADR-4)。
///
/// 独立于 F46 报告 BYOK([LlmConfig])的助手档:endpoint/model/key 自持,
/// 持久化 keys(`assistant.*`)与 `llm.*` 并存互不影响;ready 规则放宽
/// ——localhost 端点免云端 Key 门槛(端侧零配置,sprint-2 端侧推理默认)。
///
/// [LlmProvider]/[LlmEndpoints] 复用 core/llm 单一事实源,不重复定义。
library;

import 'package:yucai_client/core/llm/llm_settings.dart'
    show LlmEndpoints, LlmProvider;

/// 助手配置快照(不可变;secure storage 持久化由 T2 AssistantSettingsStore
/// 承担,apiKey 只经 secure storage 落盘 —— 照 F46 隐私红线)。
class AssistantConfig {
  const AssistantConfig({
    this.enabled = false,
    this.provider = LlmProvider.zhipu,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
  });

  /// 启用开关(默认关:零行为变化)。
  final bool enabled;

  /// 端点商(预设商端点钉死,见 [resolvedBaseUrl])。
  final LlmProvider provider;

  /// 自定义 base_url(仅 [LlmProvider.custom] 生效;允许 localhost)。
  final String baseUrl;

  /// API Key(仅经 secure storage;localhost 端点可空)。
  final String apiKey;

  /// 模型名(如 glm-4-plus / qwen3:latest)。
  final String model;

  /// 有效端点:预设商 → 预设 URL(存储的 [baseUrl] 被忽略);custom →
  /// 用户填写值(去首尾空白,未填 → 空)。
  String get resolvedBaseUrl => provider == LlmProvider.custom
      ? baseUrl.trim()
      : LlmEndpoints.preset[provider]!;

  /// 端点 host 是否环回(localhost / 127.0.0.1 / ::1)。
  ///
  /// [Uri.parse] 抛异常(如非法 IPv6 字面量)→ 按非 localhost 处理。
  bool get _isLocalhost {
    final String host;
    try {
      host = Uri.parse(resolvedBaseUrl).host;
    } on FormatException {
      return false;
    }
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  /// 配置完整性(ADR-4,与 F46 [LlmConfig.ready] 不同):启用 + 端点 +
  /// model 齐备,且(Key 非空 或 端点为环回 —— 免云端 Key 门槛)。
  bool get ready =>
      enabled &&
      resolvedBaseUrl.isNotEmpty &&
      model.trim().isNotEmpty &&
      (apiKey.trim().isNotEmpty || _isLocalhost);

  /// 字段级拷贝(设置卡草稿态编辑用)。
  AssistantConfig copyWith({
    bool? enabled,
    LlmProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) =>
      AssistantConfig(
        enabled: enabled ?? this.enabled,
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
      );
}
