import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';

/// Transaction-domain value objects and enums. Currently the proto has no
/// dedicated transaction-type enum (Record/SimpleXxx RPCs encode intent via
/// the called method), so this file holds lightweight enums the UI/bloc can
/// use without depending on generated proto code.

/// Which side of a double-entry line an [TransactionEntry] hits.
///
/// A line is a *debit* if [TransactionEntry.debitCents] > 0 and
/// [TransactionEntry.creditCents] == 0, and vice-versa. Mutually exclusive:
/// a single entry never carries both a debit and a credit.
enum EntrySide { debit, credit }

extension EntrySideLabel on EntrySide {
  String get label => this == EntrySide.debit ? '借' : '贷';
}

/// Coarse transaction flavour, derived from which convenience RPC produced it
/// (or, for full double-entry, inferred by the caller). The domain keeps this
/// as a presentation aid — the server records raw entries, not a flavour.
enum TxnFlavour { expense, income, transfer, compound }

extension TxnFlavourLabel on TxnFlavour {
  String get label {
    switch (this) {
      case TxnFlavour.expense:
        return '支出';
      case TxnFlavour.income:
        return '收入';
      case TxnFlavour.transfer:
        return '转账';
      case TxnFlavour.compound:
        return '复式';
    }
  }
}

/// Parameters for `ListTransactions`. All filters optional.
class ListTransactionsParams {
  const ListTransactionsParams({
    this.accountId,
    this.dateFrom,
    this.dateTo,
    this.pageSize = 100,
  });

  /// Restrict to entries touching this account id.
  final String? accountId;

  /// Inclusive lower bound (ISO date `YYYY-MM-DD`).
  final DateTime? dateFrom;

  /// Inclusive upper bound (ISO date `YYYY-MM-DD`).
  final DateTime? dateTo;

  final int pageSize;
}

/// Result type returned by `summary` (Task 5.1). Placeholder shape; the real
/// `MonthlySummaryDTO` lands with the proto redesign and the mapper fills the
/// real fields. Declared now so the repository trait signature is stable.
class MonthlySummary {
  const MonthlySummary({
    required this.year,
    required this.month,
    this.incomeCents = 0,
    this.expenseCents = 0,
    this.netCents = 0,
  });

  final int year;
  final int month;
  final int incomeCents;
  final int expenseCents;
  final int netCents;
}
