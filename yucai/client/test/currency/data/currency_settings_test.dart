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
  });
}
