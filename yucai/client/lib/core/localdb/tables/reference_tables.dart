import 'package:drift/drift.dart';

/// Local-owned reference tables (NOT in the backup contract — seeded per
/// install / refreshed on connect, design open question 1). Columns follow
/// the server ent semantics so mirroring stays lossless.
class Currencies extends Table {
  TextColumn get code => text()();
  TextColumn get name => text()();
  TextColumn get symbol => text()();
  RealColumn get exchangeRate => real()();
  BoolColumn get isActive => boolean()();

  @override
  Set<Column> get primaryKey => {code};
}

class RateHistories extends Table {
  TextColumn get id => text()();
  TextColumn get currencyCode => text()();
  DateTimeColumn get rateDate => dateTime()();
  RealColumn get exchangeRate => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Global reference data (securities are cross-tenant on the server and are
/// NOT backed up — holdings reference them by id, design ADR-3).
class Securities extends Table {
  TextColumn get id => text()();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get securityType => text()();
  TextColumn get exchange => text()();
  TextColumn get currencyCode => text()();
  IntColumn get currentPriceCents => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SecurityPriceHistories extends Table {
  TextColumn get id => text()();
  TextColumn get securityId => text()();
  DateTimeColumn get priceDate => dateTime()();
  IntColumn get priceCents => integer()();
  TextColumn get currencyCode => text()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
