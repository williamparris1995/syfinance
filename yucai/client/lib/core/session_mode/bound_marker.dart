import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Persistent "this device has completed binding" marker (R6 H, design
/// ADR-4): survives restarts so re-login skips the upload wizard (the
/// feature-G static flag was process-local only, and the empty-account guard
/// would misreport a bound account as blocked).
@LazySingleton()
class BoundMarker {
  BoundMarker({FlutterSecureStorage? backend})
      : _storage = backend ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'yucai.bound_tenant';

  Future<void> markBound(String tenantId) =>
      _storage.write(key: _key, value: tenantId);

  Future<bool> isBound() async =>
      await _storage.read(key: _key) != null;

  /// F11 T3(ADR-5):读回标记串 —— 同步 PushChanges 的 deviceId 来源。
  /// 绑定标记串(当前生产值为 'bound' 字面量而非 tenant uuid;server
  /// parseUUID 得 Nil 仅影响 sync_log 日志列与 device 版本 bump no-op,
  /// 无害;ticket 16 RegisterDevice 真实化时一并处理)。未绑定返回 null
  /// (调用方传空串,server 侧回退鉴权 tenant)。
  Future<String?> readTenantId() => _storage.read(key: _key);

  Future<void> clear() => _storage.delete(key: _key);
}
