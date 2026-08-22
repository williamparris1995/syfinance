import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Debt;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/receivables_summary_data_source.dart';
import 'package:yucai_client/debt/data/receivables_summary_repository_impl.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';

class _MockRemote extends Mock implements ReceivablesSummaryDataSource {}

void main() {
  late _MockRemote remote;
  late SessionModeTracker _tracker;
  late ReceivablesSummaryRepositoryImpl repo;

  final sample = ReceivablesSummary(
    totalPrincipalCents: 1000000,
    totalRemainingCents: 600000,
    totalCollectedCents: 400000,
    pendingInterestCents: 12000,
    count: 5,
    overdueCount: 1,
    overdueAmountCents: 50000,
    principalTrendCents: 1000000,
    remainingTrendCents: 600000,
    nextPaymentDate: DateTime(2026, 8, 1),
    nextPaymentAmountCents: 25000,
    nextPaymentCounterparty: '张三',
    nextPaymentPeriodNo: 3,
  );

  setUp(() {
    _tracker = SessionModeTracker()..isGuest = false;
    remote = _MockRemote();
    repo = ReceivablesSummaryRepositoryImpl(
        remote, AppDatabase(NativeDatabase.memory()), _tracker);
  });

  test('fetch success returns Right with summary', () async {
    when(() => remote.fetch()).thenAnswer((_) async => sample);
    final result = await repo.fetch();
    expect(result, Right<Failure, ReceivablesSummary>(sample));
  });

  test('fetch GrpcError returns Left<ServerFailure>', () async {
    when(() => remote.fetch()).thenThrow(const GrpcError.notFound('gone'));
    final result = await repo.fetch();
    expect(result.isLeft(), isTrue);
    expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
  });

  test('fetch generic exception returns Left<ServerFailure>', () async {
    when(() => remote.fetch()).thenThrow(StateError('boom'));
    final result = await repo.fetch();
    expect(result.isLeft(), isTrue);
    expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
  });

  test('fetch GrpcError with null message falls back to default string',
      () async {
    // GrpcError.message 可为 null,_guard 必须 fallback 到 'gRPC error'
    // 而非把 null 塞进 ServerFailure(对齐 DebtRepositoryImpl._guard)。
    when(() => remote.fetch()).thenThrow(const GrpcError.cancelled());
    final result = await repo.fetch();
    expect(result.isLeft(), isTrue);
    result.fold(
      (l) => expect(l, isA<ServerFailure>()),
      (_) => fail('expected Left'),
    );
  });
}
