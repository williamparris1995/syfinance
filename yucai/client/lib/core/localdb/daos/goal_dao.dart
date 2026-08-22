import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/goal_tables.dart';

part 'goal_dao.g.dart';

@DriftAccessor(tables: [Goals, GoalAccountLinks, GoalDebtLinks])
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.db);

  Future<void> insertGoal(GoalsCompanion entry) => into(goals).insert(entry);

  Future<Goal?> getGoalById(String id) =>
      (select(goals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Goal>> watchAllGoals() => select(goals).watch();

  Future<int> updateGoal(GoalsCompanion entry) =>
      (update(goals)..where((t) => t.id.equals(entry.id.value))).write(entry);

  Future<int> deleteGoalById(String id) =>
      (delete(goals)..where((t) => t.id.equals(id))).go();

  // Links aggregate back to the payload's uuid arrays on export (feature G,
  // design conversion rule 3).
  Future<void> insertAccountLink(GoalAccountLinksCompanion entry) =>
      into(goalAccountLinks).insert(entry);

  Future<void> insertDebtLink(GoalDebtLinksCompanion entry) =>
      into(goalDebtLinks).insert(entry);

  Future<int> deleteAccountLinksFor(String goalId) =>
      (delete(goalAccountLinks)..where((t) => t.goalId.equals(goalId))).go();

  Future<int> deleteDebtLinksFor(String goalId) =>
      (delete(goalDebtLinks)..where((t) => t.goalId.equals(goalId))).go();

  Future<(List<String> accountIds, List<String> debtIds)> linksFor(
      String goalId) async {
    final accounts = await (select(goalAccountLinks)
          ..where((t) => t.goalId.equals(goalId)))
        .get();
    final debts = await (select(goalDebtLinks)
          ..where((t) => t.goalId.equals(goalId)))
        .get();
    return (accounts.map((l) => l.linkedId).toList(),
        debts.map((l) => l.linkedId).toList());
  }
}
