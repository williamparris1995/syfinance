import 'package:dartz/dartz.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// Port interface for transaction operations. Data layer implements this.
///
/// The three `recordXxx` convenience methods wrap the server's
/// SimpleExpense / SimpleIncome / SimpleTransfer RPCs; `recordTransaction`
/// is the full double-entry path. `summary` is **declared but not yet
/// implemented** — the server's `TransactionSummary` RPC lands in Task 5.1
/// alongside a proto redesign; until then the impl throws
/// [UnimplementedError] so any premature caller fails loudly.
abstract class TransactionRepository {
  Future<Either<Failure, Transaction>> recordExpense(
      RecordExpenseParams params);

  Future<Either<Failure, Transaction>> recordIncome(
      RecordIncomeParams params);

  Future<Either<Failure, Transaction>> recordTransfer(
      RecordTransferParams params);

  Future<Either<Failure, Transaction>> recordTransaction(
      RecordTransactionParams params);

  Future<Either<Failure, List<Transaction>>> list(ListTransactionsParams params);

  Future<Either<Failure, Transaction>> getById(String id);

  Future<Either<Failure, Transaction>> update(UpdateTransactionParams params);

  Future<Either<Failure, void>> delete(String id);

  /// Deferred to Task 5.1 (proto `TransactionSummary` RPC not yet generated).
  Future<Either<Failure, MonthlySummary>> summary(
    int year,
    int month, {
    String? accountId,
  });
}

/// Records a SimpleExpense RPC: debit an expense account, credit an asset
/// account (e.g. cash / bank card).
class RecordExpenseParams {
  const RecordExpenseParams({
    required this.transactionDate,
    required this.expenseAccountId,
    required this.assetAccountId,
    required this.amountCents,
    this.description = '',
    this.note = '',
  });

  final DateTime transactionDate;
  final String expenseAccountId;
  final String assetAccountId;
  final int amountCents;
  final String description;
  final String note;
}

/// Records a SimpleIncome RPC: debit an asset account, credit an income
/// account.
class RecordIncomeParams {
  const RecordIncomeParams({
    required this.transactionDate,
    required this.assetAccountId,
    required this.incomeAccountId,
    required this.amountCents,
    this.description = '',
    this.note = '',
  });

  final DateTime transactionDate;
  final String assetAccountId;
  final String incomeAccountId;
  final int amountCents;
  final String description;
  final String note;
}

/// Records a SimpleTransfer RPC: debit the destination asset account,
/// credit the source asset account.
class RecordTransferParams {
  const RecordTransferParams({
    required this.transactionDate,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    this.description = '',
    this.note = '',
  });

  final DateTime transactionDate;
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final String description;
  final String note;
}

/// Full double-entry record. Caller supplies balanced [entries] (sum of
/// debits == sum of credits); the data layer forwards them verbatim to
/// RecordTransaction.
class RecordTransactionParams {
  const RecordTransactionParams({
    required this.transactionDate,
    required this.entries,
    this.description = '',
  });

  final DateTime transactionDate;
  final List<TransactionEntry> entries;
  final String description;
}

/// Update an existing transaction. [version] is required for optimistic
/// concurrency; the server rejects a stale version with `failedPrecondition`.
class UpdateTransactionParams {
  const UpdateTransactionParams({
    required this.id,
    required this.version,
    required this.entries,
    this.transactionDate,
    this.description = '',
  });

  final String id;
  final int version;

  /// null = leave the existing date untouched.
  final DateTime? transactionDate;
  final String description;
  final List<TransactionEntry> entries;
}
