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
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockLogin extends Mock implements LoginUseCase {}
class _MockRegister extends Mock implements RegisterUseCase {}
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
    // HomePage reads CurrencySettings from getIt (cross-page refresh listener
    // in initState); register a fake so the home branch resolves.
    getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings());

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
