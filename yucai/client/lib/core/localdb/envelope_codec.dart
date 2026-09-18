/// F11 T3(spec FR-4,design ADR-2):server 兼容 envelope **行序列化**的单一
/// 事实源 —— drift 行 → 备份 envelope 的 PascalCase 行形态(per-row)。
///
/// 2026-09-05 从 `backup/data/local_snapshot_exporter.dart` 原位抽取(逐字段
/// 等价,非重写):备份导出(F6 往返 e2e 守门)与 F11 离线上行 payload 编码
/// 共用同一份映射,防字段漂移(design Risk 表「字段映射漂移」的缓解项)。
///
/// wire 契约(server 各模块 domain struct 为无 json tag 的 Go struct,默认
/// 命名即契约;server 侧接受面由 F11 T2 集成测试钉死):
/// - 键 PascalCase;枚举 int 直传;时间戳 RFC3339 显式 `Z`;null 直传 null;
/// - 子表嵌套(交易分录 Entries / 债务期次 Schedule / 预算项 Items / 目标
///   链接 uuid 数组);holding 为**单持仓行**形态(server HoldingWriter 契约,
///   非备份模块的 {holdings, transactions} 双子数组模块形态);
/// - 无 TenantID 键(鉴权 tenant 恒赢,防注入)、无 syncState 键(本地私有列)。
library;

import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// RFC3339 时间戳:UTC 化后显式 `Z`(Go time.Time 精确往返);null 直传。
String? envelopeTimestamp(DateTime? d) {
  if (d == null) return null;
  final utc = d.toUtc();
  final iso = utc.toIso8601String();
  return iso.endsWith('Z') ? iso : '${iso}Z';
}

/// 账户行 → envelope 行(键集与 T2 `syncAccountRow` 逐字对齐)。
Map<String, dynamic> accountRowToEnvelope(db.Account r) => {
      'ID': r.id,
      'Name': r.name,
      'AccountType': r.accountType,
      'Category': r.category,
      'CurrencyCode': r.currencyCode,
      'InitialBalanceCents': r.initialBalanceCents,
      'CurrentBalanceCents': r.currentBalanceCents,
      'Ownership': r.ownership,
      'Icon': r.icon,
      'Color': r.color,
      'ChartCode': r.chartCode,
      'ParentID': r.parentId,
      'IsSystem': r.isSystem,
      'SortOrder': r.sortOrder,
      'Institution': r.institution,
      'CreditLimitCents': r.creditLimitCents,
      'CardNumberTail': r.cardNumberTail,
      'Notes': r.notes,
      'OpeningDate': envelopeTimestamp(r.openingDate),
      'InterestRate': r.interestRate,
      'CreditBillingDay': r.creditBillingDay,
      'CreditRepaymentDay': r.creditRepaymentDay,
      'CreditAnnualFeeCents': r.creditAnnualFeeCents,
      'InvestCostCents': r.investCostCents,
      'InvestMarketValueCents': r.investMarketValueCents,
      'InvestReturnYtd': r.investReturnYtd,
      'FixedPrincipalCents': r.fixedPrincipalCents,
      'FixedStartDate': envelopeTimestamp(r.fixedStartDate),
      'FixedMaturityDate': envelopeTimestamp(r.fixedMaturityDate),
      'FixedTermMonths': r.fixedTermMonths,
      'GoldProductType': r.goldProductType,
      'GoldQuantity': r.goldQuantity,
      'GoldBuyPriceCents': r.goldBuyPriceCents,
      'GoldCurrentPriceCents': r.goldCurrentPriceCents,
      'EstatePurchasePriceCents': r.estatePurchasePriceCents,
      'EstateCurrentValueCents': r.estateCurrentValueCents,
      'EstatePurchaseDate': envelopeTimestamp(r.estatePurchaseDate),
      'EstateDepreciationRate': r.estateDepreciationRate,
      'LoanOriginalCents': r.loanOriginalCents,
      'LoanRemainingCents': r.loanRemainingCents,
      'LoanMonthlyCents': r.loanMonthlyCents,
      'LoanNextPaymentDate': envelopeTimestamp(r.loanNextPaymentDate),
      'Status': r.status,
      'Version': r.version,
      'DeletedAt': null, // 本地删除=硬删+墓碑,无软删语义
      'CreatedAt': envelopeTimestamp(r.createdAt),
      'UpdatedAt': envelopeTimestamp(r.updatedAt),
    };

/// 交易头行(含分录集合)→ envelope 行。
Map<String, dynamic> transactionRowToEnvelope(
  db.Transaction h,
  List<db.TransactionEntry> entries,
) =>
    {
      'ID': h.id,
      'TransactionDate': envelopeTimestamp(h.transactionDate),
      'TransactionTime': envelopeTimestamp(h.transactionTime),
      'Description': h.description,
      'Entries': entries
          .map((e) => {
                'ID': e.id,
                'TransactionID': e.transactionId,
                'AccountID': e.accountId,
                'ChartOfAccountCode': e.chartOfAccountCode,
                'DebitCents': e.debitCents,
                'CreditCents': e.creditCents,
                'Note': e.note,
              })
          .toList(),
      'Version': h.version,
      'DeletedAt': null,
      'CreatedAt': envelopeTimestamp(h.createdAt),
      'UpdatedAt': envelopeTimestamp(h.updatedAt),
    };

/// 债务头行(含还款期次)→ envelope 行。
Map<String, dynamic> debtRowToEnvelope(
  db.Debt d,
  List<db.PaymentScheduleEntry> schedule,
) =>
    {
      'ID': d.id,
      'AccountID': d.accountId,
      'Counterparty': d.counterparty,
      'InterestRate': d.interestRate,
      'AmortizationMethod': d.amortizationMethod,
      'Cycle': d.cycle,
      'Interval': d.interval,
      'WeekdayMask': d.weekdayMask,
      'MonthlyMode': d.monthlyMode,
      'Nth': d.nth,
      'InterestWaivedCents': d.interestWaivedCents,
      'StartDate': envelopeTimestamp(d.startDate),
      'DueDate': envelopeTimestamp(d.dueDate),
      'TotalPrincipalCents': d.totalPrincipalCents,
      'DebtType': d.debtType,
      'Subtype': d.subtype,
      'Contact': d.contact,
      'ContractRef': d.contractRef,
      'GuarantorName': d.guarantorName,
      'GuarantorContact': d.guarantorContact,
      'CollectionAccountID': d.collectionAccountId,
      'Schedule': schedule
          .map((s) => {
                'ID': s.id,
                'DebtID': s.debtId,
                'PaymentDate': envelopeTimestamp(s.paymentDate),
                'PrincipalCents': s.principalCents,
                'InterestCents': s.interestCents,
                'TotalCents': s.totalCents,
                'PaidCents': s.paidCents,
                'Paid': s.paid,
                'TransactionID': s.transactionId,
              })
          .toList(),
      'Version': d.version,
      'CreatedAt': envelopeTimestamp(d.createdAt),
      'UpdatedAt': envelopeTimestamp(d.updatedAt),
    };

/// 预算头行(含预算项)→ envelope 行。
Map<String, dynamic> budgetRowToEnvelope(
  db.Budget b,
  List<db.BudgetItem> items,
) =>
    {
      'ID': b.id,
      'Name': b.name,
      'Month': b.month,
      'TotalAmountCents': b.totalAmountCents,
      'CurrencyCode': b.currencyCode,
      'IsActive': b.isActive,
      'Items': items
          .map((i) => {
                'ID': i.id,
                'BudgetID': i.budgetId,
                'AccountID': i.accountId,
                'PlannedAmountCents': i.plannedAmountCents,
                'ActualAmountCents': i.actualAmountCents,
                'Notes': i.notes,
              })
          .toList(),
      'Version': b.version,
      'DeletedAt': null,
      'CreatedAt': envelopeTimestamp(b.createdAt),
      'UpdatedAt': envelopeTimestamp(b.updatedAt),
    };

/// 目标行(链接表已折叠为 uuid 数组)→ envelope 行。
Map<String, dynamic> goalRowToEnvelope(
  db.Goal g,
  List<String> linkedAccountIds,
  List<String> linkedDebtIds,
) =>
    {
      'ID': g.id,
      'Name': g.name,
      'GoalType': g.goalType,
      'TargetAmountCents': g.targetAmountCents,
      'CurrentAmountCents': g.currentAmountCents,
      'CurrencyCode': g.currencyCode,
      'Deadline': envelopeTimestamp(g.deadline),
      'LinkedAccountIDs': linkedAccountIds,
      'LinkedDebtIDs': linkedDebtIds,
      'Notes': g.notes,
      'IsCompleted': g.isCompleted,
      'CompletedAt': envelopeTimestamp(g.completedAt),
      'Version': g.version,
      'CreatedAt': envelopeTimestamp(g.createdAt),
      'UpdatedAt': envelopeTimestamp(g.updatedAt),
    };

/// 持仓头行 → envelope 行(**单行形态**,server HoldingWriter 契约;台账行
/// 不嵌套随行 —— append-only 台账走独立 holding_ledger entityType,见下方
/// holdingTxnRowToEnvelope)。
Map<String, dynamic> holdingRowToEnvelope(db.Holding h) => {
      'ID': h.id,
      'AccountID': h.accountId,
      'SecurityID': h.securityId,
      'Quantity': h.quantity,
      'AvgCostCents': h.avgCostCents,
      'Version': h.version,
      'CreatedAt': envelopeTimestamp(h.createdAt),
      'UpdatedAt': envelopeTimestamp(h.updatedAt),
    };

/// 持仓台账行 → envelope 行(备份 envelope 的 holding.transactions 子数组
/// 内的行形态;F17-T2 起同步上行消费 —— holding_ledger entityType 的行
/// 形态,server HoldingLedgerWriter + PullApplier 同一份契约)。
Map<String, dynamic> holdingTxnRowToEnvelope(db.HoldingTransaction t) => {
      'ID': t.id,
      'AccountID': t.accountId,
      'SecurityID': t.securityId,
      'TradeType': t.tradeType,
      'Quantity': t.quantity,
      'PriceCents': t.priceCents,
      'AmountCents': t.amountCents,
      'FeeCents': t.feeCents,
      'RealizedPnLCents': t.realizedPnlCents,
      'TradeDate': envelopeTimestamp(t.tradeDate),
      'TransactionID': t.transactionId,
      'Notes': t.notes,
      'CreatedAt': envelopeTimestamp(t.createdAt),
    };

/// 标签行 → envelope 行。
Map<String, dynamic> tagRowToEnvelope(db.Tag t) => {
      'ID': t.id,
      'Name': t.name,
      'Color': t.color,
      'Version': t.version,
      'DeletedAt': null,
      'CreatedAt': envelopeTimestamp(t.createdAt),
      'UpdatedAt': envelopeTimestamp(t.updatedAt),
    };

/// 模板行 → envelope 行。
Map<String, dynamic> templateRowToEnvelope(db.TransactionTemplate r) => {
      'ID': r.id,
      'Name': r.name,
      'Description': r.description,
      'AmountCents': r.amountCents,
      'Direction': r.direction,
      'SourceAccountID': r.sourceAccountId,
      'DestinationAccountID': r.destinationAccountId,
      'Cycle': r.cycle,
      'CycleDays': r.cycleDays,
      'BillingDay': r.billingDay,
      'Interval': r.interval,
      'WeekdayMask': r.weekdayMask,
      'MonthlyMode': r.monthlyMode,
      'Nth': r.nth,
      'NextDate': envelopeTimestamp(r.nextDate),
      'StartDate': envelopeTimestamp(r.startDate),
      'EndDate': envelopeTimestamp(r.endDate),
      'AutoRecord': r.autoRecord,
      'Paused': r.paused,
      'LastTransactionID': r.lastTransactionId,
      'Category': r.category,
      'Version': r.version,
      'CreatedAt': envelopeTimestamp(r.createdAt),
      'UpdatedAt': envelopeTimestamp(r.updatedAt),
    };
