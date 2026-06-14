import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';

/// Persists auth tokens in OS keychain via flutter_secure_storage.
/// The [_backend] seam lets us unit-test the (de)serialization + key logic.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? backend})
      : _backend = backend ?? const FlutterSecureStorage();

  final FlutterSecureStorage _backend;

  static const _keyAccess = 'yucai.access_token';
  static const _keyRefresh = 'yucai.refresh_token';
  static const _keyClientId = 'yucai.client_id';

  /// Per-install client identifier. Used to distinguish this Flutter instance
  /// from others in the server log. Generated once, persisted, reused.
  Future<String?> readClientId() => _backend.read(key: _keyClientId);

  Future<void> saveClientId(String clientId) =>
      _backend.write(key: _keyClientId, value: clientId);

  Future<AuthTokens?> readTokens() async {
    final access = await _backend.read(key: _keyAccess);
    final refresh = await _backend.read(key: _keyRefresh);
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      return null;
    }
    return AuthTokens(accessToken: access, refreshToken: refresh);
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    await _backend.write(key: _keyAccess, value: tokens.accessToken);
    await _backend.write(key: _keyRefresh, value: tokens.refreshToken);
  }

  Future<void> clearTokens() async {
    await _backend.delete(key: _keyAccess);
    await _backend.delete(key: _keyRefresh);
  }
}
