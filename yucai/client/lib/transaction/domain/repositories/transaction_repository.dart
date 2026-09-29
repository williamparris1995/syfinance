import 'package:dartz/dartz.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// Port interface for transaction operations. Data layer implements this.
///
/// The three `recordXxx` convenience methods wrap the server's
/// SimpleExpense / SimpleIncome / SimpleTransfer RPCs; `recordTransaction`
/// is the full double-entry path. `summary` wraps the server's
/// `TransactionSummary` RPC (Task 5.1) and returns a [MonthlySummary].
/// Paged result of `list`.
///
/// [nextPageToken] is empty when there are no more pages. The repository maps
/// the proto `PageResponse.next_page_token` into this field; callers drive a
/// cursor-style "load more" loop with it.
class ListTransactionsResult {
  const ListTransactionsResult({
    required this.transactions,
    this.nextPageToken = '',
    this.totalCount = 0,
  });

  final List<Transaction> transactions;
  final String nextPageToken;
  final int totalCount;

  bool get hasMore => nextPageToken.isNotEmpty;
}

abstract class TransactionRepository {
  Future<Either<Failure, Transaction>> recordExpense(
      RecordExpenseParams params);

  Future<Either<Failure, Transaction>> recordIncome(
      RecordIncomeParams params);

  Future<Either<Failure, Transaction>> recordTransfer(
      RecordTransferParams params);

  Future<Either<Failure, Transaction>> recordTransaction(
      RecordTransactionParams params);

  Future<Either<Failure, ListTransactionsResult>> list(
      ListTransactionsParams params);

  Future<Either<Failure, Transaction>> getById(String id);

  Future<Either<Failure, Transaction>> update(UpdateTransactionParams params);

  Future<Either<Failure, void>> delete(String id);

  /// 反馈⑦(表单历史填写票):近期交易的 distinct 描述 —— 表单「交易对象/
  /// 商户」字段的「最近使用」建议数据。本地 drift 口径:GROUP BY
  /// description + 每组最近记录时间(MAX created_at)倒序 + 空白过滤。
  /// [limit] 缺省 200(改版「输入全显」口径:一次拉全做内存过滤,封顶防
  /// 极端库)。纯本地读:建议只是输入辅助,bound 在线时本地镜像亦随远端
  /// 写后刷新(见 TransactionRepositoryImpl 路由注释),不走三态数据路由,
  /// 也无对应服务端 RPC。
  Future<Either<Failure, List<String>>> recentDescriptions({int limit = 200});

  /// Income/expense/net/dailyAvg summary. `accountId` optional scopes to one
  /// account (account-detail view). `scope` (Task 9) selects the aggregation
  /// granularity — [SummaryScope.month] is the default (legacy callers keep
  /// their behaviour); `day` pins the day-of-month for [SummaryScope.day].
  /// `tagId`(F8 FR-4)可选:仅统计带该标签的交易(聚合前按 junction
  /// 关联集过滤,本地口径);null = 全量(既有调用零改)。
  /// Backed by the server's `TransactionSummary` RPC.
  Future<Either<Failure, MonthlySummary>> summary(
    int year,
    int month, {
    String? accountId,
    SummaryScope scope = SummaryScope.month,
    int? day,
    String? tagId,
  });
}

/// Records a SimpleExpense RPC: debit an expense account, credit an asset
/// account (e.g. cash / bank card).
///
/// [transactionTime] (Task 5) is the optional RFC3339 wall-clock timestamp
/// the form assembles from the date + TimeOfDay picker. Empty string means
/// "server stamps it itself" (legacy behavior); when set, the data layer
/// forwards it to the proto's `transaction_time` field.
class RecordExpenseParams {
  const RecordExpenseParams({
    required this.transactionDate,
    required this.expenseAccountId,
    required this.assetAccountId,
    required this.amountCents,
    this.description = '',
    this.note = '',
    this.transactionTime = '',
  });

  final DateTime transactionDate;
  final String expenseAccountId;
  final String assetAccountId;
  final int amountCents;
  final String description;
  final String note;
  final String transactionTime;
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
    this.transactionTime = '',
  });

  final DateTime transactionDate;
  final String assetAccountId;
  final String incomeAccountId;
  final int amountCents;
  final String description;
  final String note;
  final String transactionTime;
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
    this.transactionTime = '',
  });

  final DateTime transactionDate;
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final String description;
  final String note;
  final String transactionTime;
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
