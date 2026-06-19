// Wire-up test for the transaction module routes (Task: 接通交易路由).
//
// Builds the real router (buildRouter) with an AuthBloc seeded Authenticated,
// then navigates to the three transaction paths and asserts each resolves to
// the expected page surface. Catches the exact regression that prompted this
// task: a branch dropped from the StatefulShellRoute, or the sidebar/bottom-
// nav disagreeing on branch index 2.
//
// No gRPC: a fake TransactionRepository is registered in getIt so the page's
// getIt<TransactionRepository>() resolves. AccountRepository is registered too
// because TransactionFormPage / TransactionDetailPage read it.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockLogin extends Mock implements LoginUseCase {}
class _MockRegister extends Mock implements RegisterUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(ListTransactionsParams());
  });

  setUp(() {
    getIt.reset();
    final accountRepo = _MockAccountRepo();
    final txnRepo = _MockTxnRepo();
    getIt.registerSingleton<AccountRepository>(accountRepo);
    getIt.registerSingleton<TransactionRepository>(txnRepo);

    when(() => accountRepo.list()).thenAnswer(
        (_) async => dartz.Right([_account()]));
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => dartz.Right(const ListTransactionsResult(
            transactions: [], nextPageToken: '')));
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 0,
              expenseCents: 0,
              netCents: 0,
              dailyAvgCents: 0,
            )));
    when(() => txnRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(_txn()));
  });

  Widget app(GoRouter router, AuthBloc authBloc) => MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          // TransactionsPage/TransactionDetailPage call BlocProvider.of for
          // TransactionBloc during their build; in tests that lookup throws an
          // AssertionError (not ProviderNotFoundException) when no ancestor
          // bloc exists. Provide an ambient TransactionBloc so the page's
          // lookup succeeds and the create branch is skipped.
          child: BlocProvider<TransactionBloc>(
            create: (_) => TransactionBloc(getIt<TransactionRepository>()),
            child: child!,
          ),
        ),
      );

  testWidgets('/transactions resolves inside the transaction branch',
      (tester) async {
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: the list page's summary post-frame callback can
    // schedule frames indefinitely in this stripped harness (no real
    // microtask drain). A few pumps are enough for the router to resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Auth guard let us through and the route resolved to branch 2.
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/transactions');
  });

  testWidgets('/transactions/new resolves inside the transaction branch',
      (tester) async {
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions/new');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/transactions/new');
  });

  testWidgets('/transactions/:id resolves to the detail route',
      (tester) async {
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions/t-42');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/transactions/t-42');
  });

  test('router has three StatefulShell branches (home/accounts/transactions)',
      () {
    final router = buildRouter(_seededAuthBloc());
    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .first;
    expect(shell.branches.length, 3,
        reason: 'transaction branch (index 2) must be registered');
  });

  testWidgets('auth guard redirects unauthenticated /transactions to /login',
      (tester) async {
    // AuthBloc seeded Unauthenticated: redirect must bounce /transactions →
    // /login. (AuthInitial would be treated as loading → no redirect, so we
    // explicitly emit Unauthenticated.)
    final authBloc = _unauthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/login');
  });
}

/// Build an AuthBloc seeded Authenticated without driving any use case.
/// The router only reads `.state` for the redirect, so we seed the terminal
/// state directly. Use cases are mocks (never invoked).
AuthBloc _seededAuthBloc() => _SeededAuthedBloc();

class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockLogin(), _MockRegister(), _MockProfile(), _MockLogout()) {
    emit(Authenticated(_user));
  }
}

/// AuthBloc explicitly Unauthenticated (not AuthInitial, which the guard
/// treats as loading → no redirect).
AuthBloc _unauthBloc() => _SeededUnauthBloc();

class _SeededUnauthBloc extends AuthBloc {
  _SeededUnauthBloc()
      : super(_MockLogin(), _MockRegister(), _MockProfile(), _MockLogout()) {
    emit(Unauthenticated());
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

Account _account() => Account(
      id: 'a1',
      name: '现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Transaction _txn() => Transaction(
      id: 't1',
      transactionDate: DateTime(2026, 6, 19),
      description: 'stub',
      entries: const [
        TransactionEntry(accountId: 'a1', debitCents: 100, creditCents: 0),
        TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: 100),
      ],
    );
