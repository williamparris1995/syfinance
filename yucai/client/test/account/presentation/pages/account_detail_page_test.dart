// Task 6.1 — TDD widget test for AccountDetailPage 占位 → 真实.
//
// Asserts the placeholder surfaces are replaced by real transaction-module
// wiring:
//   - 「记一笔」/「转账」 AppBar buttons are ENABLED (tappable) and push the
//     TransactionFormPage (no more 🔒 disabled).
//   - 「近期交易」 panel renders the account-scoped transaction list from
//     TransactionBloc.loadByAccount (no more "待 Transaction 模块接入").
//   - 「收支统计」 4 cards render the MonthlySummary(accountId) values
//     (本月收入 / 本月支出 / 净值变动 / 交易数) — no more "—/待交易模块".
//   - 「快捷操作」 记一笔 / 转账 are activated (enabled).
//
// Both blocs are wired via BlocProvider with a fake repo; no DI / no gRPC.
// Mirrors transactions_page_test.dart harness shape.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _FakeTxnRepo extends Mock implements TransactionRepository {}

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

Account _account({AccountStatus status = AccountStatus.active}) => Account(
      id: 'a1',
      name: '现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 100000,
      ownership: Ownership.personal,
      status: status,
    );

Transaction _txn(String id, DateTime date, {int amount = 5000}) {
  return Transaction(
    id: id,
    transactionDate: date,
    description: '交易 $id',
    entries: [
      TransactionEntry(accountId: 'a1', debitCents: amount, creditCents: 0),
      TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: amount),
    ],
  );
}

Widget _harness({required Widget child}) {
  return MaterialApp(home: child);
}

void main() {
  late _MockAccountRepo accountRepo;
  late _FakeTxnRepo txnRepo;

  tearDown(() {
    GetIt.instance.reset();
  });

  setUp(() {
    accountRepo = _MockAccountRepo();
    txnRepo = _FakeTxnRepo();
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(
      const UpdateAccountParams(id: 'a1', version: 1),
    );
    // Register both repos in getIt so TransactionFormPage (pushed by
    // _recordTxn) can resolve them when building its own bloc.
    GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
    GetIt.instance.registerSingleton<TransactionRepository>(txnRepo);

    // Account detail page emits GetAccountRequested on initState.
    when(() => accountRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(_account()));
    // list is invoked by AccountFormPage if a navigation opens it; stub anyway.
    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right([_account()]));

    // Transaction list scoped to this account.
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
              _txn('t1', DateTime(2026, 6, 19)),
              _txn('t2', DateTime(2026, 6, 18)),
            ], nextPageToken: '')));
    // MonthlySummary scoped to this account (Task 5.1 accountId scope).
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 123456,
              expenseCents: 78900,
              netCents: 44556,
              dailyAvgCents: 1481,
            )));
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final listUc = _MockList();
    final createUc = _MockCreate();
    final deleteUc = _MockDelete();
    final getUc = _MockGet();
    final updateUc = _MockUpdate();
    when(() => getUc.call(any()))
        .thenAnswer((_) async => dartz.Right(_account()));

    await tester.pumpWidget(_harness(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AccountBloc>(
            create: (_) {
              final b =
                  AccountBloc(listUc, createUc, deleteUc, getUc, updateUc);
              b.add(const GetAccountRequested('a1'));
              return b;
            },
          ),
          BlocProvider<TransactionBloc>(
            create: (_) {
              final b = TransactionBloc(txnRepo);
              // account-scoped list + summary (Task 6.1 wiring the page does
              // on initState — emitted here so the harness mirrors it).
              b.add(const LoadTransactionsRequested(
                  filter: TxnFilterState(accountId: 'a1')));
              b.add(LoadSummaryRequested(
                  year: DateTime.now().year,
                  month: DateTime.now().month,
                  accountId: 'a1'));
              return b;
            },
          ),
        ],
        child: const AccountDetailPage(id: 'a1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('「记一笔」按钮 enabled (placeholder 🔒 removed)',
      (tester) async {
    await pumpPage(tester);

    // Active account → button label has no 🔒.
    expect(find.text('记一笔🔒'), findsNothing);
    // AppBar 「记一笔」 TextButton is enabled (its onPressed != null).
    final btn = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('记一笔').first,
        matching: find.byType(TextButton),
      ),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('「转账」按钮 enabled (placeholder 🔒 removed)',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('转账🔒'), findsNothing);
    final btn = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('转账').first,
        matching: find.byType(TextButton),
      ),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('「近期交易」 panel renders the account-scoped transactions',
      (tester) async {
    await pumpPage(tester);

    // Placeholder text replaced.
    expect(find.text('待 Transaction 模块接入'), findsNothing);
    // Both stubbed transactions render.
    expect(find.text('交易 t1'), findsOneWidget);
    expect(find.text('交易 t2'), findsOneWidget);
  });

  testWidgets('「收支统计」 4 cards render the account-scoped MonthlySummary',
      (tester) async {
    await pumpPage(tester);

    // Placeholder replaced.
    expect(find.text('待交易模块'), findsNothing);
    // incomeCents 123456 → ¥1,234.56 ; expenseCents 78900 → ¥789.00 ;
    // netCents 44556 → ¥445.56. Card count of transactions = 2.
    expect(find.text('¥1,234.56'), findsOneWidget);
    expect(find.text('¥789.00'), findsOneWidget);
    expect(find.text('¥445.56'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('「快捷操作」 记一笔 / 转账 are activated (enabled)',
      (tester) async {
    await pumpPage(tester);

    // Quick-action labels no longer carry the 「（待交易模块）」 placeholder.
    expect(find.textContaining('记一笔（待交易模块）'), findsNothing);
    expect(find.textContaining('转账（待交易模块）'), findsNothing);
    // Activated labels render.
    expect(find.text('记一笔'), findsWidgets);
    expect(find.text('转账'), findsWidgets);
  });

  testWidgets('tapping 记一笔 (AppBar) pushes TransactionFormPage',
      (tester) async {
    await pumpPage(tester);

    // Two 「记一笔」 surfaces exist (AppBar + 快捷操作 card). Tap the AppBar
    // one by scoping to AppBar descendants.
    final btn = find.descendant(
      of: find.byType(AppBar),
      matching: find.ancestor(
        of: find.text('记一笔'),
        matching: find.byType(TextButton),
      ),
    );
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);
    await tester.tap(btn, warnIfMissed: false);
    await tester.pumpAndSettle();

    // A new route was pushed: the form page is on screen.
    expect(find.byType(TransactionFormPage), findsOneWidget);
  });

  testWidgets('archived account keeps 记一笔 / 转账 disabled (no write ops)',
      (tester) async {
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Right(ListTransactionsResult(transactions: [])));
    when(() => accountRepo.getById(any())).thenAnswer(
        (_) async => dartz.Right(_account(status: AccountStatus.archived)));

    final getUc = _MockGet();
    when(() => getUc.call(any()))
        .thenAnswer((_) async => dartz.Right(_account(status: AccountStatus.archived)));
    final listUc = _MockList();
    final createUc = _MockCreate();
    final deleteUc = _MockDelete();
    final updateUc = _MockUpdate();

    await tester.pumpWidget(_harness(
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AccountBloc>(
            create: (_) {
              final b =
                  AccountBloc(listUc, createUc, deleteUc, getUc, updateUc);
              b.add(const GetAccountRequested('a1'));
              return b;
            },
          ),
          BlocProvider<TransactionBloc>(
            create: (_) {
              final b = TransactionBloc(txnRepo);
              b.add(const LoadTransactionsRequested(
                  filter: TxnFilterState(accountId: 'a1')));
              b.add(LoadSummaryRequested(
                  year: DateTime.now().year,
                  month: DateTime.now().month,
                  accountId: 'a1'));
              return b;
            },
          ),
        ],
        child: const AccountDetailPage(id: 'a1'),
      ),
    ));
    await tester.pumpAndSettle();

    // Archived → AppBar record/transfer buttons are removed entirely.
    expect(find.text('记一笔'), findsNothing);
    expect(find.text('转账'), findsNothing);
  });
}
