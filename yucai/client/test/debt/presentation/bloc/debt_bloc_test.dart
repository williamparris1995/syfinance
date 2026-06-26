import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';

class _MockRepo extends Mock implements DebtRepository {}

final sample = Debt(
  id: 'd1',
  accountId: 'a1',
  counterparty: 'Bank A',
  interestRate: 5.0,
  amortization: AmortizationMethod.equalPrincipalInterest,
  startDate: DateTime(2026, 1, 1),
  dueDate: DateTime(2027, 1, 1),
  totalPrincipalCents: 1000000,
  remainingPrincipalCents: 800000,
  version: 1,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

final paymentEntry = PaymentEntry(
  id: 's1',
  paymentDate: DateTime(2026, 2, 1),
  principalCents: 100000,
  interestCents: 4000,
  totalCents: 104000,
  paid: false,
  paidCents: 0,
  transactionId: '',
);

final detail = DebtDetail(
  debt: sample,
  schedule: [paymentEntry],
);

final createParams = CreateDebtParams(
  accountId: 'a1',
  counterparty: 'Bank A',
  interestRate: 5.0,
  amortizationIndex: 0,
  startDateOption: DateTime(2026, 1, 1),
  dueDateOption: DateTime(2027, 1, 1),
  totalPrincipalCents: 1000000,
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    registerFallbackValue(createParams);
  });

  blocTest<DebtBloc, DebtState>(
    'LoadDebts emits [Loading, Loaded]',
    build: () {
      when(() => repo.list()).thenAnswer((_) async => Right([sample]));
      return DebtBloc(repo);
    },
    act: (b) => b.add(LoadDebtsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [DebtLoading(), DebtsLoaded([sample])],
  );

  blocTest<DebtBloc, DebtState>(
    'LoadDebts failure emits [Loading, Error]',
    build: () {
      when(() => repo.list())
          .thenAnswer((_) async => const Left(ServerFailure('down')));
      return DebtBloc(repo);
    },
    act: (b) => b.add(LoadDebtsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [DebtLoading(), isA<DebtError>()],
  );

  blocTest<DebtBloc, DebtState>(
    'LoadDebt emits [Loading, DetailLoaded]',
    build: () {
      when(() => repo.get('d1')).thenAnswer((_) async => Right(detail));
      return DebtBloc(repo);
    },
    act: (b) => b.add(const LoadDebtRequested('d1')),
    wait: const Duration(milliseconds: 100),
    expect: () => [DebtLoading(), DebtDetailLoaded(detail)],
  );

  blocTest<DebtBloc, DebtState>(
    'Create success emits Submitting then refreshes list',
    build: () {
      when(() => repo.create(
            accountId: any(named: 'accountId'),
            counterparty: any(named: 'counterparty'),
            interestRate: any(named: 'interestRate'),
            amortizationIndex: any(named: 'amortizationIndex'),
            startDate: any(named: 'startDate'),
            dueDate: any(named: 'dueDate'),
            totalPrincipalCents: any(named: 'totalPrincipalCents'),
          )).thenAnswer((_) async => Right(sample));
      when(() => repo.list()).thenAnswer((_) async => Right([sample]));
      return DebtBloc(repo);
    },
    act: (b) => b.add(CreateDebtRequested(createParams)),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<DebtSubmitting>(),
      DebtLoading(),
      DebtsLoaded([sample]),
    ],
  );

  blocTest<DebtBloc, DebtState>(
    'Update success refreshes the list',
    build: () {
      when(() => repo.update(
            id: any(named: 'id'),
            counterparty: any(named: 'counterparty'),
            interestRate: any(named: 'interestRate'),
            version: any(named: 'version'),
          )).thenAnswer((_) async => Right(sample));
      when(() => repo.list()).thenAnswer((_) async => Right([sample]));
      return DebtBloc(repo);
    },
    act: (b) => b.add(
      const UpdateDebtRequested(
        UpdateDebtParams(id: 'd1', counterparty: 'B', interestRate: 6.0, version: 1),
      ),
    ),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<DebtSubmitting>(),
      DebtLoading(),
      DebtsLoaded([sample]),
    ],
  );

  blocTest<DebtBloc, DebtState>(
    'Delete success refreshes the list',
    build: () {
      when(() => repo.delete('d1')).thenAnswer((_) async => const Right(null));
      when(() => repo.list()).thenAnswer((_) async => Right([sample]));
      return DebtBloc(repo);
    },
    act: (b) => b.add(const DeleteDebtRequested('d1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [DebtLoading(), DebtsLoaded([sample])],
  );

  blocTest<DebtBloc, DebtState>(
    'RecordPayment refreshes detail',
    build: () {
      when(() => repo.recordPayment(
            debtId: any(named: 'debtId'),
            scheduleEntryId: any(named: 'scheduleEntryId'),
            fromAccountId: any(named: 'fromAccountId'),
          )).thenAnswer((_) async => Right(paymentEntry));
      when(() => repo.get('d1')).thenAnswer((_) async => Right(detail));
      return DebtBloc(repo);
    },
    act: (b) => b.add(
      const RecordPaymentRequested(
        debtId: 'd1',
        scheduleEntryId: 's1',
        fromAccountId: 'a1',
      ),
    ),
    wait: const Duration(milliseconds: 150),
    expect: () => [DebtLoading(), DebtDetailLoaded(detail)],
  );
}
