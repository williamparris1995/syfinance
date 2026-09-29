import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 侧栏分组展开态记忆(⑨ 导航增强 A):折叠组名集合持久化到 OS keychain。
///
/// 家法 = [ThemeSettings] 同款 flutter_secure_storage + ValueNotifier 模式
/// (tray/llm/settings 系同源):[load] 在 bootstrap(injection.dart)同步
/// 持久化值,未存储/空串回落「全展开」;[setCollapsed] 落盘并即时生效。
///
/// 编码:组名逗号拼接(中文组名,无转义歧义);解码丢空段。
/// 非法/陈旧组名(侧栏改组后的残留)不在此滤 —— UI 侧按现行组交集消费,
/// 下次折叠切换全量覆写时自愈(写入集恒由现行组名构成)。
class NavSettings {
  NavSettings(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'nav_collapsed_groups';

  final ValueNotifier<Set<String>> _notifier = ValueNotifier<Set<String>>({});
  bool _loaded = false;

  /// 当前折叠组名集合(同步)。[load] 完成前为空(全展开)。
  Set<String> get collapsedGroups => _notifier.value;

  /// 折叠组 listenable;_Sidebar 记忆态由此驱动。
  ValueListenable<Set<String>> get listenable => _notifier;

  /// 读取持久化的折叠组集合。幂等;bootstrap 调用一次。
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _notifier.value = _decode(await _storage.read(key: _key));
  }

  /// 持久化并立即应用折叠组集合。
  Future<void> setCollapsed(Set<String> groups) async {
    await _storage.write(key: _key, value: _encode(groups));
    _notifier.value = Set<String>.of(groups);
  }

  static String _encode(Set<String> groups) => groups.join(',');

  static Set<String> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    return {
      for (final part in raw.split(','))
        if (part.trim().isNotEmpty) part.trim(),
    };
  }
}
