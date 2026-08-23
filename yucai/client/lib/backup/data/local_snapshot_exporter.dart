import 'dart:convert';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// Exports the local drift store as a server-compatible BackupEnvelope
/// (R6 feature G, design ADR-3). Shape contract: the per-module JSON must be
/// structurally identical to the server exporters' domain-struct marshal —
/// PascalCase keys, int enums, RFC3339 timestamps, nested arrays (entries/
/// schedule/items), goal uuid arrays, holding's two sibling arrays. Go's
/// json.Unmarshal ignores unknown keys, so extra client fields are safe but
/// missing ones are not. Idempotent and read-only.
@LazySingleton()
class LocalSnapshotExporter {
  LocalSnapshotExporter(this._database);

  final db.AppDatabase _database;

  /// Serializes the full snapshot to envelope JSON bytes. `tenantId` is a
  /// placeholder — the server overrides it with the authenticated tenant.
  Future<Uint8List> exportAll({String tenantId = '00000000-0000-0000-0000-000000000000'}) async {
    final modules = <String, dynamic>{
      'account': await _exportAccounts(),
      'transaction': await _exportTransactions(),
      'debt': await _exportDebts(),
      'budget': await _exportBudgets(),
      'goal': await _exportGoals(),
      'tag': await _exportTags(),
      'template': await _exportTemplates(),
      'holding': await _exportHoldings(),
    };
    final envelope = {
      'Version': 1,
      'TenantID': tenantId,
      'CreatedAt': DateTime.now().toUtc().toIso8601String(),
      'Modules': modules,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  // ---- module mappers (drift row → server payload shape) ----

  Future<List<dynamic>> _exportAccounts() async {
    final rows = await _database.accountDao.getAllAccounts();
    return rows.map((r) => {
          'ID': r.id,
          'TenantID': '',
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
          'OpeningDate': _ts(r.openingDate),
          'InterestRate': r.interestRate,
          'CreditBillingDay': r.creditBillingDay,
          'CreditRepaymentDay': r.creditRepaymentDay,
          'CreditAnnualFeeCents': r.creditAnnualFeeCents,
          'InvestCostCents': r.investCostCents,
          'InvestMarketValueCents': r.investMarketValueCents,
          'InvestReturnYtd': r.investReturnYtd,
          'FixedPrincipalCents': r.fixedPrincipalCents,
          'FixedStartDate': _ts(r.fixedStartDate),
          'FixedMaturityDate': _ts(r.fixedMaturityDate),
          'FixedTermMonths': r.fixedTermMonths,
          'GoldProductType': r.goldProductType,
          'GoldQuantity': r.goldQuantity,
          'GoldBuyPriceCents': r.goldBuyPriceCents,
          'GoldCurrentPriceCents': r.goldCurrentPriceCents,
          'EstatePurchasePriceCents': r.estatePurchasePriceCents,
          'EstateCurrentValueCents': r.estateCurrentValueCents,
          'EstatePurchaseDate': _ts(r.estatePurchaseDate),
          'EstateDepreciationRate': r.estateDepreciationRate,
          'LoanOriginalCents': r.loanOriginalCents,
          'LoanRemainingCents': r.loanRemainingCents,
          'LoanMonthlyCents': r.loanMonthlyCents,
          'LoanNextPaymentDate': _ts(r.loanNextPaymentDate),
          'Status': r.status,
          'Version': r.version,
          'DeletedAt': null, // local deletes are hard deletes
          'CreatedAt': _ts(r.createdAt),
          'UpdatedAt': _ts(r.updatedAt),
        }).toList();
  }

  Future<List<dynamic>> _exportTransactions() async {
    final heads = await _database.transactionDao.getAllTransactions();
    final entries = await _database.transactionDao.getAllEntries();
    final byTxn = <String, List<db.TransactionEntry>>{};
    for (final e in entries) {
      byTxn.putIfAbsent(e.transactionId, () => []).add(e);
    }
    return heads.map((h) => {
          'ID': h.id,
          'TenantID': '',
          'TransactionDate': _ts(h.transactionDate),
          'TransactionTime': _ts(h.transactionTime),
          'Description': h.description,
          'Entries': (byTxn[h.id] ?? [])
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
          'CreatedAt': _ts(h.createdAt),
          'UpdatedAt': _ts(h.updatedAt),
        }).toList();
  }

  Future<List<dynamic>> _exportDebts() async {
    final debts = await _database.debtDao.watchAllDebts().first;
    final out = <dynamic>[];
    for (final d in debts) {
      final schedule = await _database.debtDao.getScheduleByDebt(d.id);
      out.add({
        'ID': d.id,
        'TenantID': '',
        'AccountID': d.accountId,
        'Counterparty': d.counterparty,
        'InterestRate': d.interestRate,
        'AmortizationMethod': d.amortizationMethod,
        'StartDate': _ts(d.startDate),
        'DueDate': _ts(d.dueDate),
        'TotalPrincipalCents': d.totalPrincipalCents,
        'DebtType': d.debtType,
        'Subtype': d.subtype,
        'Contact': d.contact,
        'ContractRef': d.contractRef,
        'CollectionAccountID': d.collectionAccountId,
        'Schedule': schedule
            .map((s) => {
                  'ID': s.id,
                  'DebtID': s.debtId,
                  'PaymentDate': _ts(s.paymentDate),
                  'PrincipalCents': s.principalCents,
                  'InterestCents': s.interestCents,
                  'TotalCents': s.totalCents,
                  'PaidCents': s.paidCents,
                  'Paid': s.paid,
                  'TransactionID': s.transactionId,
                })
            .toList(),
        'Version': d.version,
        'CreatedAt': _ts(d.createdAt),
        'UpdatedAt': _ts(d.updatedAt),
      });
    }
    return out;
  }

  Future<List<dynamic>> _exportBudgets() async {
    final budgets = await _database.budgetDao.watchAllBudgets().first;
    final out = <dynamic>[];
    for (final b in budgets) {
      final items = await _database.budgetDao.getItemsByBudget(b.id);
      out.add({
        'ID': b.id,
        'TenantID': '',
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
        'CreatedAt': _ts(b.createdAt),
        'UpdatedAt': _ts(b.updatedAt),
      });
    }
    return out;
  }

  Future<List<dynamic>> _exportGoals() async {
    final goals = await _database.goalDao.watchAllGoals().first;
    final out = <dynamic>[];
    for (final g in goals) {
      final (accounts, debts) = await _database.goalDao.linksFor(g.id);
      out.add({
        'ID': g.id,
        'TenantID': '',
        'Name': g.name,
        'GoalType': g.goalType,
        'TargetAmountCents': g.targetAmountCents,
        'CurrentAmountCents': g.currentAmountCents,
        'CurrencyCode': g.currencyCode,
        'Deadline': _ts(g.deadline),
        'LinkedAccountIDs': accounts,
        'LinkedDebtIDs': debts,
        'Notes': g.notes,
        'IsCompleted': g.isCompleted,
        'CompletedAt': _ts(g.completedAt),
        'Version': g.version,
        'CreatedAt': _ts(g.createdAt),
        'UpdatedAt': _ts(g.updatedAt),
      });
    }
    return out;
  }

  Future<List<dynamic>> _exportTags() async {
    final tags = await _database.tagDao.watchAllTags().first;
    return tags.map((t) => {
          'ID': t.id,
          'TenantID': '',
          'Name': t.name,
          'Color': t.color,
          'Version': t.version,
          'DeletedAt': null,
          'CreatedAt': _ts(t.createdAt),
          'UpdatedAt': _ts(t.updatedAt),
        }).toList();
  }

  Future<List<dynamic>> _exportTemplates() async {
    final rows = await _database.templateDao.watchAllTemplates().first;
    return rows.map((r) => {
          'ID': r.id,
          'TenantID': '',
          'Name': r.name,
          'Description': r.description,
          'AmountCents': r.amountCents,
          'Direction': r.direction,
          'SourceAccountID': r.sourceAccountId,
          'DestinationAccountID': r.destinationAccountId,
          'Cycle': r.cycle,
          'CycleDays': r.cycleDays,
          'BillingDay': r.billingDay,
          'NextDate': _ts(r.nextDate),
          'StartDate': _ts(r.startDate),
          'EndDate': _ts(r.endDate),
          'AutoRecord': r.autoRecord,
          'Paused': r.paused,
          'LastTransactionID': r.lastTransactionId,
          'Category': r.category,
          'Version': r.version,
          'CreatedAt': _ts(r.createdAt),
          'UpdatedAt': _ts(r.updatedAt),
        }).toList();
  }

  Future<Map<String, dynamic>> _exportHoldings() async {
    // Server shape: sibling arrays "holdings"/"transactions" under one key.
    final holdings = await _database.holdingDao.watchAllHoldings().first;
    final trades =
        await _database.holdingDao.getAllHoldingTransactions();
    return {
      'holdings': holdings
          .map((h) => {
                'ID': h.id,
                'TenantID': '',
                'AccountID': h.accountId,
                'SecurityID': h.securityId,
                'Quantity': h.quantity,
                'AvgCostCents': h.avgCostCents,
                'Version': h.version,
                'CreatedAt': _ts(h.createdAt),
                'UpdatedAt': _ts(h.updatedAt),
              })
          .toList(),
      'transactions': trades
          .map((t) => {
                'ID': t.id,
                'TenantID': '',
                'AccountID': t.accountId,
                'SecurityID': t.securityId,
                'TradeType': t.tradeType,
                'Quantity': t.quantity,
                'PriceCents': t.priceCents,
                'AmountCents': t.amountCents,
                'FeeCents': t.feeCents,
                'RealizedPnLCents': t.realizedPnlCents,
                'TradeDate': _ts(t.tradeDate),
                'TransactionID': t.transactionId,
                'Notes': t.notes,
                'CreatedAt': _ts(t.createdAt),
              })
          .toList(),
    };
  }

  String? _ts(DateTime? d) {
    if (d == null) return null;
    final utc = d.toUtc();
    // RFC3339 with explicit offset (Go time.Time round-trips this exactly).
    final iso = utc.toIso8601String();
    return iso.endsWith('Z') ? iso : '${iso}Z';
  }
}
