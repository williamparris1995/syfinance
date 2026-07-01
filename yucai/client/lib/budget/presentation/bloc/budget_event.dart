import 'package:equatable/equatable.dart';

abstract class BudgetEvent extends Equatable {
  const BudgetEvent();
  @override
  List<Object?> get props => [];
}

/// 拉取预算列表。`activeOnly` 为 true 时仅返回未删除/活跃预算。
class LoadListRequested extends BudgetEvent {
  const LoadListRequested({this.activeOnly = false});
  final bool activeOnly;
  @override
  List<Object?> get props => [activeOnly];
}

/// 拉取预算详情(含 items)。走 getBudget detail 路径。
class LoadDetailRequested extends BudgetEvent {
  const LoadDetailRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// 创建预算。`items` 为 record 列表,字段对齐 proto BudgetItemInput
/// + repo.createBudget 签名。
class CreateBudgetRequested extends BudgetEvent {
  const CreateBudgetRequested({
    required this.name,
    required this.month,
    required this.currencyCode,
    required this.items,
  });
  final String name;
  final String month; // ISO yyyy-MM
  final String currencyCode; // ISO 4217
  final List<({String accountId, int plannedAmountCents, String? notes})> items;

  @override
  List<Object?> get props => [name, month, currencyCode, items];
}

/// 删除预算(软删)。
class DeleteBudgetRequested extends BudgetEvent {
  const DeleteBudgetRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// 新增预算条目。成功后 bloc 重新拉取完整 budget(getBudget)以回填 items
/// —— addItem 返回的 BudgetView 是 BudgetDTO(无 items),不可直接展示。
class AddItemRequested extends BudgetEvent {
  const AddItemRequested({
    required this.budgetId,
    required this.accountId,
    required this.plannedAmountCents,
    this.notes,
  });
  final String budgetId;
  final String accountId;
  final int plannedAmountCents;
  final String? notes;

  @override
  List<Object?> get props => [budgetId, accountId, plannedAmountCents, notes];
}

/// 删除预算条目。同 AddItemRequested,成功后重新拉取完整 budget。
class RemoveItemRequested extends BudgetEvent {
  const RemoveItemRequested({required this.budgetId, required this.itemId});
  final String budgetId;
  final String itemId;

  @override
  List<Object?> get props => [budgetId, itemId];
}
