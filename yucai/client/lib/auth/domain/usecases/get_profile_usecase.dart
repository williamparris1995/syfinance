import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class GetProfileUseCase {
  GetProfileUseCase(this._repo);
  final AuthRepository _repo;

  Future<Either<Failure, User>> call() => _repo.getProfile();
}
