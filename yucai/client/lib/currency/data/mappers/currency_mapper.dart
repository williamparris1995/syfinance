import 'package:injectable/injectable.dart';

import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/proto/currency/v1/currency.pb.dart' as pb;

/// Maps generated proto CurrencyDTO -> domain Currency (one-way; the client
/// never creates currencies, only reads them).
@injectable
class CurrencyMapper {
  const CurrencyMapper();

  Currency toDomain(pb.CurrencyDTO dto) {
    return Currency(
      code: dto.code,
      name: dto.name,
      symbol: dto.symbol,
      exchangeRate: dto.exchangeRate,
      isActive: dto.isActive,
    );
  }
}
