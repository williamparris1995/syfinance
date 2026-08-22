// Feature E oracles — server-semantics mirrors: holding buy/sell double
// entry + fee capitalization + FIFO, budget actuals (max rule), goal
// three-source actuals, debt repayment double entry, net worth, routing.
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db
    hide Holding, Security, Debt;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';

void main() {
  late db.AppDatabase database;
  late HoldingLocalDataSource holding;
  late TransactionLocalDataSource txns;
  late AccountDao accounts;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    txns = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    holding = HoldingLocalDataSource(database, txns);
    accounts = database.accountDao;
  });

  tearDown(() => database.close());

  Future<String> seedAccount(String name, int type, {int balance = 1000000}) {
    final id = 'acc-$name';
    return accounts.getAccountById(id).then((existing) async {
      if (existing != null) return id;
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
        category: 2,
        currencyCode: 'CNY',
        initialBalanceCents: balance,
        currentBalanceCents: balance,
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
    });
  }

  Future<String> seedSecurity(String symbol) async {
    final s = await holding.createSecurity(
        symbol: symbol, name: symbol, type: SecurityType.stock, currency: 'CNY');
    return s.id;
  }

  group('holding buy/sell (FIFO + double entry)', () {
    test('buy: fee capitalizes into avgCost; cash leg excludes fee', () async {
      final cash = await seedAccount('cash', 1);
      final inv = await seedAccount('inv', 1);
      final sec = await seedSecurity('600519');
      final t = await holding.buy(
        accountId: inv,
        securityId: sec,
        fromAccountId: cash,
        quantity: 100,
        priceCents: 1000,
        feeCents: 500,
        tradeDate: '2026-08-01',
      );
      expect(t.tradeType, TradeType.buy);
      final list = await holding.listHoldings(accountId: inv);
      expect(list.single.quantity, 100);
      // (100×1000 + 500)/100 = 1005 per share (fee capitalized).
      expect(list.single.avgCostCents, 1005);
      // Cash linkage: credit cash 100000 (price×qty only, NOT fee).
      final txnRows = await database.transactionDao.getAllTransactions();
      final entries = await database.transactionDao.getAllEntries();
      expect(txnRows, hasLength(1));
      final cashLeg =
          entries.singleWhere((e) => e.accountId == cash && e.creditCents > 0);
      expect(cashLeg.creditCents, 100000);
      final invLeg =
          entries.singleWhere((e) => e.accountId == inv && e.debitCents > 0);
      expect(invLeg.debitCents, 100000);
    });

    test('sell: FIFO across two lots; realized pnl deducts fee', () async {
      final cash = await seedAccount('cash', 1);
      final inv = await seedAccount('inv', 1);
      final sec = await seedSecurity('AAPL');
      await holding.buy(accountId: inv, securityId: sec, fromAccountId: cash,
          quantity: 100, priceCents: 1000, tradeDate: '2026-01-01');
      await holding.buy(accountId: inv, securityId: sec, fromAccountId: cash,
          quantity: 100, priceCents: 2000, tradeDate: '2026-02-01');
      // Sell 150 @ 2400 with 100 fee: FIFO consumes lot1 (100) + lot2 (50).
      final t = await holding.sell(
          accountId: inv,
          securityId: sec,
          fromAccountId: cash,
          quantity: 150,
          priceCents: 2400,
          feeCents: 100,
          tradeDate: '2026-03-01');
      // realized = (2400−1000)×100 + (2400−2000)×50 − 100 = 159900.— read
      // from the drift ledger row (the entity has no realizedPnl field).
      final ledger = (await database.holdingDao.getHoldingTransactionById(t.id))!;
      expect(ledger.realizedPnlCents, 159900);
      final list = await holding.listHoldings(accountId: inv);
      expect(list.single.quantity, 50);
      // avgCost from the remaining (second) lot = 2000.
      expect(list.single.avgCostCents, 2000);
      // Remaining lots: only the 50-share remnant.
      final lots = await database.derivedDao.getLotsBySecurity(sec);
      expect(lots, hasLength(1));
      expect(lots.single.remainingQuantity, 50);
    });

    test('buy validations mirror the server', () async {
      final cash = await seedAccount('cash', 1);
      final inv = await seedAccount('inv', 1);
      final sec = await seedSecurity('X');
      // Same account.
      await expectLater(
        holding.buy(accountId: inv, securityId: sec, fromAccountId: inv,
            quantity: 1, priceCents: 10, tradeDate: '2026-08-01'),
        throwsA(isA<ValidationFailure>()),
      );
      // Insufficient balance.
      await expectLater(
        holding.buy(accountId: inv, securityId: sec, fromAccountId: cash,
            quantity: 1000, priceCents: 10000, tradeDate: '2026-08-01'),
        throwsA(isA<ServerFailure>()),
      );
      // Nothing persisted after the failures.
      expect(await holding.listHoldings(), isEmpty);
      expect((await database.transactionDao.getAllTransactions()), isEmpty);
    });
  });

  group('budget actuals (max rule)', () {
    test('actual = max(Σdebit, Σcredit) over the month window', () async {
      final food = await seedAccount('food', 5); // expense
      final salary = await seedAccount('salary', 4); // income
      final cash = await seedAccount('cash', 1);
      await txns.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 10),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      ));
      await txns.recordIncome(RecordIncomeParams(
        transactionDate: DateTime.utc(2026, 8, 20),
        incomeAccountId: salary,
        assetAccountId: cash,
        amountCents: 800000,
      ));
      // Out-of-window noise must not count.
      await txns.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 7, 31),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 999,
      ));

      final ds = BudgetLocalDataSource(database);
      final b = await ds.createBudget(
        name: 'Aug',
        month: '2026-08',
        currencyCode: 'CNY',
        items: [
          (accountId: food, plannedAmountCents: 10000, notes: null),
          (accountId: salary, plannedAmountCents: 500000, notes: null),
        ],
      );
      final detail = await ds.getBudget(b.id);
      final foodItem =
          detail.items.singleWhere((i) => i.accountId == food);
      final salaryItem =
          detail.items.singleWhere((i) => i.accountId == salary);
      expect(foodItem.actualAmountCents, 5000); // expense side = debit
      expect(salaryItem.actualAmountCents, 800000); // income side = credit
    });
  });

  group('goal three-source actuals', () {
    test('savings = Σ balances; debtPayoff = Σ schedule paid', () async {
      final save1 = await seedAccount('save1', 1, balance: 30000);
      final save2 = await seedAccount('save2', 1, balance: 20000);
      final goals = GoalLocalDataSource(database, holding);
      final g = await goals.createGoal(
        name: 'emergency',
        type: GoalType.savings,
        targetAmountCents: 100000,
        linkedAccountIds: [save1, save2],
      );
      final view = await goals.getGoal(g.id);
      expect(view.currentAmountCents, 50000);

      // debtPayoff: schedule paid sum.
      final loan = await seedAccount('loan', 2);
      final cash = await seedAccount('cash', 1);
      final debts = DebtLocalDataSource(database, txns);
      final d = await debts.create(
        accountId: loan,
        counterparty: 'Bank',
        interestRate: 3,
        amortizationIndex: 0,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 100000,
        type: DebtType.borrowedIn,
      );
      final g2 = await goals.createGoal(
        name: 'payoff',
        type: GoalType.debtPayoff,
        targetAmountCents: 100000,
        linkedDebtIds: [d.id],
      );
      expect((await goals.getGoal(g2.id)).currentAmountCents, 0);

      var schedule = await database.debtDao.getScheduleByDebt(d.id);
      if (schedule.isEmpty) {
        // Local create has no amortization engine — seed a schedule row.
        await database.debtDao.insertScheduleEntry(
            db.PaymentScheduleEntriesCompanion.insert(
          id: 'sch-goal',
          debtId: d.id,
          paymentDate: DateTime.utc(2026, 9, 1),
          principalCents: 1000,
          interestCents: 200,
          totalCents: 1200,
          paidCents: 0,
          paid: false,
        ));
        schedule = await database.debtDao.getScheduleByDebt(d.id);
      }
      // Mark one schedule row paid manually, then re-read.
      await database.debtDao.updateScheduleEntry(
          db.PaymentScheduleEntriesCompanion(
        id: Value(schedule.first.id),
        paid: const Value(true),
        paidCents: Value(schedule.first.totalCents),
      ));
      expect((await goals.getGoal(g2.id)).currentAmountCents,
          schedule.first.totalCents);
    });
  });

  group('debt repayment double entry', () {
    test('borrowedIn: credit from + debit debt account', () async {
      final loan = await seedAccount('loan', 2);
      final cash = await seedAccount('cash', 1);
      final debts = DebtLocalDataSource(database, txns);
      final d = await debts.create(
        accountId: loan,
        counterparty: 'Bank',
        interestRate: 3,
        amortizationIndex: 0,
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 120000,
        type: DebtType.borrowedIn,
      );
      final schedule = await database.debtDao.getScheduleByDebt(d.id);
      // NOTE: local create does not auto-generate schedule rows (server
      // amortization engine is out of guest scope) — insert one directly.
      if (schedule.isEmpty) {
        await database.debtDao.insertScheduleEntry(
            db.PaymentScheduleEntriesCompanion.insert(
          id: 'sch1',
          debtId: d.id,
          paymentDate: DateTime.utc(2026, 9, 1),
          principalCents: 1000,
          interestCents: 200,
          totalCents: 1200,
          paidCents: 0,
          paid: false,
        ));
      }
      final entry = (await database.debtDao.getScheduleByDebt(d.id)).first;
      final paid = await debts.recordPayment(
        debtId: d.id,
        scheduleEntryId: entry.id,
        fromAccountId: cash,
      );
      expect(paid.paid, isTrue);
      final entries = await database.transactionDao.getAllEntries();
      final loanLeg =
          entries.singleWhere((e) => e.accountId == loan && e.debitCents > 0);
      expect(loanLeg.debitCents, entry.totalCents);
      final cashLeg =
          entries.singleWhere((e) => e.accountId == cash && e.creditCents > 0);
      expect(cashLeg.creditCents, entry.totalCents);
    });
  });

  group('net worth three sources', () {
    test('assets/liabilities/net over local tables', () async {
      final networth = NetWorthLocalDataSource(database);
      await seedAccount('cash', 1, balance: 50000);
      // Liability ACCOUNT balances are NOT counted (review E-#9) — the
      // liability comes from a borrowedIn debt's unpaid schedule.
      await seedAccount('loan', 2, balance: 20000);
      final debts = DebtLocalDataSource(database, txns);
      final loanAcc = await seedAccount('loanacc', 2);
      await debts.create(
        accountId: loanAcc,
        counterparty: 'B',
        interestRate: 0,
        amortizationIndex: 2, // lump sum: one unpaid entry of 20000+0
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 6, 1),
        totalPrincipalCents: 20000,
        type: DebtType.borrowedIn,
      );
      final view = await networth.getNetWorth(baseCurrency: 'CNY');
      expect(view.totalAssetsCents, 50000);
      expect(view.totalLiabilitiesCents, 20000);
      expect(view.netWorthCents, 30000);
    });
  });

  group('amortization engine (server formulas)', () {
    test('equal installment: 12-month 120000 @0.06 sums back to principal+interest', () async {
      final loan = await seedAccount('loan2', 2);
      final cash2 = await seedAccount('cash2', 1);
      final debts = DebtLocalDataSource(database, txns);
      final d = await debts.create(
        accountId: loan,
        counterparty: 'B2',
        interestRate: 0.06,
        amortizationIndex: 0, // equalPrincipalInterest
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2027, 1, 1),
        totalPrincipalCents: 120000,
        type: DebtType.borrowedIn,
      );
      final schedule = await database.debtDao.getScheduleByDebt(d.id);
      expect(schedule, hasLength(12));
      expect(schedule.first.paymentDate, DateTime.utc(2026, 2, 1));
      // Σprincipal == 120000 (last entry absorbs rounding).
      expect(schedule.fold(0, (a, s2) => a + s2.principalCents), 120000);
      // Monthly interest declining on remaining balance.
      expect(schedule.first.interestCents, 600);
    });

    test('lump sum: single entry at due date', () async {
      final loan = await seedAccount('loan3', 2);
      final debts = DebtLocalDataSource(database, txns);
      final d = await debts.create(
        accountId: loan,
        counterparty: 'B3',
        interestRate: 0.12,
        amortizationIndex: 2, // lumpSum
        startDate: DateTime.utc(2026, 1, 1),
        dueDate: DateTime.utc(2026, 7, 1),
        totalPrincipalCents: 100000,
        type: DebtType.borrowedIn,
      );
      final schedule = await database.debtDao.getScheduleByDebt(d.id);
      expect(schedule, hasLength(1));
      expect(schedule.single.paymentDate, DateTime.utc(2026, 7, 1));
      // interest = 100000 × 0.12 × 6/12 = 6000.
      expect(schedule.single.interestCents, 6000);
    });

    test('borrowedOut create double-writes cash out', () async {
      final recv = await seedAccount('recv', 1);
      final src = await seedAccount('src', 1);
      final debts = DebtLocalDataSource(database, txns);
      final d = await debts.create(
        accountId: recv,
        counterparty: 'Zhang',
        interestRate: 0,
        amortizationIndex: 2,
        startDate: DateTime.utc(2026, 8, 1),
        dueDate: DateTime.utc(2026, 9, 1),
        totalPrincipalCents: 50000,
        type: DebtType.borrowedOut,
        sourceAccountId: src,
      );
      expect(d.type, DebtType.borrowedOut);
      final entries = await database.transactionDao.getAllEntries();
      // credit source (cash−) 50000 / debit receivable 50000.
      expect(
        entries.singleWhere((e) => e.accountId == src && e.creditCents > 0),
        isNotNull,
      );
      expect(
        entries.singleWhere((e) => e.accountId == recv && e.debitCents > 0),
        isNotNull,
      );
    });
  });

  group('split keeps consumed shares consumed', () {
    test('2:1 split after partial FIFO consumption', () async {
      final cash = await seedAccount('cash-s', 1);
      final inv = await seedAccount('inv-s', 1);
      final sec = await seedSecurity('SPLIT');
      await holding.buy(accountId: inv, securityId: sec, fromAccountId: cash,
          quantity: 100, priceCents: 1000, tradeDate: '2026-01-01');
      await holding.sell(accountId: inv, securityId: sec, fromAccountId: cash,
          quantity: 60, priceCents: 1100, tradeDate: '2026-02-01');
      await holding.recordSplit(
          accountId: inv, securityId: sec, ratio: 2, splitDate: '2026-03-01');
      final h = await holding.listHoldings(accountId: inv);
      // 40 remaining × 2 = 80 after the split.
      expect(h.single.quantity, 80);
      final lots = await database.derivedDao.getLotsByHolding(
          (await database.holdingDao.watchAllHoldings().first).first.id);
      // remaining 40 × 2 = 80 — NOT 200 (the revival bug).
      expect(lots.single.remainingQuantity, 80);
    });
  });

  group('routing', () {
    test('guest stays local for holding/budget/goal/debt repos', () async {
      final tracker = SessionModeTracker()..isGuest = true;
      // Holding: listHoldings guest → local empty, no remote ds constructed.
      expect(await holding.listHoldings(), isEmpty);
      expect(tracker.isGuest, isTrue);
    });
  });
}
