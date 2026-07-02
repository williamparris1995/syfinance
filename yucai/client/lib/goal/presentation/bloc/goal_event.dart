import 'package:equatable/equatable.dart';

import 'package:yucai_client/goal/domain/entities/goal_entity.dart';

abstract class GoalEvent extends Equatable {
  const GoalEvent();
  @override
  List<Object?> get props => [];
}

/// 拉取目标列表。`type` 为 null 时不过滤类型(对齐 proto ListGoalsRequest
/// 的 optional goalType)。
class LoadListRequested extends GoalEvent {
  const LoadListRequested({this.type});
  final GoalType? type;
  @override
  List<Object?> get props => [type];
}

/// 拉取目标详情(含 actuals,server 端 currentAmountCents 已算好)。走 getGoal 路径。
class LoadDetailRequested extends GoalEvent {
  const LoadDetailRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// 创建目标。字段对齐 proto CreateGoalRequest + repo.createGoal 签名:
/// - target 为 targetAmountCents(分,proto int64)。
/// - deadline 为 ISO 字符串(proto CreateGoalRequest.deadline 是 string,server 解析)。
/// - linkedAccountIds / linkedDebtIds 为 proto repeated string(多账户/债务关联)。
class CreateGoalRequested extends GoalEvent {
  const CreateGoalRequested({
    required this.name,
    required this.type,
    required this.target,
    this.deadline,
    this.linkedAccountIds = const [],
    this.linkedDebtIds = const [],
  });
  final String name;
  final GoalType type;
  final int target; // targetAmountCents
  final String? deadline; // ISO date string
  final List<String> linkedAccountIds;
  final List<String> linkedDebtIds;

  @override
  List<Object?> get props => [name, type, target, deadline, linkedAccountIds, linkedDebtIds];
}

/// 更新目标。字段对齐 proto UpdateGoalRequest + repo.updateGoal 签名(全可选覆盖)。
class UpdateGoalRequested extends GoalEvent {
  const UpdateGoalRequested({
    required this.id,
    this.name,
    this.target,
    this.deadline,
    this.linkedAccountIds,
    this.linkedDebtIds,
  });
  final String id;
  final String? name;
  final int? target; // targetAmountCents
  final String? deadline; // ISO date string
  final List<String>? linkedAccountIds;
  final List<String>? linkedDebtIds;

  @override
  List<Object?> get props => [id, name, target, deadline, linkedAccountIds, linkedDebtIds];
}

/// 删除目标(软删,proto 返回 Empty)。成功后 re-load list。
class DeleteGoalRequested extends GoalEvent {
  const DeleteGoalRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// 标记目标完成(proto 返回 Empty)。成功后 re-load detail。
class CompleteGoalRequested extends GoalEvent {
  const CompleteGoalRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// 记录供款/还款(proto UpdateProgress: id + amountCents)。
///
/// 注意:repo.recordContribution 返回的 GoalView 可能不含最新 actuals
/// (server 端 actuals 计算时机),故成功后 re-load detail(照 budget AddItem
/// re-fetch via getGoal 模式),而非直接 emit 返回值。
class RecordContributionRequested extends GoalEvent {
  const RecordContributionRequested({required this.id, required this.amount});
  final String id;
  final int amount; // amountCents

  @override
  List<Object?> get props => [id, amount];
}

/// 克隆目标(proto CloneGoalRequest: sourceId + 可选覆盖)。
///
/// 同 RecordContribution:repo.cloneGoal 返回的 GoalView 不保证含完整 actuals,
/// 成功后 re-load detail。
class CloneGoalRequested extends GoalEvent {
  const CloneGoalRequested({
    required this.sourceId,
    this.target,
    this.deadline,
    this.name,
  });
  final String sourceId;
  final int? target; // targetAmountCents
  final String? deadline; // ISO date string
  final String? name;

  @override
  List<Object?> get props => [sourceId, target, deadline, name];
}
