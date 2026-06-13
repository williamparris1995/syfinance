import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/entities/auth_tokens.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class RefreshTokenUseCase {
  RefreshTokenUseCase(this._repo);
  final AuthRepository _repo;

  Future<Either<Failure, AuthTokens>> call() => _repo.refreshToken();
}
