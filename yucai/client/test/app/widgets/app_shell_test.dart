// Widget test for AppShell's _TopBar frosted-glass treatment (Task 3:
// topbar 半透明米色 + 毛玻璃 blur(10)).
//
// _TopBar is private, so we pump the real router (buildRouter) — which mounts
// AppShell with a genuine StatefulNavigationShell — and assert BackdropFilter
// is present in the tree. This mirrors the harness in router_test.dart.
//
// No gRPC: the branch pages (HomePage / AccountsPage) read AccountBloc and
// TransactionBloc from getIt, so we register minimal mock-driven instances
// before pumping. AuthBloc is seeded Authenticated to clear the auth guard.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  final ValueNotifier<String> _notifier = ValueNotifier<String>('CNY');
  @override
  ValueListenable<String> get listenable => _notifier;
  @override
  String get value => 'CNY';
  @override
  Future<String> getBaseCurrency() async => 'CNY';
}

class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockGoalRepo extends Mock implements GoalRepository {}

/// Fake NetWorthDataSource — HomePage _loadNetWorth reads getIt<NetWorthDataSource>
/// at initState (68508b2); register a fake so /home resolves. Mirrors router_test.
class _FakeNetWorthDs extends Fake implements NetWorthDataSource {
  @override
  Future<NetWorthView> getNetWorth({required String baseCurrency}) async =>
      NetWorthView(
        totalAssetsCents: 0,
        totalLiabilitiesCents: 0,
        netWorthCents: 0,
        currency: 'CNY',
      );
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() {
    getIt.reset();
    final accountRepo = _MockAccountRepo();
    final txnRepo = _MockTxnRepo();
    final debtRepo = _MockDebtRepo();
    final holdingRepo = _MockHoldingRepo();
    final budgetRepo = _MockBudgetRepo();
    final goalRepo = _MockGoalRepo();
    getIt.registerSingleton<AccountRepository>(accountRepo);
    getIt.registerSingleton<TransactionRepository>(txnRepo);
    // HomePage reads CurrencySettings from getIt (cross-page refresh listener
    // in initState); register a fake so the home branch resolves.
    getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings());
    // HomePage 依赖(占位修复 68508b2 + P0-1 摘要卡):注册 NetWorthDataSource +
    // Debt/Holding/Budget/Goal Repository,stub 返空/Left → 各卡隐藏或空态。
    getIt.registerSingleton<DebtRepository>(debtRepo);
    getIt.registerSingleton<HoldingRepository>(holdingRepo);
    getIt.registerSingleton<BudgetRepository>(budgetRepo);
    getIt.registerSingleton<GoalRepository>(goalRepo);
    getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs());

    // AccountBloc is constructed by the route via getIt<AccountBloc>() (factory
    // in production via injectable). Register a factory here that wires the
    // real bloc to mock use cases backed by the mocked AccountRepository.
    getIt.registerFactory<AccountBloc>(() => AccountBloc(
          ListAccountsUseCase(accountRepo),
          CreateAccountUseCase(accountRepo),
          DeleteAccountUseCase(accountRepo),
          GetAccountUseCase(accountRepo),
          UpdateAccountUseCase(accountRepo),
        ));

    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right([]));
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Right(
            ListTransactionsResult(transactions: [], nextPageToken: '')));
    // HomePage _loadSummaryCards(summary/budget/goal)+ _UpcomingPaymentsPanel
    // + _AssetAllocationPanel 读这些 repo;stub 返零值/空/Left → 卡隐藏或空态。
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async =>
            const dartz.Right(MonthlySummary(year: 2026, month: 1)));
    when(() => debtRepo.upcomingPayments(any()))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => holdingRepo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => budgetRepo.getBudgetByMonth(any()))
        .thenAnswer((_) async => const dartz.Left(ServerFailure('not found')));
    when(() => goalRepo.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) async => const dartz.Right([]));
  });

  testWidgets('AppShell topbar uses BackdropFilter for frosted glass',
      (tester) async {
    final authBloc = _SeededAuthedBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>()),
          child: child!,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // OD .topbar = backdrop-filter:blur(10px). AppShell mounts _TopBar for
    // every protected route; it must now render a BackdropFilter.
    expect(find.byType(BackdropFilter), findsWidgets);
  });
}

class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout()) {
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
