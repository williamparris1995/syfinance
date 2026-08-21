import 'package:drift/drift.dart'
    hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  AccountsCompanion accountRow(String id, {String name = 'Cash'}) =>
      AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: 1,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: 1000,
        currentBalanceCents: 1200,
        ownership: 1,
        icon: 'wallet',
        color: '#000000',
        chartCode: '1001',
        isSystem: false,
        sortOrder: 0,
        institution: 'bank',
        cardNumberTail: '4321',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: DateTime.utc(2026, 8, 20),
        updatedAt: DateTime.utc(2026, 8, 20),
      );

  test('FR-1 memory database creates the full schema (v1)', () async {
    // createAll ran on open: a query per contract table family succeeds.
    expect(await db.select(db.accounts).get(), isEmpty);
    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.select(db.transactionEntries).get(), isEmpty);
    expect(await db.select(db.debts).get(), isEmpty);
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await db.select(db.goals).get(), isEmpty);
    expect(await db.select(db.tags).get(), isEmpty);
    expect(await db.select(db.transactionTemplates).get(), isEmpty);
    expect(await db.select(db.holdings).get(), isEmpty);
    expect(await db.select(db.holdingTransactions).get(), isEmpty);
  });

  test('FR-4 DI: lazy singleton hands out one opened instance', () async {
    final gi = GetIt.asNewInstance();
    addTearDown(() => gi.reset());
    // Production registers AppDatabase.new; the memory executor here only
    // keeps the platform channel out of the unit test.
    gi.registerLazySingleton<AppDatabase>(
        () => AppDatabase(NativeDatabase.memory()));
    final a = gi<AppDatabase>();
    final b = gi<AppDatabase>();
    expect(identical(a, b), isTrue);
    expect(await a.select(a.accounts).get(), isEmpty);
  });

  group('account CRUD (FR-3/FR-6)', () {
    test('full cycle with UUID text PK', () async {
      const id = '11111111-1111-4111-8111-111111111111';
      await db.accountDao.insertAccount(accountRow(id));
      final loaded = await db.accountDao.getAccountById(id);
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Cash');
      expect(loaded.currentBalanceCents, 1200);

      expect(
          await db.accountDao.watchAllAccounts().first, hasLength(1));

      await db.accountDao.updateAccount(const AccountsCompanion(
        id: Value(id),
        name: Value('Renamed'),
      ));
      expect((await db.accountDao.getAccountById(id))!.name, 'Renamed');

      await db.accountDao.deleteAccountById(id);
      expect(await db.accountDao.getAccountById(id), isNull);
    });

    test('timestamps round-trip in text form (ADR-6)', () async {
      const id = '22222222-2222-4222-8222-222222222222';
      final ts = DateTime.utc(2026, 8, 20, 12, 34, 56);
      await db.accountDao.insertAccount(accountRow(id)
          .copyWith(createdAt: Value(ts), openingDate: Value(ts)));
      final loaded = await db.accountDao.getAccountById(id);
      expect(loaded!.createdAt, ts);
      expect(loaded.openingDate, ts);
    });
  });

  group('transaction CRUD + entries (FR-6)', () {
    test('relation query by parent', () async {
      const txId = '33333333-3333-4333-8333-333333333333';
      await db.transactionDao.insertTransaction(
          TransactionsCompanion.insert(
        id: txId,
        transactionDate: DateTime.utc(2026, 8, 1),
        description: 'lunch',
        version: 1,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      await db.transactionDao.insertEntry(TransactionEntriesCompanion.insert(
        id: 'e1',
        transactionId: txId,
        accountId: 'a1',
        chartOfAccountCode: '1001',
        debitCents: 500,
        creditCents: 0,
        note: '',
      ));
      final entries =
          await db.transactionDao.watchEntriesByTransaction(txId).first;
      expect(entries, hasLength(1));
      expect(entries.single.debitCents, 500);
    });
  });

  group('debt CRUD + schedule (FR-6)', () {
    test('schedule query by debt', () async {
      const debtId = '44444444-4444-4444-8444-444444444444';
      await db.debtDao.insertDebt(DebtsCompanion.insert(
        id: debtId,
        accountId: 'a1',
        counterparty: 'Bank',
        interestRate: 3.5,
        amortizationMethod: 1,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2030, 1, 1),
        totalPrincipalCents: 1000000,
        debtType: 1,
        subtype: 'mortgage',
        contact: '',
        contractRef: '',
        version: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));
      await db.debtDao.insertScheduleEntry(PaymentScheduleEntriesCompanion.insert(
        id: 's1',
        debtId: debtId,
        paymentDate: DateTime.utc(2026, 9, 1),
        principalCents: 1000,
        interestCents: 200,
        totalCents: 1200,
        paidCents: 0,
        paid: false,
      ));
      final schedule = await db.debtDao.watchScheduleByDebt(debtId).first;
      expect(schedule, hasLength(1));
      expect(schedule.single.totalCents, 1200);
    });
  });

  group('budget CRUD + items (FR-6)', () {
    test('items query by budget', () async {
      const budgetId = '55555555-5555-4555-8555-555555555555';
      await db.budgetDao.insertBudget(BudgetsCompanion.insert(
        id: budgetId,
        name: 'Aug',
        month: '2026-08',
        totalAmountCents: 50000,
        currencyCode: 'CNY',
        isActive: true,
        version: 1,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      await db.budgetDao.insertItem(BudgetItemsCompanion.insert(
        id: 'i1',
        budgetId: budgetId,
        accountId: 'a1',
        plannedAmountCents: 30000,
        actualAmountCents: 0,
        notes: '',
      ));
      final items = await db.budgetDao.watchItemsByBudget(budgetId).first;
      expect(items, hasLength(1));
      expect(items.single.plannedAmountCents, 30000);
    });
  });

  group('goal CRUD + links (FR-6, conversion rule 3)', () {
    test('links round-trip as id lists', () async {
      const goalId = '66666666-6666-4666-8666-666666666666';
      await db.goalDao.insertGoal(GoalsCompanion.insert(
        id: goalId,
        name: 'Emergency fund',
        goalType: 1,
        targetAmountCents: 1000000,
        currentAmountCents: 100000,
        currencyCode: 'CNY',
        notes: '',
        isCompleted: false,
        version: 1,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      await db.goalDao
          .insertAccountLink(GoalAccountLinksCompanion.insert(
        goalId: goalId,
        linkedId: 'a1',
      ));
      await db.goalDao.insertDebtLink(GoalDebtLinksCompanion.insert(
        goalId: goalId,
        linkedId: 'd1',
      ));
      final (accountIds, debtIds) = await db.goalDao.linksFor(goalId);
      expect(accountIds, ['a1']);
      expect(debtIds, ['d1']);
    });
  });

  group('tag + template + holding CRUD (FR-6)', () {
    test('tag junction watch', () async {
      await db.tagDao.insertTag(TagsCompanion.insert(
        id: 't1',
        name: 'food',
        color: '#FF0000',
        version: 1,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      const txId = '33333333-3333-4333-8333-333333333333';
      await db.transactionDao.insertTransaction(TransactionsCompanion.insert(
        id: txId,
        transactionDate: DateTime.utc(2026, 8, 1),
        description: 'x',
        version: 1,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      await db.tagDao.insertTransactionTag(
          TransactionTagsCompanion.insert(transactionId: txId, tagId: 't1'));
      expect(await db.tagDao.watchTagIdsForTransaction(txId).first, ['t1']);
      await db.tagDao.deleteTransactionTag(txId, 't1');
      expect(await db.tagDao.watchTagIdsForTransaction(txId).first, isEmpty);
    });

    test('template full cycle', () async {
      await db.templateDao.insertTemplate(TransactionTemplatesCompanion.insert(
        id: 'tp1',
        name: 'rent',
        description: '',
        amountCents: 300000,
        direction: 1,
        sourceAccountId: 'a1',
        cycle: 2,
        cycleDays: 0,
        billingDay: 1,
        nextDate: DateTime.utc(2026, 9, 1),
        startDate: DateTime.utc(2026, 1, 1),
        autoRecord: false,
        paused: false,
        category: '',
        version: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ));
      expect((await db.templateDao.getTemplateById('tp1'))!.amountCents,
          300000);
      expect(await db.templateDao.watchAllTemplates().first, hasLength(1));
      await db.templateDao.deleteTemplateById('tp1');
      expect(await db.templateDao.getTemplateById('tp1'), isNull);
    });

    test('holding + trade ledger by security', () async {
      await db.holdingDao.insertHolding(HoldingsCompanion.insert(
        id: 'h1',
        accountId: 'a1',
        securityId: 'sec1',
        quantity: 10.5,
        avgCostCents: 1200,
        version: 1,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 8, 1),
      ));
      await db.holdingDao.insertHoldingTransaction(
          HoldingTransactionsCompanion.insert(
        id: 'ht1',
        accountId: 'a1',
        securityId: 'sec1',
        tradeType: 1,
        quantity: 10.5,
        priceCents: 1200,
        amountCents: 12600,
        feeCents: 5,
        realizedPnlCents: 0,
        tradeDate: DateTime.utc(2026, 8, 1),
        notes: '',
        createdAt: DateTime.utc(2026, 8, 1),
      ));
      final trades =
          await db.holdingDao.watchTransactionsBySecurity('sec1').first;
      expect(trades, hasLength(1));
      expect(trades.single.amountCents, 12600);
    });
  });
}
