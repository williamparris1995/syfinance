import 'package:drift/drift.dart';

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
