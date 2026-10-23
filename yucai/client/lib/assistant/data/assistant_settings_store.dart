/// F66 助手配置 secure storage 持久化(FR-2;收窄返工 F64 FR-4,
/// 2026-10-23)。
///
/// 2026-10-23 收窄:keys 削减为 `assistant.enabled`/`assistant.model`
/// 两键;`assistant.provider/.base_url/.api_key` 三键退役 —— 旧键残留
/// 无害(读取端只读两键,天然忽略),不抛错不迁移;F64 形态未随任何
/// tag 发版,零迁移直改。
///
/// 照 [LlmSettings] 家法逐条镜像:flutter_secure_storage 持久化 +
/// [ValueNotifier] 响应式 + bootstrap 幂等 [load] 一次;非法/缺失存储值
/// 回落缺省(fail-safe 关闭态)。独立 `assistant.*` namespace 与 F46 的
/// `llm.*` keys 并存互不影响(F46 LlmSettings 零改动);[AssistantConfig]
/// 不再含任何密钥字段。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

import '../domain/assistant_settings.dart';

/// 助手配置仓储 + 响应式状态(LlmSettings 家法镜像)。
///
/// 注入的 [_storage] 缝供单测 mock secure-storage 后端;[load] 幂等;
/// [setConfig] 全量落盘并通知。DI bootstrap 接线在 core/di injection.dart。
@LazySingleton()
class AssistantSettings {
  AssistantSettings({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyEnabled = 'assistant.enabled';
  static const _keyModel = 'assistant.model';

  final ValueNotifier<AssistantConfig> _notifier =
      ValueNotifier(const AssistantConfig());
  bool _loaded = false;

  /// 当前配置(同步)。[load] 完成前为缺省关闭态。
  AssistantConfig get value => _notifier.value;

  /// 配置 listenable;设置卡与助手入口用它驱动实时刷新。
  ValueListenable<AssistantConfig> get listenable => _notifier;

  /// 配置完整性(FR-2 收窄:enabled && model 非空;模型在位归引擎侧)。
  bool get ready => _notifier.value.ready;

  /// 读取持久化配置(只读两键,F64 遗留键天然忽略)。幂等;bootstrap
  /// 调用一次。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _notifier.value = AssistantConfig(
      enabled: _decodeBool(await _storage.read(key: _keyEnabled)),
      // 缺失回落默认模型 id(新装/清库);旧键不读。
      model:
          await _storage.read(key: _keyModel) ?? AssistantConfig.defaultModel,
    );
  }

  /// 全量持久化并立即应用新配置(只写两键,退役键不再触碰)。
  Future<void> setConfig(AssistantConfig config) async {
    await Future.wait([
      _storage.write(key: _keyEnabled, value: _encodeBool(config.enabled)),
      _storage.write(key: _keyModel, value: config.model),
    ]);
    _notifier.value = config;
  }

  static String _encodeBool(bool v) => v ? 'true' : 'false';

  static bool _decodeBool(String? raw) => raw == 'true'; // 非法回落 false
}
