import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/data/goal_remote_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';

@LazySingleton(as: GoalRepository)
class GoalRepositoryImpl implements GoalRepository {
  GoalRepositoryImpl(this._remote, this._local, this._tracker, [this._mirror]);

  final GoalRemoteDataSource _remote;
  final GoalLocalDataSource _local;
  final SessionModeTracker _tracker;
  final BoundMirror? _mirror;

  /// F10 FR-1:三态数据路由(guestLocal / boundRemote / boundOfflineLocal)。
  /// guest 或 bound-offline 走本地;仅绑定在线走远端(在线行为与 R6 的
  /// `_useLocal => isGuest` 逐位一致)。
  bool get _useLocalDs {
    final route = _tracker.resolveDataRoute();
    return route == DataRoute.guestLocal || route == DataRoute.boundOfflineLocal;
  }

  @override
  Future<Either<Failure, List<GoalView>>> listGoals({
    GoalType? type,
    bool? completed,
  }) =>
      _guard(() => _useLocalDs ? _local.listGoals(type: type, completed: completed) : _remote.listGoals(type: type, completed: completed));

  @override
  Future<Either<Failure, GoalView>> getGoal(String id) =>
      _guard(() => _useLocalDs ? _local.getGoal(id) : _remote.getGoal(id));

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
      _routedWrite(MirrorModule.goal,
          () => _remote.createGoal(
            name: name,
            type: type,
            targetAmountCents: targetAmountCents,
            currencyCode: currencyCode,
            deadline: deadline,
            linkedAccountIds: linkedAccountIds,
            linkedDebtIds: linkedDebtIds,
            notes: notes,
          ),
          () => _local.createGoal(
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
      _routedWrite(MirrorModule.goal,
          () => _remote.updateGoal(
            id: id,
            name: name,
            targetAmountCents: targetAmountCents,
            deadline: deadline,
            linkedAccountIds: linkedAccountIds,
            linkedDebtIds: linkedDebtIds,
            notes: notes,
            version: version,
          ),
          () => _local.updateGoal(
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
      _routedWrite(MirrorModule.goal, () => _remote.deleteGoal(id), () => _local.deleteGoal(id));

  @override
  Future<Either<Failure, void>> completeGoal(String id) =>
      _routedWrite(MirrorModule.goal, () => _remote.completeGoal(id), () => _local.completeGoal(id));

  @override
  Future<Either<Failure, GoalView>> recordContribution({
    required String id,
    required int amountCents,
  }) =>
      _routedWrite(MirrorModule.goal,
          () => _remote.recordContribution(id: id, amountCents: amountCents),
          () => _local.recordContribution(id: id, amountCents: amountCents));

  @override
  Future<Either<Failure, GoalView>> cloneGoal({
    required String sourceId,
    int? targetAmountCents,
    String? deadline,
    String? name,
  }) =>
      _routedWrite(MirrorModule.goal,
          () => _remote.cloneGoal(
            sourceId: sourceId,
            targetAmountCents: targetAmountCents,
            deadline: deadline,
            name: name,
          ),
          () => _local.cloneGoal(
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
      _guard(() => _useLocalDs ? _local.getProgressHistory(goalId: goalId, from: from, to: to) : _remote.getProgressHistory(goalId: goalId, from: from, to: to));

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  /// Bound-state mirror hook (R6 H): after a SUCCESSFUL REMOTE
  /// write, refresh this module's local mirror (fire-and-forget).
  Future<Either<Failure, T>> _mirrored<T>(MirrorModule m,
      Future<Either<Failure, T>> Function() body) async {
    final r = await body();
    if (r.isRight() && !_useLocalDs && _mirror != null) {
      unawaited(_mirror.refreshModule(m));
    }
    return r;
  }

  /// F10 FR-1/FR-1b:三态写路由 + 远端失败降级(照 transaction 范式)。
  /// guest/bound-offline 直接本地;boundRemote 先远端(Right 触发镜像刷新,
  /// 与 R6 逐位一致),NetworkFailure 降级本地落库(FR-1b 双保险)且不触发
  /// 镜像刷新(防 delete-all+rebuild 抹掉未上行本地行);其他失败原样 Left。
  /// TODO-F10T2:降级/离线写本地置 pending + 回网上行(本任务不做,锚点)。
  Future<Either<Failure, T>> _routedWrite<T>(MirrorModule m,
      Future<T> Function() remote, Future<T> Function() local) async {
    if (_useLocalDs) {
      return _mirrored(m, () => _guard(local));
    }
    return writeWithFallback(
      () => _mirrored(m, () => _guard(remote)),
      () => _guard(local),
    );
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } on Failure catch (f) {
      // Local data source failures pass through untouched.
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// F10 FR-1b:unavailable → NetworkFailure 是写降级判定的前提(照
  /// holding 范式);仅取 unavailable 分支以最小化行为变化(holding 另有
  /// unauthenticated 映射,刻意不抄),其余错误保持既有 ServerFailure
  /// 分类,行为不变。
  Failure _mapGrpcError(GrpcError e) {
    if (e.code == StatusCode.unavailable) {
      return NetworkFailure(e.message ?? '无法连接服务器');
    }
    return ServerFailure(e.message ?? 'gRPC error');
  }
}
