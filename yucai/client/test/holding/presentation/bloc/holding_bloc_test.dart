import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
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

// Task 10: RefreshPricesRequested 测试用的 server 同步时间(固定值)。
final syncAt = DateTime.utc(2026, 6, 30, 12, 0, 0);

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
  // HoldingDetailLoaded(found, trades: [], isPendingBackend: true)——
  // holding 仍带(来自 listHoldings ✅),仅交易历史降级(brief:交易历史区
  // 空态,非整页)。UI 据此保留 holding 卡/曲线/配置,仅交易历史显 ⏳ 空态。
  blocTest<HoldingBloc, HoldingState>(
    'LoadDetailRequested with listHoldingTransactions failure emits '
    'HoldingDetailLoaded(isPendingBackend: true, holding retained)',
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
      isA<HoldingDetailLoaded>()
          .having((s) => s.isPendingBackend, 'isPendingBackend', isTrue)
          .having((s) => s.holding, 'holding', sampleHolding)
          .having((s) => s.trades, 'trades', isEmpty),
    ],
  );

  // 真业务错误:listHoldings fail(无 holding)→ HoldingError(isPendingBackend:false)。
  blocTest<HoldingBloc, HoldingState>(
    'LoadDetailRequested with listHoldings failure emits '
    'HoldingError(isPendingBackend: false)',
    build: () {
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => const Left(ServerFailure('listHoldings fail')));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('h1')),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      HoldingLoading(),
      isA<HoldingError>().having((s) => s.isPendingBackend,
          'isPendingBackend', isFalse),
    ],
  );

  // holding not found(真业务错误)→ HoldingError(isPendingBackend:false)。
  blocTest<HoldingBloc, HoldingState>(
    'LoadDetailRequested with holding not found emits '
    'HoldingError(isPendingBackend: false)',
    build: () {
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => const Right([]));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(const LoadDetailRequested('missing')),
    wait: const Duration(milliseconds: 100),
    expect: () => [
      HoldingLoading(),
      isA<HoldingError>().having((s) => s.isPendingBackend,
          'isPendingBackend', isFalse),
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

  // Task 10: RefreshPricesRequested Right → 记录 lastPriceSyncedAt +
  // 重发 LoadHoldingsRequested(新价重算 marketValue/pnl)。
  // emit 顺序 [HoldingSubmitting, HoldingLoading, HoldingLoaded]。
  blocTest<HoldingBloc, HoldingState>(
    'RefreshPricesRequested success updates lastPriceSyncedAt and refreshes list',
    build: () {
      when(() => repo.syncPrices()).thenAnswer(
          (_) async => Right(SyncPricesResult(syncedCount: 3, syncedAt: syncAt)));
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(const RefreshPricesRequested()),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<HoldingSubmitting>(),
      HoldingLoading(),
      isA<HoldingLoaded>()
          .having((s) => s.lastPriceSyncedAt, 'lastPriceSyncedAt', syncAt),
    ],
    verify: (b) {
      verify(() => repo.syncPrices()).called(1);
    },
  );

  // Task 10: RefreshPricesRequested Left(syncPrices fail)→ HoldingError。
  blocTest<HoldingBloc, HoldingState>(
    'RefreshPricesRequested failure emits HoldingError',
    build: () {
      when(() => repo.syncPrices())
          .thenAnswer((_) async => const Left(ServerFailure('price source down')));
      return HoldingBloc(repo);
    },
    act: (b) => b.add(const RefreshPricesRequested()),
    wait: const Duration(milliseconds: 150),
    expect: () => [
      isA<HoldingSubmitting>(),
      isA<HoldingError>(),
    ],
    verify: (b) {
      verify(() => repo.syncPrices()).called(1);
      verifyNever(() => repo.listHoldings(accountId: any(named: 'accountId')));
    },
  );

  // Task 13(holding-C):LoadHoldingCurveRequested 成功 → 在现有
  // HoldingDetailLoaded 上 copyWith 曲线(pricePoints + realizedCents)。
  // 先发 LoadDetailRequested 建立 detail 态,再发 curve 事件。
  blocTest<HoldingBloc, HoldingState>(
    'LoadHoldingCurveRequested success copies curve onto HoldingDetailLoaded',
    build: () {
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId'),
          )).thenAnswer((_) async => Right([sampleTrade]));
      when(() => repo.getHoldingPerformance(
            holdingId: any(named: 'holdingId'),
            range: any(named: 'range'),
          )).thenAnswer((_) async => const Right(HoldingPerformance(
            realizedCents: 5000,
            unrealizedCents: 2000,
            totalCents: 7000,
          )));
      return HoldingBloc(repo);
    },
    act: (b) => b
      ..add(const LoadDetailRequested('h1'))
      ..add(const LoadHoldingCurveRequested(holdingId: 'h1')),
    wait: const Duration(milliseconds: 200),
    expect: () => [
      HoldingLoading(),
      isA<HoldingDetailLoaded>()
          .having((s) => s.holding, 'holding', sampleHolding),
      isA<HoldingDetailLoaded>()
          .having((s) => s.holdingCurveRealizedCents,
              'holdingCurveRealizedCents', 5000)
          .having((s) => s.holdingCurve, 'holdingCurve', isEmpty),
    ],
  );

  // Task 13:LoadHoldingCurveRequested 失败 → 保留当前 detail 态,曲线区空。
  // curve fail 时 emit current.copyWith()(字段全等)→ Equatable 去重,故不产生
  // 新 state(emit 列表仅 2 项:Loading + detail)。verify 确认调用发生 +
  // 终态仍 HoldingDetailLoaded(curve null)。
  blocTest<HoldingBloc, HoldingState>(
    'LoadHoldingCurveRequested failure retains HoldingDetailLoaded (curve empty)',
    build: () {
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right([sampleHolding]));
      when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId'),
          )).thenAnswer((_) async => const Left(ServerFailure('not impl')));
      when(() => repo.getHoldingPerformance(
            holdingId: any(named: 'holdingId'),
            range: any(named: 'range'),
          )).thenAnswer((_) async => const Left(ServerFailure('curve down')));
      return HoldingBloc(repo);
    },
    act: (b) => b
      ..add(const LoadDetailRequested('h1'))
      ..add(const LoadHoldingCurveRequested(holdingId: 'h1')),
    wait: const Duration(milliseconds: 200),
    expect: () => [
      HoldingLoading(),
      isA<HoldingDetailLoaded>()
          .having((s) => s.isPendingBackend, 'isPendingBackend', isTrue)
          .having((s) => s.holdingCurve, 'holdingCurve', isNull),
      // copyWith() 与原 detail 全等(Equatable 去重,不产生额外 state)。
    ],
    verify: (b) {
      verify(() => repo.getHoldingPerformance(
            holdingId: any(named: 'holdingId'),
            range: any(named: 'range'),
          )).called(1);
      // 终态仍 HoldingDetailLoaded(curve 区空态,未崩成 HoldingError)。
      expect(b.state, isA<HoldingDetailLoaded>());
      expect((b.state as HoldingDetailLoaded).holdingCurve, isNull);
    },
  );
}
