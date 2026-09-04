import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart' show SyncState;
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
  /// F10 T2 fix(round 1):镜像 rebuild 专用 upsert —— pending 持仓引用的
  /// server 证券已在「保留集」内(下方 scoped delete 不删),裸 insert 撞
  /// securities.id UNIQUE 会回滚整事务使 refreshModule 持续失败;改冲突
  /// 覆盖(server 对 server-id 行权威;本地 uuid 行 server 不含,永不冲突)。
  /// 本地建仓路径仍走 [insertSecurity](重复 id 显式失败)。
  Future<void> upsertSecurity(SecuritiesCompanion entry) =>
      into(securities).insertOnConflictUpdate(entry);


  Future<Security?> getSecurityById(String id) =>
      (select(securities)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Security>> getAllSecurities() => select(securities).get();

  Future<int> updateSecurityPrice(String id, int priceCents) =>
      (update(securities)..where((t) => t.id.equals(id)))
          .write(SecuritiesCompanion(currentPriceCents: Value(priceCents)));


  Future<int> deleteAllSecurities() => delete(securities).go();

  /// F10 T2 镜像协调兜底:pending 持仓引用的证券离线保留(证券表无
  /// syncState,以引用方状态联动;否则离线建仓证券会在刷新后变
  /// 「未知证券」)。全 synced 场景无 pending 持仓,等价 delete-all。
  Future<void> deleteSecuritiesNotReferencedByPendingHoldings() =>
      customStatement(
          'DELETE FROM securities WHERE id NOT IN '
          '(SELECT security_id FROM holdings WHERE sync_state = ?)',
          [SyncState.pending]);

  Future<void> insertSecurityPriceHistory(
          SecurityPriceHistoriesCompanion entry) =>
      into(securityPriceHistories).insert(entry);
}
