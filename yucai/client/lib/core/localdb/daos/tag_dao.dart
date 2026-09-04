import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart' show SyncState;
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
}
