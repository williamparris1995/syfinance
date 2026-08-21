import 'package:drift/drift.dart';

/// Contract tables for the debt module (backup payload []DebtDetails with
/// nested Schedule flattened into a child table).
class Debts extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get counterparty => text()();
  RealColumn get interestRate => real()();
  IntColumn get amortizationMethod => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get totalPrincipalCents => integer()();
  IntColumn get debtType => integer()();
  TextColumn get subtype => text()();
  TextColumn get contact => text()();
  TextColumn get contractRef => text()();
  TextColumn get collectionAccountId => text().nullable()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class PaymentScheduleEntries extends Table {
  TextColumn get id => text()();
  TextColumn get debtId =>
      text().references(Debts, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get paymentDate => dateTime()();
  IntColumn get principalCents => integer()();
  IntColumn get interestCents => integer()();
  IntColumn get totalCents => integer()();
  IntColumn get paidCents => integer()();
  BoolColumn get paid => boolean()();
  TextColumn get transactionId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
