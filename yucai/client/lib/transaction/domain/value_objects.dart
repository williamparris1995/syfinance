import 'package:yucai_client/account/domain/value_objects.dart';
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

/// Aggregation granularity for the `TransactionSummary` RPC (Task 9).
///
/// The server's `Scope` proto enum (DAY=1 / MONTH=2 / YEAR=3) selects the
/// aggregation period:
///   - [day]    — single bucket for the given [MonthlySummary.year] /
///     [MonthlySummary.month] / `day` (the day-of-month the caller pins).
///   - [month]  — per-day breakdown across the month (the legacy default;
///     every pre-Task-9 caller behaves as before).
///   - [year]   — per-month breakdown across the year.
///
/// Kept in the **client** layer (not re-exporting the proto enum) so the
/// domain / bloc don't depend on generated proto code — mirrors the
/// [TxnFlavour] / [EntrySide] decision above. The data layer maps this to the
/// proto `Scope` (see `TransactionRemoteDataSource.summary`).
enum SummaryScope { day, month, year }

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

/// 列表排序键(F7 FR-3):日期(默认,= transactionDate)或金额(Σdebit 口径,
/// 见 DS 层 ADR-3 注释)。枚举留在 client domain 层,与 [TxnFlavour]/[EntrySide]
/// 同一决策:UI/bloc 不依赖生成 proto 代码。
enum TxnSortKey { date, amount }

/// 列表排序方向(F7 FR-3)。默认 [desc] 与既有默认序(transactionDate DESC,
/// id DESC)一致 —— NFR-1:不带新参数时行为逐位不变。
enum TxnSortDir { asc, desc }

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
    this.category,
    this.searchText,
    this.tagId,
    this.sortKey = TxnSortKey.date,
    this.sortDir = TxnSortDir.desc,
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

  /// 账户分类过滤(F7 FR-1):仅返回任一 entry 涉及该分类账户的交易
  /// (与 [accountId] 的"任一 entry 涉及"口径对齐)。null = 不过滤。
  final AccountCategory? category;

  /// 描述模糊搜索(F7 FR-2):contains + 大小写不敏感;DS 层仅在非空非
  /// 空白时生效(null/空白 = 不过滤)。
  final String? searchText;

  /// 标签反查过滤(F8 FR-1):仅返回关联了该标签的交易(id ∈ junction
  /// 关联集,DS 层内存集合判定)。null = 不过滤;注意**空集**(该标签无
  /// 任何关联交易)= 空结果,与 null 语义严格区分。
  final String? tagId;

  /// 排序键(F7 FR-3):默认 [TxnSortKey.date]。
  final TxnSortKey sortKey;

  /// 排序方向(F7 FR-3):默认 [TxnSortDir.desc](与既有默认序一致,NFR-1)。
  final TxnSortDir sortDir;

  /// True when the params carry no narrowing filter (server-side fields only;
  /// typeFilter/category/searchText and the sort knobs are client-side so
  /// they are excluded).
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
/// request. [scope] (Task 9) echoes the requested granularity so the UI can
/// label the returned aggregation; null = the legacy month default (kept
/// backward-compatible).
class MonthlySummary {
  const MonthlySummary({
    required this.year,
    required this.month,
    this.incomeCents = 0,
    this.expenseCents = 0,
    this.netCents = 0,
    this.dailyAvgCents = 0,
    this.byDay = const <DailySummary>[],
    this.scope,
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

  /// The granularity the server aggregated at for this summary (Task 9). null
  /// on pre-Task-9 callers / the fallback zeroed summary; the mapper stamps it
  /// from the request scope. The UI reads this to label the card without
  /// re-deriving it.
  final SummaryScope? scope;
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
