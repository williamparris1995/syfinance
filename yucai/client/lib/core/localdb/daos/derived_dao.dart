import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/derived_tables.dart';

part 'derived_dao.g.dart';

/// Derived data (snapshots/lots): recomputable, no contract obligation;
/// minimal CRUD until the write paths land (features E/H).
@DriftAccessor(tables: [
  DebtProgressSnapshots,
  GoalProgressSnapshots,
  HoldingSnapshots,
  HoldingLots,
])
class DerivedDao extends DatabaseAccessor<AppDatabase>
    with _$DerivedDaoMixin {
  DerivedDao(super.db);

  Future<void> insertDebtProgressSnapshot(
          DebtProgressSnapshotsCompanion entry) =>
      into(debtProgressSnapshots).insert(entry);

  Future<void> insertGoalProgressSnapshot(
          GoalProgressSnapshotsCompanion entry) =>
      into(goalProgressSnapshots).insert(entry);

  Future<void> insertHoldingSnapshot(HoldingSnapshotsCompanion entry) =>
      into(holdingSnapshots).insert(entry);

  Future<void> insertHoldingLot(HoldingLotsCompanion entry) =>
      into(holdingLots).insert(entry);

  Future<List<HoldingLot>> getLotsBySecurity(String securityId) =>
      (select(holdingLots)..where((t) => t.securityId.equals(securityId)))
          .get();

  /// Lots are scoped per-HOLDING (server lot_repo.go:44 HoldingIDEQ) — the
  /// same security in two investment accounts must not cross-consume.
  Future<List<HoldingLot>> getLotsByHolding(String holdingId) =>
      (select(holdingLots)..where((t) => t.holdingId.equals(holdingId)))
          .get();

  Future<int> deleteLotById(String id) =>
      (delete(holdingLots)..where((t) => t.id.equals(id))).go();

  Future<int> updateLotRemaining(String id, double remainingQuantity) =>
      (update(holdingLots)..where((t) => t.id.equals(id)))
          .write(HoldingLotsCompanion(
              remainingQuantity: Value(remainingQuantity)));

  /// Split scales BOTH fields by the caller's ratio independently (server
  /// lot.go:13-15): quantity x ratio AND remainingQuantity x ratio — never
  /// reset remaining to the new full quantity (revives consumed shares).
  Future<int> updateLotSplit(
      String id, double quantity, double remainingQuantity, int priceCents) =>
      (update(holdingLots)..where((t) => t.id.equals(id)))
          .write(HoldingLotsCompanion(
        quantity: Value(quantity),
        remainingQuantity: Value(remainingQuantity),
        priceCents: Value(priceCents),
      ));

  Stream<List<DebtProgressSnapshot>> watchDebtProgressByDebt(String debtId) =>
      (select(debtProgressSnapshots)
            ..where((t) => t.debtId.equals(debtId)))
          .watch();

  Stream<List<GoalProgressSnapshot>> watchGoalProgressByGoal(String goalId) =>
      (select(goalProgressSnapshots)
            ..where((t) => t.goalId.equals(goalId)))
          .watch();

  Stream<List<HoldingSnapshot>> watchHoldingSnapshots(String holdingId) =>
      (select(holdingSnapshots)
            ..where((t) => t.holdingId.equals(holdingId)))
          .watch();
}
