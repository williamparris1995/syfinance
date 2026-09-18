/// F17-T2(spec FR-3,design ADR-2):envelope 行 → drift 行(Companion)的
/// **单一事实源** —— 与 `envelope_codec.dart`(drift → envelope 行)互为逆。
///
/// 2026-09-06 从 `backup/data/archive_importer.dart` 原位抽取(逐字段等价,
/// 非重写):备份导入(purge+全量 insert)与 F17 增量下行(PullApplier 的
/// 单行 upsert)共用同一份行映射,防字段漂移(design Risk 表「字段映射漂移」
/// 缓解项的下行侧延伸)。**单一事实源策略**:任何 envelope 键的增删改只在
/// 本文件与 envelope_codec.dart 各改一处,两个消费方(导入/拉取)自动一致;
/// server 侧接受面由 F11 T2 集成测试 + 本文件消费方测试共同钉死。
///
/// 行形态契约(与 envelope_codec.dart 同一份):PascalCase 键/int 枚举/
/// RFC3339 Z 时间戳/null 直传/子表随头行嵌套(Entries/Schedule/Items/
/// Linked*IDs);无 TenantID 键(鉴权 tenant 恒赢)、无 syncState 本地私有列。
/// 映射对缺键宽容(?? 默认值)—— server 历史行/前向兼容行可安全落库。
library;

import 'package:drift/drift.dart' hide Column;
import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// RFC3339 时间戳解析:null 直传 null;解析后 UTC 化(drift 文本时间列与
/// envelope 的 Z 形态互逆)。
DateTime? envelopeTimestampOf(dynamic v) =>
    v == null ? null : (DateTime.tryParse(v.toString())?.toUtc());

/// 账户行 → AccountsCompanion。
db.AccountsCompanion accountRowFromEnvelope(Map<dynamic, dynamic> a) =>
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
      openingDate: Value(envelopeTimestampOf(a['OpeningDate'])),
      interestRate: Value((a['InterestRate'] as num?)?.toDouble()),
      creditBillingDay: Value(a['CreditBillingDay'] as int?),
      creditRepaymentDay: Value(a['CreditRepaymentDay'] as int?),
      creditAnnualFeeCents: Value(a['CreditAnnualFeeCents'] as int?),
      investCostCents: Value(a['InvestCostCents'] as int?),
      investMarketValueCents: Value(a['InvestMarketValueCents'] as int?),
      investReturnYtd: Value((a['InvestReturnYtd'] as num?)?.toDouble()),
      fixedPrincipalCents: Value(a['FixedPrincipalCents'] as int?),
      fixedStartDate: Value(envelopeTimestampOf(a['FixedStartDate'])),
      fixedMaturityDate: Value(envelopeTimestampOf(a['FixedMaturityDate'])),
      fixedTermMonths: Value(a['FixedTermMonths'] as int?),
      goldProductType: a['GoldProductType'] as String? ?? '',
      goldQuantity: Value((a['GoldQuantity'] as num?)?.toDouble()),
      goldBuyPriceCents: Value(a['GoldBuyPriceCents'] as int?),
      goldCurrentPriceCents: Value(a['GoldCurrentPriceCents'] as int?),
      estatePurchasePriceCents: Value(a['EstatePurchasePriceCents'] as int?),
      estateCurrentValueCents: Value(a['EstateCurrentValueCents'] as int?),
      estatePurchaseDate: Value(envelopeTimestampOf(a['EstatePurchaseDate'])),
      estateDepreciationRate:
          Value((a['EstateDepreciationRate'] as num?)?.toDouble()),
      loanOriginalCents: Value(a['LoanOriginalCents'] as int?),
      loanRemainingCents: Value(a['LoanRemainingCents'] as int?),
      loanMonthlyCents: Value(a['LoanMonthlyCents'] as int?),
      loanNextPaymentDate: Value(envelopeTimestampOf(a['LoanNextPaymentDate'])),
      status: a['Status'] as int? ?? 1,
      version: a['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(a['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 交易头行 → TransactionsCompanion。
db.TransactionsCompanion transactionRowFromEnvelope(
        Map<dynamic, dynamic> t) =>
    db.TransactionsCompanion.insert(
      id: t['ID'] as String,
      transactionDate:
          envelopeTimestampOf(t['TransactionDate']) ?? DateTime.now().toUtc(),
      transactionTime: Value(envelopeTimestampOf(t['TransactionTime'])),
      description: t['Description'] as String? ?? '',
      version: t['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(t['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 交易分录行 → TransactionEntriesCompanion(锚回头行 id)。
db.TransactionEntriesCompanion entryRowFromEnvelope(
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

/// 债务头行 → DebtsCompanion。
db.DebtsCompanion debtRowFromEnvelope(Map<dynamic, dynamic> d) =>
    db.DebtsCompanion.insert(
      id: d['ID'] as String,
      accountId: d['AccountID'] as String,
      counterparty: d['Counterparty'] as String? ?? '',
      interestRate: (d['InterestRate'] as num?)?.toDouble() ?? 0,
      amortizationMethod: d['AmortizationMethod'] as int? ?? 1,
      cycle: Value(d['Cycle'] as int? ?? 2),
      interval: Value(d['Interval'] as int? ?? 1),
      weekdayMask: Value(d['WeekdayMask'] as int? ?? 0),
      monthlyMode: Value(d['MonthlyMode'] as int? ?? 0),
      nth: Value(d['Nth'] as int? ?? 0),
      interestWaivedCents: Value(d['InterestWaivedCents'] as int? ?? 0),
      startDate: envelopeTimestampOf(d['StartDate']) ?? DateTime.now().toUtc(),
      dueDate: envelopeTimestampOf(d['DueDate']) ?? DateTime.now().toUtc(),
      totalPrincipalCents: d['TotalPrincipalCents'] as int? ?? 0,
      debtType: d['DebtType'] as int? ?? 1,
      subtype: d['Subtype'] as String? ?? '',
      contact: d['Contact'] as String? ?? '',
      contractRef: d['ContractRef'] as String? ?? '',
      collectionAccountId: Value(d['CollectionAccountID'] as String?),
      version: d['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(d['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 债务期次行 → PaymentScheduleEntriesCompanion(锚回债务头行 id)。
db.PaymentScheduleEntriesCompanion scheduleRowFromEnvelope(
        String debtId, Map<dynamic, dynamic> s) =>
    db.PaymentScheduleEntriesCompanion.insert(
      id: s['ID'] as String,
      debtId: debtId,
      paymentDate:
          envelopeTimestampOf(s['PaymentDate']) ?? DateTime.now().toUtc(),
      principalCents: s['PrincipalCents'] as int? ?? 0,
      interestCents: s['InterestCents'] as int? ?? 0,
      totalCents: s['TotalCents'] as int? ?? 0,
      paidCents: s['PaidCents'] as int? ?? 0,
      paid: s['Paid'] as bool? ?? false,
      transactionId: Value(s['TransactionID'] as String?),
    );

/// 预算头行 → BudgetsCompanion。
db.BudgetsCompanion budgetRowFromEnvelope(Map<dynamic, dynamic> b) =>
    db.BudgetsCompanion.insert(
      id: b['ID'] as String,
      name: b['Name'] as String? ?? '',
      month: b['Month'] as String? ?? '',
      totalAmountCents: b['TotalAmountCents'] as int? ?? 0,
      currencyCode: b['CurrencyCode'] as String? ?? 'CNY',
      isActive: b['IsActive'] as bool? ?? true,
      version: b['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(b['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 预算项行 → BudgetItemsCompanion(锚回预算头行 id)。
db.BudgetItemsCompanion budgetItemRowFromEnvelope(
        String budgetId, Map<dynamic, dynamic> i) =>
    db.BudgetItemsCompanion.insert(
      id: i['ID'] as String,
      budgetId: budgetId,
      accountId: i['AccountID'] as String,
      plannedAmountCents: i['PlannedAmountCents'] as int? ?? 0,
      actualAmountCents: i['ActualAmountCents'] as int? ?? 0,
      notes: i['Notes'] as String? ?? '',
    );

/// 目标行 → GoalsCompanion。
db.GoalsCompanion goalRowFromEnvelope(Map<dynamic, dynamic> g) =>
    db.GoalsCompanion.insert(
      id: g['ID'] as String,
      name: g['Name'] as String? ?? '',
      goalType: g['GoalType'] as int? ?? 1,
      targetAmountCents: g['TargetAmountCents'] as int? ?? 0,
      currentAmountCents: g['CurrentAmountCents'] as int? ?? 0,
      currencyCode: g['CurrencyCode'] as String? ?? 'CNY',
      deadline: Value(envelopeTimestampOf(g['Deadline'])),
      notes: g['Notes'] as String? ?? '',
      isCompleted: g['IsCompleted'] as bool? ?? false,
      version: g['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(g['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 标签行 → TagsCompanion。
db.TagsCompanion tagRowFromEnvelope(Map<dynamic, dynamic> t) =>
    db.TagsCompanion.insert(
      id: t['ID'] as String,
      name: t['Name'] as String? ?? '',
      color: t['Color'] as String? ?? '#000000',
      version: t['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(t['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 模板行 → TransactionTemplatesCompanion。
db.TransactionTemplatesCompanion templateRowFromEnvelope(
        Map<dynamic, dynamic> t) =>
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
      interval: Value(t['Interval'] as int? ?? 1),
      weekdayMask: Value(t['WeekdayMask'] as int? ?? 0),
      monthlyMode: Value(t['MonthlyMode'] as int? ?? 0),
      nth: Value(t['Nth'] as int? ?? 0),
      nextDate:
          envelopeTimestampOf(t['NextDate']) ?? DateTime.now().toUtc(),
      startDate:
          envelopeTimestampOf(t['StartDate']) ?? DateTime.now().toUtc(),
      endDate: Value(envelopeTimestampOf(t['EndDate'])),
      autoRecord: t['AutoRecord'] as bool? ?? false,
      paused: t['Paused'] as bool? ?? false,
      lastTransactionId: Value(t['LastTransactionID'] as String?),
      category: t['Category'] as String? ?? '',
      version: t['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(t['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 持仓头行 → HoldingsCompanion(单行形态,server HoldingWriter 契约)。
db.HoldingsCompanion holdingRowFromEnvelope(Map<dynamic, dynamic> h) =>
    db.HoldingsCompanion.insert(
      id: h['ID'] as String,
      accountId: h['AccountID'] as String,
      securityId: h['SecurityID'] as String,
      quantity: (h['Quantity'] as num?)?.toDouble() ?? 0,
      avgCostCents: h['AvgCostCents'] as int? ?? 0,
      version: h['Version'] as int? ?? 1,
      createdAt:
          envelopeTimestampOf(h['CreatedAt']) ?? DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

/// 持仓台账行 → HoldingTransactionsCompanion(F17-T2:holding_ledger
/// entityType 的行形态,与备份 envelope 的 holding.transactions 子数组同构)。
db.HoldingTransactionsCompanion holdingTxnRowFromEnvelope(
        Map<dynamic, dynamic> t) =>
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
      tradeDate:
          envelopeTimestampOf(t['TradeDate']) ?? DateTime.now().toUtc(),
      transactionId: Value(t['TransactionID'] as String?),
      notes: t['Notes'] as String? ?? '',
      createdAt:
          envelopeTimestampOf(t['CreatedAt']) ?? DateTime.now().toUtc(),
    );
