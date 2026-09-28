/// F46 LLM 分析师 —— BYOK 配置(FR-1/ADR-2)。
///
/// 照 [ThemeSettings] 家法逐条镜像:flutter_secure_storage 持久化 +
/// [ValueNotifier] 响应式 + bootstrap(injection.dart,runApp 前)幂等
/// [load] 一次;非法/缺失存储值回落缺省(fail-safe 关闭态)。
///
/// 隐私红线(FR-5):[LlmConfig.apiKey] 只经 secure storage 落盘,任何
/// 日志/错误消息不得携带 Key 或完整 payload。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// OpenAI 兼容端点商(预设三家 + 自定义,FR-1 四选)。
enum LlmProvider { zhipu, openai, deepseek, custom }

/// 城市规模档位(FR-1,LLM 生活成本语境:一线/新一线/二三线)。
enum LlmCityTier { tier1, tier2, tier3 }

/// 档位 → 中文标签(payload `cityTier` 字段与 prompt 语境行共用单点,
/// 评审 R1 收口:两处重复 switch 合一)。
extension LlmCityTierLabel on LlmCityTier {
  String get label => switch (this) {
        LlmCityTier.tier1 => '一线',
        LlmCityTier.tier2 => '新一线',
        LlmCityTier.tier3 => '二三线',
      };
}

/// 预设端点映射(provider → 默认 base_url;custom = 用户填写)。
abstract final class LlmEndpoints {
  static const Map<LlmProvider, String> preset = {
    LlmProvider.zhipu: 'https://open.bigmodel.cn/api/paas/v4',
    LlmProvider.openai: 'https://api.openai.com/v1',
    LlmProvider.deepseek: 'https://api.deepseek.com/v1',
  };
}

/// 不可变配置快照(ValueNotifier 的值类型)。
class LlmConfig {
  const LlmConfig({
    this.enabled = false,
    this.provider = LlmProvider.zhipu,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = '',
    this.cityTier = LlmCityTier.tier1,
    this.includeNames = false,
    this.disclaimerAck = false,
  });

  /// 启用开关(默认关:零行为变化,Migraton Plan)。
  final bool enabled;

  /// 端点商(预设商端点钉死,见 [resolvedBaseUrl])。
  final LlmProvider provider;

  /// 自定义 base_url(仅 [LlmProvider.custom] 生效)。
  final String baseUrl;

  /// API Key(仅经 secure storage;错误消息零携带,FR-5)。
  final String apiKey;

  /// 模型名(如 glm-4-plus / gpt-4o-mini;默认值由设置卡预填,T2)。
  final String model;

  /// 城市规模档位。
  final LlmCityTier cityTier;

  /// 订阅名明文开关(默认关:模板名属负面清单,FR-2)。
  final bool includeNames;

  /// 首启用免责已确认(FR-1:确认一次持久化)。
  final bool disclaimerAck;

  /// 有效端点:预设商 → 预设 URL(存储的 [baseUrl] 被忽略);custom →
  /// 用户填写值(去首尾空白,未填 → 空)。
  String get resolvedBaseUrl => provider == LlmProvider.custom
      ? baseUrl.trim()
      : LlmEndpoints.preset[provider]!;

  /// 字段级拷贝(设置卡草稿态编辑用)。
  LlmConfig copyWith({
    bool? enabled,
    LlmProvider? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
    LlmCityTier? cityTier,
    bool? includeNames,
    bool? disclaimerAck,
  }) =>
      LlmConfig(
        enabled: enabled ?? this.enabled,
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        cityTier: cityTier ?? this.cityTier,
        includeNames: includeNames ?? this.includeNames,
        disclaimerAck: disclaimerAck ?? this.disclaimerAck,
      );

  /// 配置完整性派生(FR-4 入口可见性):启用 + 端点 + Key + 模型齐备。
  bool get ready =>
      enabled &&
      resolvedBaseUrl.isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;
}

/// BYOK 配置仓储 + 响应式状态(ThemeSettings 家法)。
///
/// 注入的 [_storage] 缝供单测 mock secure-storage 后端(照 TokenStorage
/// 可选参数形态);[load] 幂等;[setConfig] 全量落盘并通知。
@LazySingleton()
class LlmSettings {
  LlmSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyEnabled = 'llm.enabled';
  static const _keyProvider = 'llm.provider';
  static const _keyBaseUrl = 'llm.base_url';
  static const _keyApiKey = 'llm.api_key';
  static const _keyModel = 'llm.model';
  static const _keyTier = 'llm.tier';
  static const _keyIncludeNames = 'llm.include_names';
  static const _keyDisclaimerAck = 'llm.disclaimer_ack';

  final ValueNotifier<LlmConfig> _notifier = ValueNotifier(const LlmConfig());
  bool _loaded = false;

  /// 当前配置(同步)。[load] 完成前为缺省关闭态。
  LlmConfig get value => _notifier.value;

  /// 配置 listenable;设置卡与报告页入口用它驱动实时刷新。
  ValueListenable<LlmConfig> get listenable => _notifier;

  /// 配置完整性(FR-4:报告页「AI 解读」入口可见性)。
  bool get ready => _notifier.value.ready;

  /// 读取持久化配置。幂等;bootstrap 调用一次。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _notifier.value = LlmConfig(
      enabled: _decodeBool(await _storage.read(key: _keyEnabled)),
      provider: _decodeProvider(await _storage.read(key: _keyProvider)),
      baseUrl: await _storage.read(key: _keyBaseUrl) ?? '',
      apiKey: await _storage.read(key: _keyApiKey) ?? '',
      model: await _storage.read(key: _keyModel) ?? '',
      cityTier: _decodeTier(await _storage.read(key: _keyTier)),
      includeNames: _decodeBool(await _storage.read(key: _keyIncludeNames)),
      disclaimerAck:
          _decodeBool(await _storage.read(key: _keyDisclaimerAck)),
    );
  }

  /// 全量持久化并立即应用新配置。
  Future<void> setConfig(LlmConfig config) async {
    await Future.wait([
      _storage.write(key: _keyEnabled, value: _encodeBool(config.enabled)),
      _storage.write(key: _keyProvider, value: config.provider.name),
      _storage.write(key: _keyBaseUrl, value: config.baseUrl),
      _storage.write(key: _keyApiKey, value: config.apiKey),
      _storage.write(key: _keyModel, value: config.model),
      _storage.write(key: _keyTier, value: config.cityTier.name),
      _storage.write(
          key: _keyIncludeNames, value: _encodeBool(config.includeNames)),
      _storage.write(
          key: _keyDisclaimerAck, value: _encodeBool(config.disclaimerAck)),
    ]);
    _notifier.value = config;
  }

  static String _encodeBool(bool v) => v ? 'true' : 'false';

  static bool _decodeBool(String? raw) => raw == 'true'; // 非法回落 false

  static LlmProvider _decodeProvider(String? raw) =>
      LlmProvider.values.asNameMap()[raw] ??
      LlmProvider.zhipu; // 非法回落预设首选

  static LlmCityTier _decodeTier(String? raw) =>
      LlmCityTier.values.asNameMap()[raw] ??
      LlmCityTier.tier1; // 非法回落一线
}
