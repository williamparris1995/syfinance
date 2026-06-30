import 'package:equatable/equatable.dart';

import 'package:yucai_client/holding/domain/value_objects.dart';

abstract class HoldingEvent extends Equatable {
  const HoldingEvent();
  @override
  List<Object?> get props => [];
}

// —— 查询事件 ——

/// 拉取持仓列表。`typeFilter` 非空时仅展示该证券类型(前端 tab 过滤,
/// 因 proto ListHoldings 无 type 参数,实际为前端二次过滤占位)。
class LoadHoldingsRequested extends HoldingEvent {
  const LoadHoldingsRequested({this.typeFilter});
  final SecurityType? typeFilter;
  @override
  List<Object?> get props => [typeFilter];
}

/// 拉取持仓详情 + 交易流水。触发 listHoldingTransactions(⏳ 端点)。
class LoadDetailRequested extends HoldingEvent {
  const LoadDetailRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// 拉取证券主数据列表(表单选择器用)。
class LoadSecuritiesRequested extends HoldingEvent {
  const LoadSecuritiesRequested({this.type});
  final SecurityType? type;
  @override
  List<Object?> get props => [type];
}

/// 搜索证券(表单选择器联想用)。
class SearchSecuritiesRequested extends HoldingEvent {
  const SearchSecuritiesRequested(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

// —— 业务事件 Params ——

/// 买入参数。字段对齐 proto HoldingTradeRequest + repo.buy 签名:
/// fromAccountId = proto field 8,双写资金源(buy = credit 现金-)。
class BuyParams extends Equatable {
  const BuyParams({
    required this.accountId,
    required this.securityId,
    required this.fromAccountId,
    required this.quantity,
    required this.priceCents,
    this.feeCents = 0,
    required this.tradeDate,
    this.notes,
  });
  final String accountId;
  final String securityId;
  final String fromAccountId;
  final double quantity;
  final int priceCents;
  final int feeCents;
  final String tradeDate;
  final String? notes;

  @override
  List<Object?> get props => [
        accountId,
        securityId,
        fromAccountId,
        quantity,
        priceCents,
        feeCents,
        tradeDate,
        notes,
      ];
}

/// 卖出参数。同 BuyParams,fromAccountId 双写 debit 现金+。
class SellParams extends Equatable {
  const SellParams({
    required this.accountId,
    required this.securityId,
    required this.fromAccountId,
    required this.quantity,
    required this.priceCents,
    this.feeCents = 0,
    required this.tradeDate,
    this.notes,
  });
  final String accountId;
  final String securityId;
  final String fromAccountId;
  final double quantity;
  final int priceCents;
  final int feeCents;
  final String tradeDate;
  final String? notes;

  @override
  List<Object?> get props => [
        accountId,
        securityId,
        fromAccountId,
        quantity,
        priceCents,
        feeCents,
        tradeDate,
        notes,
      ];
}

/// 分红参数。对齐 proto RecordDividendRequest(无 incomeAccountId):
/// accountId / securityId / quantity / cashPerShareCents /
/// totalAmountCents / tradeDate / notes。
class DividendParams extends Equatable {
  const DividendParams({
    required this.accountId,
    required this.securityId,
    required this.quantity,
    required this.cashPerShareCents,
    required this.totalAmountCents,
    required this.tradeDate,
    this.notes,
  });
  final String accountId;
  final String securityId;
  final double quantity;
  final int cashPerShareCents;
  final int totalAmountCents;
  final String tradeDate;
  final String? notes;

  @override
  List<Object?> get props => [
        accountId,
        securityId,
        quantity,
        cashPerShareCents,
        totalAmountCents,
        tradeDate,
        notes,
      ];
}

/// 拆股参数。对齐 proto RecordSplitRequest.ratio(单一 double,非 from/to)。
class SplitParams extends Equatable {
  const SplitParams({
    required this.accountId,
    required this.securityId,
    required this.ratio,
    required this.splitDate,
    this.notes,
  });
  final String accountId;
  final String securityId;
  final double ratio;
  final String splitDate;
  final String? notes;

  @override
  List<Object?> get props => [
        accountId,
        securityId,
        ratio,
        splitDate,
        notes,
      ];
}

/// 证券主数据创建参数。
class SecurityParams extends Equatable {
  const SecurityParams({
    required this.symbol,
    required this.name,
    required this.type,
    this.exchange,
    required this.currency,
  });
  final String symbol;
  final String name;
  final SecurityType type;
  final String? exchange;
  final String currency;

  @override
  List<Object?> get props => [symbol, name, type, exchange, currency];
}

// —— 业务事件 ——

class BuyRequested extends HoldingEvent {
  const BuyRequested(this.params);
  final BuyParams params;
  @override
  List<Object?> get props => [params];
}

class SellRequested extends HoldingEvent {
  const SellRequested(this.params);
  final SellParams params;
  @override
  List<Object?> get props => [params];
}

class RecordDividendRequested extends HoldingEvent {
  const RecordDividendRequested(this.params);
  final DividendParams params;
  @override
  List<Object?> get props => [params];
}

class RecordSplitRequested extends HoldingEvent {
  const RecordSplitRequested(this.params);
  final SplitParams params;
  @override
  List<Object?> get props => [params];
}

class CreateSecurityRequested extends HoldingEvent {
  const CreateSecurityRequested(this.params);
  final SecurityParams params;
  @override
  List<Object?> get props => [params];
}

class UpdatePriceRequested extends HoldingEvent {
  const UpdatePriceRequested({required this.id, required this.priceCents});
  final String id;
  final int priceCents;
  @override
  List<Object?> get props => [id, priceCents];
}

/// 手动触发 server 端批量价格同步(持仓页刷新按钮)。
class RefreshPricesRequested extends HoldingEvent {
  const RefreshPricesRequested();
}
