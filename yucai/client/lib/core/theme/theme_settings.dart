import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// 用户主题模式偏好(跟随系统/亮/暗),持久化到 OS keychain
/// (镜像 [CurrencySettings] 的 flutter_secure_storage + ValueNotifier 模式)。
///
/// 响应式:[listenable] 驱动 MaterialApp.themeMode 实时切换;[load] 在
/// bootstrap(injection.dart,runApp 前)调用一次同步持久化值,未存储/非法值
/// 回落 [ThemeMode.system]。
///
/// 注入的 [_storage] 缝隙供单测 mock secure-storage 后端(见 CurrencySettings)。
@LazySingleton()
class ThemeSettings {
  ThemeSettings(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'theme_mode';

  final ValueNotifier<ThemeMode> _notifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );
  bool _loaded = false;

  /// 当前主题模式(同步)。[load] 完成前为 system。
  ThemeMode get value => _notifier.value;

  /// 主题模式 listenable;MaterialApp 用它驱动 themeMode 实时重建。
  ValueListenable<ThemeMode> get listenable => _notifier;

  /// 读取持久化的主题模式。幂等;bootstrap 调用一次。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _notifier.value = _decode(await _storage.read(key: _key));
  }

  /// 持久化并立即应用主题模式。
  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.write(key: _key, value: _encode(mode));
    _notifier.value = mode;
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system, // null/空/未知值回落跟随系统
      };
}
