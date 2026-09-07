import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Persistent "this device has completed binding" marker (R6 H, design
/// ADR-4): survives restarts so re-login skips the upload wizard (the
/// feature-G static flag was process-local only, and the empty-account guard
/// would misreport a bound account as blocked).
///
/// F17-T1(2026-09-06)职责单一化:标记值 'bound' 仅表「本设备已完成绑定」,
/// **不再是同步 deviceId 来源**(clientId 退役了它 —— 见
/// GrpcOfflineSyncPort / TokenStorage.readClientId)。tenant 标记与设备
/// 身份就此分离,F10-F16 的过渡形态(deviceId 借读标记串)闭环。
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

  Future<void> clear() => _storage.delete(key: _key);
}
