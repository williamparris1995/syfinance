import 'package:drift/drift.dart';

import '../app_database.dart';
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
}
