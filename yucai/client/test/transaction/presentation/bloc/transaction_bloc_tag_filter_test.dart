// TDD RED → GREEN:F8 T2 标签维度的 bloc 层(spec FR-2)。
//
// 契约(照 transaction_bloc_list_query_test.dart 既有模式):
//   - _params 映射:filter.tagId → params.tagId 原样透传(T1 管道 DS 层经
//     junction 关联集过滤);
//   - tagId 筛选变化 = 重置第 1 页(token 清空、pageIndex=0,与其它筛选维度
//     同语义,F7 FR-4 既有不变式)。
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
  });

  blocTest<TransactionBloc, TransactionState>(
    'FR-2: filter.tagId → params.tagId 原样透传(null = 不过滤)',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested(
        filter: TxnFilterState(tagId: 'tag-1'))),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.tagId, 'tag-1',
          reason: '标签反查 id 需透传到 DS 层 junction 关联集过滤');
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-2: 无 tagId(默认)→ params.tagId == null(NFR 默认行为不变)',
    build: () => TransactionBloc(txnRepo),
    act: (b) => b.add(const LoadTransactionsRequested()),
    wait: const Duration(milliseconds: 100),
    skip: 1,
    expect: () => [isA<TransactionsLoaded>()],
    verify: (_) {
      final captured = verify(() => txnRepo.list(captureAny())).captured.single
          as ListTransactionsParams;
      expect(captured.tagId, isNull);
    },
  );

  blocTest<TransactionBloc, TransactionState>(
    'FR-2: tagId 筛选变化重置第 1 页(token 清空、pageIndex=0)',
    build: () => TransactionBloc(txnRepo),
    act: (b) async {
      b.add(const LoadTransactionsRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      b.add(const GoToTransactionsPageRequested(TxnPageDirection.next));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // 标签筛选变化 → 重置第 1 页(与其它筛选维度同语义)。
      b.add(const LoadTransactionsRequested(
          filter: TxnFilterState(tagId: 'tag-1')));
    },
    wait: const Duration(milliseconds: 250),
    verify: (bloc) {
      final calls = verify(() => txnRepo.list(captureAny())).captured
          .cast<ListTransactionsParams>();
      expect(calls.length, 3);
      // 重置后的查询不带 token(第 1 页)且携带 tagId。
      expect(calls[2].pageToken, isNull);
      expect(calls[2].tagId, 'tag-1');
      final s = bloc.state as TransactionsLoaded;
      expect(s.pageIndex, 0);
      expect(s.filter.tagId, 'tag-1');
    },
  );
}
