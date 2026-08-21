import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('deleting a transaction cascades to its entries', () async {
    const txId = '33333333-3333-4333-8333-333333333333';
    final tx = TransactionsCompanion.insert(
      id: txId,
      transactionDate: DateTime.utc(2026, 8, 1),
      description: 'x',
      version: 1,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    );
    await db.transactionDao.insertTransaction(tx);
    await db.transactionDao.insertEntry(TransactionEntriesCompanion.insert(
      id: 'e1',
      transactionId: txId,
      accountId: 'a1',
      chartOfAccountCode: '1001',
      debitCents: 1,
      creditCents: 0,
      note: '',
    ));
    await db.transactionDao.deleteTransactionById(txId);
    expect(await db.select(db.transactionEntries).get(), isEmpty);
  });

  test('deleting a debt cascades to its schedule', () async {
    const debtId = '44444444-4444-4444-8444-444444444444';
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: debtId,
      accountId: 'a1',
      counterparty: 'Bank',
      interestRate: 3.5,
      amortizationMethod: 1,
      startDate: DateTime.utc(2026, 1, 1),
      dueDate: DateTime.utc(2030, 1, 1),
      totalPrincipalCents: 1000,
      debtType: 1,
      subtype: 'personal',
      contact: '',
      contractRef: '',
      version: 1,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ));
    await db.debtDao.insertScheduleEntry(
        PaymentScheduleEntriesCompanion.insert(
      id: 's1',
      debtId: debtId,
      paymentDate: DateTime.utc(2026, 9, 1),
      principalCents: 1,
      interestCents: 1,
      totalCents: 2,
      paidCents: 0,
      paid: false,
    ));
    await db.debtDao.deleteDebtById(debtId);
    expect(await db.select(db.paymentScheduleEntries).get(), isEmpty);
  });

  test('deleting a budget cascades to its items', () async {
    const budgetId = '55555555-5555-4555-8555-555555555555';
    await db.budgetDao.insertBudget(BudgetsCompanion.insert(
      id: budgetId,
      name: 'Aug',
      month: '2026-08',
      totalAmountCents: 100,
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
      plannedAmountCents: 100,
      actualAmountCents: 0,
      notes: '',
    ));
    await db.budgetDao.deleteBudgetById(budgetId);
    expect(await db.select(db.budgetItems).get(), isEmpty);
  });

  test('deleting a goal cascades to both link tables', () async {
    const goalId = '66666666-6666-4666-8666-666666666666';
    await db.goalDao.insertGoal(GoalsCompanion.insert(
      id: goalId,
      name: 'g',
      goalType: 1,
      targetAmountCents: 10,
      currentAmountCents: 0,
      currencyCode: 'CNY',
      notes: '',
      isCompleted: false,
      version: 1,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ));
    await db.goalDao.insertAccountLink(GoalAccountLinksCompanion.insert(
      goalId: goalId,
      linkedId: 'a1',
    ));
    await db.goalDao.insertDebtLink(GoalDebtLinksCompanion.insert(
      goalId: goalId,
      linkedId: 'd1',
    ));
    await db.goalDao.deleteGoalById(goalId);
    expect(await db.select(db.goalAccountLinks).get(), isEmpty);
    expect(await db.select(db.goalDebtLinks).get(), isEmpty);
  });

  test('tag junction cascades from both sides + duplicate row rejected', () async {
    const txId = '33333333-3333-4333-8333-333333333333';
    await db.transactionDao.insertTransaction(TransactionsCompanion.insert(
      id: txId,
      transactionDate: DateTime.utc(2026, 8, 1),
      description: 'x',
      version: 1,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ));
    await db.tagDao.insertTag(TagsCompanion.insert(
      id: 't1',
      name: 'food',
      color: '#FF0000',
      version: 1,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ));
    await db.tagDao.insertTransactionTag(
        TransactionTagsCompanion.insert(transactionId: txId, tagId: 't1'));

    // Composite PK rejects a duplicate junction row.
    expect(
      () => db.tagDao.insertTransactionTag(
          TransactionTagsCompanion.insert(transactionId: txId, tagId: 't1')),
      throwsA(anything),
    );

    await db.tagDao.deleteTagById('t1');
    expect(await db.select(db.transactionTags).get(), isEmpty);

    await db.tagDao.insertTag(TagsCompanion.insert(
      id: 't2',
      name: 'x',
      color: '#00FF00',
      version: 1,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ));
    await db.tagDao.insertTransactionTag(
        TransactionTagsCompanion.insert(transactionId: txId, tagId: 't2'));
    await db.transactionDao.deleteTransactionById(txId);
    expect(await db.select(db.transactionTags).get(), isEmpty);
  });

  test('holding deletion keeps the append-only trade ledger (no FK by design)',
      () async {
    await db.holdingDao.insertHolding(HoldingsCompanion.insert(
      id: 'h1',
      accountId: 'a1',
      securityId: 'sec1',
      quantity: 1,
      avgCostCents: 1,
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
      quantity: 1,
      priceCents: 1,
      amountCents: 1,
      feeCents: 0,
      realizedPnlCents: 0,
      tradeDate: DateTime.utc(2026, 8, 1),
      notes: '',
      createdAt: DateTime.utc(2026, 8, 1),
    ));
    await db.holdingDao.deleteHoldingById('h1');
    expect(await db.select(db.holdingTransactions).get(), hasLength(1));
  });
}
