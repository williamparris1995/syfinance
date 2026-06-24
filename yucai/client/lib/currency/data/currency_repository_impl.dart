import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/currency/data/currency_remote_ds.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/domain/repositories/currency_repository.dart';

@LazySingleton(as: CurrencyRepository)
class CurrencyRepositoryImpl implements CurrencyRepository {
  CurrencyRepositoryImpl(this._remote);

  final CurrencyRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Currency>>> list() async {
    try {
      final currencies = await _remote.list();
      return Right(currencies);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
