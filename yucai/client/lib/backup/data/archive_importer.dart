import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// Archive importer (R6 feature J, design ADR-2): replaces the ENTIRE local
/// store from a decrypted envelope (the inverse of G's exporter). Runs in a
/// single drift transaction — any module failure rolls back and the local
/// store is untouched.
@LazySingleton()
class ArchiveImporter {
  ArchiveImporter(this._database);

  final db.AppDatabase _database;

  Future<void> importAll(Uint8List envelopeJson) async {
    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(envelopeJson));
    } catch (_) {
      throw const ValidationFailure('存档内容无法解析');
    }
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const ValidationFailure('存档版本不支持');
    }
    final envelope = decoded;
    final modules = (envelope['modules'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    await _database.transaction(() async {
      // Purge dependents-first, import account-first — the server's restore
      // ordering (backup service orderedPorts).
      await _database.transactionDao.deleteAllEntries();
      await _database.transactionDao.deleteAllTransactions();
      await _database.debtDao.deleteAllSchedule();
      await _database.debtDao.deleteAllDebts();
      await _database.budgetDao.deleteAllItems();
      await _database.budgetDao.deleteAllBudgets();
      await _database.goalDao.deleteAllLinks();
      await _database.goalDao.deleteAllGoals();
      await _database.tagDao.deleteAllTransactionTags();
      await _database.tagDao.deleteAllTags();
      await _database.templateDao.deleteAllTemplates();
      await _database.holdingDao.deleteAllHoldingTransactions();
      await _database.holdingDao.deleteAllHoldings();
      await _database.accountDao.deleteAllAccounts();

      for (final a in _list(modules, 'account')) {
        await _database.accountDao.insertAccount(_accountRow(a));
      }
      for (final t in _list(modules, 'transaction')) {
        await _database.transactionDao
            .insertTransaction(_txnRow(t));
        for (final e in (t['Entries'] as List? ?? [])) {
          await _database.transactionDao.insertEntry(_entryRow(t['ID'], e));
        }
      }
      for (final d in _list(modules, 'debt')) {
        await _database.debtDao.insertDebt(_debtRow(d));
        for (final s in (d['Schedule'] as List? ?? [])) {
          await _database.debtDao.insertScheduleEntry(_scheduleRow(d['ID'], s));
        }
      }
      for (final b in _list(modules, 'budget')) {
        await _database.budgetDao.insertBudget(_budgetRow(b));
        for (final i in (b['Items'] as List? ?? [])) {
          await _database.budgetDao.insertItem(_budgetItemRow(b['ID'], i));
        }
      }
      for (final g in _list(modules, 'goal')) {
        await _database.goalDao.insertGoal(_goalRow(g));
        for (final a in (g['LinkedAccountIDs'] as List? ?? [])) {
          await _database.goalDao.insertAccountLink(
              db.GoalAccountLinksCompanion.insert(goalId: g['ID'], linkedId: a));
        }
        for (final d in (g['LinkedDebtIDs'] as List? ?? [])) {
          await _database.goalDao.insertDebtLink(
              db.GoalDebtLinksCompanion.insert(goalId: g['ID'], linkedId: d));
        }
      }
      for (final t in _list(modules, 'tag')) {
        await _database.tagDao.insertTag(_tagRow(t));
      }
      for (final t in _list(modules, 'template')) {
        await _database.templateDao.insertTemplate(_templateRow(t));
      }
      final holding = modules['holding'] as Map<String, dynamic>?;
      if (holding != null) {
        for (final h in (holding['holdings'] as List? ?? [])) {
          await _database.holdingDao.insertHolding(_holdingRow(h));
        }
        for (final t in (holding['transactions'] as List? ?? [])) {
          await _database.holdingDao
              .insertHoldingTransaction(_holdingTxnRow(t));
        }
      }
    });
  }

  List<dynamic> _list(Map<String, dynamic> modules, String key) =>
      modules[key] as List? ?? [];

  DateTime? _dt(dynamic v) =>
      v == null ? null : (DateTime.tryParse(v.toString())?.toUtc());

  db.AccountsCompanion _accountRow(Map<dynamic, dynamic> a) =>
      db.AccountsCompanion.insert(
        id: a['ID'] as String,
        name: a['Name'] as String? ?? '',
        accountType: a['AccountType'] as int? ?? 1,
        category: a['Category'] as int? ?? 2,
        currencyCode: a['CurrencyCode'] as String? ?? 'CNY',
        initialBalanceCents: a['InitialBalanceCents'] as int? ?? 0,
        currentBalanceCents: a['CurrentBalanceCents'] as int? ?? 0,
        ownership: a['Ownership'] as int? ?? 1,
        icon: a['Icon'] as String? ?? '',
        color: a['Color'] as String? ?? '',
        chartCode: a['ChartCode'] as String? ?? '',
        parentId: Value(a['ParentID'] as String?),
        isSystem: a['IsSystem'] as bool? ?? false,
        sortOrder: a['SortOrder'] as int? ?? 0,
        institution: a['Institution'] as String? ?? '',
        creditLimitCents: Value(a['CreditLimitCents'] as int?),
        cardNumberTail: a['CardNumberTail'] as String? ?? '',
        notes: a['Notes'] as String? ?? '',
        openingDate: Value(_dt(a['OpeningDate'])),
        interestRate: Value((a['InterestRate'] as num?)?.toDouble()),
        creditBillingDay: Value(a['CreditBillingDay'] as int?),
        creditRepaymentDay: Value(a['CreditRepaymentDay'] as int?),
        creditAnnualFeeCents: Value(a['CreditAnnualFeeCents'] as int?),
        investCostCents: Value(a['InvestCostCents'] as int?),
        investMarketValueCents: Value(a['InvestMarketValueCents'] as int?),
        investReturnYtd: Value((a['InvestReturnYtd'] as num?)?.toDouble()),
        fixedPrincipalCents: Value(a['FixedPrincipalCents'] as int?),
        fixedStartDate: Value(_dt(a['FixedStartDate'])),
        fixedMaturityDate: Value(_dt(a['FixedMaturityDate'])),
        fixedTermMonths: Value(a['FixedTermMonths'] as int?),
        goldProductType: a['GoldProductType'] as String? ?? '',
        goldQuantity: Value((a['GoldQuantity'] as num?)?.toDouble()),
        goldBuyPriceCents: Value(a['GoldBuyPriceCents'] as int?),
        goldCurrentPriceCents: Value(a['GoldCurrentPriceCents'] as int?),
        estatePurchasePriceCents: Value(a['EstatePurchasePriceCents'] as int?),
        estateCurrentValueCents: Value(a['EstateCurrentValueCents'] as int?),
        estatePurchaseDate: Value(_dt(a['EstatePurchaseDate'])),
        estateDepreciationRate: Value((a['EstateDepreciationRate'] as num?)?.toDouble()),
        loanOriginalCents: Value(a['LoanOriginalCents'] as int?),
        loanRemainingCents: Value(a['LoanRemainingCents'] as int?),
        loanMonthlyCents: Value(a['LoanMonthlyCents'] as int?),
        loanNextPaymentDate: Value(_dt(a['LoanNextPaymentDate'])),
        status: a['Status'] as int? ?? 1,
        version: a['Version'] as int? ?? 1,
        createdAt: _dt(a['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.TransactionsCompanion _txnRow(Map<dynamic, dynamic> t) =>
      db.TransactionsCompanion.insert(
        id: t['ID'] as String,
        transactionDate: _dt(t['TransactionDate']) ?? DateTime.now().toUtc(),
        transactionTime: Value(_dt(t['TransactionTime'])),
        description: t['Description'] as String? ?? '',
        version: t['Version'] as int? ?? 1,
        createdAt: _dt(t['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.TransactionEntriesCompanion _entryRow(
          String txnId, Map<dynamic, dynamic> e) =>
      db.TransactionEntriesCompanion.insert(
        id: e['ID'] as String,
        transactionId: txnId,
        accountId: e['AccountID'] as String,
        chartOfAccountCode: e['ChartOfAccountCode'] as String? ?? '',
        debitCents: e['DebitCents'] as int? ?? 0,
        creditCents: e['CreditCents'] as int? ?? 0,
        note: e['Note'] as String? ?? '',
      );

  db.DebtsCompanion _debtRow(Map<dynamic, dynamic> d) =>
      db.DebtsCompanion.insert(
        id: d['ID'] as String,
        accountId: d['AccountID'] as String,
        counterparty: d['Counterparty'] as String? ?? '',
        interestRate: (d['InterestRate'] as num?)?.toDouble() ?? 0,
        amortizationMethod: d['AmortizationMethod'] as int? ?? 1,
        startDate: _dt(d['StartDate']) ?? DateTime.now().toUtc(),
        dueDate: _dt(d['DueDate']) ?? DateTime.now().toUtc(),
        totalPrincipalCents: d['TotalPrincipalCents'] as int? ?? 0,
        debtType: d['DebtType'] as int? ?? 1,
        subtype: d['Subtype'] as String? ?? '',
        contact: d['Contact'] as String? ?? '',
        contractRef: d['ContractRef'] as String? ?? '',
        collectionAccountId: Value(d['CollectionAccountID'] as String?),
        version: d['Version'] as int? ?? 1,
        createdAt: _dt(d['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.PaymentScheduleEntriesCompanion _scheduleRow(
          String debtId, Map<dynamic, dynamic> s) =>
      db.PaymentScheduleEntriesCompanion.insert(
        id: s['ID'] as String,
        debtId: debtId,
        paymentDate: _dt(s['PaymentDate']) ?? DateTime.now().toUtc(),
        principalCents: s['PrincipalCents'] as int? ?? 0,
        interestCents: s['InterestCents'] as int? ?? 0,
        totalCents: s['TotalCents'] as int? ?? 0,
        paidCents: s['PaidCents'] as int? ?? 0,
        paid: s['Paid'] as bool? ?? false,
        transactionId: Value(s['TransactionID'] as String?),
      );

  db.BudgetsCompanion _budgetRow(Map<dynamic, dynamic> b) =>
      db.BudgetsCompanion.insert(
        id: b['ID'] as String,
        name: b['Name'] as String? ?? '',
        month: b['Month'] as String? ?? '',
        totalAmountCents: b['TotalAmountCents'] as int? ?? 0,
        currencyCode: b['CurrencyCode'] as String? ?? 'CNY',
        isActive: b['IsActive'] as bool? ?? true,
        version: b['Version'] as int? ?? 1,
        createdAt: _dt(b['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.BudgetItemsCompanion _budgetItemRow(
          String budgetId, Map<dynamic, dynamic> i) =>
      db.BudgetItemsCompanion.insert(
        id: i['ID'] as String,
        budgetId: budgetId,
        accountId: i['AccountID'] as String,
        plannedAmountCents: i['PlannedAmountCents'] as int? ?? 0,
        actualAmountCents: i['ActualAmountCents'] as int? ?? 0,
        notes: i['Notes'] as String? ?? '',
      );

  db.GoalsCompanion _goalRow(Map<dynamic, dynamic> g) =>
      db.GoalsCompanion.insert(
        id: g['ID'] as String,
        name: g['Name'] as String? ?? '',
        goalType: g['GoalType'] as int? ?? 1,
        targetAmountCents: g['TargetAmountCents'] as int? ?? 0,
        currentAmountCents: g['CurrentAmountCents'] as int? ?? 0,
        currencyCode: g['CurrencyCode'] as String? ?? 'CNY',
        deadline: Value(_dt(g['Deadline'])),
        notes: g['Notes'] as String? ?? '',
        isCompleted: g['IsCompleted'] as bool? ?? false,
        version: g['Version'] as int? ?? 1,
        createdAt: _dt(g['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.TagsCompanion _tagRow(Map<dynamic, dynamic> t) =>
      db.TagsCompanion.insert(
        id: t['ID'] as String,
        name: t['Name'] as String? ?? '',
        color: t['Color'] as String? ?? '#000000',
        version: t['Version'] as int? ?? 1,
        createdAt: _dt(t['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.TransactionTemplatesCompanion _templateRow(Map<dynamic, dynamic> t) =>
      db.TransactionTemplatesCompanion.insert(
        id: t['ID'] as String,
        name: t['Name'] as String? ?? '',
        description: t['Description'] as String? ?? '',
        amountCents: t['AmountCents'] as int? ?? 0,
        direction: t['Direction'] as int? ?? 0,
        sourceAccountId: t['SourceAccountID'] as String? ?? '',
        destinationAccountId: Value(t['DestinationAccountID'] as String?),
        cycle: t['Cycle'] as int? ?? 0,
        cycleDays: t['CycleDays'] as int? ?? 0,
        billingDay: t['BillingDay'] as int? ?? 0,
        nextDate: _dt(t['NextDate']) ?? DateTime.now().toUtc(),
        startDate: _dt(t['StartDate']) ?? DateTime.now().toUtc(),
        endDate: Value(_dt(t['EndDate'])),
        autoRecord: t['AutoRecord'] as bool? ?? false,
        paused: t['Paused'] as bool? ?? false,
        lastTransactionId: Value(t['LastTransactionID'] as String?),
        category: t['Category'] as String? ?? '',
        version: t['Version'] as int? ?? 1,
        createdAt: _dt(t['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.HoldingsCompanion _holdingRow(Map<dynamic, dynamic> h) =>
      db.HoldingsCompanion.insert(
        id: h['ID'] as String,
        accountId: h['AccountID'] as String,
        securityId: h['SecurityID'] as String,
        quantity: (h['Quantity'] as num?)?.toDouble() ?? 0,
        avgCostCents: h['AvgCostCents'] as int? ?? 0,
        version: h['Version'] as int? ?? 1,
        createdAt: _dt(h['CreatedAt']) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

  db.HoldingTransactionsCompanion _holdingTxnRow(Map<dynamic, dynamic> t) =>
      db.HoldingTransactionsCompanion.insert(
        id: t['ID'] as String,
        accountId: t['AccountID'] as String,
        securityId: t['SecurityID'] as String,
        tradeType: t['TradeType'] as int? ?? 1,
        quantity: (t['Quantity'] as num?)?.toDouble() ?? 0,
        priceCents: t['PriceCents'] as int? ?? 0,
        amountCents: t['AmountCents'] as int? ?? 0,
        feeCents: t['FeeCents'] as int? ?? 0,
        realizedPnlCents: t['RealizedPnLCents'] as int? ?? 0,
        tradeDate: _dt(t['TradeDate']) ?? DateTime.now().toUtc(),
        transactionId: Value(t['TransactionID'] as String?),
        notes: t['Notes'] as String? ?? '',
        createdAt: _dt(t['CreatedAt']) ?? DateTime.now().toUtc(),
      );
}
