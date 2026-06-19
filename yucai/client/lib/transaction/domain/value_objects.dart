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

/// Infers a coarse [TxnFlavour] from a [Transaction]'s entries, with no
/// account-type metadata.
///
/// Heuristic (mirrors `txn_row._inferFlavour`, centralised here so the data
/// layer and UI agree):
///   - balanced + exactly 2 entries → [TxnFlavour.transfer]
///   - otherwise → [TxnFlavour.compound] (real income/expense/compound can't
///     be told apart without knowing which leg hits an asset account; the UI
///     uses this only for grouping/colouring, never for accounting truth)
///
/// When the server gains a real flavour field (post Task 2.1), this returns
/// that field and the heuristic is retired.
TxnFlavour inferFlavour(Transaction txn) {
  if (txn.entries.length == 2 && txn.isBalanced) {
    return TxnFlavour.transfer;
  }
  return TxnFlavour.compound;
}

/// Parameters for `ListTransactions`. All filters optional.
///
/// **Pagination**: [pageToken] is the opaque cursor returned in the previous
/// `ListTransactionsResult.nextPageToken`. Empty/null = first page. The proto
/// `PageRequest.page_token` carries it on the wire.
///
/// **Type filter** ([typeFilter]): the server's `ListTransactions` RPC does not
/// yet expose a flavour filter (Task 2.1 server-side not landed in client proto
/// stub). Carrying it here keeps the repository contract stable; the
/// implementation applies it client-side after fetch. When the proto gains the
/// field, the wire-side wiring changes but this trait does not.
class ListTransactionsParams {
  const ListTransactionsParams({
    this.accountId,
    this.dateFrom,
    this.dateTo,
    this.pageSize = 100,
    this.pageToken,
    this.typeFilter,
  });

  /// Restrict to entries touching this account id.
  final String? accountId;

  /// Inclusive lower bound (ISO date `YYYY-MM-DD`).
  final DateTime? dateFrom;

  /// Inclusive upper bound (ISO date `YYYY-MM-DD`).
  final DateTime? dateTo;

  final int pageSize;

  /// Cursor from a prior [ListTransactionsResult.nextPageToken]; empty/null
  /// requests the first page.
  final String? pageToken;

  /// Optional client-side flavour filter (income/expense/transfer). null = all.
  final TxnFlavour? typeFilter;

  /// True when the params carry no narrowing filter (server-side fields only;
  /// typeFilter is client-side so it is excluded).
  bool get isUnfilteredServerSide =>
      (accountId == null || accountId!.isEmpty) &&
      dateFrom == null &&
      dateTo == null;
}

/// Result type returned by `summary` (Task 5.1 → Task 5.2 wired to the real
/// `TransactionSummary` RPC). Mirrors the proto `MonthlySummary` DTO:
/// income/expense/net/dailyAvg in cents plus a per-day breakdown ([byDay]).
///
/// `year`/`month` echo the request so callers don't need to thread them; the
/// server does not return them in the DTO, the mapper stamps them from the
/// request.
class MonthlySummary {
  const MonthlySummary({
    required this.year,
    required this.month,
    this.incomeCents = 0,
    this.expenseCents = 0,
    this.netCents = 0,
    this.dailyAvgCents = 0,
    this.byDay = const <DailySummary>[],
  });

  final int year;
  final int month;
  final int incomeCents;
  final int expenseCents;
  final int netCents;
  final int dailyAvgCents;

  /// Per-day breakdown for the month. Empty when the server omits it or the
  /// caller didn't request it. SummaryCard only uses the four totals, but the
  /// model carries [byDay] so future charts (Task 5.x) can read it without a
  /// second RPC round-trip.
  final List<DailySummary> byDay;
}

/// One day's contribution to a [MonthlySummary]. Mirrors proto `DailyItem`:
///   - [date] is the `YYYY-MM-DD` server wire format (kept as string here to
///     avoid a parse in the read path; UI parses lazily when it needs a
///     [DateTime]).
///   - [totalIncomeCents] is that day's total income (the proto field is named
///     `total_income`; the server Task 5.1 implementation sums the income side
///     per day). Kept as income-named to mirror the proto exactly.
///   - [byCategory] is the day's split by Income/Expense account (category).
class DailySummary {
  const DailySummary({
    required this.date,
    this.totalIncomeCents = 0,
    this.byCategory = const <CategoryTotal>[],
  });

  final String date;
  final int totalIncomeCents;
  final List<CategoryTotal> byCategory;
}

/// A single category's total within a [DailySummary]. Mirrors proto
/// `CategoryItem`. [categoryId]/[name]/[accountType] describe the Income or
/// Expense account (category); [amountCents] is the total hitting that account
/// on the day.
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    this.name = '',
    this.accountType = '',
    this.amountCents = 0,
  });

  final String categoryId;
  final String name;
  final String accountType;
  final int amountCents;
}
