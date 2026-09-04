import 'package:drift/drift.dart';

import '../sync_state.dart' show SyncState;

/// Contract tables for the budget module (backup payload []Budget with nested
/// Items flattened into a child table).
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // "YYYY-MM" kept as text — the contract carries it as a plain string.
  TextColumn get month => text()();
  IntColumn get totalAmountCents => integer()();
  TextColumn get currencyCode => text()();
  BoolColumn get isActive => boolean()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// F10 FR-3/ADR-2:同步状态(值域/语义见 sync_state.dart)。
  TextColumn get syncState =>
      text().withDefault(const Constant(SyncState.synced))();

  @override
  Set<Column> get primaryKey => {id};
}

class BudgetItems extends Table {
  TextColumn get id => text()();
  TextColumn get budgetId =>
      text().references(Budgets, #id, onDelete: KeyAction.cascade)();
  TextColumn get accountId => text()();
  IntColumn get plannedAmountCents => integer()();
  IntColumn get actualAmountCents => integer()();
  TextColumn get notes => text()();

  @override
  Set<Column> get primaryKey => {id};
}
