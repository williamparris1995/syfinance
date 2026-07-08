import 'package:equatable/equatable.dart';

import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// States for [TransactionBloc] (list-page).
///
/// - [TransactionsInitial] — pre-first-load.
/// - [TransactionsLoading] — page-1 fetch in flight; list empty.
/// - [TransactionsLoaded] — page-1 done; carries the list + cursor + filter +
///   an optional [MonthlySummary] (Task 5.2 SummaryCard).
/// - [TransactionsLoadingMore] — next-page fetch in flight; carries the
///   already-loaded list so the UI keeps rendering it.
/// - [TransactionsError] — fetch failed; retains the filter for retry.
///
/// **Summary** (Task 5.2): the month's [MonthlySummary] rides on
/// [TransactionsLoaded]/[TransactionsLoadingMore] via the [summary] field.
/// It is loaded in parallel with the list (separate RPC) and stamped onto
/// whatever list state is current when it resolves. `null` = not yet loaded;
/// the SummaryCard falls back to zeros. A summary-only failure does NOT blank
/// the list — it leaves [summary] at its prior value.
abstract class TransactionState extends Equatable {
  const TransactionState();
  @override
  List<Object?> get props => [];
}

class TransactionsInitial extends TransactionState {}

class TransactionsLoading extends TransactionState {
  const TransactionsLoading({this.filter = const TxnFilterState()});

  final TxnFilterState filter;

  @override
  List<Object?> get props => [filter];
}

class TransactionsLoaded extends TransactionState {
  const TransactionsLoaded({
    required this.transactions,
    required this.filter,
    this.nextPageToken = '',
    this.summary,
  });

  final List<Transaction> transactions;
  final TxnFilterState filter;
  final String nextPageToken;

  /// This month's summary for the SummaryCard. null until the parallel
  /// `TransactionSummary` RPC resolves. The bloc updates this in place via
  /// `copyWith`-style re-emit (new state object, same list) when the summary
  /// lands, so the UI rebuilds the card without touching the list.
  final MonthlySummary? summary;

  bool get hasMore => nextPageToken.isNotEmpty;

  @override
  List<Object?> get props => [transactions, filter, nextPageToken, summary];
}

/// Next-page fetch in flight. [transactions] is the previously loaded list so
/// the UI can keep rendering it with a trailing spinner.
class TransactionsLoadingMore extends TransactionState {
  const TransactionsLoadingMore({
    required this.transactions,
    required this.filter,
    required this.nextPageToken,
    this.summary,
  });

  final List<Transaction> transactions;
  final TxnFilterState filter;
  final String nextPageToken;
  final MonthlySummary? summary;

  bool get hasMore => nextPageToken.isNotEmpty;

  @override
  List<Object?> get props => [transactions, filter, nextPageToken, summary];
}

class TransactionsError extends TransactionState {
  const TransactionsError(this.message, {this.filter = const TxnFilterState()});

  final String message;
  final TxnFilterState filter;

  @override
  List<Object?> get props => [message, filter];
}

/// Detail-page states (Task 3.2). Separate from the list lifecycle so the two
/// pages can share [TransactionBloc] without their states interfering.
///
/// - [TransactionDetailLoading] — fetch in flight.
/// - [TransactionDetailLoaded] — carries the transaction + same-account
///   recent list (best-effort; empty when the recent fetch fails or there is
///   no usable account id on the transaction).
/// - [TransactionDetailError] — primary fetch failed.
class TransactionDetailLoading extends TransactionState {}

class TransactionDetailLoaded extends TransactionState {
  const TransactionDetailLoaded({
    required this.transaction,
    this.recent = const [],
  });

  final Transaction transaction;

  /// Recent transactions touching the same account(s) as [transaction].
  /// Excludes [transaction] itself. Best-effort: empty when unavailable.
  final List<Transaction> recent;

  @override
  List<Object?> get props => [transaction, recent];
}

class TransactionDetailError extends TransactionState {
  const TransactionDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Delete in flight (Task 3.2 CRUD). The detail page disables its actions
/// while this is the state so a double-tap can't fire two `delete` RPCs.
class TransactionDeleting extends TransactionState {
  const TransactionDeleting(this.previous);
  final Transaction previous;
  @override
  List<Object?> get props => [previous];
}

/// Delete succeeded (Task 3.2 CRUD). The detail page listens for this and
/// pops with `true` so the originating list refreshes.
class TransactionDeleted extends TransactionState {
  const TransactionDeleted();
}
