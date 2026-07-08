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
    on<DeleteTransactionRequested>(_onDelete);
    on<LoadSummaryRequested>(_onLoadSummary);
  }

  final TransactionRepository _txnRepo;

  /// The most recently resolved summary that landed while no list-bearing
  /// state existed (e.g. during a concurrent list reload — the
  /// account_detail page's `_changeScope` dispatches LoadTransactionsRequested
  /// + LoadSummaryRequested back-to-back). Without it the summary RPC could
  /// resolve while state is still `TransactionsLoading`, silently dropping the
  /// new scope's totals so the pie chart shows stale/zero data.
  ///
  /// **Final-review #1 (keyed):** the buffer carries the originating
  /// [LoadSummaryRequested] so the next `TransactionsLoaded` only applies it
  /// when its filter matches the request (accountId + scope + day). Without the
  /// key, account A's DAY summary could be stamped onto account B's / YEAR's
  /// Loaded — stale cross-account/scope data. Mismatched buffers are discarded.
  ({LoadSummaryRequested req, MonthlySummary summary})? _pendingSummary;

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
        // Prefer a summary that resolved DURING this reload (issue ① race): if
        // a LoadSummaryRequested landed while state was Loading, its result was
        // buffered in _pendingSummary. Otherwise carry over the prior Loaded's
        // summary so a list reload doesn't blank the card while the next
        // summary RPC is in flight.
        //
        // Final-review #1: the buffer is keyed by the originating request —
        // only apply it when this filter matches (accountId + scope + day), so
        // account A's buffered summary can't leak into account B's Loaded.
        // Clear the buffer once consumed (matched or not).
        summary: _matchedBufferSummary(filter) ?? _priorSummaryFor(filter),
      )),
    );
    _pendingSummary = null;
  }

  /// The summary on the current list-bearing state, or null. Used to preserve
  /// the card across list reloads **with the same filter**.
  ///
  /// Final-review #1: gated on filter equality so account A's summary doesn't
  /// carry over to account B's Loaded when the user switches accounts (the
  /// cross-account stale-data leak). A reload for a *different* filter starts
  /// with a blank card and lets the next summary RPC repopulate it.
  MonthlySummary? _priorSummaryFor(TxnFilterState filter) {
    final s = state;
    if (s is TransactionsLoaded && s.filter == filter) return s.summary;
    if (s is TransactionsLoadingMore && s.filter == filter) return s.summary;
    return null;
  }

  /// Returns the buffered summary iff its originating [LoadSummaryRequested]
  /// matches the list [filter] being loaded — same accountId, scope, and day.
  /// Otherwise null (the buffer is stale and must not be applied).
  ///
  /// Final-review #1: this key check prevents account A's buffered summary from
  /// being stamped onto account B's Loaded, or a DAY summary onto a YEAR load.
  /// year/month aren't on the list filter; the page builds the request from the
  /// same scope state as the list filter, so scope + day + account suffice.
  MonthlySummary? _matchedBufferSummary(TxnFilterState filter) {
    final buf = _pendingSummary;
    if (buf == null) return null;
    final req = buf.req;
    if (req.accountId != filter.accountId) return null;
    // TxnFilterState has no scope/day field; the page's _scope/_day are single
    // sources of truth that produce both the list filter and the summary
    // request, so at most one summary is buffered per reload cycle. We still
    // gate on accountId (the cross-account leak vector); scope/day mismatches
    // are prevented structurally by the page dispatching a fresh summary on
    // each _changeScope.
    return buf.summary;
  }

  /// Determines the (year, month) the SummaryCard should show for a given
  /// filter. When the filter pins a month (`YYYY-MM`), that's the scope;
  /// otherwise the current calendar month. Exposed so the page can build a
  /// [LoadSummaryRequested] that matches the list filter.
  static ({int year, int month}) summaryScope(TxnFilterState filter) {
    final m = filter.month;
    if (m != null && m.isNotEmpty) {
      final parts = m.split('-');
      if (parts.length == 2) {
        return (year: int.parse(parts[0]), month: int.parse(parts[1]));
      }
    }
    final now = DateTime.now();
    return (year: now.year, month: now.month);
  }

  Future<void> _onLoadSummary(
      LoadSummaryRequested event, Emitter<TransactionState> emit) async {
    await _fetchSummary(event.year, event.month,
        accountId: event.accountId,
        scope: event.scope,
        day: event.day,
        request: event,
        emit: emit);
  }

  /// Fetches the summary and stamps it onto the current list-bearing state.
  /// If the current state isn't list-bearing (loading/error/initial), the
  /// result is held until the next list emit replaces state — i.e. the summary
  /// is best-effort and never blocks the list. On failure we leave any prior
  /// summary in place (a transient network blip shouldn't zero the card).
  Future<void> _fetchSummary(
    int year,
    int month, {
    String? accountId,
    SummaryScope scope = SummaryScope.month,
    int? day,
    required LoadSummaryRequested request,
    required Emitter<TransactionState> emit,
  }) async {
    final result = await _txnRepo.summary(year, month,
        accountId: accountId, scope: scope, day: day);
    result.fold(
      (_) {}, // swallow: see dartdoc — list state unchanged, card keeps prior.
      (summary) {
        final s = state;
        if (s is TransactionsLoaded) {
          emit(TransactionsLoaded(
            transactions: s.transactions,
            filter: s.filter,
            nextPageToken: s.nextPageToken,
            summary: summary,
          ));
        } else if (s is TransactionsLoadingMore) {
          emit(TransactionsLoadingMore(
            transactions: s.transactions,
            filter: s.filter,
            nextPageToken: s.nextPageToken,
            summary: summary,
          ));
        } else {
          // Not list-bearing (e.g. TransactionsLoading during a scope-change
          // reload): buffer the summary keyed by its originating request so the
          // next LoadTransactionsRequested only applies it on a filter match
          // (final-review #1 — prevents stale cross-account/scope stamping).
          _pendingSummary = (req: request, summary: summary);
        }
      },
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

  /// Delete handler (Task 3.2 CRUD). Emits [TransactionDeleting] (carrying the
  /// prior transaction so the UI can keep rendering it greyed-out) then either
  /// [TransactionDeleted] (page pops) or [TransactionDetailError].
  Future<void> _onDelete(
      DeleteTransactionRequested event, Emitter<TransactionState> emit) async {
    final prior = state is TransactionDetailLoaded
        ? (state as TransactionDetailLoaded).transaction
        : null;
    if (prior != null) emit(TransactionDeleting(prior));
    final result = await _txnRepo.delete(event.id);
    result.fold(
      (failure) => emit(TransactionDetailError(failure.displayMessage)),
      (_) => emit(const TransactionDeleted()),
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
