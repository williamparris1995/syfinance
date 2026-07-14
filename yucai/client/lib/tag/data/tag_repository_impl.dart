import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';

@LazySingleton(as: TagRepository)
class TagRepositoryImpl implements TagRepository {
  TagRepositoryImpl(this._remote);

  final TagRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Tag>>> list() => _guard(_remote.list);

  @override
  Future<Either<Failure, Tag>> create({required String name, required String color}) =>
      _guard(() => _remote.create(name: name, color: color));

  @override
  Future<Either<Failure, Tag>> update({
    required String id,
    required String name,
    required String color,
    required int version,
  }) =>
      _guard(() => _remote.update(id: id, name: name, color: color, version: version));

  @override
  Future<Either<Failure, void>> delete(String id) => _guard(() => _remote.delete(id));

  @override
  Future<Either<Failure, void>> addTagToTransaction({
    required String tagId,
    required String transactionId,
  }) =>
      _guard(() => _remote.addTagToTransaction(tagId: tagId, transactionId: transactionId));

  @override
  Future<Either<Failure, void>> removeTagFromTransaction({
    required String tagId,
    required String transactionId,
  }) =>
      _guard(() => _remote.removeTagFromTransaction(tagId: tagId, transactionId: transactionId));

  @override
  Future<Either<Failure, List<Tag>>> getTransactionTags(String transactionId) =>
      _guard(() => _remote.getTransactionTags(transactionId));

  /// 统一 try/Either 包装(对齐 BackupRepositoryImpl._guard)。
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
