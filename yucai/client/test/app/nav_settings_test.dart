// ⑨ 导航增强 A:侧栏分组展开态记忆 —— NavSettings 单测。
// 家法 = ThemeSettings(tray/llm 同款):flutter_secure_storage 单键 +
// ValueNotifier + load 幂等,测试以 mock 后端驱动(照 theme_settings_test)。
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/app/nav_settings.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockSecureStorage backend;
  late NavSettings settings;

  setUp(() {
    backend = _MockSecureStorage();
    settings = NavSettings(backend);
    registerFallbackValue('');
  });

  group('NavSettings (⑨ 导航增强 A)', () {
    test('collapsedGroups defaults to empty before load', () {
      expect(settings.collapsedGroups, isEmpty);
    });

    test('load falls back to empty when nothing is stored', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      await settings.load();
      expect(settings.collapsedGroups, isEmpty);
    });

    test('load decodes the stored collapsed group set', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => '交易,工具');
      await settings.load();
      expect(settings.collapsedGroups, {'交易', '工具'});
    });

    test('load drops empty segments on decode', () async {
      when(() => backend.read(key: any(named: 'key')))
          .thenAnswer((_) async => ',交易,,');
      await settings.load();
      expect(settings.collapsedGroups, {'交易'});
    });

    test('setCollapsed persists under the expected storage key', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      await settings.setCollapsed(const {'工具'});

      verify(() => backend.write(key: 'nav_collapsed_groups', value: '工具'))
          .called(1);
    });

    test('setCollapsed notifies listeners with the new set', () async {
      when(() => backend.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final fired = <Set<String>>[];
      settings.listenable
          .addListener(() => fired.add(settings.collapsedGroups));

      await settings.setCollapsed(const {'资产', '借贷'});

      expect(settings.collapsedGroups, {'资产', '借贷'});
      expect(fired, [
        {'资产', '借贷'}
      ]);
    });

    test('load is idempotent (second call is a no-op)', () async {
      var calls = 0;
      when(() => backend.read(key: any(named: 'key'))).thenAnswer((_) async {
        calls++;
        return '工具';
      });
      await settings.load();
      await settings.load();
      expect(calls, 1);
      expect(settings.collapsedGroups, {'工具'});
    });
  });
}
