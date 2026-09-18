// Entity → drift row mappers for the bound-state mirror (design ADR-5):
// inverses of the D/E local-ds row→entity mappers. Entities missing
// drift-only columns (chartCode/isSystem/...) take the same defaults the
// guest write path uses.
import 'package:drift/drift.dart' hide Column;

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';

DateTime _utc(DateTime d) => d.toUtc();

db.AccountsCompanion mirrorAccountToRow(Account e, DateTime now) =>
    db.AccountsCompanion.insert(
      id: e.id,
      name: e.name,
      accountType: e.accountType.index + 1,
      category: e.category.index + 1,
      currencyCode: e.currencyCode,
      initialBalanceCents: e.initialBalanceCents,
      currentBalanceCents: e.currentBalanceCents,
      ownership: e.ownership.index + 1,
      icon: e.icon,
      color: e.color,
      chartCode: '',
      parentId: Value(e.parentId.isEmpty ? null : e.parentId),
      isSystem: false,
      sortOrder: 0,
      institution: e.institution,
      creditLimitCents: Value(e.creditLimitCents == 0 ? null : e.creditLimitCents),
      cardNumberTail: e.cardNumberTail,
      notes: e.notes,
      openingDate: Value(e.openingDate?.toUtc()),
      interestRate: Value(e.interestRate),
      creditBillingDay: Value(e.creditBillingDay),
      creditRepaymentDay: Value(e.creditRepaymentDay),
      creditAnnualFeeCents: Value(e.creditAnnualFeeCents),
      investCostCents: Value(e.investCostCents),
      investMarketValueCents: Value(e.investMarketValueCents),
      investReturnYtd: Value(e.investReturnYtd),
      fixedPrincipalCents: Value(e.fixedPrincipalCents),
      fixedStartDate: Value(e.fixedStartDate?.toUtc()),
      fixedMaturityDate: Value(e.fixedMaturityDate?.toUtc()),
      fixedTermMonths: Value(e.fixedTermMonths),
      goldProductType: e.goldProductType,
      goldQuantity: Value(e.goldQuantity),
      goldBuyPriceCents: Value(e.goldBuyPriceCents),
      goldCurrentPriceCents: Value(e.goldCurrentPriceCents),
      estatePurchasePriceCents: Value(e.estatePurchasePriceCents),
      estateCurrentValueCents: Value(e.estateCurrentValueCents),
      estatePurchaseDate: Value(e.estatePurchaseDate?.toUtc()),
      estateDepreciationRate: Value(e.estateDepreciationRate),
      loanOriginalCents: Value(e.loanOriginalCents),
      loanRemainingCents: Value(e.loanRemainingCents),
      loanMonthlyCents: Value(e.loanMonthlyCents),
      loanNextPaymentDate: Value(e.loanNextPaymentDate?.toUtc()),
      status: e.status.index + 1,
      version: e.version,
      createdAt: e.createdAt?.toUtc() ?? now,
      updatedAt: now,
    );

db.TransactionsCompanion mirrorTransactionToRow(Transaction t) =>
    db.TransactionsCompanion.insert(
      id: t.id,
      transactionDate: _utc(t.transactionDate),
      transactionTime: Value(t.transactionTime?.toUtc()),
      description: t.description,
      version: t.version,
      createdAt: t.createdAt?.toUtc() ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

db.TransactionEntriesCompanion mirrorEntryToRow(
        String txnId, TransactionEntry e) =>
    db.TransactionEntriesCompanion.insert(
      id: e.id.isEmpty ? '' : e.id,
      transactionId: txnId,
      accountId: e.accountId,
      chartOfAccountCode: '',
      debitCents: e.debitCents,
      creditCents: e.creditCents,
      note: e.note,
    );

db.DebtsCompanion mirrorDebtToRow(Debt d) => db.DebtsCompanion.insert(
      id: d.id,
      accountId: d.accountId,
      counterparty: d.counterparty,
      interestRate: d.interestRate,
      amortizationMethod: d.amortization.index + 1,
      cycle: Value(d.cycle),
      interval: Value(d.interval),
      weekdayMask: Value(d.weekdayMask),
      monthlyMode: Value(d.monthlyMode),
      nth: Value(d.nth),
      interestWaivedCents: Value(d.interestWaivedCents),
      startDate: _utc(d.startDate),
      dueDate: _utc(d.dueDate),
      totalPrincipalCents: d.totalPrincipalCents,
      debtType: d.type.index + 1,
      subtype: d.subtype,
      contact: d.contact,
      contractRef: d.contractRef,
      guarantorName: Value(d.guarantorName),
      guarantorContact: Value(d.guarantorContact),
      collectionAccountId: Value(d.collectionAccountId),
      version: d.version,
      createdAt: _utc(d.createdAt),
      updatedAt: _utc(d.updatedAt),
    );

db.PaymentScheduleEntriesCompanion mirrorScheduleToRow(
        String debtId, PaymentEntry s) =>
    db.PaymentScheduleEntriesCompanion.insert(
      id: s.id,
      debtId: debtId,
      paymentDate: _utc(s.paymentDate),
      principalCents: s.principalCents,
      interestCents: s.interestCents,
      totalCents: s.totalCents,
      paidCents: s.paidCents,
      paid: s.paid,
      transactionId: Value(s.transactionId.isEmpty ? null : s.transactionId),
    );

db.BudgetsCompanion mirrorBudgetToRow(BudgetView b) =>
    db.BudgetsCompanion.insert(
      id: b.id,
      name: b.name,
      month: b.month,
      totalAmountCents: b.totalAmountCents,
      currencyCode: b.currencyCode,
      isActive: true,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

db.BudgetItemsCompanion mirrorBudgetItemToRow(
        String budgetId, BudgetItemView i) =>
    db.BudgetItemsCompanion.insert(
      id: i.id,
      budgetId: budgetId,
      accountId: i.accountId,
      plannedAmountCents: i.plannedAmountCents,
      actualAmountCents: i.actualAmountCents,
      notes: i.notes ?? '',
    );

db.GoalsCompanion mirrorGoalToRow(GoalView g) => db.GoalsCompanion.insert(
      id: g.id,
      name: g.name,
      goalType: g.type.index + 1,
      targetAmountCents: g.targetAmountCents,
      currentAmountCents: g.currentAmountCents,
      currencyCode: g.currencyCode,
      deadline: Value(g.deadline?.toUtc()),
      notes: g.notes ?? '',
      isCompleted: g.isCompleted,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

db.TagsCompanion mirrorTagToRow(Tag t) => db.TagsCompanion.insert(
      id: t.id,
      name: t.name,
      color: t.color,
      version: t.version,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

DateTime? _dateOnlyOrNull(String? s) {
  if (s == null || s.isEmpty) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

DateTime _dateOnly(String? s) {
  if (s == null || s.isEmpty) return DateTime.now().toUtc();
  final d = DateTime.tryParse(s);
  return d == null
      ? DateTime.now().toUtc()
      : DateTime.utc(d.year, d.month, d.day);
}

db.TransactionTemplatesCompanion mirrorTemplateToRow(Template t) =>
    db.TransactionTemplatesCompanion.insert(
      id: t.id,
      name: t.name,
      description: t.description,
      amountCents: t.amountCents,
      direction: t.direction.index,
      sourceAccountId: t.sourceAccountId ?? '',
      destinationAccountId: Value(t.destinationAccountId),
      cycle: t.cycle.index,
      cycleDays: t.cycleDays,
      billingDay: t.billingDay,
      interval: Value(t.interval),
      weekdayMask: Value(t.weekdayMask),
      monthlyMode: Value(t.monthlyMode == TemplateMonthlyMode.byNthWeekday ? 1 : 0),
      nth: Value(t.nth),
      nextDate: _dateOnly(t.nextDate),
      startDate: _dateOnly(t.startDate),
      endDate: Value(_dateOnlyOrNull(t.endDate)),
      autoRecord: t.autoRecord,
      paused: t.paused,
      lastTransactionId: Value(t.lastTransactionId),
      category: t.category ?? '',
      version: t.version,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    );

db.HoldingsCompanion mirrorHoldingToRow(Holding h) =>
    db.HoldingsCompanion.insert(
      id: h.id,
      accountId: h.accountId,
      securityId: h.securityId,
      quantity: h.quantity,
      avgCostCents: h.avgCostCents,
      version: h.version,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

db.HoldingTransactionsCompanion mirrorHoldingTxnToRow(
        HoldingTransaction t) =>
    db.HoldingTransactionsCompanion.insert(
      id: t.id,
      accountId: t.accountId,
      securityId: t.securityId,
      tradeType: t.tradeType.index + 1,
      quantity: t.quantity,
      priceCents: t.priceCents,
      amountCents: t.amountCents,
      feeCents: t.feeCents,
      realizedPnlCents: 0,
      tradeDate: _dateOnly(t.tradeDate),
      transactionId: const Value(null),
      notes: t.notes ?? '',
      createdAt: t.createdAt ?? DateTime.now().toUtc(),
    );

db.SecuritiesCompanion mirrorSecurityToRow(Security s) =>
    db.SecuritiesCompanion.insert(
      id: s.id,
      symbol: s.symbol,
      name: s.name,
      securityType: s.securityType.name,
      exchange: s.exchange ?? '',
      currencyCode: s.currency,
      currentPriceCents: s.currentPriceCents,
      createdAt: s.createdAt ?? DateTime.now().toUtc(),
    );
