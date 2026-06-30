// 收益统计页 Bloc(Task 13,holding-C)。
//
// 职责:消费 HoldingRepository.getPortfolioPerformance(Task 12)→
// PerformanceLoaded(portfolioPoints + benchmarkPoints + realized/unrealized/
// total cents + annualizedPct/totalPct)。range 大写英文串('DAY'/'MONTH'/
// 'YEAR'),由 UI PerfRange enum 经 rangeName() 映射后传入(见
// performance_page.dart)。
//
// DI:@injectable + build_runner 重生成 injection.config.dart(Factory 注册)。
// 路由层 BlocProvider<PerformanceBloc>(getIt<PerformanceBloc>())注入。
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_event.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_state.dart';

@injectable
class PerformanceBloc extends Bloc<PerformanceEvent, PerformanceState> {
  PerformanceBloc(this._repo) : super(PerformanceInitial()) {
    on<LoadPortfolioPerformanceRequested>(_onLoad);
  }

  final HoldingRepository _repo;

  Future<void> _onLoad(
    LoadPortfolioPerformanceRequested event,
    Emitter<PerformanceState> emit,
  ) async {
    emit(PerformanceLoading());
    final result = await _repo.getPortfolioPerformance(
      range: event.range,
      accountId: event.accountId,
      includeBenchmark: true,
    );
    result.fold(
      (f) => emit(PerformanceError(f.displayMessage)),
      (perf) => emit(PerformanceLoaded(perf)),
    );
  }
}
