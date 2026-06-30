// Task 13(holding-C)— PerformanceBloc 单元测试。
//
// 验证(对齐 plan Task 13 Step 8):
//   - LoadPortfolioPerformanceRequested + Right(PortfolioPerformance) →
//     emit [PerformanceLoading, PerformanceLoaded]。
//   - Left(ServerFailure) → emit [PerformanceLoading, PerformanceError]。
//   - range 参数原样透传给 repo(curveRangeToProto 在 remote_ds 层映射,
//     bloc 不做 enum→串转换 —— 必须是大写英文串,由 UI rangeName() 保证)。
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_event.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_state.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart';

class _MockRepo extends Mock implements HoldingRepository {}

final _perf = PortfolioPerformance(
  portfolioPoints: [
    PerfPoint(time: DateTime(2026, 6, 1), value: 100),
    PerfPoint(time: DateTime(2026, 6, 30), value: 120),
  ],
  benchmarkPoints: const [],
  realizedCents: 80000,
  unrealizedCents: 250000,
  totalCents: 330000,
  annualizedPct: 12.3,
  benchmarkName: '沪深300',
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
  });

  blocTest<PerformanceBloc, PerformanceState>(
    'LoadPortfolioPerformanceRequested with Right emits [Loading, Loaded]',
    build: () {
      when(() => repo.getPortfolioPerformance(
            range: any(named: 'range'),
            accountId: any(named: 'accountId'),
            includeBenchmark: any(named: 'includeBenchmark'),
          )).thenAnswer((_) async => Right(_perf));
      return PerformanceBloc(repo);
    },
    act: (b) => b.add(const LoadPortfolioPerformanceRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      PerformanceLoading(),
      isA<PerformanceLoaded>()
          .having((s) => s.performance.realizedCents, 'realizedCents', 80000)
          .having((s) => s.performance.portfolioPoints.length,
              'portfolioPoints.length', 2),
    ],
    verify: (b) {
      // includeBenchmark 必须为 true(performance_page 需基准)。
      verify(() => repo.getPortfolioPerformance(
            range: 'DAY',
            accountId: any(named: 'accountId'),
            includeBenchmark: true,
          )).called(1);
    },
  );

  blocTest<PerformanceBloc, PerformanceState>(
    'LoadPortfolioPerformanceRequested with Left emits [Loading, Error]',
    build: () {
      when(() => repo.getPortfolioPerformance(
            range: any(named: 'range'),
            accountId: any(named: 'accountId'),
            includeBenchmark: any(named: 'includeBenchmark'),
          )).thenAnswer((_) async => const Left(ServerFailure('boom')));
      return PerformanceBloc(repo);
    },
    act: (b) => b.add(const LoadPortfolioPerformanceRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      PerformanceLoading(),
      isA<PerformanceError>().having((s) => s.message, 'message', 'boom'),
    ],
  );

  // 关键约束:range 大写英文串原样透传(bloc 不做 enum 转换)。
  // 验证 'MONTH' 透传(而非 PerfRange.label 中文「月」)。
  blocTest<PerformanceBloc, PerformanceState>(
    'range passed through as-is (uppercase string, not PerfRange.label)',
    build: () {
      when(() => repo.getPortfolioPerformance(
            range: any(named: 'range'),
            accountId: any(named: 'accountId'),
            includeBenchmark: any(named: 'includeBenchmark'),
          )).thenAnswer((_) async => Right(_perf));
      return PerformanceBloc(repo);
    },
    act: (b) => b.add(const LoadPortfolioPerformanceRequested(range: 'MONTH')),
    wait: const Duration(milliseconds: 100),
    verify: (b) {
      verify(() => repo.getPortfolioPerformance(
            range: 'MONTH',
            accountId: any(named: 'accountId'),
            includeBenchmark: any(named: 'includeBenchmark'),
          )).called(1);
      // 绝未以中文「月」或小写调用(暴露回归)。
      verifyNever(() => repo.getPortfolioPerformance(
            range: '月',
            accountId: any(named: 'accountId'),
            includeBenchmark: any(named: 'includeBenchmark'),
          ));
    },
  );
}
