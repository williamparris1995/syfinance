import 'package:equatable/equatable.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';

/// 持仓汇总(对齐 proto HoldingDTO)。
///
/// proto DTO 仅含核心字段;currentPriceCents / pnlPct / securityType / currency
/// 为前端展示补充(可空):Task 3 mapper 从关联 Security 填 currentPriceCents /
/// securityType / currency,pnlPct 由前端按 avgCostCents 与当前价计算。
class Holding extends Equatable {
  const Holding({
    required this.id,
    required this.accountId,
    required this.securityId,
    required this.securityName,
    required this.securitySymbol,
    required this.quantity,
    required this.avgCostCents,
    required this.marketValueCents,
    required this.unrealizedPnlCents,
    required this.version,
    this.currentPriceCents,
    this.pnlPct,
    this.securityType,
    this.currency,
  });

  final String id;
  final String accountId; // 关联投资账户
  final String securityId;
  final String securityName; // 冗余自 Security,展示快查
  final String securitySymbol; // 冗余自 Security,展示快查
  final double quantity; // 持有份额 / 股数
  final int avgCostCents; // 加权平均成本(每单位,分)
  final int marketValueCents; // 当前市值(分)
  final int unrealizedPnlCents; // 未实现盈亏(分)
  final int version;

  // —— 前端展示补充(proto DTO 无,mapper / 前端填充)——
  final int? currentPriceCents; // 来自关联 Security.currentPriceCents
  final double? pnlPct; // 前端按 (price-avgCost)/avgCost 计算
  final SecurityType? securityType; // 来自关联 Security
  final String? currency; // 来自关联 Security

  @override
  List<Object?> get props => [id, version];
}

/// 证券主数据(对齐 proto SecurityDTO)。
class Security extends Equatable {
  const Security({
    required this.id,
    required this.symbol,
    required this.name,
    required this.securityType,
    this.exchange,
    required this.currency,
    required this.currentPriceCents,
    this.createdAt,
  });

  final String id;
  final String symbol; // 股票代码(如 600519 / AAPL)
  final String name; // 证券名称
  final SecurityType securityType;
  final String? exchange; // 交易所(可空)
  final String currency; // ISO 4217 货币码
  final int currentPriceCents; // 最新价(分)
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id];
}

/// 持仓交易流水(对齐 proto HoldingTransactionDTO)。
///
/// tradeDate 为服务端返回的日期字符串(ISO yyyy-MM-dd);与 createdAt(Timestamp)
/// 区分:tradeDate 是用户声明的交易日,createdAt 是记录创建时间。
class HoldingTransaction extends Equatable {
  const HoldingTransaction({
    required this.id,
    required this.accountId,
    required this.securityId,
    required this.tradeType,
    required this.quantity,
    required this.priceCents,
    required this.amountCents,
    required this.feeCents,
    required this.tradeDate,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String accountId;
  final String securityId;
  final TradeType tradeType;
  final double quantity;
  final int priceCents; // 单位价(分);dividend 时为 cashPerShareCents
  final int amountCents; // 交易总额(分)
  final int feeCents; // 手续费(分)
  final String tradeDate; // ISO 日期串
  final String? notes;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id];
}

/// 投资目标关联卡(纯前端展示模型,非 proto DTO)。
///
/// ⚠️ holding.proto **无** goal RPC / DTO —— goal 数据源待定(⏳),Task 10 空态用。
/// 此模型仅用于详情页"关联目标"卡片展示,字段由前端聚合 goal + holding 数据计算。
class GoalLink extends Equatable {
  const GoalLink({
    required this.goalId,
    required this.name,
    required this.backingHoldingId,
    required this.targetCents,
    required this.currentMarketValueCents,
    this.pnlPct,
    required this.status,
  });

  final String goalId;
  final String name; // 目标名称
  final String backingHoldingId; // 该 goal 由哪个 holding 背书
  final int targetCents; // 目标金额(分)
  final int currentMarketValueCents; // 当前 backing holding 市值(分)
  final double? pnlPct; // 该 holding 的盈亏百分比(可空)
  final String status; // 目标状态(英文 key,如 on_track / behind)

  @override
  List<Object?> get props => [goalId];
}

/// SyncPrices RPC 结果(client 用)。对齐 proto SyncPricesResponse。
///
/// syncPrices 触发 server 端批量价格同步(手动刷新),返回成功更新的
/// security 数 + server 完成同步的时间。Task 9 新增,Task 10 bloc 用。
class SyncPricesResult extends Equatable {
  const SyncPricesResult({required this.syncedCount, required this.syncedAt});

  final int syncedCount; // 成功更新的 security 数
  final DateTime syncedAt; // server 同步时间(proto Timestamp → DateTime)

  @override
  List<Object?> get props => [syncedCount, syncedAt];
}
