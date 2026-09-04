import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';

/// Dual-source account repository (R6 ADR-1): guest sessions hit the local
/// drift store, every other session keeps the remote gRPC path byte-for-byte.
@LazySingleton(as: AccountRepository)
class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._remote, this._local, this._tracker, [this._mirror]);

  final AccountRemoteDataSource _remote;
  final AccountLocalDataSource _local;
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
  Future<Either<Failure, List<Account>>> list() async =>
      _guard(() => _useLocalDs ? _local.list() : _remote.list());

  @override
  Future<Either<Failure, Account>> create(CreateAccountParams params) =>
      _routedWrite(MirrorModule.account, () => _remote.create(params),
          (markPending) => _local.create(params, markPending: markPending));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _routedWrite(MirrorModule.account, () => _remote.delete(id),
          (markPending) => _local.delete(id, writeTombstone: markPending));

  @override
  Future<Either<Failure, Account>> getById(String id) =>
      _guard(() => _useLocalDs ? _local.getById(id) : _remote.getById(id));

  @override
  Future<Either<Failure, Account>> update(UpdateAccountParams params) =>
      _routedWrite(MirrorModule.account, () => _remote.update(params),
          (markPending) => _local.update(params, markPending: markPending));

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
        final msg = e.message ?? '';
        if (msg.contains('non-zero balance')) {
          return const ServerFailure(
              '账户余额非零，无法删除，请先清空余额或转账后再试');
        }
        return ServerFailure(msg.isNotEmpty ? msg : '操作无法完成');
      default:
        return ServerFailure(e.message ?? e.codeName);
    }
  }
}
