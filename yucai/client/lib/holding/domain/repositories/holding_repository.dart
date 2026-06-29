import 'package:dartz/dartz.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

/// 持仓仓储抽象(对齐 holding.proto HoldingService,10 个 RPC)。
///
/// 签名以 proto 真契约为准(非 plan 原文),关键对齐点:
/// - buy / sell 含 fromAccountId(proto HoldingTradeRequest.from_account_id field 8,
///   双写资金源:buy=credit 现金−,sell=debit 现金+)。
/// - recordDividend **无** incomeAccountId,proto RecordDividendRequest 仅
///   account_id / security_id / quantity / cash_per_share_cents /
///   total_amount_cents / trade_date / notes。
/// - recordSplit 用单一 ratio double(proto RecordSplitRequest.ratio),
///   非 ratioFrom/ratioTo 整数对。
/// - recordDividend / recordSplit 含 accountId(proto field 1)。
///
/// holding.proto **无** goal RPC / DTO → 本接口不含 goal 方法
/// (goal 数据源待定 ⏳,Task 10 空态用;GoalLink 为纯前端展示模型)。
abstract class HoldingRepository {
  // —— 查询 ——
  Future<Either<Failure, List<Holding>>> listHoldings({String? accountId});
  Future<Either<Failure, List<HoldingTransaction>>> listHoldingTransactions({
    String? accountId,
    String? securityId,
  });

  // —— 交易(buy / sell 共用 HoldingTradeRequest)——
  Future<Either<Failure, HoldingTransaction>> buy({
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  });
  Future<Either<Failure, HoldingTransaction>> sell({
    required String accountId,
    required String securityId,
    required String fromAccountId,
    required double quantity,
    required int priceCents,
    int feeCents = 0,
    required String tradeDate,
    String? notes,
  });

  // —— 公司行动(dividend / split)——
  Future<Either<Failure, HoldingTransaction>> recordDividend({
    required String accountId,
    required String securityId,
    required double quantity,
    required int cashPerShareCents,
    required int totalAmountCents,
    required String tradeDate,
    String? notes,
  });
  Future<Either<Failure, HoldingTransaction>> recordSplit({
    required String accountId,
    required String securityId,
    required double ratio,
    required String splitDate,
    String? notes,
  });

  // —— 证券主数据 ——
  Future<Either<Failure, Security>> createSecurity({
    required String symbol,
    required String name,
    required SecurityType type,
    String? exchange,
    required String currency,
  });
  Future<Either<Failure, List<Security>>> listSecurities({SecurityType? type});
  Future<Either<Failure, List<Security>>> searchSecurities(String query);
  Future<Either<Failure, void>> updateSecurityPrice({
    required String id,
    required int priceCents,
  });
}
