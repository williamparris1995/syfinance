import 'package:drift/drift.dart';

import '../sync_state.dart' show SyncState;

/// Contract table for the template module (backup payload
/// []TransactionTemplate; template_record_log is NOT in the contract).
class TransactionTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  IntColumn get amountCents => integer()();
  IntColumn get direction => integer()();
  TextColumn get sourceAccountId => text()();
  TextColumn get destinationAccountId => text().nullable()();
  IntColumn get cycle => integer()();
  IntColumn get cycleDays => integer()();
  IntColumn get billingDay => integer()();
  DateTimeColumn get nextDate => dateTime()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get autoRecord => boolean()();
  BoolColumn get paused => boolean()();
  TextColumn get lastTransactionId => text().nullable()();
  TextColumn get category => text()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// F10 FR-3/ADR-2:同步状态(值域/语义见 sync_state.dart)。离线 record
  /// 推进 nextDate/lastTransactionId 时置 pending 保护本地推进量。
  TextColumn get syncState =>
      text().withDefault(const Constant(SyncState.synced))();

  @override
  Set<Column> get primaryKey => {id};
}
