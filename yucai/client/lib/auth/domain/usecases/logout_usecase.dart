import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';

@injectable
class LogoutUseCase {
  LogoutUseCase(this._repo);
  final AuthRepository _repo;

  Future<void> call() => _repo.logout();
}
