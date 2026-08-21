import 'package:drift/drift.dart';

import '../app_database.dart';
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
}
