import 'package:flutter_test/flutter_test.dart';
import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Debt;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

class _MockRemote extends Mock implements DebtRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase db;
  late SessionModeTracker tracker;
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
    db = AppDatabase(NativeDatabase.memory());
    tracker = SessionModeTracker()..isGuest = false;
    repo = DebtRepositoryImpl(remote, DebtLocalDataSource(db, TransactionLocalDataSource(db, BalanceLocalUpdater(db))), tracker);
  });

  test('list success returns Right with debts', () async {
    when(() => remote.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => [sample]);
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
    when(() => remote.list(typeFilter: any(named: 'typeFilter')))
        .thenThrow(const GrpcError.notFound('gone'));
    final result = await repo.list();
    expect(result.isLeft(), isTrue);
    expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
  });

  test('list forwards typeFilter to remote', () async {
    when(() => remote.list(typeFilter: DebtType.borrowedOut))
        .thenAnswer((_) async => [sample]);
    await repo.list(typeFilter: DebtType.borrowedOut);
    verify(() => remote.list(typeFilter: DebtType.borrowedOut)).called(1);
  });

  test('get success returns Right with DebtDetail', () async {
    final detail = DebtDetail(debt: sample, schedule: const []);
    when(() => remote.get('d1')).thenAnswer((_) async => detail);
    final result = await repo.get('d1');
    expect(result, Right<Failure, DebtDetail>(detail));
  });

  test('update forwards subtype to remote DS(F33-T4 透传)', () async {
    when(() => remote.update(
          id: any(named: 'id'),
          counterparty: any(named: 'counterparty'),
          interestRate: any(named: 'interestRate'),
          version: any(named: 'version'),
          contact: any(named: 'contact'),
          contractRef: any(named: 'contractRef'),
          guarantorName: any(named: 'guarantorName'),
          guarantorContact: any(named: 'guarantorContact'),
          collectionAccountId: any(named: 'collectionAccountId'),
          amortizationIndex: any(named: 'amortizationIndex'),
          dueDate: any(named: 'dueDate'),
          termPeriods: any(named: 'termPeriods'),
          cycle: any(named: 'cycle'),
          interval: any(named: 'interval'),
          weekdayMask: any(named: 'weekdayMask'),
          monthlyMode: any(named: 'monthlyMode'),
          nth: any(named: 'nth'),
          interestWaivedCents: any(named: 'interestWaivedCents'),
          subtype: any(named: 'subtype'),
        )).thenAnswer((_) async => sample);
    final result = await repo.update(
      id: 'd1',
      counterparty: 'Bank',
      interestRate: 5.0,
      version: 1,
      subtype: 'credit_card',
    );
    expect(result.isRight(), isTrue);
    verify(() => remote.update(
          id: 'd1',
          counterparty: 'Bank',
          interestRate: 5.0,
          version: 1,
          subtype: 'credit_card',
        )).called(1);
  });

  test('delete success returns Right(null)', () async {
    when(() => remote.delete('d1')).thenAnswer((_) async {});
    final result = await repo.delete('d1');
    expect(result.isRight(), isTrue);
  });

  test('delete failure returns Left<ServerFailure>', () async {
    when(() => remote.delete(any())).thenThrow(const GrpcError.notFound('gone'));
    final result = await repo.delete('x');
    expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
  });
}
