import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage backend;
  late ThemeSettings settings;

  setUp(() {
    backend = _MockSecureStorage();
    settings = ThemeSettings(backend);
    registerFallbackValue('');
  });

  group('ThemeSettings (R8 F1)', () {
    test('value defaults to system before load', () {
      expect(settings.value, ThemeMode.system);
    });

    test('load falls back to system when nothing is stored', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      await settings.load();
      expect(settings.value, ThemeMode.system);
    });

    test('load falls back to system on unknown stored value', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'sepia');
      await settings.load();
      expect(settings.value, ThemeMode.system);
    });

    test('load syncs the persisted dark mode into value', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => 'dark');
      await settings.load();
      expect(settings.value, ThemeMode.dark);
    });

    test('setThemeMode persists under the expected storage key', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await settings.setThemeMode(ThemeMode.light);

      verify(() => backend.write(key: 'theme_mode', value: 'light')).called(1);
    });

    test('setThemeMode notifies listeners with the new mode', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final fired = <ThemeMode>[];
      settings.listenable.addListener(() => fired.add(settings.value));

      await settings.setThemeMode(ThemeMode.dark);

      expect(settings.value, ThemeMode.dark);
      expect(fired, [ThemeMode.dark]);
    });

    test('load is idempotent (second call is a no-op)', () async {
      var calls = 0;
      when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async {
        calls++;
        return 'dark';
      });
      await settings.load();
      await settings.load();
      expect(calls, 1);
      expect(settings.value, ThemeMode.dark);
    });
  });
}
