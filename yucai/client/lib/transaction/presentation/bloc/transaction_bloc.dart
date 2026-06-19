import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

/// Bloc backing the transactions **list** page.
///
/// Single repository: [TransactionRepository] for `list`. The page separately
/// loads accounts (for the FilterBar dropdown) via [AccountRepository] — kept
/// out of this bloc so it has one responsibility. Page-constructed via
/// [BlocProvider] with the repo injected from `getIt` (see [TransactionsPage]);
/// this keeps the bloc DI-light and unit-testable without regenerating
/// injectable config, mirroring [TransactionFormBloc].
///
/// **Type filter limitation**: the server's `ListTransactions` has no flavour
/// field yet (Task 2.1 not landed in client proto), so the type segment is
/// applied client-side via [TxnFlavour]. The client-side `inferFlavour`
/// heuristic only distinguishes transfer (balanced 2-entry) from compound, so
/// income/expense filtering is coarse until the server gains the field. This
/// is documented, not hidden — the UI still lets users pick the segment.
class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc(this._txnRepo) : super(TransactionsInitial()) {
    on<LoadTransactionsRequested>(_onLoad);
    on<LoadMoreTransactionsRequested>(_onLoadMore);
    on<RetryTransactionsRequested>(_onRetry);
    on<LoadTransactionDetail>(_onLoadDetail);
  }

  final TransactionRepository _txnRepo;

  Future<void> _onLoad(
      LoadTransactionsRequested event, Emitter<TransactionState> emit) async {
    final filter = event.filter;
    emit(TransactionsLoading(filter: filter));
    final result = await _txnRepo.list(_params(filter: filter));
    result.fold(
      (failure) =>
          emit(TransactionsError(failure.displayMessage, filter: filter)),
      (page) => emit(TransactionsLoaded(
        transactions: page.transactions,
        filter: filter,
        nextPageToken: page.nextPageToken,
      )),
    );
  }

  Future<void> _onLoadMore(
      LoadMoreTransactionsRequested event, Emitter<TransactionState> emit) async {
    final s = state;
    final loaded = s is TransactionsLoaded ? s : null;
    // LoadingMore also carries a nextToken; support resuming from it.
    final loadingMore = s is TransactionsLoadingMore ? s : null;
    final token = loaded?.nextPageToken ?? loadingMore?.nextPageToken ?? '';
    final prior = loaded?.transactions ?? loadingMore?.transactions ?? const [];
    final filter = loaded?.filter ?? loadingMore?.filter ?? const TxnFilterState();
    if (token.isEmpty) return; // nothing more to fetch
    emit(TransactionsLoadingMore(
      transactions: prior,
      filter: filter,
      nextPageToken: token,
    ));
    final result =
        await _txnRepo.list(_params(filter: filter, pageToken: token));
    result.fold(
      (failure) =>
          emit(TransactionsError(failure.displayMessage, filter: filter)),
      (page) => emit(TransactionsLoaded(
        transactions: [...prior, ...page.transactions],
        filter: filter,
        nextPageToken: page.nextPageToken,
      )),
    );
  }

  Future<void> _onRetry(
      RetryTransactionsRequested event, Emitter<TransactionState> emit) async {
    final filter = state is TransactionsError
        ? (state as TransactionsError).filter
        : const TxnFilterState();
    await _onLoad(LoadTransactionsRequested(filter: filter), emit);
  }

  ListTransactionsParams _params({
    required TxnFilterState filter,
    String? pageToken,
  }) {
    final flavour = _flavourOf(filter.type);
    return ListTransactionsParams(
      accountId: filter.accountId,
      // month filter → month-bounded date range (YYYY-MM → from/to).
      dateFrom: filter.month != null ? _monthStart(filter.month!) : null,
      dateTo: filter.month != null ? _monthEnd(filter.month!) : null,
      pageToken: pageToken,
      typeFilter: flavour,
    );
  }

  /// Maps the UI type segment to the domain flavour used for client-side
  /// filtering. `all` → null (no filter). income/expense both map to compound
  /// because the heuristic cannot tell them apart server-side yet; this is
  /// the documented limitation noted in the class dartdoc.
  TxnFlavour? _flavourOf(TxnTypeFilter t) {
    switch (t) {
      case TxnTypeFilter.all:
        return null;
      case TxnTypeFilter.transfer:
        return TxnFlavour.transfer;
      case TxnTypeFilter.income:
      case TxnTypeFilter.expense:
        return TxnFlavour.compound;
    }
  }

  DateTime _monthStart(String ym) {
    final parts = ym.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime _monthEnd(String ym) {
    final parts = ym.split('-');
    final start = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    // Next month, day 0 = last day of this month.
    return DateTime(start.year, start.month + 1, 0);
  }

  /// Detail-page handler (Task 3.2). Fetches the transaction, then the recent
  /// same-account list for the 「同分类近期」 panel.
  ///
  /// **findRecentByAccount workaround**: the server `FindRecentByAccount` RPC
  /// (Task 3.1) is not yet in the regenerated client proto stub. As an interim
  /// we reuse `list(ListTransactionsParams{accountId})` and trim to the first
  /// few rows, excluding the current transaction. Swap to a dedicated
  /// `findRecentByAccount` repo method once the stub is regenerated.
  Future<void> _onLoadDetail(
      LoadTransactionDetail event, Emitter<TransactionState> emit) async {
    emit(TransactionDetailLoading());
    final result = await _txnRepo.getById(event.id);
    await result.fold(
      (failure) async => emit(TransactionDetailError(failure.displayMessage)),
      (txn) async {
        final recent = await _recentSameAccount(txn, event.id);
        emit(TransactionDetailLoaded(transaction: txn, recent: recent));
      },
    );
  }

  /// Best-effort recent same-account list. Picks the first debit-side account
  /// on the transaction (the 「expense / category」 leg) and lists a few rows
  /// for it, excluding the current transaction. Empty on any failure.
  Future<List<Transaction>> _recentSameAccount(
      Transaction txn, String currentId) async {
    final debitEntry = txn.entries.cast<TransactionEntry?>().firstWhere(
          (e) => e != null && e.debitCents > 0,
          orElse: () => txn.entries.isEmpty ? null : txn.entries.first,
        );
    final account = debitEntry?.accountId ?? '';
    if (account.isEmpty) return const [];
    final result = await _txnRepo
        .list(ListTransactionsParams(accountId: account, pageSize: 10));
    return result.fold(
      (_) => const [],
      (page) =>
          page.transactions.where((t) => t.id != currentId).take(5).toList(),
    );
  }
}
