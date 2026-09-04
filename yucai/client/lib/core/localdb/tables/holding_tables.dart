import 'package:drift/drift.dart';

import '../sync_state.dart' show SyncState;

/// Contract tables for the holding module (backup payload wraps two sibling
/// arrays "holdings"/"transactions"; linked logically by account+security,
/// no parent-child FK — mirrors the server, which also has none).
class Holdings extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get securityId => text()();
  RealColumn get quantity => real()();
  IntColumn get avgCostCents => integer()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// F10 FR-3/ADR-2:同步状态(值域/语义见 sync_state.dart)。离线 buy/sell/
  /// dividend/split 头行置 pending,其 trade 台账行随镜像协调按
  /// (accountId, securityId) 联动保留。
  TextColumn get syncState =>
      text().withDefault(const Constant(SyncState.synced))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Append-only trade ledger (no updatedAt, same as the server struct).
class HoldingTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get securityId => text()();
  IntColumn get tradeType => integer()();
  RealColumn get quantity => real()();
  IntColumn get priceCents => integer()();
  IntColumn get amountCents => integer()();
  IntColumn get feeCents => integer()();
  IntColumn get realizedPnlCents => integer()();
  DateTimeColumn get tradeDate => dateTime()();
  TextColumn get transactionId => text().nullable()();
  TextColumn get notes => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
