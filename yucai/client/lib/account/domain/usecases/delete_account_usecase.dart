import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class DeleteAccountUseCase {
  DeleteAccountUseCase(this._repo);
  final AccountRepository _repo;

  Future<Either<Failure, void>> call(String id) => _repo.delete(id);
}
