import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

class RegisterParams extends Equatable {
  const RegisterParams({required this.email, required this.password, required this.displayName});
  final String email;
  final String password;
  final String displayName;
  @override
  List<Object?> get props => [email, password, displayName];
}

@injectable
class RegisterUseCase {
  RegisterUseCase(this._repo);
  final AuthRepository _repo;

  Future<Either<Failure, User>> call(RegisterParams p) =>
      _repo.register(p.email, p.password, p.displayName);
}
