// Task 11 (holding-D) — widget tests for HomePage _NetWorthCard.
//
// HomePage reads NetWorthDataSource + CurrencySettings from getIt (both
// @LazySingleton in production), so we register fakes before pumping.
// AccountBloc is provided via BlocProvider with a mock AccountRepository
// (empty account list — net worth no longer folds account balances; it comes
// from the DS).
//
// Coverage:
// - success (CNY base): renders 折算后 net worth (¥ + grouped) + 总资产/总负债
// - success (USD base): symbol switches to $ (非硬编码 ¥)
// - error: shows 加载失败 (graceful, not crash)
//
// _NetWorthCard is private; we drive it via the public HomePage.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';

class _MockLogin extends Mock implements LoginUseCase {}
class _MockRegister extends Mock implements RegisterUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}

/// Fake NetWorthDataSource — overrides getNetWorth to return a fixed view or
/// throw. (Fake, not Mock: getNetWorth is a real method we want to stub via an
/// injected callback.)
class _FakeNetWorthDs extends Fake implements NetWorthDataSource {
  _FakeNetWorthDs(this._result);
  final Future<NetWorthView> Function() _result;

  @override
  Future<NetWorthView> getNetWorth({required String baseCurrency}) =>
      _result();
}

/// Fake CurrencySettings — returns a fixed base currency code.
class _FakeCurrencySettings extends Fake implements CurrencySettings {
  _FakeCurrencySettings(this._base);
  final String _base;
  @override
  Future<String> getBaseCurrency() async => _base;
}

class _MockAccountRepo extends Mock implements AccountRepository {}

/// AuthBloc seeded Authenticated (HomePage watches state for display name).
class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockLogin(), _MockRegister(), _MockProfile(), _MockLogout()) {
    emit(Authenticated(_user));
  }
}

final _user = User(
  id: 'u1',
  tenantId: 't1',
  email: 't@example.com',
  displayName: '测试用户',
  avatarUrl: '',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

NetWorthView _view({
  int assets = 1200000, // ¥12,000.00
  int liabilities = 300000, // ¥3,000.00
  String currency = 'CNY',
}) {
  final net = assets - liabilities;
  return NetWorthView(
    totalAssetsCents: assets,
    totalLiabilitiesCents: liabilities,
    netWorthCents: net,
    currency: currency,
  );
}

Widget _harness({
  required Future<NetWorthView> Function() netWorthResult,
  required String baseCurrency,
}) {
  final getIt = GetIt.instance;
  getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs(netWorthResult));
  getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings(baseCurrency));

  final accountRepo = _MockAccountRepo();
  when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([]));

  final accountBloc = AccountBloc(
    ListAccountsUseCase(accountRepo),
    CreateAccountUseCase(accountRepo),
    DeleteAccountUseCase(accountRepo),
    GetAccountUseCase(accountRepo),
    UpdateAccountUseCase(accountRepo),
  );

  final authBloc = _SeededAuthedBloc();
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<AccountBloc>.value(value: accountBloc),
      ],
      child: const HomePage(),
    ),
  );
}

/// Finds a widget whose rendered text (plain Text or RichText.toPlainText)
/// contains [needle]. find.textContaining does not reliably traverse nested
/// TextSpans in this flutter_test version, so we check RichText explicitly.
Finder _textContaining(String needle) => find.byWidgetPredicate(
      (w) {
        if (w is Text) {
          return (w.data ?? '').contains(needle) ||
              (w.textSpan?.toPlainText() ?? '').contains(needle);
        }
        if (w is RichText) {
          return w.text.toPlainText().contains(needle);
        }
        return false;
      },
    );

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    getIt.reset();
  });

  tearDown(() {
    if (getIt.isRegistered<NetWorthDataSource>()) {
      getIt.unregister<NetWorthDataSource>();
    }
    if (getIt.isRegistered<CurrencySettings>()) {
      getIt.unregister<CurrencySettings>();
    }
  });

  testWidgets(
      'success (CNY base): renders 折算后 net worth ¥9,000.00 + 总资产/总负债',
      (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    // net worth = assets(1200000) − liab(300000) = 900000 cents = ¥9,000.00
    // grouped → '9,000' (整数部分),fen '.00'。
    expect(_textContaining('9,000'), findsWidgets);
    // base 符号 ¥(非硬编码 — 来自 NetWorthView.currency=CNY → currencySymbol)。
    expect(_textContaining('¥'), findsWidgets);
    // 资产分解 4 卡:流动资产 / 总负债 label + 折算后金额。
    expect(find.text('流动资产'), findsOneWidget);
    expect(find.text('总负债'), findsOneWidget);
    // 流动资产 = ¥12,000.00(1200000 cents)。
    expect(_textContaining('12,000'), findsWidgets);
  });

  testWidgets('success (USD base): symbol switches to \$ (非硬编码 ¥)',
      (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(currency: 'USD'),
      baseCurrency: 'USD',
    ));
    await t.pumpAndSettle();

    // currency=USD → currencySymbol(USD) = '$'(非 ¥)。
    expect(_textContaining(r'$'), findsWidgets);
    // 不应出现裸 ¥(硬编码检查)。
    expect(find.text('¥'), findsNothing);
  });

  testWidgets('error: shows 加载失败 (graceful, no crash)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => throw Exception('rpc unavailable'),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    // FutureBuilder error → _NetWorthCard error=true → '加载失败'。
    expect(_textContaining('加载失败'), findsWidgets);
  });
}
