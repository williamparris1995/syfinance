import 'package:drift/drift.dart';

import '../sync_state.dart' show SyncState;
import 'transaction_tables.dart';

/// Contract table for the tag module. TransactionTags is a local-owned
/// junction (NOT in the backup contract — server drops tag links on restore,
/// accepted limitation R1 in design.md).
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // #RRGGBB, validated at the app layer like the server does.
  TextColumn get color => text()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// F10 FR-3/ADR-2:同步状态(值域/语义见 sync_state.dart)。
  TextColumn get syncState =>
      text().withDefault(const Constant(SyncState.synced))();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionTags extends Table {
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}
