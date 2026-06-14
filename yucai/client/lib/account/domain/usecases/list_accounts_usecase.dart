import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class ListAccountsUseCase {
  ListAccountsUseCase(this._repo);
  final AccountRepository _repo;

  Future<Either<Failure, List<Account>>> call() => _repo.list();
}
