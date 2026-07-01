import 'package:equatable/equatable.dart';

import 'package:yucai_client/budget/domain/entities/budget_entity.dart';

abstract class BudgetState extends Equatable {
  const BudgetState();
  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {}

class BudgetLoading extends BudgetState {}

/// 列表 loaded。budgets 为 BudgetView 列表(BudgetDTO 路径,items 空)。
class BudgetListLoaded extends BudgetState {
  const BudgetListLoaded(this.budgets);
  final List<BudgetView> budgets;
  @override
  List<Object?> get props => [budgets];
}

/// 详情 loaded。budget 为完整 BudgetView(BudgetDetailDTO 路径,items 填充)。
class BudgetDetailLoaded extends BudgetState {
  const BudgetDetailLoaded(this.budget);
  final BudgetView budget;
  @override
  List<Object?> get props => [budget];
}

/// 错误状态。
class BudgetError extends BudgetState {
  const BudgetError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
