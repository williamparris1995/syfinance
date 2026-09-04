import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';

@LazySingleton(as: BudgetRepository)
class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this._remote, this._local, this._tracker, [this._mirror]);

  final BudgetRemoteDataSource _remote;
  final BudgetLocalDataSource _local;
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
  Future<Either<Failure, List<BudgetView>>> listBudgets({bool activeOnly = false}) =>
      _guard(() => _useLocalDs ? _local.listBudgets(activeOnly: activeOnly) : _remote.listBudgets(activeOnly: activeOnly));

  @override
  Future<Either<Failure, BudgetView>> getBudget(String id) =>
      _guard(() => _useLocalDs ? _local.getBudget(id) : _remote.getBudget(id));

  @override
  Future<Either<Failure, BudgetView>> getBudgetByMonth(String month) =>
      _guard(() => _useLocalDs ? _local.getBudgetByMonth(month) : _remote.getBudgetByMonth(month));

  @override
  Future<Either<Failure, BudgetView>> createBudget({
    required String name,
    required String month,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) =>
      _routedWrite(MirrorModule.budget,
          () => _remote.createBudget(name: name, month: month, currencyCode: currencyCode, items: items),
          (markPending) => _local.createBudget(
              name: name, month: month, currencyCode: currencyCode, items: items,
              markPending: markPending));

  @override
  Future<Either<Failure, void>> deleteBudget(String id) =>
      _routedWrite(MirrorModule.budget, () => _remote.deleteBudget(id),
          (markPending) => _local.deleteBudget(id, writeTombstone: markPending));

  @override
  Future<Either<Failure, BudgetView>> addItem({
    required String budgetId,
    required String accountId,
    required int plannedAmountCents,
    String? notes,
  }) =>
      _routedWrite(MirrorModule.budget,
          () => _remote.addItem(budgetId: budgetId, accountId: accountId, plannedAmountCents: plannedAmountCents, notes: notes),
          (markPending) => _local.addItem(
              budgetId: budgetId, accountId: accountId,
              plannedAmountCents: plannedAmountCents, notes: notes,
              markPending: markPending));

  @override
  Future<Either<Failure, BudgetView>> removeItem({
    required String budgetId,
    required String itemId,
  }) =>
      _routedWrite(MirrorModule.budget,
          () => _remote.removeItem(budgetId: budgetId, itemId: itemId),
          (markPending) => _local.removeItem(
              budgetId: budgetId, itemId: itemId, markPending: markPending));

  @override
  Future<Either<Failure, BudgetView>> updateBudget({
    required String id,
    required String name,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) =>
      _routedWrite(MirrorModule.budget,
          () => _remote.updateBudget(id: id, name: name, currencyCode: currencyCode, items: items),
          (markPending) => _local.updateBudget(
              id: id, name: name, currencyCode: currencyCode, items: items,
              markPending: markPending));

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
  Future<Either<Failure, T>> _routedWrite<T>(MirrorModule m,
      Future<T> Function() remote,
      Future<T> Function(bool markPending) local) async {
    switch (_tracker.resolveDataRoute()) {
      case DataRoute.guestLocal:
        // guest 行 synced(无上行语义,R6 行为不变;缺省不传 = false)。
        return _mirrored(m, () => _guard(() => local(false)));
      case DataRoute.boundOfflineLocal:
        // 离线写本地,行 pending 待回网上行(FR-3,T2 落地)。
        return _mirrored(m, () => _guard(() => local(true)));
      case DataRoute.boundRemote:
        // 在线先远端(Right 触发镜像刷新,与 R6 逐位一致);NetworkFailure
        // 降级本地落库置 pending(FR-1b 双保险,同为 bound 路由)。
        return writeWithFallback(
          () => _mirrored(m, () => _guard(remote)),
          () => _guard(() => local(true)),
        );
    }
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
