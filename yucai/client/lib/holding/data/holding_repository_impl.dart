import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

@LazySingleton(as: HoldingRepository)
class HoldingRepositoryImpl implements HoldingRepository {
  HoldingRepositoryImpl(this._remote);

  final HoldingRemoteDataSource _remote;

  // —— 查询 ——
  @override
  Future<Either<Failure, List<Holding>>> listHoldings({String? accountId}) =>
      _guard(() => _remote.listHoldings(accountId: accountId));

  @override
  Future<Either<Failure, List<HoldingTransaction>>> listHoldingTransactions({
    String? accountId,
    String? securityId,
  }) =>
      _guard(() => _remote.listHoldingTransactions(
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
      _guard(() => _remote.buy(
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
      _guard(() => _remote.sell(
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
      _guard(() => _remote.recordDividend(
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
      _guard(() => _remote.recordSplit(
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
      _guard(() => _remote.createSecurity(
            symbol: symbol,
            name: name,
            type: type,
            exchange: exchange,
            currency: currency,
          ));

  @override
  Future<Either<Failure, List<Security>>> listSecurities({SecurityType? type}) =>
      _guard(() => _remote.listSecurities(type: type));

  @override
  Future<Either<Failure, List<Security>>> searchSecurities(String query) =>
      _guard(() => _remote.searchSecurities(query));

  @override
  Future<Either<Failure, void>> updateSecurityPrice({
    required String id,
    required int priceCents,
  }) =>
      _guard(() => _remote.updateSecurityPrice(
            id: id,
            priceCents: priceCents,
          ));

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
