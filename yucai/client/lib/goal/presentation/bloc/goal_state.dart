import 'package:equatable/equatable.dart';

import 'package:yucai_client/goal/domain/entities/goal_entity.dart';

abstract class GoalState extends Equatable {
  const GoalState();
  @override
  List<Object?> get props => [];
}

class GoalInitial extends GoalState {}

class GoalLoading extends GoalState {}

/// 列表 loaded。goals 为 GoalView 列表。
class GoalListLoaded extends GoalState {
  const GoalListLoaded(this.goals);
  final List<GoalView> goals;
  @override
  List<Object?> get props => [goals];
}

/// 详情 loaded。goal 为完整 GoalView(server 端 currentAmountCents 已算好)。
class GoalDetailLoaded extends GoalState {
  const GoalDetailLoaded(this.goal);
  final GoalView goal;
  @override
  List<Object?> get props => [goal];
}

/// 错误状态。
class GoalError extends GoalState {
  const GoalError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
