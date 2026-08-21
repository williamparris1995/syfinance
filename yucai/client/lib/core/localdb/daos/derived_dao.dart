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
