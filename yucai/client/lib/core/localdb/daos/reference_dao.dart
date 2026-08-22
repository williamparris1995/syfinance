import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/reference_tables.dart';

part 'reference_dao.g.dart';

/// Reference data (currencies/securities + histories): seeded per install,
/// refreshed on connect (mechanism = design open question 1).
@DriftAccessor(
    tables: [Currencies, RateHistories, Securities, SecurityPriceHistories])
class ReferenceDao extends DatabaseAccessor<AppDatabase>
    with _$ReferenceDaoMixin {
  ReferenceDao(super.db);

  Future<void> insertCurrency(CurrenciesCompanion entry) =>
      into(currencies).insert(entry);

  Future<Currency?> getCurrencyByCode(String code) =>
      (select(currencies)..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  Stream<List<Currency>> watchActiveCurrencies() =>
      (select(currencies)..where((t) => t.isActive.equals(true))).watch();

  Future<void> insertRateHistory(RateHistoriesCompanion entry) =>
      into(rateHistories).insert(entry);

  Future<void> insertSecurity(SecuritiesCompanion entry) =>
      into(securities).insert(entry);

  Future<Security?> getSecurityById(String id) =>
      (select(securities)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Security>> getAllSecurities() => select(securities).get();

  Future<int> updateSecurityPrice(String id, int priceCents) =>
      (update(securities)..where((t) => t.id.equals(id)))
          .write(SecuritiesCompanion(currentPriceCents: Value(priceCents)));

  Future<void> insertSecurityPriceHistory(
          SecurityPriceHistoriesCompanion entry) =>
      into(securityPriceHistories).insert(entry);
}
