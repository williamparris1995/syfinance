import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/goal_dao.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart'
    show HoldingLocalDataSource;
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';

/// Guest-mode data source for the goal module (R6, C-paradigm).
///
/// currentAmount is computed at READ time from the three sources
/// (goal/application/service.go:215-300): Investment = Σ linked accounts'
/// holdings market value (avgCost fallback), Savings = Σ linked accounts'
/// balance, DebtPayoff = Σ linked debts' schedule paidCents; no links → 0.
@LazySingleton()
class GoalLocalDataSource {
  GoalLocalDataSource(this._database, this._holdingsDs, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final HoldingLocalDataSource _holdingsDs;

  final db.AppDatabase _database;
  final Uuid _uuid;

  GoalDao get _dao => _database.goalDao;

  Future<List<GoalView>> listGoals({GoalType? type, bool? completed}) async {
    final rows = await _dao.watchAllGoals().first;
    final views = <GoalView>[];
    for (final r in rows) {
      if (type != null && r.goalType != type.index + 1) continue;
      if (completed != null && r.isCompleted != completed) continue;
      views.add(await _toView(r));
    }
    return views;
  }

  Future<GoalView> getGoal(String id) async {
    final row = await _dao.getGoalById(id);
    if (row == null) throw const ServerFailure('目标不存在');
    return _toView(row);
  }

  Future<GoalView> createGoal({
    required String name,
    required GoalType type,
    required int targetAmountCents,
    String currencyCode = 'CNY',
    String? deadline,
    List<String> linkedAccountIds = const [],
    List<String> linkedDebtIds = const [],
    String? notes,
    bool markPending = false,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _database.transaction(() async {
      await _dao.insertGoal(db.GoalsCompanion.insert(
        id: id,
        name: name,
        goalType: type.index + 1,
        targetAmountCents: targetAmountCents,
        currentAmountCents: 0,
        currencyCode: currencyCode,
        deadline: Value(_parseDate(deadline)),
        notes: notes ?? '',
        isCompleted: false,
        version: 1,
        createdAt: now,
        updatedAt: now,
        syncState: syncStateValue(markPending),
      ));
      for (final a in linkedAccountIds) {
        await _dao.insertAccountLink(
            db.GoalAccountLinksCompanion.insert(goalId: id, linkedId: a));
      }
      for (final d in linkedDebtIds) {
        await _dao.insertDebtLink(
            db.GoalDebtLinksCompanion.insert(goalId: id, linkedId: d));
      }
    });
    return getGoal(id);
  }

  /// 各写方法 [markPending] 三态语义(F10 FR-3):guest 缺省 false → 头行
  /// synced;boundOfflineLocal / boundRemote 降级传 true → 头行 pending
  /// (链接子表无 syncState,随头行整包上行)。
  Future<GoalView> updateGoal({
    required String id,
    String? name,
    int? targetAmountCents,
    String? deadline,
    List<String>? linkedAccountIds,
    List<String>? linkedDebtIds,
    String? notes,
    int? version,
    bool markPending = false,
  }) async {
    final row = await _require(id);
    // Server: explicit optimistic lock (goal/application/service.go:97).
    if (version != null && version != row.version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    await _database.transaction(() async {
      await _dao.updateGoal(db.GoalsCompanion(
        id: Value(id),
        name: Value(name ?? row.name),
        targetAmountCents: Value(targetAmountCents ?? row.targetAmountCents),
        deadline:
            Value(deadline == null ? row.deadline : _parseDate(deadline)),
        notes: Value(notes ?? row.notes),
        version: Value(row.version + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        syncState: markPending
            ? const Value(SyncState.pending)
            : const Value.absent(),
      ));
      // Links: null = untouched, provided list = whole-set replacement.
      if (linkedAccountIds != null) {
        await _dao.deleteAccountLinksFor(id);
        for (final a in linkedAccountIds) {
          await _dao.insertAccountLink(
              db.GoalAccountLinksCompanion.insert(goalId: id, linkedId: a));
        }
      }
      if (linkedDebtIds != null) {
        await _dao.deleteDebtLinksFor(id);
        for (final d in linkedDebtIds) {
          await _dao.insertDebtLink(
              db.GoalDebtLinksCompanion.insert(goalId: id, linkedId: d));
        }
      }
    });
    return getGoal(id);
  }

  /// [writeTombstone]:bound 路由删除硬删行后补墓碑(FR-4);guest 不写。
  Future<void> deleteGoal(String id, {bool writeTombstone = false}) async {
    if (await _dao.getGoalById(id) == null) throw const ServerFailure('目标不存在');
    await _database.transaction(() async {
      await _dao.deleteGoalById(id); // links cascade
      if (writeTombstone) {
        await _database.syncTombstoneDao.upsertTombstone(
            db.SyncTombstonesCompanion.insert(
                module: SyncModule.goal,
                entityId: id,
                deletedAt: DateTime.now().toUtc()));
      }
    });
  }

  Future<void> completeGoal(String id, {bool markPending = false}) async {
    final row = await _require(id);
    await _dao.updateGoal(db.GoalsCompanion(
      id: Value(id),
      isCompleted: const Value(true),
      completedAt: Value(DateTime.now().toUtc()),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
      syncState: markPending
          ? const Value(SyncState.pending)
          : const Value.absent(),
    ));
  }

  /// Server UpdateProgress adds the contribution to current_amount (the
  /// scheduler later reconciles against sources); the guest read recomputes
  /// from sources, so we record the bump on the stored column and let the
  /// read-time source sum dominate where linked.
  Future<GoalView> recordContribution({
    required String id,
    required int amountCents,
    bool markPending = false,
  }) async {
    final row = await _require(id);
    await _dao.updateGoal(db.GoalsCompanion(
      id: Value(id),
      currentAmountCents: Value(row.currentAmountCents + amountCents),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
      syncState: markPending
          ? const Value(SyncState.pending)
          : const Value.absent(),
    ));
    return getGoal(id);
  }

  Future<GoalView> cloneGoal({
    required String sourceId,
    int? targetAmountCents,
    String? deadline,
    String? name,
    bool markPending = false,
  }) async {
    final src = await _require(sourceId);
    final (accounts, debts) = await _dao.linksFor(sourceId);
    return createGoal(
      name: name ?? '${src.name} 副本',
      type: GoalType.values[src.goalType - 1],
      targetAmountCents: targetAmountCents ?? src.targetAmountCents,
      currencyCode: src.currencyCode,
      deadline: deadline ?? _formatDate(src.deadline),
      linkedAccountIds: accounts,
      linkedDebtIds: debts,
      notes: src.notes.isEmpty ? null : src.notes,
      markPending: markPending,
    );
  }

  Future<List<GoalProgressPoint>> getProgressHistory({
    required String goalId,
    required DateTime from,
    required DateTime to,
  }) async {
    // Snapshot scheduler is a server artifact — accepted empty (design ADR-4).
    return const [];
  }

  // ---- helpers ----

  Future<db.Goal> _require(String id) async {
    final row = await _dao.getGoalById(id);
    if (row == null) throw const ServerFailure('目标不存在');
    return row;
  }

  Future<GoalView> _toView(db.Goal row) async {
    final (accounts, debts) = await _dao.linksFor(row.id);
    // Read-time three-source actuals (server SyncAllGoals rule). Goals with
    // no links are skipped by the server scheduler, so their stored manual
    // contributions stay visible — mirror that (review E-#6).
    var current = row.currentAmountCents;
    final type = row.goalType;
    if (type == 3 && accounts.isNotEmpty) {
      // Investment: Σ linked accounts' holdings market value (live price,
      // avgCost fallback) — same helper the holding page uses.
      final holdings = await _database.holdingDao.watchAllHoldings().first;
      final scoped =
          holdings.where((h) => accounts.contains(h.accountId)).toList();
      final values =
          await Future.wait(scoped.map(_holdingsDs.marketValueOf));
      current = values.fold(0, (a, v) => a + v);
    } else if (type == 1 && accounts.isNotEmpty) {
      // Savings: Σ linked accounts' current balance.
      final accs = await _database.accountDao.getAllAccounts();
      current = accs
          .where((a) => accounts.contains(a.id))
          .fold(0, (a, x) => a + x.currentBalanceCents);
    } else if (type == 2 && debts.isNotEmpty) {
      // DebtPayoff: Σ linked debts' schedule paidCents.
      for (final d in debts) {
        final schedule = await _database.debtDao
            .watchScheduleByDebt(d)
            .first;
        current += schedule.fold(0, (a, s) => a + s.paidCents);
      }
    }
    return GoalView(
      id: row.id,
      name: row.name,
      type: GoalType.values[row.goalType - 1],
      targetAmountCents: row.targetAmountCents,
      currentAmountCents: current,
      currencyCode: row.currencyCode,
      deadline: row.deadline,
      linkedAccountIds: accounts,
      linkedDebtIds: debts,
      notes: row.notes.isEmpty ? null : row.notes,
      isCompleted: row.isCompleted,
    );
  }



  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final d = DateTime.tryParse(s);
    return d == null ? null : DateTime.utc(d.year, d.month, d.day);
  }

  String? _formatDate(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
}
