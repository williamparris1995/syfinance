import 'dart:async';

import 'dart:developer' as developer;

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

@LazySingleton(as: TransactionRepository)
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._remote, this._local, this._tracker, [this._mirror]);

  final TransactionRemoteDataSource _remote;
  final TransactionLocalDataSource _local;
  final SessionModeTracker _tracker;
  final BoundMirror? _mirror;

  /// F10 FR-1:三态数据路由(guestLocal / boundRemote / boundOfflineLocal)。
  /// guest 或 bound-offline(断网 / 离线冷启动)走本地 drift;仅绑定在线走
  /// 远端 —— 在线场景与 R6 的 `_useLocal => isGuest` 行为逐位一致。
  bool get _useLocalDs {
    final route = _tracker.resolveDataRoute();
    return route == DataRoute.guestLocal || route == DataRoute.boundOfflineLocal;
  }

  @override
  Future<Either<Failure, Transaction>> recordExpense(
          RecordExpenseParams params) =>
      _routedWrite(MirrorModule.transaction, () => _remote.recordExpense(params),
          (markPending) => _local.recordExpense(params, markPending: markPending));

  @override
  Future<Either<Failure, Transaction>> recordIncome(
          RecordIncomeParams params) =>
      _routedWrite(MirrorModule.transaction, () => _remote.recordIncome(params),
          (markPending) => _local.recordIncome(params, markPending: markPending));

  @override
  Future<Either<Failure, Transaction>> recordTransfer(
          RecordTransferParams params) =>
      _routedWrite(MirrorModule.transaction, () => _remote.recordTransfer(params),
          (markPending) => _local.recordTransfer(params, markPending: markPending));

  @override
  Future<Either<Failure, Transaction>> recordTransaction(
          RecordTransactionParams params) =>
      _routedWrite(MirrorModule.transaction, () => _remote.recordTransaction(params),
          (markPending) => _local.recordTransaction(params, markPending: markPending));

  @override
  Future<Either<Failure, ListTransactionsResult>> list(
          ListTransactionsParams params) =>
      _guard(() => _useLocalDs ? _local.list(params) : _remote.list(params));

  @override
  Future<Either<Failure, Transaction>> getById(String id) =>
      _guard(() => _useLocalDs ? _local.getById(id) : _remote.getById(id));

  @override
  Future<Either<Failure, Transaction>> update(
          UpdateTransactionParams params) =>
      _routedWrite(MirrorModule.transaction, () => _remote.update(params),
          (markPending) => _local.update(params, markPending: markPending));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _routedWrite(MirrorModule.transaction, () => _remote.delete(id),
          (markPending) => _local.delete(id, writeTombstone: markPending));

  @override
  Future<Either<Failure, MonthlySummary>> summary(
    int year,
    int month, {
    String? accountId,
    SummaryScope scope = SummaryScope.month,
    int? day,
  }) =>
      _guard(() => _useLocalDs
          ? _local.summary(year, month,
              accountId: accountId, scope: scope, day: day)
          : _remote.summary(year, month,
              accountId: accountId, scope: scope, day: day));

  /// Maps thrown GrpcError / exceptions to [Failure], wrapping the op in
  /// Either. Mirrors [AccountRepositoryImpl._guard].
  ///
  /// Logs every exception with the runtime type + message so a crash that the
  /// static DI/proto wiring can't surface shows up in the console as
  /// `[TXN] _guard(...)`. This was added during the post-4643811 investigation:
  /// DI was confirmed correct but users still reported list/detail crashes, so
  /// the actual exception needed to be observable at runtime.
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

  /// F10 FR-1/FR-1b:三态写路由 + 远端失败降级(8 repo 统一模式)。
  /// - guestLocal / boundOfflineLocal:直接本地写(`_mirrored` 的刷新条件
  ///   `!_useLocalDs` 不成立,不触发镜像,与 R6 guest 语义一致);
  /// - boundRemote:先远端,Right 直返并触发模块镜像刷新(与 R6 在线路径
  ///   逐位一致);NetworkFailure(grpc unavailable / 断网)→ 降级本地写
  ///   落库(FR-1b 双保险:connectivity 误报在线的兜底),降级成功**不**
  ///   触发镜像刷新 —— delete-all+rebuild 的镜像重建会抹掉未上行的本地行;
  /// - 其他失败(校验 / 权限 / 服务端错误)不降级,原样 Left 上抛。
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
    } on GrpcError catch (e, st) {
      debugPrint('[TXN] _guard GrpcError: code=${e.code} '
          'name=${e.codeName} msg=${e.message}');
      developer.log('[TXN] _guard GrpcError', name: 'txn.repo',
          error: e, stackTrace: st);
      return Left(_mapGrpcError(e));
    } on Failure catch (f) {
      // Local data source failures pass through untouched.
      return Left(f);
    } catch (e, st) {
      debugPrint('[TXN] _guard ${e.runtimeType}: $e');
      developer.log('[TXN] _guard ${e.runtimeType}', name: 'txn.repo',
          error: e, stackTrace: st);
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  Failure _mapGrpcError(GrpcError e) {
    switch (e.code) {
      case StatusCode.unauthenticated:
        return AuthFailure(e.message ?? '凭证无效');
      case StatusCode.unavailable:
        return NetworkFailure(e.message ?? '无法连接服务器');
      case StatusCode.invalidArgument:
        return ValidationFailure(e.message ?? '参数错误');
      case StatusCode.failedPrecondition:
        return ServerFailure(e.message?.isNotEmpty == true ? e.message! : '操作无法完成');
      default:
        return ServerFailure(e.message ?? e.codeName);
    }
  }
}
