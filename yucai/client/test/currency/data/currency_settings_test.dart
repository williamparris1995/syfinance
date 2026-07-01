import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage backend;
  late CurrencySettings settings;

  setUp(() {
    backend = _MockSecureStorage();
    settings = CurrencySettings(backend);
    registerFallbackValue('');
  });

  group('CurrencySettings', () {
    test('getBaseCurrency returns default "CNY" when key is absent (null)',
        () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      expect(await settings.getBaseCurrency(), 'CNY');
    });

    test('getBaseCurrency returns "CNY" when stored value is empty', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => '');
      expect(await settings.getBaseCurrency(), 'CNY');
    });

    test('setBaseCurrency then getBaseCurrency round-trips the code',
        () async {
      final stored = <String, String>{};
      when(() => backend.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((inv) async => stored[inv.namedArguments[#key] as String] =
              inv.namedArguments[#value] as String);
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((inv) async => stored[inv.namedArguments[#key] as String]);

      await settings.setBaseCurrency('USD');
      expect(await settings.getBaseCurrency(), 'USD');
    });

    test('setBaseCurrency persists under the expected storage key', () async {
      when(() => backend.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      await settings.setBaseCurrency('EUR');

      verify(() => backend.write(key: 'base_currency', value: 'EUR')).called(1);
    });

    test('getBaseCurrency returns stored non-default code', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'JPY');
      expect(await settings.getBaseCurrency(), 'JPY');
    });

    // --- Reactive base currency (cross-page refresh) ---

    test('value defaults to CNY before load', () {
      // Notifier starts at the default; load() syncs the persisted value.
      expect(settings.value, 'CNY');
    });

    test('load syncs the persisted base currency into value', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'USD');
      expect(settings.value, 'CNY'); // before load
      await settings.load();
      expect(settings.value, 'USD');
    });

    test('setBaseCurrency notifies listeners with the new code', () async {
      when(() => backend.write(key: any(named: 'key'), value: any(named: 'value')))
          .thenAnswer((_) async {});

      final fired = <String>[];
      settings.listenable.addListener(() => fired.add(settings.value));

      await settings.setBaseCurrency('USD');

      expect(settings.value, 'USD');
      expect(fired, ['USD']);
    });

    test('load is idempotent (second call is a no-op)', () async {
      var calls = 0;
      when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async {
        calls++;
        return 'USD';
      });
      await settings.load();
      await settings.load();
      expect(calls, 1);
      expect(settings.value, 'USD');
    });
  });
}
