import 'package:drift/drift.dart';

/// Contract tables for the goal module. The backup payload carries
/// LinkedAccountIDs/LinkedDebtIDs as uuid arrays; locally they become link
/// tables (design conversion rule 3, re-aggregated on export in feature G).
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get goalType => integer()();
  IntColumn get targetAmountCents => integer()();
  IntColumn get currentAmountCents => integer()();
  TextColumn get currencyCode => text()();
  DateTimeColumn get deadline => dateTime().nullable()();
  TextColumn get notes => text()();
  BoolColumn get isCompleted => boolean()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get version => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class GoalAccountLinks extends Table {
  TextColumn get goalId =>
      text().references(Goals, #id, onDelete: KeyAction.cascade)();
  TextColumn get linkedId => text()();

  @override
  Set<Column> get primaryKey => {goalId, linkedId};
}

class GoalDebtLinks extends Table {
  TextColumn get goalId =>
      text().references(Goals, #id, onDelete: KeyAction.cascade)();
  TextColumn get linkedId => text()();

  @override
  Set<Column> get primaryKey => {goalId, linkedId};
}
