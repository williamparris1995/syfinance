import 'package:equatable/equatable.dart';

/// 预算条目(对齐 proto BudgetItemDTO)。
///
/// accountName 为前端展示补充(proto DTO 无,mapper / 前端按 accountId 关联
/// account 名称填)。remainingCents / usagePct / isOverBudget 为派生 getter,
/// 纯计算无 IO。
class BudgetItemView extends Equatable {
  const BudgetItemView({
    required this.id,
    required this.accountId,
    this.accountName,
    required this.plannedAmountCents,
    required this.actualAmountCents,
    this.notes,
  });

  final String id;
  final String accountId;
  final String? accountName; // 展示补充(proto 无,mapper 按 accountId 关联填)
  final int plannedAmountCents; // 计划金额(分)
  final int actualAmountCents; // 实际金额(分,server actuals 计算)
  final String? notes;

  int get remainingCents => plannedAmountCents - actualAmountCents;
  double get usagePct =>
      plannedAmountCents == 0 ? 0 : actualAmountCents / plannedAmountCents * 100;
  bool get isOverBudget => actualAmountCents > plannedAmountCents;

  @override
  List<Object?> get props =>
      [id, accountId, accountName, plannedAmountCents, actualAmountCents, notes];
}

/// 预算汇总(对齐 proto BudgetDTO / BudgetDetailDTO)。
///
/// 列表(BudgetDTO)与详情(BudgetDetailDTO)共用此 entity:
/// - BudgetDTO 路径:items 空,totalActualCents / usagePct 由 server actuals
///   计算回填(Task 2 加在 BudgetDTO)。
/// - BudgetDetailDTO 路径:items 填充,totalActualCents / usagePct 来自 detail
///   顶层字段(优先,比 BudgetDTO 同名字段更准 —— detail 是计算后快照)。
class BudgetView extends Equatable {
  const BudgetView({
    required this.id,
    required this.name,
    required this.month,
    required this.currencyCode,
    required this.totalAmountCents,
    this.totalActualCents = 0,
    this.usagePct = 0,
    this.items = const [],
  });

  final String id;
  final String name;
  final String month; // ISO yyyy-MM(对齐 proto BudgetDTO.month)
  final String currencyCode; // ISO 4217
  final int totalAmountCents; // 预算总额(各 item planned 之和,分)
  final int totalActualCents; // 实际总额(server actuals 计算,分)
  final double usagePct; // 使用率 %(server 计算,totalActual/totalAmount*100)
  final List<BudgetItemView> items;

  int get totalRemainingCents => totalAmountCents - totalActualCents;
  bool get isOverBudget => totalActualCents > totalAmountCents;

  @override
  List<Object?> get props =>
      [id, name, month, currencyCode, totalAmountCents, totalActualCents, usagePct, items];
}
