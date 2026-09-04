import 'package:drift/drift.dart';

import '../app_database.dart';
import '../sync_state.dart' show SyncState;
import '../tables/transaction_tables.dart';

part 'transaction_dao.g.dart';

@DriftAccessor(tables: [Transactions, TransactionEntries])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<void> insertTransaction(TransactionsCompanion entry) =>
      into(transactions).insert(entry);

  Future<Transaction?> getTransactionById(String id) =>
      (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Transaction>> watchAllTransactions() =>
      select(transactions).watch();

  Future<int> updateTransaction(TransactionsCompanion entry) =>
      (update(transactions)..where((t) => t.id.equals(entry.id.value)))
          .write(entry);


  Future<int> deleteAllTransactions() => delete(transactions).go();

  Future<int> deleteAllEntries() => delete(transactionEntries).go();
  Future<int> deleteTransactionById(String id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  Future<void> insertEntry(TransactionEntriesCompanion entry) =>
      into(transactionEntries).insert(entry);

  Stream<List<TransactionEntry>> watchEntriesByTransaction(String transactionId) =>
      (select(transactionEntries)
            ..where((t) => t.transactionId.equals(transactionId)))
          .watch();

  /// One-shot reads for the seam's list/assembly paths.
  Future<List<Transaction>> getAllTransactions() => select(transactions).get();

  Future<List<TransactionEntry>> getAllEntries() =>
      select(transactionEntries).get();

  /// Whole-entry-set replacement for the update-in-place semantics (design
  /// ADR-1: old entries are deleted then re-inserted in one drift tx).
  Future<int> deleteEntriesByTransaction(String transactionId) =>
      (delete(transactionEntries)
            ..where((t) => t.transactionId.equals(transactionId)))
          .go();

  Future<int> deleteEntryById(String id) =>
      (delete(transactionEntries)..where((t) => t.id.equals(id))).go();

  // ---- F10 T2:syncState 支持(spec FR-3,design ADR-2/ADR-3) ----

  /// 镜像协调:delete-all 改为排除 pending(在线全 synced 等价 delete-all);
  /// 非 pending 头行删除时其分录经 FK 级联清除。
  Future<int> deleteAllSyncedTransactions() =>
      (delete(transactions)
            ..where((t) => t.syncState.equals(SyncState.pending).not()))
          .go();

  /// 兜底清非 pending 交易的分录(pending 头行的分录保留,内容与存在性
  /// 不变);正常路径由 FK 级联完成,悬挂行防御。
  Future<void> deleteEntriesOfSyncedTransactions() => customStatement(
      'DELETE FROM transaction_entries WHERE transaction_id NOT IN '
      '(SELECT id FROM transactions WHERE sync_state = ?)',
      [SyncState.pending]);

  /// T3 收集器:一次性读待上行交易头行。
  Future<List<Transaction>> getPendingTransactions() =>
      (select(transactions)..where((t) => t.syncState.equals(SyncState.pending)))
          .get();

  /// T3 状态流(待同步计数):监听待上行交易头行。
  Stream<List<Transaction>> watchPendingTransactions() =>
      (select(transactions)..where((t) => t.syncState.equals(SyncState.pending)))
          .watch();
}
