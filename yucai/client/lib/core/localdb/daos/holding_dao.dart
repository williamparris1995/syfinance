import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/holding_tables.dart';

part 'holding_dao.g.dart';

@DriftAccessor(tables: [Holdings, HoldingTransactions])
class HoldingDao extends DatabaseAccessor<AppDatabase>
    with _$HoldingDaoMixin {
  HoldingDao(super.db);

  Future<void> insertHolding(HoldingsCompanion entry) =>
      into(holdings).insert(entry);

  Future<Holding?> getHoldingById(String id) =>
      (select(holdings)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Holding>> watchAllHoldings() => select(holdings).watch();

  Future<int> updateHolding(HoldingsCompanion entry) =>
      (update(holdings)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);


  Future<int> deleteAllHoldings() => delete(holdings).go();

  Future<int> deleteAllHoldingTransactions() =>
      delete(holdingTransactions).go();
  Future<int> deleteHoldingById(String id) =>
      (delete(holdings)..where((t) => t.id.equals(id))).go();

  Future<void> insertHoldingTransaction(HoldingTransactionsCompanion entry) =>
      into(holdingTransactions).insert(entry);

  Future<List<HoldingTransaction>> getAllHoldingTransactions() =>
      select(holdingTransactions).get();

  Stream<List<HoldingTransaction>> watchAllHoldingTransactions() =>
      select(holdingTransactions).watch();

  Future<HoldingTransaction?> getHoldingTransactionById(String id) =>
      (select(holdingTransactions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<List<HoldingTransaction>> watchTransactionsBySecurity(
          String securityId) =>
      (select(holdingTransactions)
            ..where((t) => t.securityId.equals(securityId)))
          .watch();
}
