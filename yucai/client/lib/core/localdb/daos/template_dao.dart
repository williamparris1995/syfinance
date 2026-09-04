import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart' show SyncState;
import '../tables/template_tables.dart';

part 'template_dao.g.dart';

@DriftAccessor(tables: [TransactionTemplates])
class TemplateDao extends DatabaseAccessor<AppDatabase>
    with _$TemplateDaoMixin {
  TemplateDao(super.db);

  Future<void> insertTemplate(TransactionTemplatesCompanion entry) =>
      into(transactionTemplates).insert(entry);

  Future<TransactionTemplate?> getTemplateById(String id) =>
      (select(transactionTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<List<TransactionTemplate>> watchAllTemplates() =>
      select(transactionTemplates).watch();

  Future<int> updateTemplate(TransactionTemplatesCompanion entry) =>
      (update(transactionTemplates)
            ..where((t) => t.id.equals(entry.id.value)))
          .write(entry);


  Future<int> deleteAllTemplates() => delete(transactionTemplates).go();
  Future<int> deleteTemplateById(String id) =>
      (delete(transactionTemplates)..where((t) => t.id.equals(id))).go();

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:delete-all 改为排除 pending(在线全 synced 等价
  /// delete-all;离线 record 推进的 nextDate/lastTransactionId 保住)。
  Future<int> deleteAllSyncedTemplates() =>
      (delete(transactionTemplates)
            ..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// T3 收集器:一次性读待上行模板行。
  Future<List<TransactionTemplate>> getPendingTemplates() =>
      (select(transactionTemplates)
            ..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行模板行。
  Stream<List<TransactionTemplate>> watchPendingTemplates() =>
      (select(transactionTemplates)
            ..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();

  /// F10 T3(fix round 1):上行成功回写 —— 批内实体 pending → synced,带
  /// **版本守卫**(仅当行当前 version 仍等于批次快照版本才回写,在途
  /// FR-1b 降级更新的行保持 pending 留下次上行;core 层不能 import binding
  /// 域 DTO,以 id→版本 Map 承载;T2 无此方法,T3 补)。
  Future<int> markTemplatesSynced(Map<String, int> versionsById) {
    if (versionsById.isEmpty) return Future.value(0);
    final guard = versionsById.entries
        .map((e) => transactionTemplates.id.equals(e.key) &
            transactionTemplates.version.equals(e.value))
        .reduce((a, b) => a | b);
    return (update(transactionTemplates)
          ..where((t) => guard & t.syncState.equals(SyncState.pending)))
        .write(const TransactionTemplatesCompanion(
            syncState: Value(SyncState.synced)));
  }
}
