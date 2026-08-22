// TransactionLocalDataSource tests — server-semantics oracles: Simple* entry
// directions, nested-entry atomicity, whole-set update replacement, offset
// paging, and the summary CASE rule (income=credit, expense=debit).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

void main() {
  late db.AppDatabase database;
  late TransactionLocalDataSource ds;
  late AccountDao accounts;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    ds = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    accounts = database.accountDao;
  });

  tearDown(() => database.close());

  Future<String> seedAccount(String name, int type) async {
    final id = 'acc-$name';
    if (await accounts.getAccountById(id) != null) return id;
    await accounts.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: type,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: false,
      sortOrder: 0,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    return id;
  }

  test('recordExpense pairs entries: debit expense / credit asset (oracle)',
      () async {
    final cash = await seedAccount('cash', 1); // asset
    final food = await seedAccount('food', 5); // expense
    final t = await ds.recordExpense(RecordExpenseParams(
      transactionDate: DateTime.utc(2026, 8, 22),
      expenseAccountId: food,
      assetAccountId: cash,
      amountCents: 5000,
    ));
    expect(t.version, 1);
    expect(t.entries, hasLength(2));
    final debit = t.entries.singleWhere((e) => e.debitCents > 0);
    final credit = t.entries.singleWhere((e) => e.creditCents > 0);
    expect(debit.accountId, food);
    expect(debit.debitCents, 5000);
    expect(credit.accountId, cash);
    expect(credit.creditCents, 5000);
    // Coarse heuristic: balanced 2-entry txns always read as transfer
    // (expense/income can't be told apart without account-type metadata).
    expect(inferFlavour(t), TxnFlavour.transfer);
  });

  test('recordIncome: debit asset / credit income; transfer: debit to / credit from',
      () async {
    final cash = await seedAccount('cash', 1);
    final salary = await seedAccount('salary', 4); // income
    final bank = await seedAccount('bank', 1);
    final inc = await ds.recordIncome(RecordIncomeParams(
      transactionDate: DateTime.utc(2026, 8, 22),
      incomeAccountId: salary,
      assetAccountId: cash,
      amountCents: 800000,
    ));
    expect(inc.entries.singleWhere((e) => e.debitCents > 0).accountId, cash);
    expect(inc.entries.singleWhere((e) => e.creditCents > 0).accountId, salary);

    final tr = await ds.recordTransfer(RecordTransferParams(
      transactionDate: DateTime.utc(2026, 8, 22),
      fromAccountId: cash,
      toAccountId: bank,
      amountCents: 100,
    ));
    expect(tr.entries.singleWhere((e) => e.debitCents > 0).accountId, bank);
    expect(tr.entries.singleWhere((e) => e.creditCents > 0).accountId, cash);
  });

  test('unbalanced entry packet is rejected before any write', () async {
    expect(
      () => ds.recordTransaction(RecordTransactionParams(
        transactionDate: DateTime.utc(2026, 8, 22),
        description: 'bad',
        entries: [
          const TransactionEntry(accountId: 'x', debitCents: 10, creditCents: 10),
        ],
      )),
      throwsA(isA<ValidationFailure>()),
    );
    expect((await ds.list(const ListTransactionsParams())).transactions, isEmpty);
  });

  test('update replaces the whole entry set and bumps the version',
      () async {
    final a = await seedAccount('a', 1);
    final b = await seedAccount('b', 1);
    final c = await seedAccount('c', 1);
    final t = await ds.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 8, 22),
      description: 'x',
      entries: [
        TransactionEntry(accountId: a, debitCents: 100, creditCents: 0),
        TransactionEntry(accountId: b, debitCents: 0, creditCents: 100),
      ],
    ));
    final updated = await ds.update(UpdateTransactionParams(
      id: t.id,
      version: t.version,
      description: 'y',
      entries: [
        TransactionEntry(accountId: a, debitCents: 100, creditCents: 0),
        TransactionEntry(accountId: c, debitCents: 0, creditCents: 100),
      ],
    ));
    expect(updated.description, 'y');
    expect(updated.version, 2);
    expect(updated.entries.map((e) => e.accountId), containsAll([a, c]));
    expect(updated.entries.map((e) => e.accountId), isNot(contains(b)));
  });

  test('update with a stale version is rejected', () async {
    final a = await seedAccount('a', 1);
    final t = await ds.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 8, 22),
      description: 'x',
      entries: [
        TransactionEntry(accountId: a, debitCents: 1, creditCents: 0),
        TransactionEntry(accountId: a, debitCents: 0, creditCents: 1),
      ],
    ));
    expect(
      () => ds.update(UpdateTransactionParams(
        id: t.id,
        version: 99,
        entries: [
          TransactionEntry(accountId: a, debitCents: 2, creditCents: 0),
          TransactionEntry(accountId: a, debitCents: 0, creditCents: 2),
        ],
      )),
      throwsA(isA<ServerFailure>()),
    );
  });

  test('list paginates by offset with a date-desc stable order', () async {
    final a = await seedAccount('a', 1);
    for (var i = 1; i <= 3; i++) {
      await ds.recordTransaction(RecordTransactionParams(
        transactionDate: DateTime.utc(2026, 8, i),
        description: 't$i',
        entries: [
          TransactionEntry(accountId: a, debitCents: i, creditCents: 0),
          TransactionEntry(accountId: a, debitCents: 0, creditCents: i),
        ],
      ));
    }
    final page1 = await ds
        .list(const ListTransactionsParams(pageSize: 2))
        ;
    expect(page1.transactions.map((t) => t.description), ['t3', 't2']);
    expect(page1.totalCount, 3);
    expect(page1.hasMore, isTrue);
    final page2 = await ds.list(ListTransactionsParams(
      pageSize: 2,
      pageToken: page1.nextPageToken,
    ));
    expect(page2.transactions.map((t) => t.description), ['t1']);
    expect(page2.hasMore, isFalse);
  });

  test('summary mirrors the server CASE rule and dailyAvg', () async {
    final cash = await seedAccount('cash', 1);
    final food = await seedAccount('food', 5); // expense
    final salary = await seedAccount('salary', 4); // income
    // Asset-only legs must not count toward income/expense.
    await ds.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 8, 20),
      description: 'ignore',
      entries: [
        TransactionEntry(accountId: cash, debitCents: 999, creditCents: 0),
        TransactionEntry(accountId: cash, debitCents: 0, creditCents: 999),
      ],
    ));
    await ds.recordExpense(RecordExpenseParams(
      transactionDate: DateTime.utc(2026, 8, 21),
      expenseAccountId: food,
      assetAccountId: cash,
      amountCents: 5000,
    ));
    await ds.recordIncome(RecordIncomeParams(
      transactionDate: DateTime.utc(2026, 8, 21),
      incomeAccountId: salary,
      assetAccountId: cash,
      amountCents: 800000,
    ));

    final s = await ds.summary(2026, 8);
    expect(s.incomeCents, 800000);
    expect(s.expenseCents, 5000);
    expect(s.netCents, 795000);
    // One active day (both txns on 08-21) → net / 1.
    expect(s.dailyAvgCents, 795000);
    expect(s.byDay, hasLength(1));
    expect(s.byDay.single.date, '2026-08-21');
    expect(s.byDay.single.totalIncomeCents, 800000);
    final cats = s.byDay.single.byCategory;
    expect(
      cats.firstWhere((c) => c.categoryId == salary).accountType,
      'income',
    );
    expect(
      cats.firstWhere((c) => c.categoryId == food).accountType,
      'expense',
    );
  });
}
