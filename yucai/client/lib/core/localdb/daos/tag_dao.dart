import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart'
    show SyncState, chunked, syncWritebackChunkSize;
import '../tables/tag_tables.dart';
import '../tables/transaction_tables.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, TransactionTags, Transactions])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Future<void> insertTag(TagsCompanion entry) => into(tags).insert(entry);

  Future<Tag?> getTagById(String id) =>
      (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  Future<int> updateTag(TagsCompanion entry) =>
      (update(tags)..where((t) => t.id.equals(entry.id.value))).write(entry);


  Future<int> deleteAllTags() => delete(tags).go();

  /// Mirroring wipes junction rows too (tags without transactions lose
  /// their links until re-applied — matches the server backup contract
  /// which excludes the junction, review H-J5).
  Future<int> deleteAllTransactionTags() => delete(transactionTags).go();
  Future<int> deleteTagById(String id) =>
      (delete(tags)..where((t) => t.id.equals(id))).go();

  // Junction ops: local-owned (backup contract drops tag links, R1).
  Future<void> insertTransactionTag(TransactionTagsCompanion entry) =>
      into(transactionTags).insert(entry);

  Future<int> deleteTransactionTag(String transactionId, String tagId) =>
      (delete(transactionTags)
            ..where((t) =>
                t.transactionId.equals(transactionId) &
                t.tagId.equals(tagId)))
          .go();

  Stream<List<String>> watchTagIdsForTransaction(String transactionId) =>
      (select(transactionTags)
            ..where((t) => t.transactionId.equals(transactionId)))
          .map((row) => row.tagId)
          .watch();

  /// F8 FR-1/design ADR-1 反查单点:标签 → 关联交易 id 集合(junction 一次性
  /// 查询,免 watch 形态)。transaction DS 的 list/summary 过滤共用此方法
  /// (单一事实源,NFR)。标签无任何关联交易时返回**空集** —— 调用方口径:
  /// 空集 = 无关联交易 → 空结果,与"未传 tagId 不过滤"严格区分。
  Future<Set<String>> transactionIdsForTag(String tagId) async {
    final rows = await (select(transactionTags)
          ..where((t) => t.tagId.equals(tagId)))
        .get();
    return rows.map((row) => row.transactionId).toSet();
  }

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:delete-all 改为排除 pending(在线全 synced 等价 delete-all)。
  Future<int> deleteAllSyncedTags() =>
      (delete(tags)..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// 兜底清非 pending 标签的联表(pending 标签的本地联表保留;联表不在
  /// 备份契约,属本地私有数据);正常路径由 FK 级联完成,悬挂行防御。
  Future<void> deleteTransactionTagsOfSyncedTags() => customStatement(
      'DELETE FROM transaction_tags WHERE tag_id NOT IN '
      '(SELECT id FROM tags WHERE sync_state = ?)',
      [SyncState.pending]);

  /// T3 收集器:一次性读待上行标签行。
  Future<List<Tag>> getPendingTags() =>
      (select(tags)..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行标签行。
  Stream<List<Tag>> watchPendingTags() =>
      (select(tags)..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();

  /// F10 T3(fix round 1):上行成功回写 —— 批内实体 pending → synced,带
  /// **版本守卫**(仅当行当前 version 仍等于批次快照版本才回写,在途
  /// FR-1b 降级更新的行保持 pending 留下次上行;core 层不能 import binding
  /// 域 DTO,以 id→版本 Map 承载;T2 无此方法,T3 补)。
  ///
  /// F19-T1:OR 守卫按 [syncWritebackChunkSize] 分片逐句执行(SQLite 深嵌套
  /// OR 解析器栈溢出,见常量 doc);净效果与单句等价,返回影响行数求和。
  Future<int> markTagsSynced(Map<String, int> versionsById) async {
    if (versionsById.isEmpty) return 0;
    var updated = 0;
    for (final chunk
        in chunked(versionsById.entries, syncWritebackChunkSize)) {
      final guard = chunk
          .map((e) => tags.id.equals(e.key) & tags.version.equals(e.value))
          .reduce((a, b) => a | b);
      updated += await (update(tags)
            ..where((t) => guard & t.syncState.equals(SyncState.pending)))
          .write(const TagsCompanion(syncState: Value(SyncState.synced)));
    }
    return updated;
  }

  /// F19-T1(spec FR-2,design ADR-2):合并前全量标记 —— synced → pending,
  /// guest 期行由此进入 PendingCollector 通路(单条 UPDATE,非逐行)。仅动
  /// synced 行(pending 行原样),幂等;返回影响行数。guest 无墓碑(F10
  /// 语义:guest 删除不落墓碑),墓碑表无对应方法。
  Future<int> markAllPendingForSync() =>
      (update(tags)..where((t) => t.syncState.equals(SyncState.synced)))
          .write(const TagsCompanion(syncState: Value(SyncState.pending)));
}
