import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';

class _MockRepo extends Mock implements HoldingRepository {}

final sampleHolding = Holding(
  id: 'h1',
  accountId: 'a1',
  securityId: 's1',
  securityName: 'ACME',
  securitySymbol: 'ACME',
  quantity: 10,
  avgCostCents: 1000,
  marketValueCents: 12000,
  unrealizedPnlCents: 2000,
  version: 1,
);

final sampleTrade = HoldingTransaction(
  id: 't1',
  accountId: 'a1',
  securityId: 's1',
  tradeType: TradeType.buy,
  quantity: 10,
  priceCents: 1000,
  amountCents: 10000,
  feeCents: 0,
  tradeDate: '2026-01-01',
);

final buyParams = BuyParams(
  accountId: 'a1',
  securityId: 's1',
  fromAccountId: 'a1',
  quantity: 10,
  priceCents: 1000,
  tradeDate: '2026-01-01',
);

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    registerFallbackValue(SecurityType.stock);
  });

  blocTest<HoldingBloc, HoldingState>(
    'LoadHoldingsRequested emits [Loading, Loaded]',
    build: () {
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(const LoadHoldingsRequested()),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      HoldingLoading(),
      isA<HoldingLoaded>()
          .having((s) => s.holdings, 'holdings', [sampleHolding]),
    ],
  );

  blocTest<HoldingBloc, HoldingState>(
    'BuyRequested emits Submitting then refreshes list (Loaded)',
    build: () {
      when(() => repo.buy(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId'),
            fromAccountId: any(named: 'fromAccountId'),
            quantity: any(named: 'quantity'),
            priceCents: any(named: 'priceCents'),
            feeCents: any(named: 'feeCents'),
            tradeDate: any(named: 'tradeDate'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => Right(sampleTrade));
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(BuyRequested(buyParams)),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<HoldingSubmitting>(),
      HoldingLoading(),
      isA<HoldingLoaded>(),
    ],
  );

  // ⏳ fail 降级核心:ListHoldingTransactions(后端 B/C/D 未实现)fail →
  // HoldingError(isPendingBackend: true),UI 据此显示空态 + ⏳ 标注,
  // 而非当作真业务错误。
  blocTest<HoldingBloc, HoldingState>(
    'LoadDetailRequested with listHoldingTransactions failure emits '
    'HoldingError(isPendingBackend: true)',
    build: () {
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId'),
          )).thenAnswer((_) async => const Left(ServerFailure('unimplemented')));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('h1')),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      HoldingLoading(),
      isA<HoldingError>().having((s) => s.isPendingBackend,
          'isPendingBackend', isTrue),
    ],
  );

  // 数据正确性:LoadDetailRequested 必须用 securityId(非 holding id)查交易。
  // sampleHolding id='h1' ≠ securityId='s1',传错(holding id)会被 verify 拒绝。
  blocTest<HoldingBloc, HoldingState>(
    'LoadDetailRequested queries transactions by securityId (not holding id)',
    build: () {
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: 's1',
          )).thenAnswer((_) async => Right([sampleTrade]));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('h1')),
    wait: const Duration(milliseconds: 100),
    verify: (b) {
      verify(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: 's1',
          )).called(1);
      // 显式断言:绝未以 holding id 'h1' 调用(暴露回归)。
      verifyNever(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: 'h1',
          ));
    },
  );

  // 真业务错误(buy fail)→ HoldingError(isPendingBackend: false,默认)。
  blocTest<HoldingBloc, HoldingState>(
    'BuyRequested failure emits HoldingError(isPendingBackend: false)',
    build: () {
      when(() => repo.buy(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId'),
            fromAccountId: any(named: 'fromAccountId'),
            quantity: any(named: 'quantity'),
            priceCents: any(named: 'priceCents'),
            feeCents: any(named: 'feeCents'),
            tradeDate: any(named: 'tradeDate'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => const Left(ServerFailure('rejected')));
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(BuyRequested(buyParams)),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<HoldingSubmitting>(),
      isA<HoldingError>()
          .having((s) => s.isPendingBackend, 'isPendingBackend', isFalse),
    ],
  );
}
