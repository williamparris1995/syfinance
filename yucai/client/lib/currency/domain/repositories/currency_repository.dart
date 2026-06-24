import 'package:dartz/dartz.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';

/// Port interface for currency operations. Data layer implements this.
abstract class CurrencyRepository {
  Future<Either<Failure, List<Currency>>> list();
}
