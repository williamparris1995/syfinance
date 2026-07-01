import 'package:dartz/dartz.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

/// 预算仓储抽象(对齐 budget.proto BudgetService,7 个核心 RPC)。
///
/// 签名以 proto 真契约为准:
/// - createBudget 的 items 为 record 列表 `({String accountId, int
///   plannedAmountCents, String? notes})`,DS 端转 proto BudgetItemInput。
/// - addItem / removeItem 返回更新后的 BudgetView(BudgetResponse.budget 是
///   BudgetDTO,无 items;items 详情走 getBudget detail 路径)。
/// - getBudgetByMonth / getBudget 返回 detail(含 items);listBudgets 返回列表
///   (无 items,items 空)。
abstract class BudgetRepository {
  Future<Either<Failure, List<BudgetView>>> listBudgets({bool activeOnly = false});
  Future<Either<Failure, BudgetView>> getBudget(String id);
  Future<Either<Failure, BudgetView>> getBudgetByMonth(String month);
  Future<Either<Failure, BudgetView>> createBudget({
    required String name,
    required String month,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  });
  Future<Either<Failure, void>> deleteBudget(String id);
  Future<Either<Failure, BudgetView>> addItem({
    required String budgetId,
    required String accountId,
    required int plannedAmountCents,
    String? notes,
  });
  Future<Either<Failure, BudgetView>> removeItem({
    required String budgetId,
    required String itemId,
  });
}
