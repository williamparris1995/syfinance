import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockRemote extends Mock implements TransactionRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late TransactionRepositoryImpl repo;

  final sampleDate = DateTime(2026, 6, 19);
  final sample = Transaction(
    id: 't1',
    transactionDate: sampleDate,
    description: '午餐',
    entries: <TransactionEntry>[
      TransactionEntry(
        id: 'e1',
        accountId: 'acc-expense',
        debitCents: 5000,
        creditCents: 0,
        note: '食堂',
      ),
      TransactionEntry(
        id: 'e2',
        accountId: 'acc-cash',
        debitCents: 0,
        creditCents: 5000,
        note: '',
      ),
    ],
    version: 1,
  );

  setUp(() {
    remote = _MockRemote();
    repo = TransactionRepositoryImpl(remote);
    registerFallbackValue(RecordExpenseParams(
      transactionDate: sampleDate,
      expenseAccountId: '',
      assetAccountId: '',
      amountCents: 0,
    ));
    registerFallbackValue(RecordIncomeParams(
      transactionDate: sampleDate,
      assetAccountId: '',
      incomeAccountId: '',
      amountCents: 0,
    ));
    // Task 9: `any(named: 'scope')` requires a SummaryScope fallback value.
    registerFallbackValue(SummaryScope.month);
    registerFallbackValue(RecordTransferParams(
      transactionDate: sampleDate,
      fromAccountId: '',
      toAccountId: '',
      amountCents: 0,
    ));
    registerFallbackValue(RecordTransactionParams(
      transactionDate: sampleDate,
      description: '',
      entries: const <TransactionEntry>[],
    ));
    registerFallbackValue(UpdateTransactionParams(
      id: '',
      version: 0,
      entries: const <TransactionEntry>[],
    ));
    registerFallbackValue(ListTransactionsParams());
  });

  group('recordExpense', () {
    test('success returns Right with created transaction', () async {
      final params = RecordExpenseParams(
        transactionDate: sampleDate,
        description: '午餐',
        expenseAccountId: 'acc-expense',
        assetAccountId: 'acc-cash',
        amountCents: 5000,
        note: '食堂',
      );
      when(() => remote.recordExpense(any()))
          .thenAnswer((_) async => sample);

      final result = await repo.recordExpense(params);

      expect(result, Right<Failure, Transaction>(sample));
      final captured = verify(() => remote.recordExpense(captureAny()))
          .captured
          .single as RecordExpenseParams;
      expect(captured.amountCents, 5000);
      expect(captured.expenseAccountId, 'acc-expense');
    });

    test('invalidArgument maps to ValidationFailure', () async {
      when(() => remote.recordExpense(any()))
          .thenThrow(GrpcError.invalidArgument('bad amount'));
      final result = await repo.recordExpense(RecordExpenseParams(
        transactionDate: sampleDate,
        description: '',
        expenseAccountId: 'x',
        assetAccountId: 'y',
        amountCents: 0,
      ));
      expect(result.fold((l) => l, (_) => null), isA<ValidationFailure>());
    });
  });

  group('recordIncome', () {
    test('success forwards params and returns Right', () async {
      final params = RecordIncomeParams(
        transactionDate: sampleDate,
        description: '工资',
        assetAccountId: 'acc-cash',
        incomeAccountId: 'acc-income',
        amountCents: 100000,
      );
      when(() => remote.recordIncome(any())).thenAnswer((_) async => sample);
      final result = await repo.recordIncome(params);
      expect(result.isRight(), isTrue);
    });
  });

  group('recordTransfer', () {
    test('success forwards params and returns Right', () async {
      final params = RecordTransferParams(
        transactionDate: sampleDate,
        description: '转账',
        fromAccountId: 'acc-cash',
        toAccountId: 'acc-bank',
        amountCents: 30000,
      );
      when(() => remote.recordTransfer(any()))
          .thenAnswer((_) async => sample);
      final result = await repo.recordTransfer(params);
      expect(result.isRight(), isTrue);
    });
  });

  group('recordTransaction (full double-entry)', () {
    test('success returns Right with created transaction', () async {
      final params = RecordTransactionParams(
        transactionDate: sampleDate,
        description: '复式',
        entries: sample.entries,
      );
      when(() => remote.recordTransaction(any()))
          .thenAnswer((_) async => sample);
      final result = await repo.recordTransaction(params);
      expect(result, Right<Failure, Transaction>(sample));
    });
  });

  group('list', () {
    test('success returns Right with transaction list', () async {
      when(() => remote.list(any())).thenAnswer((_) async =>
          ListTransactionsResult(transactions: [sample], nextPageToken: ''));
      final result = await repo.list(ListTransactionsParams());
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (page) {
          expect(page.transactions.length, 1);
          expect(page.transactions.first.id, 't1');
          expect(page.transactions.first.entries.length, 2);
          expect(page.hasMore, isFalse);
        },
      );
    });

    test('unavailable maps to NetworkFailure', () async {
      when(() => remote.list(any()))
          .thenThrow(GrpcError.unavailable('down'));
      final result = await repo.list(ListTransactionsParams());
      expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
    });
  });

  group('getById', () {
    test('success returns the transaction', () async {
      when(() => remote.getById('t1')).thenAnswer((_) async => sample);
      final result = await repo.getById('t1');
      expect(result, Right<Failure, Transaction>(sample));
    });

    test('notFound maps to ServerFailure', () async {
      when(() => remote.getById(any()))
          .thenThrow(GrpcError.notFound('gone'));
      final result = await repo.getById('x');
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });
  });

  group('update', () {
    test('success returns the updated transaction', () async {
      final params = UpdateTransactionParams(
        id: 't1',
        version: 1,
        description: '午餐（改）',
        entries: sample.entries,
      );
      when(() => remote.update(any())).thenAnswer((_) async => sample);
      final result = await repo.update(params);
      expect(result.isRight(), isTrue);
    });
  });

  group('delete', () {
    test('success returns Right(null)', () async {
      when(() => remote.delete('t1')).thenAnswer((_) async {});
      final result = await repo.delete('t1');
      expect(result.isRight(), isTrue);
    });
  });

  group('summary (Task 5.2 — wired to TransactionSummary RPC)', () {
    final sampleSummary = MonthlySummary(
      year: 2026,
      month: 6,
      incomeCents: 1200000,
      expenseCents: 800000,
      netCents: 400000,
      dailyAvgCents: 13333,
    );

    test('forwards (year, month, accountId) and returns Right', () async {
      when(() => remote.summary(2026, 6,
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => sampleSummary);
      final result = await repo.summary(2026, 6, accountId: 'acc-1');
      expect(result, Right<Failure, MonthlySummary>(sampleSummary));
      verify(() => remote.summary(2026, 6,
              accountId: 'acc-1',
              scope: SummaryScope.month,
              day: null))
          .called(1);
    });

    test('null accountId forwarded as null', () async {
      when(() => remote.summary(any(), any(),
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => sampleSummary);
      await repo.summary(2026, 6);
      verify(() => remote.summary(2026, 6,
              accountId: null, scope: SummaryScope.month, day: null))
          .called(1);
    });

    test('forwards scope + day when provided (Task 9)', () async {
      when(() => remote.summary(any(), any(),
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenAnswer((_) async => sampleSummary);
      await repo.summary(2026, 6, scope: SummaryScope.year, day: 15);
      verify(() => remote.summary(2026, 6,
              accountId: null, scope: SummaryScope.year, day: 15))
          .called(1);
    });

    test('unavailable maps to NetworkFailure', () async {
      when(() => remote.summary(any(), any(),
              accountId: any(named: 'accountId'),
              scope: any(named: 'scope'),
              day: any(named: 'day')))
          .thenThrow(GrpcError.unavailable('down'));
      final result = await repo.summary(2026, 6);
      expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
    });
  });

  group('DTO ↔ entity round-trip (sanity)', () {
    test('Transaction equality holds for reconstructed entries', () {
      final t1 = sample;
      final t2 = Transaction(
        id: 't1',
        transactionDate: sampleDate,
        description: '午餐',
        entries: <TransactionEntry>[
          TransactionEntry(
            id: 'e1',
            accountId: 'acc-expense',
            debitCents: 5000,
            creditCents: 0,
            note: '食堂',
          ),
          TransactionEntry(
            id: 'e2',
            accountId: 'acc-cash',
            debitCents: 0,
            creditCents: 5000,
            note: '',
          ),
        ],
        version: 1,
      );
      expect(t1, t2);
      expect(t1.entries.first.entrySide, EntrySide.debit);
      expect(t1.entries.last.entrySide, EntrySide.credit);
    });
  });
}
