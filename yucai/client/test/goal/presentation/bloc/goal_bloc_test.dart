import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_state.dart';

class _MockRepo extends Mock implements GoalRepository {}

// —— 样本数据 ——

/// 列表用 GoalView(currentAmountCents = 0,未完成)。
const sampleGoalList = GoalView(
  id: 'g1',
  name: 'Emergency Fund',
  type: GoalType.savings,
  targetAmountCents: 1000000,
  currentAmountCents: 0,
  currencyCode: 'CNY',
);

/// 详情用 GoalView(server 端 actuals 已算好,currentAmountCents > 0)。
const sampleGoalDetail = GoalView(
  id: 'g1',
  name: 'Emergency Fund',
  type: GoalType.savings,
  targetAmountCents: 1000000,
  currentAmountCents: 250000,
  currencyCode: 'CNY',
);

/// 克隆产生的新目标(新 id)。
const sampleClonedGoal = GoalView(
  id: 'g2',
  name: 'Emergency Fund (clone)',
  type: GoalType.savings,
  targetAmountCents: 1000000,
  currentAmountCents: 0,
  currencyCode: 'CNY',
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    // mocktail 需为带默认值的 named/positional 参数注册 fallback。
    registerFallbackValue(GoalType.savings);
  });

  // —— LoadListRequested ——

  blocTest<GoalBloc, GoalState>(
    'LoadListRequested emits [Loading, ListLoaded]',
    build: () {
      when(() => repo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => Right([sampleGoalList]));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const LoadListRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      GoalLoading(),
      GoalListLoaded([sampleGoalList]),
    ],
  );

  blocTest<GoalBloc, GoalState>(
    'LoadListRequested(type: debtPayoff) forwards filter to repo',
    build: () {
      when(() => repo.listGoals(type: GoalType.debtPayoff))
          .thenAnswer((_) async => const Right([]));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const LoadListRequested(type: GoalType.debtPayoff)),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      GoalLoading(),
      const GoalListLoaded([]),
    ],
    verify: (b) {
      verify(() => repo.listGoals(type: GoalType.debtPayoff)).called(1);
    },
  );

  blocTest<GoalBloc, GoalState>(
    'LoadListRequested failure emits GoalError',
    build: () {
      when(() => repo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const Left(ServerFailure('list down')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const LoadListRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'list down'),
    ],
  );

  // —— LoadDetailRequested ——

  blocTest<GoalBloc, GoalState>(
    'LoadDetailRequested emits [Loading, DetailLoaded]',
    build: () {
      when(() => repo.getGoal(any()))
          .thenAnswer((_) async => Right(sampleGoalDetail));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('g1')),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      GoalLoading(),
      GoalDetailLoaded(sampleGoalDetail),
    ],
    verify: (b) {
      verify(() => repo.getGoal('g1')).called(1);
    },
  );

  blocTest<GoalBloc, GoalState>(
    'LoadDetailRequested failure emits GoalError',
    build: () {
      when(() => repo.getGoal(any()))
          .thenAnswer((_) async => const Left(ServerFailure('not found')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('missing')),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'not found'),
    ],
  );

  // —— CreateGoalRequested ——

  blocTest<GoalBloc, GoalState>(
    'CreateGoalRequested success refreshes list (Loading deduped, ListLoaded)',
    build: () {
      when(() => repo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => Right(sampleGoalList));
      when(() => repo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => Right([sampleGoalList]));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const CreateGoalRequested(
      name: 'Emergency Fund',
      type: GoalType.savings,
      target: 1000000,
    )),
    wait: const Duration(milliseconds: 150),
    // Note: _onCreate emits GoalLoading, then re-dispatches LoadListRequested
    // which emits GoalLoading again — bloc_test dedupes consecutive equal
    // Equatable states, so only one appears.
    expect: () => [
      GoalLoading(),
      GoalListLoaded([sampleGoalList]),
    ],
    verify: (b) {
      verify(() => repo.createGoal(
            name: 'Emergency Fund',
            type: GoalType.savings,
            targetAmountCents: 1000000,
            deadline: null,
            linkedAccountIds: const [],
            linkedDebtIds: const [],
          )).called(1);
    },
  );

  blocTest<GoalBloc, GoalState>(
    'CreateGoalRequested failure emits GoalError',
    build: () {
      when(() => repo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => const Left(ServerFailure('dup name')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const CreateGoalRequested(
      name: 'Emergency Fund',
      type: GoalType.savings,
      target: 1000000,
    )),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'dup name'),
    ],
    verify: (b) {
      verifyNever(() => repo.listGoals(type: any(named: 'type')));
    },
  );

  // —— UpdateGoalRequested ——

  blocTest<GoalBloc, GoalState>(
    'UpdateGoalRequested success emits DetailLoaded (updateGoal returns GoalView)',
    build: () {
      when(() => repo.updateGoal(
            id: any(named: 'id'),
            name: any(named: 'name'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => Right(sampleGoalDetail));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const UpdateGoalRequested(
      id: 'g1',
      target: 2000000,
    )),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      GoalDetailLoaded(sampleGoalDetail),
    ],
    verify: (b) {
      verify(() => repo.updateGoal(
            id: 'g1',
            name: null,
            targetAmountCents: 2000000,
            deadline: null,
            linkedAccountIds: null,
            linkedDebtIds: null,
          )).called(1);
      // updateGoal 返回 GoalView,直接 emit,不 re-fetch。
      verifyNever(() => repo.getGoal(any()));
    },
  );

  blocTest<GoalBloc, GoalState>(
    'UpdateGoalRequested forwards linkedAccountIds/linkedDebtIds to repo (M2 Task 2)',
    build: () {
      when(() => repo.updateGoal(
            id: any(named: 'id'),
            name: any(named: 'name'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => Right(sampleGoalDetail));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const UpdateGoalRequested(
      id: 'g1',
      name: '新',
      target: 2000000,
      linkedAccountIds: ['a-1', 'a-2'],
      linkedDebtIds: ['d-1'],
    )),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      GoalDetailLoaded(sampleGoalDetail),
    ],
    verify: (b) {
      // load-bearing:linked list 原样透传,无丢失/默认空。
      verify(() => repo.updateGoal(
            id: 'g1',
            name: '新',
            targetAmountCents: 2000000,
            deadline: null,
            linkedAccountIds: ['a-1', 'a-2'],
            linkedDebtIds: ['d-1'],
          )).called(1);
    },
  );

  blocTest<GoalBloc, GoalState>(
    'UpdateGoalRequested failure emits GoalError',
    build: () {
      when(() => repo.updateGoal(
            id: any(named: 'id'),
            name: any(named: 'name'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => const Left(ServerFailure('stale version')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const UpdateGoalRequested(id: 'g1', name: 'new')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'stale version'),
    ],
  );

  // —— DeleteGoalRequested ——

  blocTest<GoalBloc, GoalState>(
    'DeleteGoalRequested success refreshes list',
    build: () {
      when(() => repo.deleteGoal(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const Right([]));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const DeleteGoalRequested('g1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      const GoalListLoaded([]),
    ],
    verify: (b) {
      verify(() => repo.deleteGoal('g1')).called(1);
    },
  );

  blocTest<GoalBloc, GoalState>(
    'DeleteGoalRequested failure emits GoalError',
    build: () {
      when(() => repo.deleteGoal(any()))
          .thenAnswer((_) async => const Left(ServerFailure('no perm')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const DeleteGoalRequested('g1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'no perm'),
    ],
  );

  // —— CompleteGoalRequested: completeGoal 返回 void,必须 re-fetch detail ——

  blocTest<GoalBloc, GoalState>(
    'CompleteGoalRequested re-fetches detail via getGoal',
    build: () {
      when(() => repo.completeGoal(any()))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.getGoal(any()))
          .thenAnswer((_) async => Right(sampleGoalDetail));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const CompleteGoalRequested('g1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      GoalDetailLoaded(sampleGoalDetail),
    ],
    verify: (b) {
      verify(() => repo.completeGoal('g1')).called(1);
      verify(() => repo.getGoal('g1')).called(1);
    },
  );

  blocTest<GoalBloc, GoalState>(
    'CompleteGoalRequested failure (completeGoal) emits GoalError without getGoal',
    build: () {
      when(() => repo.completeGoal(any()))
          .thenAnswer((_) async => const Left(ServerFailure('complete fail')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const CompleteGoalRequested('g1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'complete fail'),
    ],
    verify: (b) {
      verifyNever(() => repo.getGoal(any()));
    },
  );

  // —— RecordContributionRequested: 关键 — recordContribution 返回的
  // GoalView 不保证含最新 actuals,bloc 必须重新 getGoal 取完整 detail,
  // 而非直接 emit recordContribution 的返回值。 ——

  blocTest<GoalBloc, GoalState>(
    'RecordContributionRequested re-fetches detail via getGoal (not the stale recordContribution result)',
    build: () {
      when(() => repo.recordContribution(
            id: any(named: 'id'),
            amountCents: any(named: 'amountCents'),
          )).thenAnswer((_) async => Right(sampleGoalList)); // currentAmountCents = 0 (stale)
      when(() => repo.getGoal(any()))
          .thenAnswer((_) async => Right(sampleGoalDetail)); // currentAmountCents = 250000 (fresh)
      return GoalBloc(repo);
    },
    act: (b) => b.add(const RecordContributionRequested(id: 'g1', amount: 50000)),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      GoalDetailLoaded(sampleGoalDetail),
    ],
    verify: (b) {
      // 关键:必须调 getGoal 取完整 detail,且用正确的 goalId。
      verify(() => repo.getGoal('g1')).called(1);
    },
  );

  blocTest<GoalBloc, GoalState>(
    'RecordContributionRequested failure (recordContribution) emits GoalError without getGoal',
    build: () {
      when(() => repo.recordContribution(
            id: any(named: 'id'),
            amountCents: any(named: 'amountCents'),
          )).thenAnswer((_) async => const Left(ServerFailure('record fail')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const RecordContributionRequested(id: 'g1', amount: 50000)),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'record fail'),
    ],
    verify: (b) {
      verifyNever(() => repo.getGoal(any()));
    },
  );

  // —— CloneGoalRequested: cloneGoal 返回新目标 GoalView(新 id),
  // bloc 用返回的新 id re-fetch detail ——//

  blocTest<GoalBloc, GoalState>(
    'CloneGoalRequested re-fetches detail via getGoal with new cloned id',
    build: () {
      when(() => repo.cloneGoal(
            sourceId: any(named: 'sourceId'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            name: any(named: 'name'),
          )).thenAnswer((_) async => Right(sampleClonedGoal)); // id = g2
      when(() => repo.getGoal('g2'))
          .thenAnswer((_) async => Right(sampleClonedGoal));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const CloneGoalRequested(sourceId: 'g1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      GoalDetailLoaded(sampleClonedGoal),
    ],
    verify: (b) {
      verify(() => repo.cloneGoal(
            sourceId: 'g1',
            targetAmountCents: null,
            deadline: null,
            name: null,
          )).called(1);
      // 关键:用 cloneGoal 返回的新 id (g2) re-fetch,不是 sourceId (g1)。
      verify(() => repo.getGoal('g2')).called(1);
      verifyNever(() => repo.getGoal('g1'));
    },
  );

  blocTest<GoalBloc, GoalState>(
    'CloneGoalRequested failure (cloneGoal) emits GoalError without getGoal',
    build: () {
      when(() => repo.cloneGoal(
            sourceId: any(named: 'sourceId'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            name: any(named: 'name'),
          )).thenAnswer((_) async => const Left(ServerFailure('clone fail')));
      return GoalBloc(repo);
    },
    act: (b) => b.add(const CloneGoalRequested(sourceId: 'g1')),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      GoalLoading(),
      isA<GoalError>().having((s) => s.message, 'message', 'clone fail'),
    ],
    verify: (b) {
      verifyNever(() => repo.getGoal(any()));
    },
  );
}
