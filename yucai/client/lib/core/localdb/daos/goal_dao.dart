import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart' show SyncState;
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


  Future<int> deleteAllGoals() => delete(goals).go();

  Future<void> deleteAllLinks() async {
    await delete(goalAccountLinks).go();
    await delete(goalDebtLinks).go();
  }

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

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:delete-all 改为排除 pending(在线全 synced 等价 delete-all);
  /// 非 pending 头行删除时其链接经 FK 级联清除。
  Future<int> deleteAllSyncedGoals() =>
      (delete(goals)
            ..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// 兜底清非 pending 目标的链接(pending 头行的链接保留);正常路径由
  /// FK 级联完成,悬挂行防御。
  Future<void> deleteLinksOfSyncedGoals() async {
    await customStatement(
        'DELETE FROM goal_account_links WHERE goal_id NOT IN '
        '(SELECT id FROM goals WHERE sync_state = ?)',
        [SyncState.pending]);
    await customStatement(
        'DELETE FROM goal_debt_links WHERE goal_id NOT IN '
        '(SELECT id FROM goals WHERE sync_state = ?)',
        [SyncState.pending]);
  }

  /// T3 收集器:一次性读待上行目标头行。
  Future<List<Goal>> getPendingGoals() =>
      (select(goals)..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行目标头行。
  Stream<List<Goal>> watchPendingGoals() =>
      (select(goals)..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();
}
