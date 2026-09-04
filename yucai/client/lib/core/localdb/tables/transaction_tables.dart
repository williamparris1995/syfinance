import 'package:drift/drift.dart';

import '../sync_state.dart' show SyncState;

/// Contract tables for the transaction module (backup payload []Transaction
/// with nested Entries flattened into a child table, design conversion rule 4).
class Transactions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get transactionTime => dateTime().nullable()();
  TextColumn get description => text()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// F10 FR-3/ADR-2:同步状态(值域/语义见 sync_state.dart)。
  TextColumn get syncState =>
      text().withDefault(const Constant(SyncState.synced))();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionEntries extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  // Cross-module references stay plain columns (uuid strings): integrity is
  // enforced at the app layer (feature F), matching the contract import order.
  TextColumn get accountId => text()();
  TextColumn get chartOfAccountCode => text()();
  IntColumn get debitCents => integer()();
  IntColumn get creditCents => integer()();
  TextColumn get note => text()();

  @override
  Set<Column> get primaryKey => {id};
}
