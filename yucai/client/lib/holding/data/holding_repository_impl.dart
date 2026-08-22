import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

@LazySingleton(as: HoldingRepository)
class HoldingRepositoryImpl implements HoldingRepository {
  HoldingRepositoryImpl(this._remote, this._local, this._tracker, this._goalViewDs);

  final HoldingRemoteDataSource _remote;
  final HoldingLocalDataSource _local;
  final SessionModeTracker _tracker;

  bool get _useLocal => _tracker.isGuest;
  final GoalViewDataSource _goalViewDs;

  // —— 查询 ——
  @override
  Future<Either<Failure, List<Holding>>> listHoldings({String? accountId}) =>
      _guard(() => _useLocal ? _local.listHoldings(accountId: accountId) : _remote.listHoldings(accountId: accountId));

  @override
  Future<Either<Failure, List<HoldingTransaction>>> listHoldingTransactions({
    String? accountId,
    String? securityId,
  }) =>
      _guard(() => _useLocal ? _local.listHoldingTransactions(
            accountId: accountId,
            securityId: securityId,
          ) : _remote.listHoldingTransactions(
            accountId: accountId,
            securityId: securityId,
          ));

  // —— 交易(buy / sell 共用 HoldingTradeRequest)——
  @override
  Future<Either<Failure, HoldingTransaction>> buy({
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  }) =>
      _guard(() => _useLocal ? _local.buy(
            accountId: accountId,
            securityId: securityId,
            fromAccountId: fromAccountId,
            quantity: quantity,
            priceCents: priceCents,
            feeCents: feeCents,
            tradeDate: tradeDate,
            notes: notes,
          ) : _remote.buy(
            accountId: accountId,
            securityId: securityId,
            fromAccountId: fromAccountId,
            quantity: quantity,
            priceCents: priceCents,
            feeCents: feeCents,
            tradeDate: tradeDate,
            notes: notes,
          ));

  @override
  Future<Either<Failure, HoldingTransaction>> sell({
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  }) =>
      _guard(() => _useLocal ? _local.sell(
            accountId: accountId,
            securityId: securityId,
            fromAccountId: fromAccountId,
            quantity: quantity,
            priceCents: priceCents,
            feeCents: feeCents,
            tradeDate: tradeDate,
            notes: notes,
          ) : _remote.sell(
            accountId: accountId,
            securityId: securityId,
            fromAccountId: fromAccountId,
            quantity: quantity,
            priceCents: priceCents,
            feeCents: feeCents,
            tradeDate: tradeDate,
            notes: notes,
          ));

  // —— 公司行动(dividend / split)——
  @override
  Future<Either<Failure, HoldingTransaction>> recordDividend({
    required String accountId,
    required String securityId,
    required double quantity,
    required int cashPerShareCents,
    required int totalAmountCents,
    required String tradeDate,
    String? notes,
  }) =>
      _guard(() => _useLocal ? _local.recordDividend(
            accountId: accountId,
            securityId: securityId,
            quantity: quantity,
            cashPerShareCents: cashPerShareCents,
            totalAmountCents: totalAmountCents,
            tradeDate: tradeDate,
            notes: notes,
          ) : _remote.recordDividend(
            accountId: accountId,
            securityId: securityId,
            quantity: quantity,
            cashPerShareCents: cashPerShareCents,
            totalAmountCents: totalAmountCents,
            tradeDate: tradeDate,
            notes: notes,
          ));

  @override
  Future<Either<Failure, HoldingTransaction>> recordSplit({
    required String accountId,
    required String securityId,
    required double ratio,
    required String splitDate,
    String? notes,
  }) =>
      _guard(() => _useLocal ? _local.recordSplit(
            accountId: accountId,
            securityId: securityId,
            ratio: ratio,
            splitDate: splitDate,
            notes: notes,
          ) : _remote.recordSplit(
            accountId: accountId,
            securityId: securityId,
            ratio: ratio,
            splitDate: splitDate,
            notes: notes,
          ));

  // —— 证券主数据 ——
  @override
  Future<Either<Failure, Security>> createSecurity({
    required String symbol,
    required String name,
    required SecurityType type,
    String? exchange,
    required String currency,
  }) =>
      _guard(() => _useLocal ? _local.createSecurity(
            symbol: symbol,
            name: name,
            type: type,
            exchange: exchange,
            currency: currency,
          ) : _remote.createSecurity(
            symbol: symbol,
            name: name,
            type: type,
            exchange: exchange,
            currency: currency,
          ));

  @override
  Future<Either<Failure, List<Security>>> listSecurities({SecurityType? type}) =>
      _guard(() => _useLocal ? _local.listSecurities(type: type) : _remote.listSecurities(type: type));

  @override
  Future<Either<Failure, List<Security>>> searchSecurities(String query) =>
      _guard(() => _useLocal ? _local.searchSecurities(query) : _remote.searchSecurities(query));

  @override
  Future<Either<Failure, void>> updateSecurityPrice({
    required String id,
    required int priceCents,
  }) =>
      _guard(() => _useLocal ? _local.updateSecurityPrice(
            id: id,
            priceCents: priceCents,
          ) : _remote.updateSecurityPrice(
            id: id,
            priceCents: priceCents,
          ));

  // —— 价格批量同步(Task 9 新增)——
  @override
  Future<Either<Failure, SyncPricesResult>> syncPrices() =>
      _guard(() => _useLocal ? _local.syncPrices() : _remote.syncPrices());

  // —— 收益曲线(Task 12,holding-C 新增;Task 12 D-currency 加 baseCurrency)——
  @override
  Future<Either<Failure, PortfolioPerformance>> getPortfolioPerformance({
    required String range,
    String? accountId,
    bool includeBenchmark = false,
    String baseCurrency = '',
  }) =>
      _guard(() => _useLocal ? _local.getPortfolioPerformance(
            range: range,
            accountId: accountId,
            includeBenchmark: includeBenchmark,
            baseCurrency: baseCurrency,
          ) : _remote.getPortfolioPerformance(
            range: range,
            accountId: accountId,
            includeBenchmark: includeBenchmark,
            baseCurrency: baseCurrency,
          ));

  @override
  Future<Either<Failure, HoldingPerformance>> getHoldingPerformance({
    required String holdingId,
    required String range,
    String baseCurrency = '',
  }) =>
      _guard(() => _useLocal ? _local.getHoldingPerformance(
            holdingId: holdingId,
            range: range,
            baseCurrency: baseCurrency,
          ) : _remote.getHoldingPerformance(
            holdingId: holdingId,
            range: range,
            baseCurrency: baseCurrency,
          ));

  // —— 投资目标关联(Task 10,holding-D 跨模块 goal gRPC)——
  @override
  Future<Either<Failure, List<GoalView>>> listInvestmentGoals() =>
      // Guest: read the local goals table (investment-type only) — the
      // cross-module GoalViewDataSource is gRPC-bound.
      _guard(() => _useLocal
          ? _local.listInvestmentGoalsLocal()
          : _goalViewDs.listInvestmentGoals());

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(ServerFailure(e.message ?? 'gRPC error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
