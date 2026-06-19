import 'package:equatable/equatable.dart';

import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// Events for [TransactionBloc] (the list-page bloc; the form-page bloc is
/// separate in `transaction_form_*`).
///
/// Lifecycle:
///   - [LoadTransactionsRequested] — (re)fetch page 1 with a (possibly new)
///     filter. Resets accumulated list + cursor.
///   - [LoadMoreTransactionsRequested] — fetch the next page using the prior
///     `nextPageToken` and append. No-op when there is no next page.
///   - [RetryTransactionsRequested] — re-run the last requested filter.
abstract class TransactionEvent extends Equatable {
  const TransactionEvent();
  @override
  List<Object?> get props => [];
}

/// (Re)load the first page. [filter] defaults to "all" when omitted.
class LoadTransactionsRequested extends TransactionEvent {
  const LoadTransactionsRequested({this.filter = const TxnFilterState()});

  final TxnFilterState filter;

  @override
  List<Object?> get props => [filter];
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
