// TDD RED → GREEN: 反馈#2-B 交易列表无限滚动 bloc 契约。
//
// Seam: TransactionEvent → TransactionBloc → TransactionRepository.list
// (公共边界 = 事件 + repo 调用参数,不测内部)。
//
// 契约:
//   - LoadTransactionsRequested{pageSize} → repo.list 收到该 pageSize,
//     pageIndex 归 0(首页)。
//   - LoadMoreTransactionsRequested{pageSize} → 携带 prior nextToken 追加,
//     repo.list 收到同一 pageSize,Loaded.pageIndex+1。
//   - 重入防抖:LoadingMore 期间再发 LoadMore = no-op(不重复请求/追加)。
//   - hasMore=false(空 token):LoadMore no-op(既有,回归守卫)。
//   - 筛选/搜索变化(Load 事件):追加若干页后重置回第 1 页(替换,不残留)。
//
// pageSize 默认 100 的兼容面(account_detail 近期交易共享本 bloc)由
// account_detail_txn_suite_test 钉死,此处不重复。
import 'dart:async';

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

Transaction _txn(String id, {DateTime? date}) {
  return Transaction(
    id: id,
    transactionDate: date ?? DateTime(2026, 6, 19),
    description: '流水 $id',
    entries: const [
      TransactionEntry(accountId: 'a1', debitCents: 5000, creditCents: 0),
      TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: 5000),
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
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
            )));
  });

  blocTest<TransactionBloc, TransactionState>(
    'LoadTransactionsRequested(pageSize: 50) forwards pageSize to repo '
    '(first page, pageIndex reset to 0)',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], 'c1'));
      return TransactionBloc(txnRepo);
    },
    act: (b) => b.add(const LoadTransactionsRequested(pageSize: 50)),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [
      isA<TransactionsLoaded>()
          .having((s) => s.pageIndex, 'pageIndex', 0)
          .having((s) => s.hasMore, 'hasMore', true),
    ],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.pageSize, 50, reason: '首页 50 条(#2-B)');
      expect(captured.pageToken, isNull, reason: '首页不带 token');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadMore(pageSize: 50) carries the cursor + same pageSize and appends '
    'with pageIndex+1',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((invocation) async {
        final p =
            invocation.positionalArguments.single as ListTransactionsParams;
        return (p.pageToken ?? '').isEmpty
            ? _ok([_txn('t1'), _txn('t2')], 'c1')
            : _ok([_txn('t3')], '');
      });
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested(pageSize: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadMoreTransactionsRequested(pageSize: 50));
    },
    wait: const Duration(milliseconds: 200),
    skip: 1,
    expect: () => [
      isA<TransactionsLoaded>()
          .having((s) => s.transactions.length, 'page1', 2),
      isA<TransactionsLoadingMore>(),
      isA<TransactionsLoaded>()
          .having((s) => s.transactions.length, 'appended', 3)
          .having((s) => s.pageIndex, 'pageIndex', 1)
          .having((s) => s.hasMore, 'hasMore', false),
    ],
    verify: (_) {
      final calls = verify(() => txnRepo.list(captureAny())).captured
          .cast<ListTransactionsParams>();
      expect(calls.length, 2);
      expect(calls[0].pageSize, 50);
      expect(calls[1].pageSize, 50, reason: '追加页沿用同一 pageSize');
      expect(calls[1].pageToken, 'c1');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadMore during LoadingMore is a no-op (reentry debounce: no duplicate '
    'fetch, no duplicate append)',
    build: () {
      final page2 = Completer<dartz.Either<Failure, ListTransactionsResult>>();
      when(() => txnRepo.list(any())).thenAnswer((invocation) async {
        final p =
            invocation.positionalArguments.single as ListTransactionsParams;
        return (p.pageToken ?? '').isEmpty
            ? _ok([_txn('t1')], 'c1')
            : page2.future;
      });
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested(pageSize: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadMoreTransactionsRequested(pageSize: 50));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // 此时 state == TransactionsLoadingMore(第 2 页未返回)—— 再来一次。
      b.add(const LoadMoreTransactionsRequested(pageSize: 50));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    },
    wait: const Duration(milliseconds: 100),
    // 在 wait 期间补齐第 2 页,让挂起的第一次 LoadMore 正常收尾。
    // (blocTest 的 wait 先于 expect;这里通过 verify + 终态断言替代时序拆分。)
    expect: () => [
      isA<TransactionsLoading>(),
      isA<TransactionsLoaded>(),
      isA<TransactionsLoadingMore>(),
    ],
    verify: (b) {
      // 只有首页 + 一次追加两次请求;第二次 LoadMore 未触发第三次。
      verify(() => txnRepo.list(any())).called(2);
      // 终态仍停在 LoadingMore(第 2 页 completer 未完成)。
      expect(b.state, isA<TransactionsLoadingMore>());
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'LoadMore on the last page (empty token) is a no-op — hasMore '
    'termination (regression guard)',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((_) async => _ok([_txn('t1')], ''));
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested(pageSize: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadMoreTransactionsRequested(pageSize: 50));
    },
    wait: const Duration(milliseconds: 150),
    skip: 1,
    expect: () => [
      isA<TransactionsLoaded>().having((s) => s.hasMore, 'hasMore', false),
      // 无 LoadingMore / 二次 Loaded。
    ],
    verify: (_) => verify(() => txnRepo.list(any())).called(1),
  );

  blocTest<TransactionBloc, TransactionState>(
    'a filter change after appended pages resets to page 1 (replaced, not '
    'residual)',
    build: () {
      when(() => txnRepo.list(any())).thenAnswer((invocation) async {
        final p =
            invocation.positionalArguments.single as ListTransactionsParams;
        if ((p.pageToken ?? '').isEmpty && p.searchText == null) {
          return _ok([_txn('t1'), _txn('t2')], 'c1');
        }
        if (p.pageToken == 'c1') return _ok([_txn('t3')], '');
        // 新筛选的首查:一条、末页。
        return _ok([_txn('s1')], '');
      });
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested(pageSize: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadMoreTransactionsRequested(pageSize: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 追加完两页后改搜索词 → Load 事件 = 重置第 1 页。
      b.add(const LoadTransactionsRequested(
          filter: TxnFilterState(searchText: '早餐'), pageSize: 50));
    },
    wait: const Duration(milliseconds: 200),
    verify: (b) {
      final s = b.state as TransactionsLoaded;
      expect(s.transactions.map((t) => t.id), ['s1'],
          reason: '筛选重置后列表替换,不残留旧页');
      expect(s.pageIndex, 0, reason: '筛选重置 pageIndex 归 0');
      expect(s.hasMore, false);
      final calls = verify(() => txnRepo.list(captureAny())).captured
          .cast<ListTransactionsParams>();
      expect(calls.last.searchText, '早餐');
      expect(calls.last.pageToken, isNull, reason: '重置 = 首页不带 token');
      expect(calls.last.pageSize, 50);
    },
  );
}
