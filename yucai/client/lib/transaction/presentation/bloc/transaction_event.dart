import 'package:equatable/equatable.dart';

import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// Events for [TransactionBloc] (the list-page bloc; the form-page bloc is
/// separate in `transaction_form_*`).
///
/// Lifecycle:
///   - [LoadTransactionsRequested] — (re)fetch page 1 with a (possibly new)
///     filter. Resets accumulated list + cursor.
///   - [LoadMoreTransactionsRequested] — fetch the next page using the prior
///     `nextPageToken` and append. No-op when there is no next page.
///   - [GoToTransactionsPageRequested] — F7 FR-4 翻页(prev/next):filter 不变,
///     仅换 pageToken 重查当前页切片(替换,不追加)。
///   - [RetryTransactionsRequested] — re-run the last requested filter.
///   - [LoadSummaryRequested] — fetch the month's [MonthlySummary] for the
///     SummaryCard. Scoped by [year]/[month]/[accountId] (Task 5.2).
abstract class TransactionEvent extends Equatable {
  const TransactionEvent();
  @override
  List<Object?> get props => [];
}

/// (Re)load the first page. [filter] defaults to "all" when omitted.
///
/// 语义 = **重置第 1 页**(F7 FR-4):任一筛选/搜索/排序变化触发时 token 清空、
/// pageIndex 归 0。
class LoadTransactionsRequested extends TransactionEvent {
  const LoadTransactionsRequested({this.filter = const TxnFilterState()});

  final TxnFilterState filter;

  @override
  List<Object?> get props => [filter];
}

/// 翻页方向(F7 FR-4):prev=上一页,next=下一页。
enum TxnPageDirection { prev, next }

/// 翻页(F7 FR-4):携带方向,filter 保持当前不变,内部换 pageToken 重发查询。
/// 命名随库内 `...Requested` 惯例(对齐 design.md LLD 口径)。
/// 第 1 页 prev / 末页(nextPageToken 为空)next 均为 no-op。
class GoToTransactionsPageRequested extends TransactionEvent {
  const GoToTransactionsPageRequested(this.direction);

  final TxnPageDirection direction;

  @override
  List<Object?> get props => [direction];
}

/// Fetch the next page and append to the current list. Ignored when the
/// current state has no `nextPageToken`.
class LoadMoreTransactionsRequested extends TransactionEvent {}

/// Retry the last load (typically after a [TransactionsError]).
class RetryTransactionsRequested extends TransactionEvent {}

/// Load the detail view for one transaction (Task 3.2 detail page).
///
/// Fetches the transaction by [id] plus a few recent same-account transactions
/// (for the 「同分类近期」 panel). The same-account list is served by the same
/// `list` RPC scoped to the transaction's first entry account — a client-side
/// workaround until the Task 3.1 server `FindRecentByAccount` RPC lands in the
/// regenerated client proto stub (see progress.md / stub-regen backlog). The
/// detail bloc handler documents this explicitly so the workaround is not
/// hidden.
class LoadTransactionDetail extends TransactionEvent {
  const LoadTransactionDetail(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Fetch the summary for the SummaryCard. [year]/[month] select the calendar
/// anchor; [accountId] optional scopes to one account. [scope] (Task 9)
/// selects the aggregation granularity — [SummaryScope.month] is the default
/// (pre-Task-9 callers keep their behaviour); [day] is only meaningful with
/// [SummaryScope.day] (the day-of-month to pin). The bloc emits [SummaryLoading]
/// then [SummaryLoaded] (or [SummaryError]).
///
/// This is a parallel concern to the list lifecycle — the page emits it on
/// init and on filter change, and the state holds summary independently of the
/// list states so a summary failure doesn't blank the list (and vice versa).
/// Delete the transaction currently shown on the detail page (Task 3.2 CRUD).
///
/// Emits `TransactionDeleting` → `TransactionDeleted` (page pops + signals the
/// list to refresh) or `TransactionDetailError`. Backed by
/// [TransactionRepository.delete], which the server implements as a
/// balance-reversing soft-delete.
class DeleteTransactionRequested extends TransactionEvent {
  const DeleteTransactionRequested(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class LoadSummaryRequested extends TransactionEvent {
  const LoadSummaryRequested({
    required this.year,
    required this.month,
    this.accountId,
    this.scope = SummaryScope.month,
    this.day,
  });

  final int year;
  final int month;
  final String? accountId;

  /// Aggregation granularity. Defaults to [SummaryScope.month] so existing
  /// callers that omit it behave exactly as before (Task 9 backward-compat).
  final SummaryScope scope;

  /// Day-of-month. Required for [SummaryScope.day] to be meaningful; ignored
  /// otherwise. Forwarded verbatim to the RPC.
  final int? day;

  @override
  List<Object?> get props => [year, month, accountId, scope, day];
}
