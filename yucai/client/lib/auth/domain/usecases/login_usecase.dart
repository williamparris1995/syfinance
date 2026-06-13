import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

class LoginParams extends Equatable {
  const LoginParams({required this.email, required this.password});
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}

@injectable
class LoginUseCase {
  LoginUseCase(this._repo);
  final AuthRepository _repo;

  Future<Either<Failure, User>> call(LoginParams p) => _repo.login(p.email, p.password);
}
