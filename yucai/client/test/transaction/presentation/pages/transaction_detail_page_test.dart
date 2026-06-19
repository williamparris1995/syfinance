// TDD three-size widget test for TransactionDetailPage (Task 3.2).
//
// Asserts:
//   - LoadTransactionDetail{id} dispatches repo.getById + same-account recent
//     list, emitting TransactionDetailLoaded carrying both.
//   - Detail page renders the journal entries via JournalEntry:
//       * account name from injected accountNameOf (餐饮 / 招商银行)
//       * 「借贷平衡」badge when balanced
//   - Summary shows amount + description + date.
//   - Recent same-account transactions render as a list.
//   - Three placeholder zones (AA 分摊 / 同商户 / 预算联动) show with 🔒.
//   - Quick actions (编辑 / 复制 / 删除) present in AppBar.
//   - Three breakpoints render distinct layouts without crashing.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_detail_page.dart';

class _FakeTxnRepo extends Mock implements TransactionRepository {}
class _FakeAcctRepo extends Mock implements AccountRepository {}

final DateTime _date = DateTime(2026, 6, 19);

Transaction _expense() => Transaction(
      id: 't1',
      transactionDate: _date,
      description: '晚餐 餐厅',
      entries: const [
        TransactionEntry(
            accountId: 'exp-food', debitCents: 38000, creditCents: 0),
        TransactionEntry(
            accountId: 'acc-cmb', debitCents: 0, creditCents: 38000),
      ],
    );

Transaction _recent(String id, int amount) => Transaction(
      id: id,
      transactionDate: _date,
      description: '早餐 $id',
      entries: [
        TransactionEntry(
            accountId: 'exp-food', debitCents: amount, creditCents: 0),
        TransactionEntry(
            accountId: 'acc-cmb', debitCents: 0, creditCents: amount),
      ],
    );

Account _account(String id, String name, AccountCategory cat) => Account(
      id: id,
      name: name,
      accountType: AccountType.expense,
      category: cat,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

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
  late _FakeAcctRepo acctRepo;

  setUp(() {
    txnRepo = _FakeTxnRepo();
    acctRepo = _FakeAcctRepo();
    registerFallbackValue(ListTransactionsParams());
    when(() => txnRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(_expense()));
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
            ListTransactionsResult(transactions: [
          _recent('r1', 1500),
          _recent('r2', 2200),
        ], nextPageToken: '')));
    when(() => acctRepo.list()).thenAnswer((_) async => dartz.Right([
          _account('exp-food', '餐饮', AccountCategory.savings),
          _account('acc-cmb', '招商银行', AccountCategory.savings),
        ]));
  });

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    await tester.pumpWidget(_harness(
      size: size,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AccountRepository>.value(value: acctRepo),
        ],
        child: BlocProvider<TransactionBloc>(
          create: (_) {
            final b = TransactionBloc(txnRepo);
            b.add(const LoadTransactionDetail('t1'));
            return b;
          },
          child: const TransactionDetailPage(id: 't1'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'desktop (1440): renders journal entry 餐饮/招商银行 + 平衡 badge + 3 placeholders + recent list',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Summary: description + amount.
    expect(find.text('晚餐 餐厅'), findsOneWidget);
    expect(find.textContaining('380'), findsWidgets);

    // Journal entry: both account names resolved via injected accountNameOf.
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('招商银行'), findsWidgets);
    // Balanced badge.
    expect(find.text('借贷平衡'), findsOneWidget);

    // Recent same-account transactions.
    expect(find.text('早餐 r1'), findsOneWidget);
    expect(find.text('早餐 r2'), findsOneWidget);

    // Three placeholder zones.
    expect(find.text('AA 分摊'), findsOneWidget);
    expect(find.text('同商户交易'), findsOneWidget);
    expect(find.text('预算联动'), findsOneWidget);
    // Locked marker present (3 zones).
    expect(find.text('🔒'), findsNWidgets(3));

    // Quick actions: app bar (编辑/复制/删除) + quick-actions card (编辑/复制/删除).
    // Each appears twice; assert at least one of each.
    expect(find.text('编辑'), findsWidgets);
    expect(find.text('复制'), findsWidgets);
    expect(find.text('删除'), findsWidgets);
  });

  testWidgets('tablet (1024): renders without crashing', (tester) async {
    await pumpPage(tester, const Size(1024, 768));
    expect(find.text('晚餐 餐厅'), findsOneWidget);
    expect(find.text('借贷平衡'), findsOneWidget);
  });

  testWidgets('mobile (390): renders stacked cards without crashing',
      (tester) async {
    await pumpPage(tester, const Size(390, 844));
    expect(find.text('晚餐 餐厅'), findsOneWidget);
    expect(find.text('借贷平衡'), findsOneWidget);
  });
}
