import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    hide Holding, HoldingTransaction, Security;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

class _MockRemote extends Mock implements HoldingRemoteDataSource {}
class _MockGoalViewDs extends Mock implements GoalViewDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase db;
  late SessionModeTracker tracker;
  late _MockGoalViewDs goalViewDs;
  late HoldingRepositoryImpl repo;

  const sampleHolding = Holding(
    id: 'h1',
    accountId: 'acc-1',
    securityId: 'sec-1',
    securityName: '茅台',
    securitySymbol: '600519',
    quantity: 100.0,
    avgCostCents: 1800000,
    marketValueCents: 2000000,
    unrealizedPnlCents: 200000,
    version: 1,
  );

  const sampleTx = HoldingTransaction(
    id: 't1',
    accountId: 'acc-1',
    securityId: 'sec-1',
    tradeType: TradeType.buy,
    quantity: 10.0,
    priceCents: 1800000,
    amountCents: 18000000,
    feeCents: 500,
    tradeDate: '2026-01-15',
  );

  const sampleSecurity = Security(
    id: 'sec-1',
    symbol: '600519',
    name: '茅台',
    securityType: SecurityType.stock,
    exchange: 'SSE',
    currency: 'CNY',
    currentPriceCents: 2000000,
  );

  setUp(() {
    remote = _MockRemote();
    db = AppDatabase(NativeDatabase.memory());
    tracker = SessionModeTracker()..isGuest = false;
    goalViewDs = _MockGoalViewDs();
    repo = HoldingRepositoryImpl(remote, HoldingLocalDataSource(db, TransactionLocalDataSource(db, BalanceLocalUpdater(db))), tracker, goalViewDs);
    registerFallbackValue(SecurityType.stock);
  });

  group('listHoldings', () {
    test('success returns Right with holdings', () async {
      when(() => remote.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => [sampleHolding]);
      final result = await repo.listHoldings();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (list) {
          expect(list.length, 1);
          expect(list.first.id, 'h1');
        },
      );
    });

    test('failure returns Left<ServerFailure>', () async {
      when(() => remote.listHoldings(accountId: any(named: 'accountId')))
          .thenThrow(const GrpcError.notFound('gone'));
      final result = await repo.listHoldings();
      expect(result.isLeft(), isTrue);
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });

    test('forwards accountId to remote', () async {
      when(() => remote.listHoldings(accountId: 'acc-1'))
          .thenAnswer((_) async => [sampleHolding]);
      await repo.listHoldings(accountId: 'acc-1');
      verify(() => remote.listHoldings(accountId: 'acc-1')).called(1);
    });
  });

  group('buy', () {
    test('success returns Right with HoldingTransaction', () async {
      when(() => remote.buy(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId'),
            fromAccountId: any(named: 'fromAccountId'),
            quantity: any(named: 'quantity'),
            priceCents: any(named: 'priceCents'),
            feeCents: any(named: 'feeCents'),
            tradeDate: any(named: 'tradeDate'),
            notes: any(named: 'notes'),
          )).thenAnswer((_) async => sampleTx);
      final result = await repo.buy(
        accountId: 'acc-1',
        securityId: 'sec-1',
        fromAccountId: 'cash-1',
        quantity: 10,
        priceCents: 1800000,
        tradeDate: '2026-01-15',
      );
      expect(result, const Right<Failure, HoldingTransaction>(sampleTx));
    });

    test('GrpcError → Left<ServerFailure>', () async {
      when(() => remote.buy(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId'),
            fromAccountId: any(named: 'fromAccountId'),
            quantity: any(named: 'quantity'),
            priceCents: any(named: 'priceCents'),
            feeCents: any(named: 'feeCents'),
            tradeDate: any(named: 'tradeDate'),
            notes: any(named: 'notes'),
          )).thenThrow(const GrpcError.invalidArgument('bad'));
      final result = await repo.buy(
        accountId: 'acc-1',
        securityId: 'sec-1',
        fromAccountId: 'cash-1',
        quantity: 10,
        priceCents: 1800000,
        tradeDate: '2026-01-15',
      );
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });
  });

  group('createSecurity', () {
    test('success returns Right with Security', () async {
      when(() => remote.createSecurity(
            symbol: any(named: 'symbol'),
            name: any(named: 'name'),
            type: any(named: 'type'),
            exchange: any(named: 'exchange'),
            currency: any(named: 'currency'),
          )).thenAnswer((_) async => sampleSecurity);
      final result = await repo.createSecurity(
        symbol: '600519',
        name: '茅台',
        type: SecurityType.stock,
        currency: 'CNY',
      );
      expect(result, const Right<Failure, Security>(sampleSecurity));
    });

    test('failure returns Left<ServerFailure>', () async {
      when(() => remote.createSecurity(
            symbol: any(named: 'symbol'),
            name: any(named: 'name'),
            type: any(named: 'type'),
            exchange: any(named: 'exchange'),
            currency: any(named: 'currency'),
          )).thenThrow(const GrpcError.alreadyExists('dup'));
      final result = await repo.createSecurity(
        symbol: '600519',
        name: '茅台',
        type: SecurityType.stock,
        currency: 'CNY',
      );
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });
  });

  group('updateSecurityPrice', () {
    test('success returns Right(null)', () async {
      when(() => remote.updateSecurityPrice(
            id: any(named: 'id'),
            priceCents: any(named: 'priceCents'),
          )).thenAnswer((_) async {});
      final result = await repo.updateSecurityPrice(
          id: 'sec-1', priceCents: 2100000);
      expect(result.isRight(), isTrue);
    });

    test('failure returns Left<ServerFailure>', () async {
      when(() => remote.updateSecurityPrice(
            id: any(named: 'id'),
            priceCents: any(named: 'priceCents'),
          )).thenThrow(const GrpcError.notFound('gone'));
      final result = await repo.updateSecurityPrice(
          id: 'x', priceCents: 100);
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });
  });

  group('syncPrices', () {
    test('success returns Right<SyncPricesResult>', () async {
      // ignore: prefer_const_constructors — DateTime.utc is not const-evaluable.
      when(() => remote.syncPrices()).thenAnswer((_) async => SyncPricesResult(
            syncedCount: 7,
            syncedAt: DateTime.utc(2026, 6, 30, 12, 0, 0),
          ));
      final result = await repo.syncPrices();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (r) {
          expect(r.syncedCount, 7);
          expect(r.syncedAt, DateTime.utc(2026, 6, 30, 12, 0, 0));
        },
      );
    });

    test('GrpcError → Left<ServerFailure>', () async {
      when(() => remote.syncPrices())
          .thenThrow(const GrpcError.unavailable('upstream down'));
      final result = await repo.syncPrices();
      expect(result.fold((l) => l, (_) => null), isA<ServerFailure>());
    });
  });
}
