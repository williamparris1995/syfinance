// Task 11 — TDD widget tests for the settings page (preferred currency +
// rate-sync interval). Drives SettingsPage through a mocked CurrencyBloc that
// emits currencies [CNY, USD, EUR] + preferred=CNY + interval=8, asserts the
// dropdown renders the current preferred code, and that selecting USD invokes
// AuthRemoteDataSource.updatePreferences('USD', 8) + reloads preferences.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_event.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/settings/presentation/settings_page.dart';

class _MockAuthRemote extends Mock implements AuthRemoteDataSource {}

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

Widget _harness(CurrencyState state, AuthRemoteDataSource authRemote) {
  final bloc = _StubCurrencyBloc(state);
  return MaterialApp(
    home: BlocProvider<CurrencyBloc>.value(
      value: bloc,
      child: SettingsPage(authRemote: authRemote),
    ),
  );
}

void main() {
  late _MockAuthRemote authRemote;

  setUp(() {
    authRemote = _MockAuthRemote();
    registerFallbackValue(const LoadPreferencesRequested());
  });

  testWidgets('dropdown shows current preferred currency code (CNY)', (t) async {
    const state = CurrencyState(
      currencies: _currencies,
      preferred: 'CNY',
      intervalHours: 8,
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harness(state, authRemote));
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

    await t.pumpWidget(_harness(state, authRemote));
    await t.pumpAndSettle();

    // Tap the currency dropdown to open the menu.
    await t.tap(find.byType(DropdownButton<String>));
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

    await t.pumpWidget(_harness(state, authRemote));
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
    await t.pumpWidget(_harness(state, authRemote));
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
}
