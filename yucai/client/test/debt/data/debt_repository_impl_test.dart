import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

class _MockRemote extends Mock implements DebtRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late DebtRepositoryImpl repo;

  final sample = Debt(
    id: 'd1',
    accountId: 'a1',
    counterparty: 'Bank',
    interestRate: 5.0,
    amortization: AmortizationMethod.equalPrincipalInterest,
    startDate: DateTime(2026, 1, 1),
    dueDate: DateTime(2026, 12, 31),
    totalPrincipalCents: 100000,
    remainingPrincipalCents: 100000,
    version: 1,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    remote = _MockRemote();
    repo = DebtRepositoryImpl(remote);
  });

  test('list success returns Right with debts', () async {
    when(() => remote.list()).thenAnswer((_) async => [sample]);
    final result = await repo.list();
    expect(result.isRight(), isTrue);
    result.fold(
      (_) => fail('expected Right'),
      (debts) {
        expect(debts.length, 1);
        expect(debts.first.id, 'd1');
      },
    );
  });

  test('list failure returns Left<ServerFailure>', () async {
    when(() => remote.list()).thenThrow(GrpcError.notFound('gone'));
    final result = await repo.list();
    expect(result.isLeft(), isTrue);
    expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
  });

  test('get success returns Right with DebtDetail', () async {
    final detail = DebtDetail(debt: sample, schedule: const []);
    when(() => remote.get('d1')).thenAnswer((_) async => detail);
    final result = await repo.get('d1');
    expect(result, Right<Failure, DebtDetail>(detail));
  });

  test('delete success returns Right(null)', () async {
    when(() => remote.delete('d1')).thenAnswer((_) async {});
    final result = await repo.delete('d1');
    expect(result.isRight(), isTrue);
  });

  test('delete failure returns Left<ServerFailure>', () async {
    when(() => remote.delete(any())).thenThrow(GrpcError.notFound('gone'));
    final result = await repo.delete('x');
    expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
  });
}
