import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/budget/v1/budget.pb.dart' as pb;
import 'package:yucai_client/proto/budget/v1/budget.pbgrpc.dart' as grpc;
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;

/// Wraps the generated BudgetServiceClient. Throws GrpcError on failure
/// (caught and mapped by the repo layer). Mirrors HoldingRemoteDataSource /
/// DebtRemoteDataSource: every RPC is wrapped in AuthRetryCaller so a 401
/// triggers a transparent refresh + single retry.
///
/// 8 RPCs: createBudget / getBudget / getBudgetByMonth / listBudgets /
/// deleteBudget / addBudgetItem / removeBudgetItem / updateBudget.
///
/// Mapper notes:
/// - Int64 → int via `.toInt()` (mirror holding mapper).
/// - empty notes string (`''`) → null (proto unset scalar string defaults to
///   '' but we surface null for "no notes" so the UI can omit the chip).
/// - createBudget items: caller record `({accountId, plannedAmountCents, notes})`
///   → proto BudgetItemInput.
/// - addItem / removeBudgetItem return BudgetResponse.budget (BudgetDTO, no
///   items); getBudget / getBudgetByMonth return BudgetDetailResponse.budget
///   (BudgetDetailDTO, items populated).
@LazySingleton()
class BudgetRemoteDataSource {
  BudgetRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.BudgetServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.BudgetServiceClient _client;

  // —— 查询 ——
  Future<List<BudgetView>> listBudgets({bool activeOnly = false}) async {
    return _retry.call(() async {
      final res = await _client.listBudgets(pb.ListBudgetsRequest(
        activeOnly: activeOnly,
        page: common.PageRequest(pageSize: 100),
      ));
      return res.budgets.map(budgetDtoToView).toList();
    });
  }

  Future<BudgetView> getBudget(String id) async {
    return _retry.call(() async {
      final res = await _client.getBudget(pb.GetBudgetRequest(id: id));
      return budgetDetailDtoToView(res.budget);
    });
  }

  Future<BudgetView> getBudgetByMonth(String month) async {
    return _retry.call(() async {
      final res = await _client.getBudgetByMonth(pb.GetBudgetByMonthRequest(month: month));
      return budgetDetailDtoToView(res.budget);
    });
  }

  // —— 写入 ——
  Future<BudgetView> createBudget({
    required String name,
    required String month,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) async {
    return _retry.call(() async {
      final res = await _client.createBudget(pb.CreateBudgetRequest(
        name: name,
        month: month,
        currencyCode: currencyCode,
        items: items
            .map((i) => pb.BudgetItemInput(
                  accountId: i.accountId,
                  plannedAmountCents: Int64(i.plannedAmountCents),
                  notes: i.notes ?? '',
                ))
            .toList(),
      ));
      return budgetDtoToView(res.budget);
    });
  }

  Future<void> deleteBudget(String id) async {
    return _retry.call(() async {
      await _client.deleteBudget(pb.DeleteBudgetRequest(id: id));
    });
  }

  Future<BudgetView> addItem({
    required String budgetId,
    required String accountId,
    required int plannedAmountCents,
    String? notes,
  }) async {
    return _retry.call(() async {
      final res = await _client.addBudgetItem(pb.AddBudgetItemRequest(
        budgetId: budgetId,
        accountId: accountId,
        plannedAmountCents: Int64(plannedAmountCents),
        notes: notes ?? '',
      ));
      return budgetDtoToView(res.budget);
    });
  }

  Future<BudgetView> removeItem({
    required String budgetId,
    required String itemId,
  }) async {
    return _retry.call(() async {
      final res = await _client.removeBudgetItem(pb.RemoveBudgetItemRequest(
        budgetId: budgetId,
        itemId: itemId,
      ));
      return budgetDtoToView(res.budget);
    });
  }

  /// 编辑预算(整体 name+currency+items 原地更新,不删旧重建)。
  /// 返回 BudgetResponse.budget(BudgetDTO 无 items)—— 调用方(bloc)
  /// 成功后重新 getBudget 回填 items,照 addItem/removeItem 范式。
  Future<BudgetView> updateBudget({
    required String id,
    required String name,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) async {
    return _retry.call(() async {
      final res = await _client.updateBudget(pb.UpdateBudgetRequest(
        id: id,
        name: name,
        currencyCode: currencyCode,
        items: items
            .map((i) => pb.BudgetItemInput(
                  accountId: i.accountId,
                  plannedAmountCents: Int64(i.plannedAmountCents),
                  notes: i.notes ?? '',
                ))
            .toList(),
      ));
      return budgetDtoToView(res.budget);
    });
  }
}

/// proto BudgetDTO → BudgetView(listBudgets / createBudget / addItem /
/// removeBudgetItem 路径,无 items)。
///
/// totalActualCents / usagePct 来自 Task 2 在 BudgetDTO 上新增的字段
/// (field 10 / 11),server actuals 计算回填。
BudgetView budgetDtoToView(pb.BudgetDTO dto) => BudgetView(
      id: dto.id,
      name: dto.name,
      month: dto.month,
      currencyCode: dto.currencyCode,
      totalAmountCents: dto.totalAmountCents.toInt(),
      totalActualCents: dto.totalActualCents.toInt(),
      usagePct: dto.usagePct,
    );

/// proto BudgetDetailDTO → BudgetView(getBudget / getBudgetByMonth 路径,
/// items 填充)。
///
/// detail 顶层 totalActualCents / usagePct 优先(计算后快照,比内嵌
/// budget.totalActualCents 更准)。items 的 notes 空串 → null。
BudgetView budgetDetailDtoToView(pb.BudgetDetailDTO dto) => BudgetView(
      id: dto.budget.id,
      name: dto.budget.name,
      month: dto.budget.month,
      currencyCode: dto.budget.currencyCode,
      totalAmountCents: dto.budget.totalAmountCents.toInt(),
      totalActualCents: dto.totalActualCents.toInt(),
      usagePct: dto.usagePct,
      items: dto.items
          .map((i) => BudgetItemView(
                id: i.id,
                accountId: i.accountId,
                plannedAmountCents: i.plannedAmountCents.toInt(),
                actualAmountCents: i.actualAmountCents.toInt(),
                notes: i.notes.isEmpty ? null : i.notes,
              ))
          .toList(),
    );
