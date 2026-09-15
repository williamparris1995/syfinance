
// Feature J — settings archive entries existence (lightweight widget test).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

class _StubCurrencyBloc extends Fake implements CurrencyBloc {
  @override
  CurrencyState get state => const CurrencyState();

  @override
  Stream<CurrencyState> get stream => const Stream.empty();
}
class _StubAuthBloc extends Fake implements AuthBloc {
  @override
  AuthState get state => Guest();

  @override
  Stream<AuthState> get stream => const Stream.empty();
}

void main() {
  testWidgets('settings shows archive export/import entries', (t) async {
    final authRemote = _MockAuthRemote();
    final settings = _FakeCurrencySettings();
    final gi = GetIt.instance;
    if (!gi.isRegistered<CurrencySettings>()) {
      gi.registerSingleton<CurrencySettings>(settings);
    }
    if (!gi.isRegistered<AuthRemoteDataSource>()) {
      gi.registerSingleton<AuthRemoteDataSource>(authRemote);
    }
    // SettingsPage reads ThemeSettings from getIt (R8 F1 主题模式)。
    if (!gi.isRegistered<ThemeSettings>()) {
      gi.registerSingleton<ThemeSettings>(_FakeThemeSettings());
    }
    // SettingsPage reads TraySettings from getIt (F22 窗口与提醒)。
    if (!gi.isRegistered<TraySettings>()) {
      gi.registerSingleton<TraySettings>(_FakeTraySettings());
    }
    // SettingsPage reads BoundMarker from getIt (F21 清空入口绑定态判定)。
    if (!gi.isRegistered<BoundMarker>()) {
      gi.registerSingleton<BoundMarker>(_FakeBoundMarker());
    }
    addTearDown(gi.reset);

    await t.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _StubAuthBloc()),
          BlocProvider<CurrencyBloc>.value(value: _StubCurrencyBloc()),
        ],
        child: SettingsPage(authRemote: authRemote),
      ),
    ));
    await t.pump();

    expect(find.text('导出存档'), findsOneWidget);
    expect(find.text('导入存档'), findsOneWidget);
  });
}

class _FakeThemeSettings extends Fake implements ThemeSettings {
  final ValueNotifier<ThemeMode> _notifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  @override
  ValueListenable<ThemeMode> get listenable => _notifier;
  @override
  ThemeMode get value => ThemeMode.system;
  @override
  Future<void> load() async {}
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
}

/// Fake TraySettings(F22 窗口与提醒)— 满足页面 build 期 getIt 解析与
/// SegmentedButton/Switch 的 listenable 读取(默认 hide/minutes30/显示金额)。
class _FakeTraySettings extends Fake implements TraySettings {
  final ValueNotifier<TrayCloseBehavior> _close =
      ValueNotifier<TrayCloseBehavior>(TrayCloseBehavior.hide);
  final ValueNotifier<TrayScanInterval> _scan =
      ValueNotifier<TrayScanInterval>(TrayScanInterval.minutes30);
  final ValueNotifier<bool> _amounts = ValueNotifier<bool>(true);

  @override
  ValueListenable<TrayCloseBehavior> get closeBehaviorListenable => _close;

  @override
  ValueListenable<TrayScanInterval> get scanIntervalListenable => _scan;

  @override
  ValueListenable<bool> get showTrayAmountsListenable => _amounts;
}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  final ValueNotifier<String> _notifier = ValueNotifier<String>('CNY');
  @override
  ValueListenable<String> get listenable => _notifier;
  @override
  String get value => 'CNY';
}

/// Fake BoundMarker — 未绑定(F21 清空入口按未绑定渲染,既有断言不涉及)。
class _FakeBoundMarker extends Fake implements BoundMarker {
  @override
  Future<bool> isBound() async => false;
}
