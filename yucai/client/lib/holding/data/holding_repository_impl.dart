import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
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
  HoldingRepositoryImpl(this._remote, this._local, this._tracker, this._goalViewDs, [this._mirror]);

  final HoldingRemoteDataSource _remote;
  final HoldingLocalDataSource _local;
  final SessionModeTracker _tracker;
  final BoundMirror? _mirror;

  /// F10 FR-1:三态数据路由(guestLocal / boundRemote / boundOfflineLocal)。
  /// guest 或 bound-offline 走本地;仅绑定在线走远端(在线行为与 R6 的
  /// `_useLocal => isGuest` 逐位一致)。
  bool get _useLocalDs {
    final route = _tracker.resolveDataRoute();
    return route == DataRoute.guestLocal || route == DataRoute.boundOfflineLocal;
  }
  final GoalViewDataSource _goalViewDs;

  // —— 查询 ——
  @override
  Future<Either<Failure, List<Holding>>> listHoldings({String? accountId}) =>
      _guard(() => _useLocalDs ? _local.listHoldings(accountId: accountId) : _remote.listHoldings(accountId: accountId));

  @override
  Future<Either<Failure, List<HoldingTransaction>>> listHoldingTransactions({
    String? accountId,
    String? securityId,
  }) =>
      _guard(() => _useLocalDs ? _local.listHoldingTransactions(
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
      _routedWrite(MirrorModule.holding,
          () => _remote.buy(
            accountId: accountId,
            securityId: securityId,
            fromAccountId: fromAccountId,
            quantity: quantity,
            priceCents: priceCents,
            feeCents: feeCents,
            tradeDate: tradeDate,
            notes: notes,
          ),
          () => _local.buy(
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
      _routedWrite(MirrorModule.holding,
          () => _remote.sell(
            accountId: accountId,
            securityId: securityId,
            fromAccountId: fromAccountId,
            quantity: quantity,
            priceCents: priceCents,
            feeCents: feeCents,
            tradeDate: tradeDate,
            notes: notes,
          ),
          () => _local.sell(
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
      _routedWrite(MirrorModule.holding,
          () => _remote.recordDividend(
            accountId: accountId,
            securityId: securityId,
            quantity: quantity,
            cashPerShareCents: cashPerShareCents,
            totalAmountCents: totalAmountCents,
            tradeDate: tradeDate,
            notes: notes,
          ),
          () => _local.recordDividend(
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
      _routedWrite(MirrorModule.holding,
          () => _remote.recordSplit(
            accountId: accountId,
            securityId: securityId,
            ratio: ratio,
            splitDate: splitDate,
            notes: notes,
          ),
          () => _local.recordSplit(
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
      _routedWrite(MirrorModule.holding,
          () => _remote.createSecurity(
            symbol: symbol,
            name: name,
            type: type,
            exchange: exchange,
            currency: currency,
          ),
          () => _local.createSecurity(
            symbol: symbol,
            name: name,
            type: type,
            exchange: exchange,
            currency: currency,
          ));

  @override
  Future<Either<Failure, List<Security>>> listSecurities({SecurityType? type}) =>
      _guard(() => _useLocalDs ? _local.listSecurities(type: type) : _remote.listSecurities(type: type));

  @override
  Future<Either<Failure, List<Security>>> searchSecurities(String query) =>
      _guard(() => _useLocalDs ? _local.searchSecurities(query) : _remote.searchSecurities(query));

  @override
  Future<Either<Failure, void>> updateSecurityPrice({
    required String id,
    required int priceCents,
  }) =>
      _routedWrite(MirrorModule.holding,
          () => _remote.updateSecurityPrice(id: id, priceCents: priceCents),
          () => _local.updateSecurityPrice(id: id, priceCents: priceCents));

  // —— 价格批量同步(Task 9 新增)——
  @override
  Future<Either<Failure, SyncPricesResult>> syncPrices() =>
      _guard(() => _useLocalDs ? _local.syncPrices() : _remote.syncPrices());

  // —— 收益曲线(Task 12,holding-C 新增;Task 12 D-currency 加 baseCurrency)——
  @override
  Future<Either<Failure, PortfolioPerformance>> getPortfolioPerformance({
    required String range,
    String? accountId,
    bool includeBenchmark = false,
    String baseCurrency = '',
  }) async {
    if (_useLocalDs) {
      return _guard(() => _local.getPortfolioPerformance(
            range: range,
            accountId: accountId,
            includeBenchmark: includeBenchmark,
            baseCurrency: baseCurrency,
          ));
    }
    // 绑定在线:server 权威;NetworkFailure(断网)→ 本地引擎兜底
    // (R7-D FR-3 β;本地值 offlineScope=true,UI 标「离线口径」)。
    final remote = await _guard(() => _remote.getPortfolioPerformance(
          range: range,
          accountId: accountId,
          includeBenchmark: includeBenchmark,
          baseCurrency: baseCurrency,
        ));
    return remote.fold(
      (f) => f is NetworkFailure
          ? _guard(() => _local.getPortfolioPerformance(
                range: range,
                accountId: accountId,
                includeBenchmark: includeBenchmark,
                baseCurrency: baseCurrency,
              ))
          : Left<Failure, PortfolioPerformance>(f),
      (r) => Right<Failure, PortfolioPerformance>(r),
    );
  }

  @override
  Future<Either<Failure, HoldingPerformance>> getHoldingPerformance({
    required String holdingId,
    required String range,
    String baseCurrency = '',
  }) =>
      _guard(() => _useLocalDs ? _local.getHoldingPerformance(
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
      // Guest / bound-offline(F10 FR-1): read the local goals table
      // (investment-type only) — the cross-module GoalViewDataSource is
      // gRPC-bound.
      _guard(() => _useLocalDs
          ? _local.listInvestmentGoalsLocal()
          : _goalViewDs.listInvestmentGoals());

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  /// Bound-state mirror hook (R6 H): after a SUCCESSFUL REMOTE
  /// write, refresh this module's local mirror (fire-and-forget).
  Future<Either<Failure, T>> _mirrored<T>(MirrorModule m,
      Future<Either<Failure, T>> Function() body) async {
    final r = await body();
    if (r.isRight() && !_useLocalDs && _mirror != null) {
      unawaited(_mirror.refreshModule(m));
    }
    return r;
  }

  /// F10 FR-1/FR-1b:三态写路由 + 远端失败降级(照 transaction 范式)。
  /// guest/bound-offline 直接本地;boundRemote 先远端(Right 触发镜像刷新,
  /// 与 R6 逐位一致),NetworkFailure 降级本地落库(FR-1b 双保险)且不触发
  /// 镜像刷新(防 delete-all+rebuild 抹掉未上行本地行);其他失败原样 Left。
  /// TODO-F10T2:降级/离线写本地置 pending + 回网上行(本任务不做,锚点)。
  Future<Either<Failure, T>> _routedWrite<T>(MirrorModule m,
      Future<T> Function() remote, Future<T> Function() local) async {
    if (_useLocalDs) {
      return _mirrored(m, () => _guard(local));
    }
    return writeWithFallback(
      () => _mirrored(m, () => _guard(remote)),
      () => _guard(local),
    );
  }

  /// GrpcError → Failure 分类(对齐 account/transaction 等兄弟模块;
  /// R7-D:unavailable → NetworkFailure 是绑定断网本地兜底的前提)。
  Failure _mapGrpcError(GrpcError e) {
    switch (e.code) {
      case StatusCode.unavailable:
        return NetworkFailure(e.message ?? '无法连接服务器');
      case StatusCode.unauthenticated:
        return AuthFailure(e.message ?? '凭证无效');
      default:
        return ServerFailure(e.message ?? 'gRPC error');
    }
  }

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } on Failure catch (f) {
      // Local data source failures pass through untouched.
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
