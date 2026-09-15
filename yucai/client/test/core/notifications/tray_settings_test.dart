import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage backend;
  late TraySettings settings;

  setUp(() {
    backend = _MockSecureStorage();
    settings = TraySettings(backend);
    registerFallbackValue('');
  });

  group('TraySettings (R8 F22 T1)', () {
    test('defaults before load: hide / minutes30 / not prompted / show amounts',
        () {
      expect(settings.closeBehavior, TrayCloseBehavior.hide);
      expect(settings.scanInterval, TrayScanInterval.minutes30);
      expect(settings.firstClosePrompted, isFalse);
      // F25:隐私默认显示(spec grill「隐私默认值=显示」)。
      expect(settings.showTrayAmounts, isTrue);
    });

    test('scanInterval exposes minutes for each value', () {
      expect(TrayScanInterval.minutes15.minutes, 15);
      expect(TrayScanInterval.minutes30.minutes, 30);
      expect(TrayScanInterval.minutes60.minutes, 60);
    });

    test('load falls back to defaults when nothing is stored', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      await settings.load();
      expect(settings.closeBehavior, TrayCloseBehavior.hide);
      expect(settings.scanInterval, TrayScanInterval.minutes30);
      expect(settings.firstClosePrompted, isFalse);
      // 未存储 → 默认显示金额(F25 隐私默认显示)。
      expect(settings.showTrayAmounts, isTrue);
    });

    test('load falls back to defaults on unknown stored values', () async {
      when(() => backend.read(key: 'tray_close_behavior'))
          .thenAnswer((_) async => 'minimize');
      when(() => backend.read(key: 'tray_scan_interval'))
          .thenAnswer((_) async => '45');
      when(() => backend.read(key: 'tray_first_close_prompted'))
          .thenAnswer((_) async => 'maybe');
      when(() => backend.read(key: 'tray_show_amounts'))
          .thenAnswer((_) async => 'maybe');
      await settings.load();
      expect(settings.closeBehavior, TrayCloseBehavior.hide);
      expect(settings.scanInterval, TrayScanInterval.minutes30);
      expect(settings.firstClosePrompted, isFalse);
      // 未知值回落默认显示(与既有字段「非法值回落默认」同语义)。
      expect(settings.showTrayAmounts, isTrue);
    });

    test('load syncs the persisted values (round trip)', () async {
      when(() => backend.read(key: 'tray_close_behavior'))
          .thenAnswer((_) async => 'exit');
      when(() => backend.read(key: 'tray_scan_interval'))
          .thenAnswer((_) async => '60');
      when(() => backend.read(key: 'tray_first_close_prompted'))
          .thenAnswer((_) async => 'true');
      when(() => backend.read(key: 'tray_show_amounts'))
          .thenAnswer((_) async => 'false');
      await settings.load();
      expect(settings.closeBehavior, TrayCloseBehavior.exit);
      expect(settings.scanInterval, TrayScanInterval.minutes60);
      expect(settings.firstClosePrompted, isTrue);
      expect(settings.showTrayAmounts, isFalse); // 用户显式关过 → 保持隐藏
    });

    test('setCloseBehavior persists under the expected storage key', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await settings.setCloseBehavior(TrayCloseBehavior.exit);

      verify(() => backend.write(
            key: 'tray_close_behavior',
            value: 'exit',
          )).called(1);
    });

    test('setCloseBehavior notifies listeners with the new value', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final fired = <TrayCloseBehavior>[];
      settings.closeBehaviorListenable
          .addListener(() => fired.add(settings.closeBehavior));

      await settings.setCloseBehavior(TrayCloseBehavior.exit);

      expect(settings.closeBehavior, TrayCloseBehavior.exit);
      expect(fired, [TrayCloseBehavior.exit]);
    });

    test('setScanInterval persists and notifies listeners', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final fired = <TrayScanInterval>[];
      settings.scanIntervalListenable
          .addListener(() => fired.add(settings.scanInterval));

      await settings.setScanInterval(TrayScanInterval.minutes15);

      verify(() => backend.write(
            key: 'tray_scan_interval',
            value: '15',
          )).called(1);
      expect(settings.scanInterval, TrayScanInterval.minutes15);
      expect(fired, [TrayScanInterval.minutes15]);
    });

    test('setFirstClosePrompted flips false to true and persists', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final fired = <bool>[];
      settings.firstClosePromptedListenable
          .addListener(() => fired.add(settings.firstClosePrompted));

      expect(settings.firstClosePrompted, isFalse);

      await settings.setFirstClosePrompted(true);

      verify(() => backend.write(
            key: 'tray_first_close_prompted',
            value: 'true',
          )).called(1);
      expect(settings.firstClosePrompted, isTrue);
      expect(fired, [true]);
    });

    test('load is idempotent (second call is a no-op)', () async {
      var calls = 0;
      when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async {
        calls++;
        return 'exit';
      });
      await settings.load();
      await settings.load();
      expect(calls, 4); // 四个键各读一次,重复 load 不再读(F25 扩第四键)
      expect(settings.closeBehavior, TrayCloseBehavior.exit);
    });
  });

  // ── F25 T1:托盘显示金额(第四字段,完全镜像既有三字段范式) ──────
  group('showTrayAmounts (F25 FR-3)', () {
    test('setShowTrayAmounts persists under tray_show_amounts', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await settings.setShowTrayAmounts(false);

      verify(() => backend.write(
            key: 'tray_show_amounts',
            value: 'false',
          )).called(1);
    });

    test('setShowTrayAmounts notifies listeners with the new value', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final fired = <bool>[];
      settings.showTrayAmountsListenable
          .addListener(() => fired.add(settings.showTrayAmounts));

      expect(settings.showTrayAmounts, isTrue); // 默认显示

      await settings.setShowTrayAmounts(false);

      expect(settings.showTrayAmounts, isFalse);
      expect(fired, [false]); // listenable 广播(菜单即时重设的接线面)
    });
  });
}
