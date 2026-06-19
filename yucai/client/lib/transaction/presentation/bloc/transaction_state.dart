import 'package:equatable/equatable.dart';

import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// States for [TransactionBloc] (list-page).
///
/// - [TransactionsInitial] — pre-first-load.
/// - [TransactionsLoading] — page-1 fetch in flight; list empty.
/// - [TransactionsLoaded] — page-1 done; carries the list + cursor + filter.
/// - [TransactionsLoadingMore] — next-page fetch in flight; carries the
///   already-loaded list so the UI keeps rendering it.
/// - [TransactionsError] — fetch failed; retains the filter for retry.
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
  });

  final List<Transaction> transactions;
  final TxnFilterState filter;
  final String nextPageToken;

  bool get hasMore => nextPageToken.isNotEmpty;

  @override
  List<Object?> get props => [transactions, filter, nextPageToken];
}

/// Next-page fetch in flight. [transactions] is the previously loaded list so
/// the UI can keep rendering it with a trailing spinner.
class TransactionsLoadingMore extends TransactionState {
  const TransactionsLoadingMore({
    required this.transactions,
    required this.filter,
    required this.nextPageToken,
  });

  final List<Transaction> transactions;
  final TxnFilterState filter;
  final String nextPageToken;

  bool get hasMore => nextPageToken.isNotEmpty;

  @override
  List<Object?> get props => [transactions, filter, nextPageToken];
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
