// 收益统计页 Bloc 状态(Task 13,holding-C)。
//
// 对齐 performance_page 4 状态分支:Initial / Loading / Loaded(perf) /
// Error(message)。Loaded 携带 PortfolioPerformance(Task 12 entity:
// portfolioPoints + benchmarkPoints + realized/unrealized/total cents +
// annualizedPct/totalPct)。
import 'package:equatable/equatable.dart';

import 'package:yucai_client/holding/domain/entities/performance_entity.dart';

abstract class PerformanceState extends Equatable {
  const PerformanceState();
  @override
  List<Object?> get props => [];
}

class PerformanceInitial extends PerformanceState {}

class PerformanceLoading extends PerformanceState {}

class PerformanceLoaded extends PerformanceState {
  const PerformanceLoaded(this.performance);
  final PortfolioPerformance performance;
  @override
  List<Object?> get props => [performance];
}

class PerformanceError extends PerformanceState {
  const PerformanceError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
