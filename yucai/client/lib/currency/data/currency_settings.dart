import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';

/// Persists the user's configured base currency (reporting currency) in the OS
/// keychain via flutter_secure_storage. Defaults to "CNY" when unset/empty/null
/// so callers always get a usable ISO 4217 code.
///
/// Reactive: [listenable] broadcasts the current base currency so pages (home
/// net-worth, performance curve, holding-detail curve) re-fetch immediately
/// when the user changes it in settings (cross-page refresh). [load] must run
/// once at bootstrap (before pages read [value]) to sync the notifier from
/// storage; thereafter [setBaseCurrency] keeps storage and the notifier in sync.
///
/// The injected [_storage] seam lets unit tests mock the secure-storage backend
/// (see the established pattern in [TokenStorage]).
@LazySingleton()
class CurrencySettings {
  CurrencySettings(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'base_currency';
  static const String defaultBaseCurrency = 'CNY';

  final ValueNotifier<String> _notifier =
      ValueNotifier<String>(defaultBaseCurrency);
  bool _loaded = false;

  /// The current base currency (sync). Defaults to CNY until [load] completes.
  String get value => _notifier.value;

  /// Listenable for the base currency; pages add a listener to re-fetch on
  /// change (cross-page refresh). Display widgets can use ValueListenableBuilder.
  ValueListenable<String> get listenable => _notifier;

  /// Loads the persisted base currency into the notifier. Idempotent; call once
  /// during app bootstrap (configureDependencies, before runApp) so [value] is
  /// accurate when pages first read it.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    _notifier.value = await getBaseCurrency();
  }

  /// Returns the configured base currency code, or "CNY" when no value has been
  /// set, the value is null, or the stored value is the empty string.
  Future<String> getBaseCurrency() async {
    final v = await _storage.read(key: _key);
    return (v != null && v.isNotEmpty) ? v : defaultBaseCurrency;
  }

  /// Persists [code] as the user's base currency and notifies listeners so open
  /// pages re-fetch with the new reporting currency.
  Future<void> setBaseCurrency(String code) async {
    await _storage.write(key: _key, value: code);
    _notifier.value = code;
  }
}
