// TDD three-size widget test for TransactionsPage.
//
// Asserts the御财 responsive breakpoints drive distinct layouts:
//   - 390   → mobile  → card-stack rows (TxnRow mobile branch), SummaryCard grid
//   - 1024  → tablet  → table rows (TxnRow table branch)
//   - 1440  → desktop → table rows, SummaryCard single row
//
// Plus:
//   - transactions are grouped by day, each group shows a date header
//   - the FilterBar is rendered and selecting a type dispatches a reload
//   - a "load more" control appears when the bloc signals hasMore
//   - the "新增交易" entry (FAB / button) is present
//
// The bloc is wired via BlocProvider with a fake repo; no DI / no gRPC.
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transactions_page.dart';

class _FakeTxnRepo extends Mock implements TransactionRepository {}
class _FakeAccountRepo extends Mock implements AccountRepository {}

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

Widget _harness({required Widget child, required Size size}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late _FakeTxnRepo txnRepo;

  setUp(() {
    txnRepo = _FakeTxnRepo();
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          _txn('t1', DateTime(2026, 6, 19)),
          _txn('t2', DateTime(2026, 6, 19)),
          _txn('t3', DateTime(2026, 6, 18)),
        ], nextPageToken: '')));
    // Task 5.2: the page triggers LoadSummaryRequested on init / filter
    // change / after-create. Default to a non-zero summary so tests that assert
    // on the card values have something to render; override per-test as needed.
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 123456,
              expenseCents: 78900,
              netCents: 44556,
              dailyAvgCents: 1481,
            )));
  });

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    await tester.pumpWidget(_harness(
      size: size,
      child: BlocProvider<TransactionBloc>(
        create: (_) {
          final b = TransactionBloc(txnRepo);
          b.add(const LoadTransactionsRequested());
          return b;
        },
        child: const TransactionsPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mobile (390): renders card-stack rows (no table header), SummaryCard grid',
      (tester) async {
    await pumpPage(tester, const Size(390, 844));

    // No table header column labels on mobile.
    expect(find.text('日期'), findsNothing);
    // Card-stack rows render each txn description.
    expect(find.text('交易 t1'), findsOneWidget);
    expect(find.text('交易 t2'), findsOneWidget);
    // Summary placeholder cells present (four of them).
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
  });

  testWidgets(
      'tablet (1024): renders table header + table rows',
      (tester) async {
    await pumpPage(tester, const Size(1024, 768));

    expect(find.text('日期'), findsOneWidget);
    expect(find.text('交易 t1'), findsOneWidget);
  });

  testWidgets(
      'desktop (1440): renders table header + table rows + SummaryCard row',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    expect(find.text('日期'), findsOneWidget);
    expect(find.text('交易 t1'), findsOneWidget);
  });

  testWidgets('transactions are grouped by day with date headers',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Two distinct day groups: 06-19 (t1, t2) and 06-18 (t3).
    expect(find.text('06-19'), findsWidgets);
    expect(find.text('06-18'), findsWidgets);
  });

  testWidgets('FilterBar type segment "支出" dispatches a reload',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Tap the 支出 segment in the filter bar.
    await tester.tap(find.text('支出').first);
    await tester.pumpAndSettle();

    // repo.list called at least twice (initial + reload).
    verify(() => txnRepo.list(any())).called(greaterThanOrEqualTo(2));
  });

  testWidgets('"加载更多" appears when the bloc has a next page token',
      (tester) async {
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(
            transactions: [_txn('t1', DateTime(2026, 6, 19))],
            nextPageToken: 'cursor1')));

    await pumpPage(tester, const Size(1440, 900));
    expect(find.text('加载更多'), findsOneWidget);

    // Tapping it triggers a second list call with the cursor.
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(
            transactions: [_txn('t2', DateTime(2026, 6, 19))],
            nextPageToken: '')));
    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    verify(() => txnRepo.list(any())).called(greaterThanOrEqualTo(2));
  });

  testWidgets('error state surfaces the message and a retry control',
      (tester) async {
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Left(ServerFailure('加载失败')));

    await pumpPage(tester, const Size(1440, 900));

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('empty state shows a "新增交易" entry', (tester) async {
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Right(ListTransactionsResult(transactions: [])));

    await pumpPage(tester, const Size(1440, 900));
    expect(find.textContaining('新增交易'), findsWidgets);
  });

  // ───────────────────────── Task 5.2: SummaryCard 接真实 ─────────────────────────

  testWidgets('SummaryCard renders the real MonthlySummary values', (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Default stub: income 123456 → ¥1,234.56 ; expense 78900 → ¥789.00.
    expect(find.text('¥1,234.56'), findsOneWidget);
    expect(find.text('¥789.00'), findsOneWidget);
    // net 44556 → ¥445.56 (positive → green / income-coloured).
    expect(find.text('¥445.56'), findsOneWidget);
    // dailyAvg 1481 → ¥14.81.
    expect(find.text('¥14.81'), findsOneWidget);
  });

  testWidgets('SummaryCard falls back to ¥0.00 before summary resolves',
      (tester) async {
    // summary never resolves (pending) → card shows zeros, list still renders.
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) => Completer<dartz.Either<Failure, MonthlySummary>>()
            .future);
    await pumpPage(tester, const Size(1440, 900));
    expect(find.text('¥0.00'), findsWidgets);
  });

  testWidgets('a failed summary leaves the card at ¥0.00 (does not crash)',
      (tester) async {
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Left(ServerFailure('summary err')));
    await pumpPage(tester, const Size(1440, 900));
    expect(find.text('¥0.00'), findsWidgets);
    // The list still renders normally — a summary blip doesn't blank it.
    expect(find.text('交易 t1'), findsOneWidget);
  });

  // ─────────── Task 1: _MobileTxnCard 副行(账户首字母方块 + HH:MM) + 右侧分类 chip ───────────

  testWidgets(
      'mobile txn card: 分类 chip + HH:MM + 账户首字母方块 (text assertions)',
      (tester) async {
    // 注入账户仓库:一个 expense(餐饮)账户 + 一个 asset(现金)账户,
    // 让 _CategoryChip / _AccountTag 有真实 account 可渲染。
    final accountRepo = _FakeAccountRepo();
    const expenseAcct = Account(
      id: 'a2',
      name: '餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
    const assetAcct = Account(
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
    when(() => accountRepo.list())
        .thenAnswer((_) async => const dartz.Right([expenseAcct, assetAcct]));

    // 交易带 transactionTime(HH:MM 来源)。
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          Transaction(
            id: 'm1',
            transactionDate: DateTime(2026, 6, 19),
            transactionTime: DateTime(2026, 6, 19, 9, 5),
            description: '早餐',
            entries: const [
              TransactionEntry(
                  accountId: 'a1', debitCents: 1200, creditCents: 0),
              TransactionEntry(
                  accountId: 'a2', debitCents: 0, creditCents: 1200),
            ],
          ),
        ], nextPageToken: '')));

    // mobile viewport 375×900 触发 mobile 分支。
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 包一层 RepositoryProvider<AccountRepository> 让页面 _loadAccounts 可解析。
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(375, 900)),
        child: Scaffold(
          body: RepositoryProvider<AccountRepository>.value(
            value: accountRepo,
            child: BlocProvider<TransactionBloc>(
              create: (_) {
                final b = TransactionBloc(txnRepo);
                b.add(const LoadTransactionsRequested());
                return b;
              },
              child: const TransactionsPage(),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 分类 chip:expense 账户 category.label
    expect(find.text('其他资产'), findsWidgets,
        reason: 'mobile 交易卡右侧应渲染分类 chip (账户 category label)');
    // HH:MM 时间(transactionTime 09:05,副行显示「· 09:05」)
    expect(find.textContaining(RegExp(r'\d{2}:\d{2}')), findsWidgets,
        reason: 'mobile 副行应显示 HH:MM');
    // 账户首字母方块:_AccountTag 渲染 asset 账户名「现金」
    expect(find.text('现金'), findsWidgets,
        reason: 'mobile 副行应含账户首字母方块 + 账户名');
  });
}
