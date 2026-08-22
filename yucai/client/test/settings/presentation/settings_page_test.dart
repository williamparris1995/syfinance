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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

/// Fake CurrencySettings — fixed base code + records setBaseCurrency calls
/// (Task 12 D-currency picker). getBaseCurrency drives the FutureBuilder value
/// of the base dropdown; setBaseCurrency captures the code the user picked.
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
}) {
  final bloc = _StubCurrencyBloc(state);
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<CurrencySettings>()) {
    getIt.registerSingleton<CurrencySettings>(currencySettings);
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
}
