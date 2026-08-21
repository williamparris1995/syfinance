import 'package:drift/drift.dart';

/// Local-owned derived tables (NOT in the backup contract): recomputable
/// snapshots/lots with no upload obligation (design ADR-3). Write paths
/// (local recompute vs mirror) are decided in features E/H.
class DebtProgressSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get debtId => text()();
  DateTimeColumn get snapshotDate => dateTime()();
  IntColumn get totalPrincipalCents => integer()();
  IntColumn get remainingPrincipalCents => integer()();
  IntColumn get paidTotalCents => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class GoalProgressSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text()();
  DateTimeColumn get snapshotDate => dateTime()();
  IntColumn get currentAmountCents => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class HoldingSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get holdingId => text()();
  TextColumn get securityId => text()();
  TextColumn get accountId => text()();
  DateTimeColumn get snapshotDate => dateTime()();
  IntColumn get marketValueCents => integer()();
  IntColumn get unrealizedPnlCents => integer()();
  TextColumn get currencyCode => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// FIFO lots replayable from HoldingTransactions (server semantics).
class HoldingLots extends Table {
  TextColumn get id => text()();
  TextColumn get holdingId => text()();
  TextColumn get securityId => text()();
  DateTimeColumn get acquiredDate => dateTime()();
  TextColumn get acquiredTradeId => text()();
  IntColumn get priceCents => integer()();
  RealColumn get quantity => real()();
  RealColumn get remainingQuantity => real()();

  @override
  Set<Column> get primaryKey => {id};
}
