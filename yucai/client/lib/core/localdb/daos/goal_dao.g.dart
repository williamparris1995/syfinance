// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'goal_dao.dart';

// ignore_for_file: type=lint
mixin _$GoalDaoMixin on DatabaseAccessor<AppDatabase> {
  $GoalsTable get goals => attachedDatabase.goals;
  $GoalAccountLinksTable get goalAccountLinks =>
      attachedDatabase.goalAccountLinks;
  $GoalDebtLinksTable get goalDebtLinks => attachedDatabase.goalDebtLinks;
  GoalDaoManager get managers => GoalDaoManager(this);
}

class GoalDaoManager {
  final _$GoalDaoMixin _db;
  GoalDaoManager(this._db);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db.attachedDatabase, _db.goals);
  $$GoalAccountLinksTableTableManager get goalAccountLinks =>
      $$GoalAccountLinksTableTableManager(
        _db.attachedDatabase,
        _db.goalAccountLinks,
      );
  $$GoalDebtLinksTableTableManager get goalDebtLinks =>
      $$GoalDebtLinksTableTableManager(_db.attachedDatabase, _db.goalDebtLinks);
}
