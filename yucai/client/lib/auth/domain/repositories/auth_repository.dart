import 'package:dartz/dartz.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

/// Port interface for authentication. Data layer implements this.
abstract class AuthRepository {
  Future<Either<Failure, User>> register(String email, String password, String displayName);
  Future<Either<Failure, User>> login(String email, String password);
  Future<Either<Failure, AuthTokens>> refreshToken();
  Future<Either<Failure, User>> getProfile();
  Future<void> logout();
}
