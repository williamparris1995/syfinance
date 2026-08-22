import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/data/goal_remote_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';

@LazySingleton(as: GoalRepository)
class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl(this._remote, this._local, this._tracker);

  final GoalRemoteDataSource _remote;
  final GoalLocalDataSource _local;
  final SessionModeTracker _tracker;

  bool get _useLocal => _tracker.isGuest;

  @override
  Future<Either<Failure, List<GoalView>>> listGoals({
    GoalType? type,
    bool? completed,
  }) =>
      _guard(() => _useLocal ? _local.listGoals(type: type, completed: completed) : _remote.listGoals(type: type, completed: completed));

  @override
  Future<Either<Failure, GoalView>> getGoal(String id) =>
      _guard(() => _useLocal ? _local.getGoal(id) : _remote.getGoal(id));

  @override
  Future<Either<Failure, GoalView>> createGoal({
    required String name,
    required GoalType type,
    required int targetAmountCents,
    String currencyCode = 'CNY',
    String? deadline,
    List<String> linkedAccountIds = const [],
    List<String> linkedDebtIds = const [],
    String? notes,
  }) =>
      _guard(() => _useLocal ? _local.createGoal(
            name: name,
            type: type,
            targetAmountCents: targetAmountCents,
            currencyCode: currencyCode,
            deadline: deadline,
            linkedAccountIds: linkedAccountIds,
            linkedDebtIds: linkedDebtIds,
            notes: notes,
          ) : _remote.createGoal(
            name: name,
            type: type,
            targetAmountCents: targetAmountCents,
            currencyCode: currencyCode,
            deadline: deadline,
            linkedAccountIds: linkedAccountIds,
            linkedDebtIds: linkedDebtIds,
            notes: notes,
          ));

  @override
  Future<Either<Failure, GoalView>> updateGoal({
    required String id,
    String? name,
    int? targetAmountCents,
    String? deadline,
    List<String>? linkedAccountIds,
    List<String>? linkedDebtIds,
    String? notes,
    int? version,
  }) =>
      _guard(() => _useLocal ? _local.updateGoal(
            id: id,
            name: name,
            targetAmountCents: targetAmountCents,
            deadline: deadline,
            linkedAccountIds: linkedAccountIds,
            linkedDebtIds: linkedDebtIds,
            notes: notes,
            version: version,
          ) : _remote.updateGoal(
            id: id,
            name: name,
            targetAmountCents: targetAmountCents,
            deadline: deadline,
            linkedAccountIds: linkedAccountIds,
            linkedDebtIds: linkedDebtIds,
            notes: notes,
            version: version,
          ));

  @override
  Future<Either<Failure, void>> deleteGoal(String id) =>
      _guard(() => _useLocal ? _local.deleteGoal(id) : _remote.deleteGoal(id));

  @override
  Future<Either<Failure, void>> completeGoal(String id) =>
      _guard(() => _useLocal ? _local.completeGoal(id) : _remote.completeGoal(id));

  @override
  Future<Either<Failure, GoalView>> recordContribution({
    required String id,
    required int amountCents,
  }) =>
      _guard(() => _useLocal ? _local.recordContribution(
            id: id,
            amountCents: amountCents,
          ) : _remote.recordContribution(
            id: id,
            amountCents: amountCents,
          ));

  @override
  Future<Either<Failure, GoalView>> cloneGoal({
    required String sourceId,
    int? targetAmountCents,
    String? deadline,
    String? name,
  }) =>
      _guard(() => _useLocal ? _local.cloneGoal(
            sourceId: sourceId,
            targetAmountCents: targetAmountCents,
            deadline: deadline,
            name: name,
          ) : _remote.cloneGoal(
            sourceId: sourceId,
            targetAmountCents: targetAmountCents,
            deadline: deadline,
            name: name,
          ));

  @override
  Future<Either<Failure, List<GoalProgressPoint>>> getProgressHistory({
    required String goalId,
    required DateTime from,
    required DateTime to,
  }) =>
      _guard(() => _useLocal ? _local.getProgressHistory(goalId: goalId, from: from, to: to) : _remote.getProgressHistory(goalId: goalId, from: from, to: to));

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(ServerFailure(e.message ?? 'gRPC error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
