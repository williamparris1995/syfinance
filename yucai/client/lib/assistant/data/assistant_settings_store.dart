/// F64 助手地基 —— 助手配置 secure storage 持久化(FR-4/ADR-4)。
///
/// 照 [LlmSettings] 家法逐条镜像:flutter_secure_storage 持久化 +
/// [ValueNotifier] 响应式 + bootstrap 幂等 [load] 一次;非法/缺失存储值
/// 回落缺省(fail-safe 关闭态)。独立 `assistant.*` namespace 与 F46 的
/// `llm.*` keys 并存互不影响(F46 LlmSettings 零改动);[AssistantConfig.ready]
/// 放宽 localhost 端点免云端 Key 门槛(ADR-4,与 F46 语义不同)。
///
/// 隐私红线(照 F46):[AssistantConfig.apiKey] 只经 secure storage 落盘,
/// 任何日志/错误消息不得携带 Key 或完整 payload。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/core/llm/llm_settings.dart' show LlmProvider;

import '../domain/assistant_settings.dart';

/// 助手配置仓储 + 响应式状态(LlmSettings 家法镜像,ADR-4)。
///
/// 注入的 [_storage] 缝供单测 mock secure-storage 后端;[load] 幂等;
/// [setConfig] 全量落盘并通知。DI bootstrap 接线归 T6。
@LazySingleton()
class AssistantSettings {
  AssistantSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyEnabled = 'assistant.enabled';
  static const _keyProvider = 'assistant.provider';
  static const _keyBaseUrl = 'assistant.base_url';
  static const _keyApiKey = 'assistant.api_key';
  static const _keyModel = 'assistant.model';

  final ValueNotifier<AssistantConfig> _notifier =
      ValueNotifier(const AssistantConfig());
  bool _loaded = false;

  /// 当前配置(同步)。[load] 完成前为缺省关闭态。
  AssistantConfig get value => _notifier.value;

  /// 配置 listenable;设置卡与助手入口用它驱动实时刷新。
  ValueListenable<AssistantConfig> get listenable => _notifier;

  /// 配置完整性(ADR-4 放宽:localhost 端点免云端 Key)。
  bool get ready => _notifier.value.ready;

  /// 读取持久化配置。幂等;bootstrap 调用一次。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _notifier.value = AssistantConfig(
      enabled: _decodeBool(await _storage.read(key: _keyEnabled)),
      provider: _decodeProvider(await _storage.read(key: _keyProvider)),
      baseUrl: await _storage.read(key: _keyBaseUrl) ?? '',
      apiKey: await _storage.read(key: _keyApiKey) ?? '',
      model: await _storage.read(key: _keyModel) ?? '',
    );
  }

  /// 全量持久化并立即应用新配置。
  Future<void> setConfig(AssistantConfig config) async {
    await Future.wait([
      _storage.write(key: _keyEnabled, value: _encodeBool(config.enabled)),
      _storage.write(key: _keyProvider, value: config.provider.name),
      _storage.write(key: _keyBaseUrl, value: config.baseUrl),
      _storage.write(key: _keyApiKey, value: config.apiKey),
      _storage.write(key: _keyModel, value: config.model),
    ]);
    _notifier.value = config;
  }

  static String _encodeBool(bool v) => v ? 'true' : 'false';

  static bool _decodeBool(String? raw) => raw == 'true'; // 非法回落 false

  static LlmProvider _decodeProvider(String? raw) =>
      LlmProvider.values.asNameMap()[raw] ??
      LlmProvider.zhipu; // 非法回落预设首选
}
