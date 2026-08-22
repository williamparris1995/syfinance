import 'package:injectable/injectable.dart';
import 'package:yucai_client/auth/domain/repositories/auth_repository.dart';

@injectable
class HasStoredCredentialsUseCase {
  HasStoredCredentialsUseCase(this._repo);
  final AuthRepository _repo;

  Future<bool> call() => _repo.hasStoredCredentials();
}
