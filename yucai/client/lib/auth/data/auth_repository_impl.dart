import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/data/token_storage.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;

  @override
  Future<Either<Failure, User>> register(String email, String password, String displayName) async {
    try {
      final result = await _remote.register(email, password, displayName);
      await _storage.saveTokens(result.tokens);
      return Right(result.user);
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> login(String email, String password) async {
    try {
      final result = await _remote.login(email, password);
      await _storage.saveTokens(result.tokens);
      return Right(result.user);
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthTokens>> refreshToken() async {
    try {
      final existing = await _storage.readTokens();
      if (existing == null) {
        return const Left(AuthFailure('no refresh token'));
      }
      final tokens = await _remote.refreshToken(existing.refreshToken);
      await _storage.saveTokens(tokens);
      return Right(tokens);
    } on GrpcError catch (e) {
      await _storage.clearTokens();
      return Left(_mapGrpcError(e));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> getProfile() async {
    try {
      return Right(await _remote.getProfile());
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<void> logout() async {
    await _storage.clearTokens();
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
