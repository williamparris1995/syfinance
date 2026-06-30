import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/holding/data/mappers/holding_mapper.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;
import 'package:yucai_client/proto/holding/v1/holding.pb.dart' as pb;
import 'package:yucai_client/proto/holding/v1/holding.pbgrpc.dart' as grpc;

/// Wraps the generated HoldingServiceClient. Throws GrpcError on failure
/// (caught and mapped by the repo layer). Mirrors DebtRemoteDataSource: every
/// RPC is wrapped in AuthRetryCaller so a 401 triggers a transparent refresh +
/// single retry.
///
/// 11 RPCs: createSecurity / listSecurities / updateSecurityPrice /
/// searchSecurities / buyHolding / sellHolding / recordDividend / recordSplit /
/// listHoldings / listHoldingTransactions / syncPrices.
///
/// SecurityType / TradeType off-by-one: proto values are 0=UNSPECIFIED, 1+
/// business, while domain enum indices are 0+. We therefore translate by NAME
/// via HoldingMapper.securityTypeToProto / .securityTypeFromProto on the wire —
/// NOT by passing the index straight to proto (which would land on UNSPECIFIED
/// for index 0 and be off-by-one elsewhere).
///
/// buy/sell fromAccountId: proto HoldingTradeRequest.from_account_id (field 8)
/// drives cash-asset double-write (buy=credit 现金−, sell=debit 现金+). The DS
/// writes `fromAccountId ?? ''` — empty string = backend skips double-write.
@LazySingleton()
class HoldingRemoteDataSource {
  HoldingRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.HoldingServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.HoldingServiceClient _client;

  // —— 查询 ——
  Future<List<Holding>> listHoldings({String? accountId}) async {
    return _retry.call(() async {
      final res = await _client.listHoldings(pb.ListHoldingsRequest(
        accountId: accountId ?? '',
        page: common.PageRequest(pageSize: 100),
      ));
      return res.holdings.map(HoldingMapper.toDomain).toList();
    });
  }

  Future<List<HoldingTransaction>> listHoldingTransactions({
    String? accountId,
    String? securityId,
  }) async {
    return _retry.call(() async {
      final res = await _client.listHoldingTransactions(pb.ListTradesRequest(
        accountId: accountId ?? '',
        securityId: securityId ?? '',
        page: common.PageRequest(pageSize: 100),
      ));
      return res.trades.map(HoldingMapper.transactionToDomain).toList();
    });
  }

  // —— 交易(buy / sell 共用 HoldingTradeRequest)——
  Future<HoldingTransaction> buy({
    required String accountId,
    required String securityId,
    required String? fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  }) {
    return _trade(
      kind: _TradeKind.buy,
      accountId: accountId,
      securityId: securityId,
      fromAccountId: fromAccountId,
      quantity: quantity,
      priceCents: priceCents,
      feeCents: feeCents,
      tradeDate: tradeDate,
      notes: notes,
    );
  }

  Future<HoldingTransaction> sell({
    required String accountId,
    required String securityId,
    required String? fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  }) {
    return _trade(
      kind: _TradeKind.sell,
      accountId: accountId,
      securityId: securityId,
      fromAccountId: fromAccountId,
      quantity: quantity,
      priceCents: priceCents,
      feeCents: feeCents,
      tradeDate: tradeDate,
      notes: notes,
    );
  }

  Future<HoldingTransaction> _trade({
    required _TradeKind kind,
    required String accountId,
    required String securityId,
    required String? fromAccountId,
    required double quantity,
    required int priceCents,
    required int feeCents,
    required String tradeDate,
    String? notes,
  }) {
    return _retry.call(() async {
      final req = pb.HoldingTradeRequest(
        accountId: accountId,
        securityId: securityId,
        quantity: quantity,
        priceCents: Int64(priceCents),
        feeCents: Int64(feeCents),
        tradeDate: tradeDate,
        notes: notes ?? '',
        // 空串 = 不双写(cash asset 来源未选 / dividend & split 无此场景)。
        fromAccountId: fromAccountId ?? '',
      );
      final res = kind == _TradeKind.buy
          ? await _client.buyHolding(req)
          : await _client.sellHolding(req);
      return HoldingMapper.transactionToDomain(res.transaction);
    });
  }

  // —— 公司行动(dividend / split)——
  Future<HoldingTransaction> recordDividend({
    required String accountId,
    required String securityId,
    required double quantity,
    required int cashPerShareCents,
    required int totalAmountCents,
    required String tradeDate,
    String? notes,
  }) async {
    return _retry.call(() async {
      final res = await _client.recordDividend(pb.RecordDividendRequest(
        accountId: accountId,
        securityId: securityId,
        quantity: quantity,
        cashPerShareCents: Int64(cashPerShareCents),
        totalAmountCents: Int64(totalAmountCents),
        tradeDate: tradeDate,
        notes: notes ?? '',
      ));
      return HoldingMapper.transactionToDomain(res.transaction);
    });
  }

  Future<HoldingTransaction> recordSplit({
    required String accountId,
    required String securityId,
    required double ratio,
    required String splitDate,
    String? notes,
  }) async {
    return _retry.call(() async {
      final res = await _client.recordSplit(pb.RecordSplitRequest(
        accountId: accountId,
        securityId: securityId,
        ratio: ratio,
        splitDate: splitDate,
        notes: notes ?? '',
      ));
      return HoldingMapper.transactionToDomain(res.transaction);
    });
  }

  // —— 证券主数据 ——
  Future<Security> createSecurity({
    required String symbol,
    required String name,
    required SecurityType type,
    String? exchange,
    required String currency,
  }) async {
    return _retry.call(() async {
      final res = await _client.createSecurity(pb.CreateSecurityRequest(
        symbol: symbol,
        name: name,
        // ⚠️ off-by-one:按 NAME 映射,domain type 0+ → proto 业务值 1+。
        securityType: HoldingMapper.securityTypeToProto(type),
        exchange: exchange ?? '',
        currencyCode: currency,
      ));
      return HoldingMapper.securityToDomain(res.security);
    });
  }

  Future<List<Security>> listSecurities({SecurityType? type}) async {
    return _retry.call(() async {
      final res = await _client.listSecurities(pb.ListSecuritiesRequest(
        page: common.PageRequest(pageSize: 100),
        securityType:
            type == null ? null : HoldingMapper.securityTypeToProto(type),
      ));
      return res.securities.map(HoldingMapper.securityToDomain).toList();
    });
  }

  Future<List<Security>> searchSecurities(String query) async {
    return _retry.call(() async {
      final res = await _client.searchSecurities(
          pb.SearchSecuritiesRequest(query: query, limit: 50));
      return res.securities.map(HoldingMapper.securityToDomain).toList();
    });
  }

  Future<void> updateSecurityPrice({
    required String id,
    required int priceCents,
  }) async {
    return _retry.call(() async {
      await _client.updateSecurityPrice(pb.UpdatePriceRequest(
        securityId: id,
        priceCents: Int64(priceCents),
      ));
    });
  }

  // —— 价格批量同步(server 拉外部行情,Task 9 新增)——
  /// 触发 server 端批量价格同步(手动刷新)。返回成功更新数 + server 同步时间。
  ///
  /// 不接收参数:server 拉所有已配置行情源的 security 最新价。syncedAt
  /// 为 server 完成同步的时间戳(proto Timestamp),toDateTime() 转 DateTime
  /// (与 HoldingMapper createdAt 转换一致)。
  Future<SyncPricesResult> syncPrices() async {
    return _retry.call(() async {
      final res = await _client.syncPrices(pb.SyncPricesRequest());
      return SyncPricesResult(
        syncedCount: res.syncedCount,
        syncedAt: res.syncedAt.toDateTime(),
      );
    });
  }
}

/// buy/sell 共用 _trade helper 的方向标记(避免重复构造 HoldingTradeRequest)。
enum _TradeKind { buy, sell }
