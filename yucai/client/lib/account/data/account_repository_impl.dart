import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';
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

  bool get _useLocal => _tracker.isGuest;

  @override
  Future<Either<Failure, List<Account>>> list() async =>
      _guard(() => _useLocal ? _local.list() : _remote.list());

  @override
  Future<Either<Failure, Account>> create(CreateAccountParams params) =>
      _mirrored(MirrorModule.account, () => _guard(() => _useLocal ? _local.create(params) : _remote.create(params)));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _mirrored(MirrorModule.account, () => _guard(() => _useLocal ? _local.delete(id) : _remote.delete(id)));

  @override
  Future<Either<Failure, Account>> getById(String id) =>
      _guard(() => _useLocal ? _local.getById(id) : _remote.getById(id));

  @override
  Future<Either<Failure, Account>> update(UpdateAccountParams params) =>
      _mirrored(MirrorModule.account, () => _guard(() => _useLocal ? _local.update(params) : _remote.update(params)));

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  /// Bound-state mirror hook (R6 H): after a SUCCESSFUL REMOTE
  /// write, refresh this module's local mirror (fire-and-forget).
  Future<Either<Failure, T>> _mirrored<T>(MirrorModule m,
      Future<Either<Failure, T>> Function() body) async {
    final r = await body();
    if (r.isRight() && !_useLocal && _mirror != null) {
      unawaited(_mirror.refreshModule(m));
    }
    return r;
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
