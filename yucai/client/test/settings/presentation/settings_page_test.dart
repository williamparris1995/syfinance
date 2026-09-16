// Task 11 — TDD widget tests for the settings page (preferred currency +
// rate-sync interval). Drives SettingsPage through a mocked CurrencyBloc that
// emits currencies [CNY, USD, EUR] + preferred=CNY + interval=8, asserts the
// dropdown renders the current preferred code, and that selecting USD invokes
// AuthRemoteDataSource.updatePreferences('USD', 8) + reloads preferences.
//
// Task 12 D-currency — base currency picker tests: SettingsPage now also reads
// CurrencySettings (via getIt) for the base-currency row. The harness must
// register a fake CurrencySettings; tests assert the dropdown renders the
// current base (CNY · Chinese Yuan) and that selecting USD calls
// CurrencySettings.setBaseCurrency('USD') + surfaces a snackbar.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/notifications/app_exit_port.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

/// Fake BoundMarker — 未绑定(F21 清空入口按未绑定渲染;既有断言不涉及该行,
/// 仅满足页面 build 期的 getIt<BoundMarker> 解析)。
class _FakeBoundMarker extends Fake implements BoundMarker {
  @override
  Future<bool> isBound() async => false;
}

/// Fake CurrencySettings — fixed base code + records setBaseCurrency calls
/// (Task 12 D-currency picker). getBaseCurrency drives the FutureBuilder value
/// of the base dropdown; setBaseCurrency captures the code the user picked.
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

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  _FakeCurrencySettings(this._base) : _notifier = ValueNotifier<String>(_base);
  String _base;
  final List<String> setCalls = [];
  final ValueNotifier<String> _notifier;

  @override
  ValueListenable<String> get listenable => _notifier;

  @override
  String get value => _base;

  @override
  Future<String> getBaseCurrency() async => _base;

  @override
  Future<void> setBaseCurrency(String code) async {
    _base = code;
    setCalls.add(code);
    _notifier.value = code;
  }
}

/// Fake TraySettings(F22 窗口与提醒)— 默认 hide/minutes30,记录 setX 调用
/// (照 _FakeThemeSettings 范式:notifier 驱动 SegmentedButton 选中态;
/// F25 扩第四字段 showTrayAmounts,默认 true)。
class _FakeTraySettings extends Fake implements TraySettings {
  final ValueNotifier<TrayCloseBehavior> _close =
      ValueNotifier<TrayCloseBehavior>(TrayCloseBehavior.hide);
  final ValueNotifier<TrayScanInterval> _scan =
      ValueNotifier<TrayScanInterval>(TrayScanInterval.minutes30);
  final ValueNotifier<bool> _amounts = ValueNotifier<bool>(true);
  final List<TrayCloseBehavior> closeCalls = [];
  final List<TrayScanInterval> scanCalls = [];
  final List<bool> amountCalls = [];

  @override
  TrayCloseBehavior get closeBehavior => _close.value;

  @override
  ValueListenable<TrayCloseBehavior> get closeBehaviorListenable => _close;

  @override
  TrayScanInterval get scanInterval => _scan.value;

  @override
  ValueListenable<TrayScanInterval> get scanIntervalListenable => _scan;

  @override
  bool get showTrayAmounts => _amounts.value;

  @override
  ValueListenable<bool> get showTrayAmountsListenable => _amounts;

  @override
  Future<void> setCloseBehavior(TrayCloseBehavior behavior) async {
    closeCalls.add(behavior);
    _close.value = behavior;
  }

  @override
  Future<void> setScanInterval(TrayScanInterval interval) async {
    scanCalls.add(interval);
    _scan.value = interval;
  }

  @override
  Future<void> setShowTrayAmounts(bool show) async {
    amountCalls.add(show);
    _amounts.value = show;
  }
}

/// Fake AppExitPort(F22 页底退出按钮)— 仅计数 exitApp 调用,不真退进程
/// (真实现 TrayAppExit 会 exit(0) 杀掉测试运行器)。
class _FakeAppExitPort extends Fake implements AppExitPort {
  int exitCalls = 0;

  @override
  Future<void> exitApp() async => exitCalls++;
}

/// Minimal CurrencyBloc stub: holds a fixed state and records dispatched events
/// so the test can assert LoadPreferencesRequested was re-dispatched after an
/// update. Cannot use Fake (need add() to capture events).
class _StubCurrencyBloc extends Fake implements CurrencyBloc {
  _StubCurrencyBloc(this._state);
  final CurrencyState _state;
  final List<CurrencyEvent> dispatched = [];

  @override
  CurrencyState get state => _state;

  @override
  Stream<CurrencyState> get stream => Stream.value(_state);

  @override
  void add(CurrencyEvent event) => dispatched.add(event);
}

const _currencies = <Currency>[
  Currency(
      code: 'CNY',
      name: 'Chinese Yuan',
      symbol: '¥',
      exchangeRate: 7.8,
      isActive: true),
  Currency(
      code: 'USD',
      name: 'US Dollar',
      symbol: r'$',
      exchangeRate: 1.08,
      isActive: true),
  Currency(
      code: 'EUR',
      name: 'Euro',
      symbol: '€',
      exchangeRate: 1.0,
      isActive: true),
];

/// Harness: injects a mocked CurrencyBloc (fixed state) + registers a fake
/// CurrencySettings in getIt (Task 12 D-currency — the page reads it via
/// `getIt<CurrencySettings>()` at build time). Returns the fake so the test
/// can assert setBaseCurrency calls.
Widget _harness(
  CurrencyState state,
  AuthRemoteDataSource authRemote,
  _FakeCurrencySettings currencySettings, {
  AuthState? authState,
  TraySettings? traySettings,
  AppExitPort? appExitPort,
}) {
  final bloc = _StubCurrencyBloc(state);
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<CurrencySettings>()) {
    getIt.registerSingleton<CurrencySettings>(currencySettings);
  }
  // SettingsPage reads ThemeSettings from getIt (R8 F1 主题模式)。
  if (!getIt.isRegistered<ThemeSettings>()) {
    getIt.registerSingleton<ThemeSettings>(_FakeThemeSettings());
  }
  // SettingsPage reads TraySettings from getIt (F22 窗口与提醒)。
  if (!getIt.isRegistered<TraySettings>()) {
    getIt.registerSingleton<TraySettings>(traySettings ?? _FakeTraySettings());
  }
  // SettingsPage reads AppExitPort from getIt (F22 页底退出按钮;生产注册
  // 在 T4 bootstrap,测试先注册 fake 让按钮渲染)。
  if (!getIt.isRegistered<AppExitPort>()) {
    getIt.registerSingleton<AppExitPort>(appExitPort ?? _FakeAppExitPort());
  }
  // SettingsPage reads BoundMarker from getIt (F21 清空入口绑定态判定)。
  if (!getIt.isRegistered<BoundMarker>()) {
    getIt.registerSingleton<BoundMarker>(_FakeBoundMarker());
  }
  // SettingsPage reads AuthBloc (guest login card, R6) — provide a stub the
  // same way the production tree does (app.dart BlocProvider above router).
  // Default keeps the card hidden so pre-existing assertions are unchanged.
  final authBloc = _StubAuthBloc(authState ?? AuthInitial());
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<CurrencyBloc>.value(value: bloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: SettingsPage(authRemote: authRemote),
    ),
  );
}

/// Minimal AuthBloc stub: fixed state + single-value stream (mirrors
/// _StubCurrencyBloc; BlocBuilder reads state + stream only).
class _StubAuthBloc extends Fake implements AuthBloc {
  _StubAuthBloc(this._state);
  final AuthState _state;

  @override
  AuthState get state => _state;

  @override
  Stream<AuthState> get stream => Stream.value(_state);
}

void main() {
  final getIt = GetIt.instance;
  late _MockAuthRemote authRemote;
  late _FakeCurrencySettings currencySettings;

  setUp(() {
    authRemote = _MockAuthRemote();
    currencySettings = _FakeCurrencySettings('CNY');
    registerFallbackValue(const LoadPreferencesRequested());
  });

  tearDown(() {
    if (getIt.isRegistered<CurrencySettings>()) {
      getIt.unregister<CurrencySettings>();
    }
    if (getIt.isRegistered<BoundMarker>()) {
      getIt.unregister<BoundMarker>();
    }
    // F22:TraySettings/AppExitPort fake 记录调用数,须逐测试换新实例。
    if (getIt.isRegistered<TraySettings>()) {
      getIt.unregister<TraySettings>();
    }
    if (getIt.isRegistered<AppExitPort>()) {
      getIt.unregister<AppExitPort>();
    }
  });

  testWidgets('guest sees the login entry card; authenticated does not (R6)',
      (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 24,
      status: CurrencyStatus.loaded,
    );

    await t.pumpWidget(_harness(state, authRemote, currencySettings,
        authState: Guest()));
    await t.pump();
    expect(find.text('登录账号'), findsOneWidget);
    expect(find.text('绑定后可同步数据到服务器'), findsOneWidget);

    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pump();
    expect(find.text('登录账号'), findsNothing);
  });

  testWidgets('dropdown shows current preferred currency code (CNY)', (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // The DropdownButton's selected value renders as a Text widget containing
    // the preferred code (code + name format).
    expect(find.textContaining('CNY'), findsWidgets);
  });

  testWidgets('selecting USD calls updatePreferences(USD, 8) and reloads',
      (t) async {
    // F22 窗口与提醒区使页面超出默认 800x600 视口;拉高测试表面让货币
    // dropdown 可直接 tap(页面本身可滚动,断言语义不变)。
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    when(() => authRemote.updatePreferences(any<String>(), any<int>()))
        .thenAnswer((_) async {});

    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // Tap the currency dropdown to open the menu.
    await t.tap(find.byType(DropdownButton<String>).first);
    await t.pumpAndSettle();

    // Select the USD menu item.
    await t.tap(find.textContaining('USD').last);
    await t.pumpAndSettle();

    verify(() => authRemote.updatePreferences('USD', 8)).called(1);
  });

  testWidgets('selecting a new interval calls updatePreferences with new interval',
      (t) async {
    // F22 窗口与提醒区使页面超出默认视口;拉高测试表面(同上,语义不变)。
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    when(() => authRemote.updatePreferences(any<String>(), any<int>()))
        .thenAnswer((_) async {});

    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // The interval selector is the second DropdownButton<int>.
    final intervalDropdowns = find.byType(DropdownButton<int>);
    await t.tap(intervalDropdowns);
    await t.pumpAndSettle();

    // Pick 24h.
    await t.tap(find.text('24h').last);
    await t.pumpAndSettle();

    verify(() => authRemote.updatePreferences('CNY', 24)).called(1);
  });

  testWidgets('renders in a surface card (御财 token)', (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // The page content sits in a Container whose decoration color is surface.
    final surfaceCards = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).color == AppColors.surface,
    );
    expect(surfaceCards, findsWidgets);
  });

  // Task 12 D-currency — base currency picker tests. The page renders a third
  // preference row whose dropdown reads CurrencySettings.getBaseCurrency()
  // (FutureBuilder) for the current value and calls setBaseCurrency on change.
  // Currencies list feeds the items; switching → persist + snackbar. Brief
  // specifies "切换 → setBaseCurrency + 刷新".
  testWidgets(
      'Task 12 D-currency: base dropdown shows current base (CNY · Chinese Yuan)',
      (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // The base dropdown is the second DropdownButton<String>. Its FutureBuilder
    // resolves base='CNY' → selected item renders 'CNY · Chinese Yuan'.
    final baseDropdown = find.byType(DropdownButton<String>).at(1);
    expect(
      find.descendant(
        of: baseDropdown,
        matching: find.textContaining('CNY · Chinese Yuan'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'Task 12 D-currency: selecting USD calls setBaseCurrency(USD) + snackbar',
      (t) async {
    // F22 窗口与提醒区使页面超出默认视口;拉高测试表面(同上,语义不变)。
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // Open the base-currency dropdown (second DropdownButton<String>).
    await t.tap(find.byType(DropdownButton<String>).at(1));
    await t.pumpAndSettle();

    // Pick the USD menu item. Menu items use the same 'code · name' format.
    await t.tap(find.textContaining('USD · US Dollar').last);
    await t.pumpAndSettle();

    // Persisted via CurrencySettings.setBaseCurrency('USD').
    expect(currencySettings.setCalls, ['USD']);
    // Brief: 刷新 (refresh) — surfaced as a snackbar telling the user the new
    // base takes effect on next visit to performance/detail.
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('本位币已更新'), findsOneWidget);
  });

  // ── F22 T2:窗口与提醒区 + 页底退出按钮 ──────────────────────────
  // 视觉契约 ui/settings-window-reminders.html:区标题、两行 SegmentedButton
  // (默认 hide + 30 分钟)、hint 文案逐字、页底「退出御财」soft destructive。

  testWidgets('F22: 窗口与提醒区渲染(区标题/两行标签/hint 文案逐字)', (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // 区标题(brief:置于「数据」区之后,文案照原型)。
    expect(find.text('窗口与提醒'), findsOneWidget);
    // 行 1:关闭按钮行为 + hint。
    expect(find.text('关闭按钮行为'), findsOneWidget);
    expect(find.text('点窗口 ✕ 时:隐藏到托盘继续运行,或直接退出'), findsOneWidget);
    // 行 2:提醒检查频率 + hint。
    expect(find.text('提醒检查频率'), findsOneWidget);
    expect(find.text('到期提醒与自动记账的定时扫描间隔;数据变更时总会即时检查'),
        findsOneWidget);
    // 分段文案:行为两段 + 频率三段。
    expect(find.text('隐藏到托盘'), findsOneWidget);
    expect(find.text('退出程序'), findsOneWidget);
    expect(find.text('15 分钟'), findsOneWidget);
    expect(find.text('30 分钟'), findsOneWidget);
    expect(find.text('60 分钟'), findsOneWidget);
  });

  testWidgets('F22: 关闭按钮行为默认隐藏到托盘,切换调 setCloseBehavior(exit)',
      (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    final tray = _FakeTraySettings();
    await t.pumpWidget(_harness(state, authRemote, currencySettings,
        traySettings: tray));
    await t.pumpAndSettle();

    // 初值 = hide(TraySettings 默认),选中态经 closeBehaviorListenable 驱动。
    final segFinder = find.byType(SegmentedButton<TrayCloseBehavior>);
    expect(
      t.widget<SegmentedButton<TrayCloseBehavior>>(segFinder).selected,
      {TrayCloseBehavior.hide},
    );

    // 切到「退出程序」→ setCloseBehavior(exit),高亮随 listenable 刷新。
    await t.tap(find.text('退出程序'));
    await t.pumpAndSettle();
    expect(tray.closeCalls, [TrayCloseBehavior.exit]);
    expect(
      t.widget<SegmentedButton<TrayCloseBehavior>>(segFinder).selected,
      {TrayCloseBehavior.exit},
    );
  });

  testWidgets('F22: 提醒检查频率默认 30 分钟,切换调 setScanInterval(minutes60)',
      (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    final tray = _FakeTraySettings();
    await t.pumpWidget(_harness(state, authRemote, currencySettings,
        traySettings: tray));
    await t.pumpAndSettle();

    // 初值 = minutes30(TraySettings 默认)。
    final segFinder = find.byType(SegmentedButton<TrayScanInterval>);
    expect(
      t.widget<SegmentedButton<TrayScanInterval>>(segFinder).selected,
      {TrayScanInterval.minutes30},
    );

    // 切到「60 分钟」→ setScanInterval(minutes60)。
    await t.tap(find.text('60 分钟'));
    await t.pumpAndSettle();
    expect(tray.scanCalls, [TrayScanInterval.minutes60]);
    expect(
      t.widget<SegmentedButton<TrayScanInterval>>(segFinder).selected,
      {TrayScanInterval.minutes60},
    );
  });

  testWidgets('F22: 页底退出按钮点击即时调 AppExitPort.exitApp(无确认弹窗)',
      (t) async {
    // 按钮在页面最底(所有 card 之后):拉高测试表面让可直接 tap。
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    final exitPort = _FakeAppExitPort();
    await t.pumpWidget(_harness(state, authRemote, currencySettings,
        appExitPort: exitPort));
    await t.pumpAndSettle();

    // 按钮存在(全宽 soft destructive,含退出图标)。
    expect(find.text('退出御财'), findsOneWidget);
    expect(find.byIcon(LucideIcons.logOut), findsOneWidget);

    // 点击 → 即时无确认:直接触发 exitApp,不弹 AlertDialog。
    await t.tap(find.text('退出御财'));
    await t.pump();
    expect(exitPort.exitCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
  });

  // ── F25 T4:「托盘显示金额」Switch 行(FR-3 隐私开关) ─────────────
  testWidgets('F25: 托盘显示金额行渲染于窗口与提醒区,默认开', (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    // 行标签 + hint(窗口与提醒区第三行)。
    expect(find.text('托盘显示金额'), findsOneWidget);
    expect(find.text('托盘菜单顶部的今日收支与本月结余'), findsOneWidget);
    // Switch 初值 = true(隐私默认显示,spec grill 定案)。
    expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('F25: 切换托盘显示金额 → setShowTrayAmounts(false) 持久化',
      (t) async {
    // F25 行在窗口与提醒区第三行:拉高测试表面让 Switch 可直接 tap
    // (同 F22 既有测试手法,断言语义不变)。
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    final tray = _FakeTraySettings();
    await t.pumpWidget(_harness(state, authRemote, currencySettings,
        traySettings: tray));
    await t.pumpAndSettle();

    // 切到关 → setShowTrayAmounts(false)(TraySettings 持久化 + listenable
    // 即时驱动托盘菜单重设)。
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(tray.amountCalls, [false]);
    expect(t.widget<Switch>(find.byType(Switch)).value, isFalse);

    // 再切回开。
    await t.tap(find.byType(Switch));
    await t.pumpAndSettle();
    expect(tray.amountCalls, [false, true]);
    expect(t.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

/// 「关于与更新」卡(验收补充 2026-09-16):版本行 + 检查更新入口。
group('关于与更新卡 (验收补充)', () {
  testWidgets('版本行与检查更新入口渲染;点击 → auto_updater channel', (t) async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.leanflutter.plugins/auto_updater'),
      (call) async {
        calls.add(call);
        return null;
      },
    );
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 24,
      status: CurrencyStatus.loaded,
    );
    // 卡在页底:拉高视口(F25 先例),否则检查更新行在屏外 tap 不到。
    t.view.physicalSize = const Size(800, 1800);
    t.view.devicePixelRatio = 1.0;
    await t.pumpWidget(_harness(state, authRemote, currencySettings));
    await t.pumpAndSettle();

    expect(find.text('关于与更新'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    // 版本行:PackageInfo 在测试环境解析出 '1.0.0'/'unknown' 均可,断言含 v 或 --。
    expect(
      find.textContaining(RegExp(r'御财 v|--')), findsOneWidget);

    await t.tap(find.text('检查更新'));
    await t.pump();
    expect(calls.map((c) => c.method), contains('checkForUpdates'));
  });
});
}
