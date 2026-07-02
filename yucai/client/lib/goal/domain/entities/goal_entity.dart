import 'package:equatable/equatable.dart';

/// 目标类型(对齐 proto GoalType,但去 UNSPECIFIED 占位:业务值从 0 起)。
///
/// proto GoalType 有 GOAL_TYPE_UNSPECIFIED=0 占位,业务值从 1 起;domain 枚举
/// 无占位,业务值从 0 起。mapper 显式按 NAME 映射(参照 holding mapper 模式),
/// 绝不按 int 强转 —— 否则会 off-by-one。
enum GoalType { savings, debtPayoff, investment }

/// 目标视图(对齐 proto GoalDTO)。
///
/// 与 budget BudgetView 同款:Equatable + 派生 getter(progressPct /
/// remainingCents),纯计算无 IO。linkedAccountIds / linkedDebtIds 为 proto
/// repeated string(field 17 / 18,多账户关联)。
///
/// notes 空串 → null(mapper 处理,proto unset scalar string 默认 '' 但 UI 层
/// 需区分 "无备注" 省略 chip)。
class GoalView extends Equatable {
  const GoalView({
    required this.id,
    required this.name,
    required this.type,
    required this.targetAmountCents,
    this.currentAmountCents = 0,
    this.currencyCode = 'CNY',
    this.deadline,
    this.linkedAccountIds = const [],
    this.linkedDebtIds = const [],
    this.notes,
    this.isCompleted = false,
  });

  final String id;
  final String name;
  final GoalType type; // savings / debtPayoff / investment
  final int targetAmountCents; // 目标金额(分)
  final int currentAmountCents; // 当前已存/已还金额(分,server actuals 计算)
  final String currencyCode; // ISO 4217
  final DateTime? deadline; // 目标截止日(proto Timestamp → DateTime?)
  final List<String> linkedAccountIds; // 关联账户 id 列表(proto repeated string)
  final List<String> linkedDebtIds; // 关联债务 id 列表(proto repeated string)
  final String? notes; // 备注(proto 空串 → null)
  final bool isCompleted; // 是否已完成

  /// 完成率 %(currentAmount / targetAmount * 100)。targetAmount 为 0 时返回 0
  /// 避免 NaN / Infinity。
  double get progressPct =>
      targetAmountCents == 0 ? 0 : currentAmountCents / targetAmountCents * 100;

  /// 剩余金额(分,targetAmount - currentAmount)。
  int get remainingCents => targetAmountCents - currentAmountCents;

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        targetAmountCents,
        currentAmountCents,
        currencyCode,
        deadline,
        linkedAccountIds,
        linkedDebtIds,
        notes,
        isCompleted,
      ];
}
