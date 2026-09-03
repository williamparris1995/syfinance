// TDD RED → GREEN:F7 T2 列表查询四件套的 bloc 层(FR-1/2/3/4)。
//
// 契约(照 transaction_bloc_test.dart 既有模式):
//   - _params 映射:filter.category(name 串)→ params.category(AccountCategory);
//     filter.searchText → params.searchText;filter.sortKey/sortDir → params。
//   - 分页状态:Loaded/LoadingMore 携带 pageIndex(0 起);hasMore 仍由
//     nextPageToken 推出。
//   - GoToTransactionsPageRequested(next/prev):filter 不变,仅换 pageToken 重查,
//     列表为切片替换(不追加);next 在末页 / prev 在第 1 页为 no-op。
//   - LoadTransactionsRequested(任一筛选/搜索/排序变化)= 重置第 1 页
//     (token 清空、pageIndex=0)。
//   - summary 只随 filter 变化:翻页不重发 summary RPC,且翻页后的 Loaded
//     保留当前 summary。
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockTxnRepo extends Mock implements TransactionRepository {}

Transaction _txn(String id) {
  return Transaction(
    id: id,
    transactionDate: DateTime(2026, 6, 19),
    description: '交易 $id',
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
    // 默认 list 桩:第 1 页 1 条、下一页 token '100';带 '100' 查第 2 页。
    when(() => txnRepo.list(any())).thenAnswer((invocation) async {
      final p = invocation.positionalArguments.single as ListTransactionsParams;
      final token = p.pageToken ?? '';
      if (token.isEmpty) return _ok([_txn('t1')], '100');
      if (token == '100') return _ok([_txn('t2')], '');
      return _ok([_txn('t3')], '');
    });
    // 默认 summary 桩(bloc 不主动发 summary,仅显式 LoadSummaryRequested 用)。
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 100,
            )));
  });

  // ───────────────────── FR-1/2/3:_params 映射 ─────────────────────

  blocTest<TransactionBloc, TransactionState>(
    'FR-1: filter.category(AccountCategory.name 串)→ params.category 枚举',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(category: 'savings'))),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.category, AccountCategory.savings,
          reason: '分类下拉 value 是 AccountCategory.name,bloc 需反查回枚举');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-1: 未知 category 名 → params.category == null(容错不过滤)',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(category: 'no-such-category'))),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.category, isNull);
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-2: filter.searchText → params.searchText 原样透传',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(searchText: '午餐'))),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.searchText, '午餐');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-3: 默认排序 = date/desc(NFR-1 默认行为不变)',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested()),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.sortKey, TxnSortKey.date);
      expect(captured.sortDir, TxnSortDir.desc);
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-3: 排序四态透传(amount/asc)',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(
            sortKey: TxnSortKey.amount, sortDir: TxnSortDir.asc))),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.sortKey, TxnSortKey.amount);
      expect(captured.sortDir, TxnSortDir.asc);
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-3: 排序四态透传(date/asc)',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(sortDir: TxnSortDir.asc))),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.sortKey, TxnSortKey.date);
      expect(captured.sortDir, TxnSortDir.asc);
    },
  );

  // ───────────────────── FR-4:翻页 ─────────────────────

  blocTest<TransactionBloc, TransactionState>(
    'FR-4: 翻页 next 携带 nextToken 前进,列表切片替换不追加,pageIndex 递增',
    build: () => TransactionBloc(txnRepo),
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.next));
    },
    wait: const Duration(milliseconds: 200),
    skip: 1, // 跳过第 1 次请求的 Loading
    expect: () => [
      // 第 1 页 Loaded(pageIndex 0,hasMore true)。
      isA<TransactionsLoaded>()
          .having((s) => s.pageIndex, 'pageIndex', 0)
          .having((s) => s.hasMore, 'hasMore', true),
      isA<TransactionsLoadingMore>().having((s) => s.pageIndex, 'pageIndex', 1),
      // 第 2 页 Loaded:列表 = 第 2 页切片(t2 一条),而非 t1+t2 追加。
      isA<TransactionsLoaded>()
          .having((s) => s.pageIndex, 'pageIndex', 1)
          .having((s) => s.transactions.length, 'replaced', 1)
          .having((s) => s.transactions.first.id, 'page2 first', 't2')
          .having((s) => s.hasMore, 'hasMore', false),
    ],
    verify: (_) {
      final calls = verify(() => txnRepo.list(captureAny())).captured
          .cast<ListTransactionsParams>();
      expect(calls.length, 2);
      expect(calls[0].pageToken, isNull);
      expect(calls[1].pageToken, '100',
          reason: 'next 用上一页返回的 nextToken 查下一页');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-4: 翻页 prev 复用第 1 页 token(空)回退,pageIndex 归 0',
    build: () => TransactionBloc(txnRepo),
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.next));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.prev));
    },
    wait: const Duration(milliseconds: 250),
    verify: (bloc) {
      final calls = verify(() => txnRepo.list(captureAny())).captured
          .cast<ListTransactionsParams>();
      expect(calls.length, 3);
      // 第 3 次调用(prev)回到第 1 页:token 为空(第 1 页无 token)。
      expect(calls[2].pageToken, isNull);
      final s = bloc.state as TransactionsLoaded;
      expect(s.pageIndex, 0);
      expect(s.transactions.first.id, 't1');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-4: 末页 next 为 no-op(不重发查询)',
    build: () => TransactionBloc(txnRepo),
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.next));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 现在在第 2 页且 hasMore=false → next 应被忽略。
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.next));
    },
    wait: const Duration(milliseconds: 200),
    verify: (_) => verify(() => txnRepo.list(any())).called(2),
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-4: 第 1 页 prev 为 no-op',
    build: () => TransactionBloc(txnRepo),
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.prev));
    },
    wait: const Duration(milliseconds: 150),
    verify: (_) => verify(() => txnRepo.list(any())).called(1),
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-4: 筛选/搜索变化重置第 1 页(token 清空、pageIndex=0)',
    build: () => TransactionBloc(txnRepo),
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.next));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 任一筛选/搜索/排序变化 → 重置第 1 页。
      b.add(const LoadTransactionsRequested(
          filter: TxnFilterState(searchText: '午餐')));
    },
    wait: const Duration(milliseconds: 250),
    verify: (bloc) {
      final calls = verify(() => txnRepo.list(captureAny())).captured
          .cast<ListTransactionsParams>();
      expect(calls.length, 3);
      // 重置后的查询不带 token(第 1 页)。
      expect(calls[2].pageToken, isNull);
      final s = bloc.state as TransactionsLoaded;
      expect(s.pageIndex, 0);
      expect(s.filter.searchText, '午餐');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-4: 翻页不重发 summary,且翻页后的 Loaded 保留当前 summary',
    build: () {
      when(() => txnRepo.summary(2026, 6,
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => const dartz.Right(MonthlySummary(
                year: 2026,
                month: 6,
                incomeCents: 999,
              )));
      return TransactionBloc(txnRepo);
    },
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const LoadSummaryRequested(year: 2026, month: 6));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.next));
    },
    wait: const Duration(milliseconds: 250),
    verify: (bloc) {
      // summary 只随 filter 变化:翻页只是切片,不重算。
      verify(() => txnRepo.summary(any(), any(),
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .called(1);
      final s = bloc.state as TransactionsLoaded;
      expect(s.pageIndex, 1);
      expect(s.summary, isNotNull, reason: '翻页后 summary 应保留');
      expect(s.summary!.incomeCents, 999);
    },
  );
}
