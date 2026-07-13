import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/backup/data/backup_remote_ds.dart';
import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/domain/repositories/backup_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@LazySingleton(as: BackupRepository)
class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl(this._remote);

  final BackupRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Backup>>> list() => _guard(_remote.list);

  @override
  Future<Either<Failure, Backup>> create({
    required bool encrypted,
    String password = '',
  }) =>
      _guard(() => _remote.create(encrypted: encrypted, password: password));

  @override
  Future<Either<Failure, void>> restore({
    required String id,
    required String password,
  }) =>
      _guard(() => _remote.restore(id: id, password: password));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _guard(() => _remote.delete(id));

  /// 统一 try/Either 包装（对齐 AuthRepositoryImpl 模式）。
  /// 401 不单独映射：AuthRetryCaller 已在 remote_ds 透明刷新；若仍到此处说明
  /// refresh 失败 → AuthBloc logout，bloc 显示通用错误即可。
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  Failure _mapGrpcError(GrpcError e) {
    switch (e.code) {
      case StatusCode.unavailable:
        return NetworkFailure(e.message ?? '无法连接服务器');
      case StatusCode.invalidArgument:
        return ValidationFailure(e.message ?? '参数错误');
      default:
        return ServerFailure(e.message ?? e.codeName);
    }
  }
}
