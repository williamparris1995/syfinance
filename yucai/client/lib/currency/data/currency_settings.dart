import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Persists the user's configured base currency (reporting currency) in the OS
/// keychain via flutter_secure_storage. Defaults to "CNY" when unset/empty/null
/// so callers always get a usable ISO 4217 code.
///
/// The injected [_storage] seam lets unit tests mock the secure-storage backend
/// (see the established pattern in [TokenStorage]).
@LazySingleton()
class CurrencySettings {
  CurrencySettings(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'base_currency';
  static const String defaultBaseCurrency = 'CNY';

  /// Returns the configured base currency code, or "CNY" when no value has been
  /// set, the value is null, or the stored value is the empty string.
  Future<String> getBaseCurrency() async {
    final v = await _storage.read(key: _key);
    return (v != null && v.isNotEmpty) ? v : defaultBaseCurrency;
  }

  /// Persists [code] as the user's base currency.
  Future<void> setBaseCurrency(String code) async {
    await _storage.write(key: _key, value: code);
  }
}
