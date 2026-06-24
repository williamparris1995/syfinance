// TDD RED → GREEN: bloc backing the transactions list page.
//
// Contract:
//   - LoadTransactionsRequested{filter} → repo.list → TransactionsLoaded
//   - type/account/month filter changes re-issue LoadTransactionsRequested
//   - LoadMoreTransactionsRequested uses the prior nextPageToken, appends
//   - failure → TransactionsError (filter retained so UI can retry / re-filter)
//
// DI-light: constructed with one repo (no injectable config regen), mirroring
// TransactionFormBloc. The page separately loads accounts for the FilterBar
// dropdown, so this bloc has a single responsibility.
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockTxnRepo extends Mock implements TransactionRepository {}

Transaction _txn(String id, {DateTime? date, int amount = 5000}) {
  return Transaction(
    id: id,
    transactionDate: date ?? DateTime(2026, 6, 19),
    description: '午餐 $id',
    entries: [
      TransactionEntry(accountId: 'a1', debitCents: amount, creditCents: 0),
      TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: amount),
    ],
  );
}

dartz.Right<Failure, ListTransactionsResult> _ok(
        List<Transaction> txns, String nextToken) =>
    dartz.Right(ListTransactionsResult(
        transactions: txns, nextPageToken: nextToken));

void main() {
  late _MockTxnRepo txnRepo;

  setUp(() {
    txnRepo = _MockTxnRepo();
    registerFallbackValue(ListTransactionsParams());
    // Task 9: `any(named: 'scope')` requires a SummaryScope fallback value.
    registerFallbackValue(SummaryScope.month);
    // Task 5.2: _onLoad triggers a parallel summary fetch on every successful
    // page-1 load. Provide a default stub so existing list tests don't hit
    // MissingStubError; tests that assert on summary override this.
    // Task 9: summary() now carries scope + day; wildcard them so all callers
    // (default-month and explicit-scope alike) hit this fallback.
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 100,
              expenseCents: 50,
              netCents: 50,
            )));
  });

  blocTest<TransactionBloc, TransactionState>(
    'initial state is TransactionsInitial',
    build: () => TransactionBloc(txnRepo),
    verify: (b) => expect(b.state, isA<TransactionsInitial>()),
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadTransactions emits [Loading, Loaded] with empty nextToken',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], ''));
      return TransactionBloc(txnRepo);
    },
    act: (b) => b.add(const LoadTransactionsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionsLoading>(),
      isA<TransactionsLoaded>()
          .having((s) => s.transactions.length, 'count', 1)
          .having((s) => s.hasMore, 'hasMore', false),
    ],
    verify: (_) => verify(() => txnRepo.list(any())).called(1),
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadTransactions with type=expense forwards a non-null typeFilter',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], ''));
      return TransactionBloc(txnRepo);
    },
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(type: TxnTypeFilter.expense))),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionsLoading>(),
      isA<TransactionsLoaded>()
          .having((s) => s.filter.type, 'type', TxnTypeFilter.expense),
    ],
    verify: (bloc) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      // income/expense both map to compound (documented heuristic); the point
      // of this assertion is that a non-null flavour was forwarded to the repo.
      expect(captured.typeFilter, isNotNull);
      expect((bloc.state as TransactionsLoaded).filter.type,
          TxnTypeFilter.expense);
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadTransactions with month filter forwards date range',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([], ''));
      return TransactionBloc(txnRepo);
    },
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(month: '2026-06'))),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.dateFrom, DateTime(2026, 6, 1));
      expect(captured.dateTo, DateTime(2026, 6, 30));
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'failure emits [Loading, Error] retaining the requested filter',
    build: () {
      when(() => txnRepo.list(any()))
          .thenAnswer((_) async => const dartz.Left(ServerFailure('boom')));
      return TransactionBloc(txnRepo);
    },
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(accountId: 'a1'))),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      isA<TransactionsLoading>(),
      isA<TransactionsError>()
          .having((s) => s.message, 'message', 'boom')
          .having((s) => s.filter.accountId, 'filter.accountId', 'a1'),
    ],
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadMore appends to the existing list and clears nextToken when done',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((invocation) async {
        final p =
            invocation.positionalArguments.single as ListTransactionsParams;
        if ((p.pageToken ?? '').isEmpty) {
          return _ok([_txn('t1')], 'cursor1');
        }
        return _ok([_txn('t2')], '');
      });
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(LoadMoreTransactionsRequested());
    },
    wait: const Duration(milliseconds: 200),
    skip: 1, // skip the initial Loading emitted before the first Loaded
    expect: () => [
      isA<TransactionsLoaded>().having((s) => s.transactions.length, 'p1', 1),
      isA<TransactionsLoadingMore>(),
      isA<TransactionsLoaded>()
          .having((s) => s.transactions.length, 'p2', 2)
          .having((s) => s.hasMore, 'hasMore', false),
    ],
    verify: (bloc) {
      final calls = verify(() => txnRepo.list(captureAny())).captured
          .cast<ListTransactionsParams>();
      expect(calls.length, 2);
      expect(calls[0].pageToken, isNull);
      expect(calls[1].pageToken, 'cursor1');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadMore is a no-op when there is no next page',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], ''));
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(LoadMoreTransactionsRequested());
    },
    wait: const Duration(milliseconds: 150),
    skip: 1,
    expect: () => [
      isA<TransactionsLoaded>(),
      // no LoadingMore / second Loaded — LoadMore returned early.
    ],
    verify: (_) => verify(() => txnRepo.list(any())).called(1),
  );

  // ───────────────────────── Task 9: summary scope ─────────────────────────

  // Task 9: LoadSummaryRequested now carries SummaryScope (day/month/year) +
  // optional day. The bloc forwards them to the repo; the repo maps them to the
  // proto Scope on the wire (asserted in the remote_ds test). Here we assert
  // the bloc → repo contract: scope=year reaches summary() as SummaryScope.year
  // with the day forwarded verbatim.
  blocTest<TransactionBloc, TransactionState>(
    'LoadSummaryRequested(scope: year, day: 15) forwards scope+day to repo.summary',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], ''));
      when(() => txnRepo.summary(2026, 6,
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day'))).thenAnswer((_) async => const dartz.Right(
          MonthlySummary(
              year: 2026, month: 6, scope: SummaryScope.year, incomeCents: 1)));
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadSummaryRequested(
          year: 2026, month: 6, scope: SummaryScope.year, day: 15));
    },
    wait: const Duration(milliseconds: 150),
    verify: (bloc) {
      verify(() => txnRepo.summary(2026, 6,
          accountId: null, scope: SummaryScope.year, day: 15)).called(1);
    },
  );

  // ───────────────────────── Task 5.2: summary ─────────────────────────

  blocTest<TransactionBloc, TransactionState>(
    'LoadSummaryRequested stamps summary onto the current Loaded state',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], ''));
      when(() => txnRepo.summary(2026, 6,
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => const dartz.Right(MonthlySummary(
                year: 2026,
                month: 6,
                incomeCents: 1000,
                expenseCents: 400,
                netCents: 600,
              )));
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadSummaryRequested(year: 2026, month: 6));
    },
    wait: const Duration(milliseconds: 150),
    verify: (bloc) {
      final s = bloc.state as TransactionsLoaded;
      expect(s.summary, isNotNull);
      expect(s.summary!.incomeCents, 1000);
      expect(s.summary!.expenseCents, 400);
      expect(s.summary!.netCents, 600);
      // List contents preserved.
      expect(s.transactions.length, 1);
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadSummaryRequested is a no-op when state is not list-bearing',
    build: () {
      when(() => txnRepo.summary(any(), any(),
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => const dartz.Right(MonthlySummary(
                year: 2026,
                month: 6,
                incomeCents: 1,
              )));
      return TransactionBloc(txnRepo);
    },
    act: (b) => b.add(const LoadSummaryRequested(year: 2026, month: 6)),
    expect: () => const <TransactionState>[],
    verify: (bloc) => expect(bloc.state, isA<TransactionsInitial>()),
  );

  blocTest<TransactionBloc, TransactionState>(
    'a failed summary leaves the prior Loaded state untouched (no error state)',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], ''));
      when(() => txnRepo.summary(any(), any(),
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => const dartz.Left(ServerFailure('boom')));
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadSummaryRequested(year: 2026, month: 6));
    },
    wait: const Duration(milliseconds: 150),
    verify: (bloc) {
      expect(bloc.state, isA<TransactionsLoaded>());
      final s = bloc.state as TransactionsLoaded;
      expect(s.summary, isNull); // prior summary was null; failure leaves it.
    },
  );

  // ───── Issue ① regression: summary must survive a concurrent list reload ─────
  //
  // The account_detail page's _changeScope dispatches BOTH LoadTransactionsRequested
  // (which flips state to TransactionsLoading) AND LoadSummaryRequested in quick
  // succession. If the summary RPC resolves while the list reload is still in
  // flight (state == Loading, not list-bearing), the summary must NOT be silently
  // dropped — otherwise the pie chart shows stale/zero data for the new scope.
  //
  // This test reproduces the race: summary resolves first (fast mock), list
  // resolves second (slow mock). The buffered summary must reappear on the next
  // Loaded state.

  blocTest<TransactionBloc, TransactionState>(
    'LoadSummaryRequested resolves during a list reload: summary is buffered '
    'and stamped onto the next Loaded (issue ① race)',
    build: () {
      // Slow list (50ms) so the summary RPC — fast (0ms) — resolves while the
      // state is still TransactionsLoading.
      when(() => txnRepo.list(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _ok([_txn('t1')], '');
      });
      when(() => txnRepo.summary(2026, 6,
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => const dartz.Right(MonthlySummary(
                year: 2026,
                month: 6,
                incomeCents: 28600,
                expenseCents: 28600,
                netCents: 0,
              )));
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      // Mirror _changeScope → _refreshTxn: dispatch list reload + summary back
      // to back. The summary resolves before the list reload completes.
      b.add(const LoadTransactionsRequested());
      b.add(const LoadSummaryRequested(year: 2026, month: 6));
    },
    wait: const Duration(milliseconds: 150),
    verify: (bloc) {
      expect(bloc.state, isA<TransactionsLoaded>());
      final s = bloc.state as TransactionsLoaded;
      // The buffered DAY/YEAR summary must survive — not dropped while Loading.
      expect(s.summary, isNotNull,
          reason: 'issue ①: summary resolved during Loading must not be dropped');
      expect(s.summary!.incomeCents, 28600);
      expect(s.summary!.expenseCents, 28600);
    },
  );

  // ───── Final-review Important #1: stale-buffer must be keyed ─────
  //
  // _pendingSummary is a single slot keyed by nothing. If account A's summary
  // resolves during a list reload, then the user switches to account B (or a
  // different scope), the buffered A-summary could be stamped onto B's Loaded —
  // stale cross-account/scope data. The buffer must only apply when the
  // LoadTransactionsRequested filter matches the buffered LoadSummaryRequested
  // (accountId + scope + day); otherwise it is discarded.
  //
  // This test: account A summary resolves while Loading; then account B's list
  // is requested. B's Loaded must NOT carry A's summary.

  blocTest<TransactionBloc, TransactionState>(
    'buffered summary is NOT applied to a mismatched-account Loaded '
    '(final-review #1 stale-buffer)',
    build: () {
      // Account A's summary resolves instantly (buffered while accA Loading).
      when(() => txnRepo.summary(2026, 6,
              accountId: 'accA',
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => const dartz.Right(MonthlySummary(
                year: 2026,
                month: 6,
                incomeCents: 999, // marker for accA
              )));
      // Slow list so the summary reliably buffers during Loading.
      when(() => txnRepo.list(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _ok([], '');
      });
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      // accA list reload (goes Loading, slow) + accA summary (fast → buffered).
      b.add(const LoadTransactionsRequested(
          filter: TxnFilterState(accountId: 'accA')));
      b.add(const LoadSummaryRequested(
          year: 2026, month: 6, accountId: 'accA'));
      // Before accA's slow list resolves, switch to accB: its Loaded must NOT
      // carry accA's buffered summary.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      b.add(const LoadTransactionsRequested(
          filter: TxnFilterState(accountId: 'accB')));
    },
    wait: const Duration(milliseconds: 200),
    verify: (bloc) {
      expect(bloc.state, isA<TransactionsLoaded>());
      final s = bloc.state as TransactionsLoaded;
      expect(s.filter.accountId, 'accB');
      expect(s.summary, isNull,
          reason: 'final-review #1: accA buffered summary must not leak into '
              'accB Loaded (stale cross-account data)');
    },
  );

  // Positive counterpart: a MATCHED buffer (same account/scope) IS applied —
  // guards against an over-aggressive fix that drops the buffer unconditionally.
  blocTest<TransactionBloc, TransactionState>(
    'buffered summary IS applied to a matched-account Loaded '
    '(final-review #1 positive)',
    build: () {
      when(() => txnRepo.summary(2026, 6,
              accountId: 'accA',
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => const dartz.Right(MonthlySummary(
                year: 2026,
                month: 6,
                incomeCents: 777,
              )));
      // Slow list so the summary buffers during Loading, then re-applies on
      // the matched accA Loaded.
      when(() => txnRepo.list(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _ok([], '');
      });
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested(
          filter: TxnFilterState(accountId: 'accA')));
      b.add(const LoadSummaryRequested(
          year: 2026, month: 6, accountId: 'accA'));
    },
    wait: const Duration(milliseconds: 150),
    verify: (bloc) {
      final s = bloc.state as TransactionsLoaded;
      expect(s.summary, isNotNull,
          reason: 'matched buffer must apply (regression guard)');
      expect(s.summary!.incomeCents, 777);
    },
  );
}
