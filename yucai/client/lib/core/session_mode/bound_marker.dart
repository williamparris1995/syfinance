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

  Future<void> clear() => _storage.delete(key: _key);
}
