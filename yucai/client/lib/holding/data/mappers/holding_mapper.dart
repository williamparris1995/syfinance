import 'package:flutter/foundation.dart';

import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart'
    show PerfPoint;
import 'package:yucai_client/proto/holding/v1/holding.pb.dart' as pb;

/// Maps generated proto HoldingDTO / SecurityDTO / HoldingTransactionDTO ↔
/// domain entities.
///
/// ⚠️ **off-by-one — 按符号 NAME switch,绝不按 int 强转。**
///
/// proto SecurityType / TradeType 各有一个 UNSPECIFIED=0 占位,业务值从 1
/// 起;domain 枚举无占位,业务值从 0 起。直接按 index 转换会让 proto STOCK=1
/// 错位成 domain fund=1,UNSPECIFIED=0 错位成 domain stock=0。因此显式按符号
/// NAME 映射(参照 debt domain DebtType / AmortizationMethod 同款处理)。
///
/// UNSPECIFIED 折叠:
/// - SecurityType.UNSPECIFIED → SecurityType.other(catch-all,未知证券归类)。
/// - TradeType.UNSPECIFIED → TradeType.buy(最常见的交易动作默认值)。
class HoldingMapper {
  HoldingMapper._();

  // —— toDomain ——

  /// HoldingDTO → Holding。proto DTO 仅含 10 个核心字段;前端展示补充字段
  /// (currentPriceCents / pnlPct / securityType / currency)proto DTO 无 →
  /// 全部设 null。UI 层从关联 Security 填 currentPriceCents / securityType /
  /// currency,pnlPct 由前端按 (price - avgCost) / avgCost 计算。
  static Holding toDomain(pb.HoldingDTO dto) {
    return Holding(
      id: dto.id,
      accountId: dto.accountId,
      securityId: dto.securityId,
      securityName: dto.securityName,
      securitySymbol: dto.securitySymbol,
      quantity: dto.quantity,
      avgCostCents: dto.avgCostCents.toInt(),
      marketValueCents: dto.marketValueCents.toInt(),
      unrealizedPnlCents: dto.unrealizedPnlCents.toInt(),
      version: dto.version.toInt(),
      // proto HoldingDTO 无以下字段 → null(UI 层从关联 Security / 前端计算填)。
      currentPriceCents: null,
      pnlPct: null,
      securityType: null,
      currency: null,
    );
  }

  /// SecurityDTO → Security。currency_code(proto)→ currency(domain)。
  static Security securityToDomain(pb.SecurityDTO dto) {
    return Security(
      id: dto.id,
      symbol: dto.symbol,
      name: dto.name,
      securityType: securityTypeFromProto(dto.securityType),
      exchange: dto.exchange,
      currency: dto.currencyCode,
      currentPriceCents: dto.currentPriceCents.toInt(),
      createdAt: dto.hasCreatedAt() ? dto.createdAt.toDateTime() : null,
    );
  }

  /// HoldingTransactionDTO → HoldingTransaction。
  /// tradeDate 为 ISO 日期串(直传,不解析);tradeType 经 tradeTypeFromProto。
  static HoldingTransaction transactionToDomain(
      pb.HoldingTransactionDTO dto) {
    return HoldingTransaction(
      id: dto.id,
      accountId: dto.accountId,
      securityId: dto.securityId,
      tradeType: tradeTypeFromProto(dto.tradeType),
      quantity: dto.quantity,
      priceCents: dto.priceCents.toInt(),
      amountCents: dto.amountCents.toInt(),
      feeCents: dto.feeCents.toInt(),
      tradeDate: dto.tradeDate,
      notes: dto.notes,
      createdAt: dto.hasCreatedAt() ? dto.createdAt.toDateTime() : null,
    );
  }

  // —— SecurityType NAME 映射 ——

  /// proto SecurityType → domain SecurityType。
  ///
  /// ⚠️ off-by-one:proto UNSPECIFIED=0 / STOCK=1 / ... / OTHER=7,而 domain
  /// 索引为 stock=0 / ... / other=6。按符号 NAME switch,绝不按 int 强转。
  /// UNSPECIFIED 折叠为 other(未知证券的 catch-all)。
  static SecurityType securityTypeFromProto(pb.SecurityType t) {
    switch (t) {
      case pb.SecurityType.SECURITY_TYPE_STOCK:
        return SecurityType.stock;
      case pb.SecurityType.SECURITY_TYPE_FUND:
        return SecurityType.fund;
      case pb.SecurityType.SECURITY_TYPE_ETF:
        return SecurityType.etf;
      case pb.SecurityType.SECURITY_TYPE_BOND:
        return SecurityType.bond;
      case pb.SecurityType.SECURITY_TYPE_GOLD:
        return SecurityType.gold;
      case pb.SecurityType.SECURITY_TYPE_OPTION:
        return SecurityType.option;
      case pb.SecurityType.SECURITY_TYPE_OTHER:
        return SecurityType.other;
      case pb.SecurityType.SECURITY_TYPE_UNSPECIFIED:
      default:
        // UNSPECIFIED 折叠为 other(未知证券归类)。
        return SecurityType.other;
    }
  }

  /// domain SecurityType → proto SecurityType。securityTypeFromProto 的逆映射
  /// (UNSPECIFIED 在正向不可达,故为部分逆)。
  static pb.SecurityType securityTypeToProto(SecurityType t) {
    switch (t) {
      case SecurityType.stock:
        return pb.SecurityType.SECURITY_TYPE_STOCK;
      case SecurityType.fund:
        return pb.SecurityType.SECURITY_TYPE_FUND;
      case SecurityType.etf:
        return pb.SecurityType.SECURITY_TYPE_ETF;
      case SecurityType.bond:
        return pb.SecurityType.SECURITY_TYPE_BOND;
      case SecurityType.gold:
        return pb.SecurityType.SECURITY_TYPE_GOLD;
      case SecurityType.option:
        return pb.SecurityType.SECURITY_TYPE_OPTION;
      case SecurityType.other:
        return pb.SecurityType.SECURITY_TYPE_OTHER;
    }
  }

  // —— TradeType NAME 映射 ——

  /// proto TradeType → domain TradeType。
  ///
  /// ⚠️ off-by-one:proto UNSPECIFIED=0 / BUY=1 / SELL=2 / DIVIDEND=3 / SPLIT=4,
  /// 而 domain 索引为 buy=0 / sell=1 / dividend=2 / split=3。按符号 NAME switch。
  /// UNSPECIFIED 折叠为 buy(最常见交易动作默认值)。
  static TradeType tradeTypeFromProto(pb.TradeType t) {
    switch (t) {
      case pb.TradeType.TRADE_TYPE_BUY:
        return TradeType.buy;
      case pb.TradeType.TRADE_TYPE_SELL:
        return TradeType.sell;
      case pb.TradeType.TRADE_TYPE_DIVIDEND:
        return TradeType.dividend;
      case pb.TradeType.TRADE_TYPE_SPLIT:
        return TradeType.split;
      case pb.TradeType.TRADE_TYPE_UNSPECIFIED:
      default:
        // UNSPECIFIED 折叠为 buy(常见默认交易动作)。
        // ⚠️ 后端未正确填充/新交易类型/后端 bug 会落入此分支 — 记日志让
        // 异常可观测,避免本应是 sell/dividend/split 的交易被误显示为 buy
        // 而误导已实现盈亏判断。映射行为不变(仍 → buy)。
        debugPrint('[HOLDING] tradeTypeFromProto 收到 UNSPECIFIED TradeType'
            '(后端未填充或新类型?),默认 buy');
        return TradeType.buy;
    }
  }

  /// domain TradeType → proto TradeType。tradeTypeFromProto 的逆映射
  /// (UNSPECIFIED 在正向不可达,故为部分逆)。
  static pb.TradeType tradeTypeToProto(TradeType t) {
    switch (t) {
      case TradeType.buy:
        return pb.TradeType.TRADE_TYPE_BUY;
      case TradeType.sell:
        return pb.TradeType.TRADE_TYPE_SELL;
      case TradeType.dividend:
        return pb.TradeType.TRADE_TYPE_DIVIDEND;
      case TradeType.split:
        return pb.TradeType.TRADE_TYPE_SPLIT;
    }
  }
}

// —— 收益曲线(Task 12,holding-C)——
// 顶层函数(非 HoldingMapper 静态方法):与 plan 一致,且收益曲线映射是独立
// 关注点(不涉及 SecurityType/TradeType off-by-one),单独成组更清晰。

/// CurvePoint → PerfPoint。proto Timestamp → DateTime 用 toDateTime()
/// (protobuf 6.x 扩展,与 HoldingMapper createdAt / syncPrices syncedAt 一致)。
PerfPoint curvePointToPerfPoint(pb.CurvePoint cp) =>
    PerfPoint(time: cp.time.toDateTime(), value: cp.value);

/// PortfolioPerformanceResponse → PortfolioPerformance。
/// realized/unrealized/total cents 为 proto Int64 → domain int(.toInt(),
/// 与 HoldingMapper avgCostCents.toInt() 同款,避免 Int64→int 类型错位)。
PortfolioPerformance portfolioResponseToEntity(
        pb.PortfolioPerformanceResponse r) =>
    PortfolioPerformance(
      portfolioPoints: r.portfolioPoints.map(curvePointToPerfPoint).toList(),
      benchmarkPoints: r.benchmarkPoints.map(curvePointToPerfPoint).toList(),
      benchmarkName: r.benchmarkName,
      realizedCents: r.realizedCents.toInt(),
      unrealizedCents: r.unrealizedCents.toInt(),
      totalCents: r.totalCents.toInt(),
      annualizedPct: r.hasAnnualizedPct() ? r.annualizedPct : null,
      rangeAnnualizedPct: r.hasRangeAnnualizedPct() ? r.rangeAnnualizedPct : null,
      twrAnnualizedPct: r.hasTwrAnnualizedPct() ? r.twrAnnualizedPct : null,
      rangeTwrAnnualizedPct:
          r.hasRangeTwrAnnualizedPct() ? r.rangeTwrAnnualizedPct : null,
      cagrAnnualizedPct: r.hasCagrAnnualizedPct() ? r.cagrAnnualizedPct : null,
      rangeCagrAnnualizedPct:
          r.hasRangeCagrAnnualizedPct() ? r.rangeCagrAnnualizedPct : null,
      totalPct: r.totalPct,
      currency: r.currency,
    );

/// HoldingPerformanceResponse → HoldingPerformance。
HoldingPerformance holdingResponseToEntity(pb.HoldingPerformanceResponse r) =>
    HoldingPerformance(
      pricePoints: r.pricePoints.map(curvePointToPerfPoint).toList(),
      realizedCents: r.realizedCents.toInt(),
      unrealizedCents: r.unrealizedCents.toInt(),
      totalCents: r.totalCents.toInt(),
      annualizedPct: r.hasAnnualizedPct() ? r.annualizedPct : null,
      rangeAnnualizedPct: r.hasRangeAnnualizedPct() ? r.rangeAnnualizedPct : null,
      twrAnnualizedPct: r.hasTwrAnnualizedPct() ? r.twrAnnualizedPct : null,
      cagrAnnualizedPct: r.hasCagrAnnualizedPct() ? r.cagrAnnualizedPct : null,
      rangeCagrAnnualizedPct:
          r.hasRangeCagrAnnualizedPct() ? r.rangeCagrAnnualizedPct : null,
      currency: r.currency,
    );

/// 区间字符串 → proto CurveRange。UI 层以 'DAY'/'MONTH'/'YEAR'(对齐
/// PerfRange.day/month/year)传入;未知值折叠为 DAY(最细粒度默认)。
/// UNSPECIFIED 在正向不可达(server 不接受 0)。
pb.CurveRange curveRangeToProto(String range) {
  switch (range) {
    case 'MONTH':
      return pb.CurveRange.CURVE_RANGE_MONTH;
    case 'YEAR':
      return pb.CurveRange.CURVE_RANGE_YEAR;
    default:
      return pb.CurveRange.CURVE_RANGE_DAY;
  }
}
