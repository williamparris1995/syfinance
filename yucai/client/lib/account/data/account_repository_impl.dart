import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@LazySingleton(as: AccountRepository)
class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl(this._remote);

  final AccountRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Account>>> list() async => _guard(() => _remote.list());

  @override
  Future<Either<Failure, Account>> create(CreateAccountParams params) =>
      _guard(() => _remote.create(params));

  @override
  Future<Either<Failure, void>> delete(String id) => _guard(() => _remote.delete(id));

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
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
      case StatusCode.unauthenticated:
        return AuthFailure(e.message ?? '凭证无效');
      case StatusCode.unavailable:
        return NetworkFailure(e.message ?? '无法连接服务器');
      case StatusCode.invalidArgument:
        return ValidationFailure(e.message ?? '参数错误');
      default:
        return ServerFailure(e.message ?? e.codeName);
    }
  }
}
