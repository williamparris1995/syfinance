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
//   - Amount colour follows the touched account types (Task 3.2 fix):
//       * expense account touched  → 支出红 (AppColors.negative)
//       * income  account touched  → 收入绿 (AppColors.positive)
//       * asset-only (transfer)    → 中性色 (AppColors.fg)
//   - initState self-drives the load (dispatches LoadTransactionDetail even
//     when the parent harness does not).
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
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

/// SimpleIncome (复式记账的收入交易): 借 asset / 贷 income。
/// Prior heuristic (inferFlavour == compound ? 红 : 绿) mis-coloured this red.
Transaction _income() => Transaction(
      id: 't1',
      transactionDate: _date,
      description: '工资',
      entries: const [
        TransactionEntry(
            accountId: 'acc-cmb', debitCents: 50000, creditCents: 0),
        TransactionEntry(
            accountId: 'inc-salary', debitCents: 0, creditCents: 50000),
      ],
    );

/// SimpleTransfer: both legs are asset accounts → neutral colour.
Transaction _transfer() => Transaction(
      id: 't1',
      transactionDate: _date,
      description: '转账',
      entries: const [
        TransactionEntry(
            accountId: 'acc-cmb', debitCents: 0, creditCents: 10000),
        TransactionEntry(
            accountId: 'acc-ali', debitCents: 10000, creditCents: 0),
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

Account _account(String id, String name, AccountType type) => Account(
      id: id,
      name: name,
      accountType: type,
      category: AccountCategory.savings,
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
          _account('exp-food', '餐饮', AccountType.expense),
          _account('acc-cmb', '招商银行', AccountType.asset),
          _account('acc-ali', '支付宝', AccountType.asset),
          _account('inc-salary', '工资', AccountType.income),
        ]));
  });

  /// Pumps the page. By default the harness pre-dispatches
  /// LoadTransactionDetail (mirrors how list pages navigate in with the event
  /// already in flight). Pass [selfDriveOnly] = true to NOT pre-dispatch and
  /// verify initState triggers the load itself.
  Future<void> pumpPage(
    WidgetTester tester,
    Size size, {
    bool selfDriveOnly = false,
    Transaction Function()? txnOverride,
  }) async {
    if (txnOverride != null) {
      when(() => txnRepo.getById(any()))
          .thenAnswer((_) async => dartz.Right(txnOverride()));
    }
    await tester.pumpWidget(_harness(
      size: size,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AccountRepository>.value(value: acctRepo),
        ],
        child: BlocProvider<TransactionBloc>(
          create: (_) {
            final b = TransactionBloc(txnRepo);
            if (!selfDriveOnly) {
              b.add(const LoadTransactionDetail('t1'));
            }
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

  // ───────────────── Amount colour by account type (Task 3.2 fix) ─────────

  /// Finds the summary amount Text widget (large display number in the
  /// summary card) and returns its colour.
  Color? summaryAmountColor(WidgetTester tester) {
    final amountPattern = RegExp(r'^¥\s');
    Color? found;
    tester.widgetList<Text>(find.byType(Text)).forEach((t) {
      if (found != null) return;
      final data = t.data ?? '';
      if (amountPattern.hasMatch(data) &&
          (t.style?.fontSize ?? 0) >= 28 &&
          t.style?.color != null) {
        found = t.style!.color;
      }
    });
    return found;
  }

  testWidgets('amount colour: expense transaction → 支出红 (negative)',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));
    // Expense touches exp-food (AccountType.expense) → red.
    expect(summaryAmountColor(tester), AppColors.negative);
  });

  testWidgets('amount colour: income transaction → 收入绿 (positive)',
      (tester) async {
    await pumpPage(
      tester,
      const Size(1440, 900),
      txnOverride: _income,
    );
    // Income touches inc-salary (AccountType.income) → green.
    expect(summaryAmountColor(tester), AppColors.positive);
  });

  testWidgets('amount colour: asset-only transfer → 中性色 (fg)',
      (tester) async {
    await pumpPage(
      tester,
      const Size(1440, 900),
      txnOverride: _transfer,
    );
    // Both legs are asset accounts → neutral (fg).
    expect(summaryAmountColor(tester), AppColors.fg);
  });

  // ───────────────── initState self-drive (Task 3.2 fix) ─────────────────

  testWidgets(
      'initState dispatches LoadTransactionDetail (self-drive on real route)',
      (tester) async {
    // Pump WITHOUT pre-dispatching — the page must trigger the load itself.
    await pumpPage(tester, const Size(1440, 900), selfDriveOnly: true);

    // The repo.getById must have been called (proves the bloc event fired).
    verify(() => txnRepo.getById('t1')).called(1);

    // And the page reached the loaded state (renders description, not blank).
    expect(find.text('晚餐 餐厅'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
