// Portfolio / 单持仓 收益曲线 + 盈亏明细 entity(Task 12,holding-C)。
//
// 对齐 server holding.proto PortfolioPerformanceResponse /
// HoldingPerformanceResponse。复用 presentation/widgets/perf_curve_chart.dart
// 已定型的 PerfPoint(纯数据:DateTime + double value)—— 务实 import,避免
// 双份定义;若需更干净的 layering 可后续把 PerfPoint 提取到 domain
// (见 plan Task 12 Step 1 注)。
//
// 复用方:Task 13 PerformanceBloc / HoldingBloc 将曲线 points + foot 喂给
// PerfCurveChart(以及 holding_detail_page 的 _costBasisCurve)。
import 'package:equatable/equatable.dart';

import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart'
    show PerfPoint;

/// 组合收益曲线 + 盈亏明细(对应 GetPortfolioPerformance RPC)。
///
/// [portfolioPoints] 组合 CNY 市值曲线;[benchmarkPoints] 可选基准(如 CSI300)
/// 曲线,[benchmarkName] 基准名(无基准时为空串)。foot 三项 + 年化/总收益 %。
/// currency 默认 'CNY'(server 端折算)。
class PortfolioPerformance extends Equatable {
  const PortfolioPerformance({
    this.portfolioPoints = const [],
    this.benchmarkPoints = const [],
    this.benchmarkName = '',
    required this.realizedCents,
    required this.unrealizedCents,
    required this.totalCents,
    this.annualizedPct, // double?(全期 XIRR 资金加权,null=降级)
    this.rangeAnnualizedPct, // double?(区间 XIRR 资金加权)
    this.twrAnnualizedPct, // double?(全期 TWR 时间加权,null=降级)
    this.rangeTwrAnnualizedPct, // double?(区间 TWR 时间加权,null=降级/区间不足)
    this.totalPct = 0,
    this.currency = 'CNY',
  });

  final List<PerfPoint> portfolioPoints;
  final List<PerfPoint> benchmarkPoints;
  final String benchmarkName;
  final int realizedCents;
  final int unrealizedCents;
  final int totalCents;
  final double? annualizedPct;
  final double? rangeAnnualizedPct;
  /// 全期 TWR(时间加权年化)。null=server 未算/数据不足 → UI 显「—」。
  /// 与 [annualizedPct](XIRR 资金加权)并列,提供双维度收益视角。
  final double? twrAnnualizedPct;
  /// 区间 TWR(时间加权年化,随 CurveRange)。null=server 未算/区间不足 →
  /// UI 不渲染区间副标注。与 [twrAnnualizedPct](全期 TWR)并列,镜像
  /// [rangeAnnualizedPct](区间 XIRR)的区间维度。
  final double? rangeTwrAnnualizedPct;
  final double totalPct;
  final String currency;

  @override
  List<Object?> get props => [
        portfolioPoints,
        benchmarkPoints,
        benchmarkName,
        realizedCents,
        unrealizedCents,
        totalCents,
        annualizedPct,
        rangeAnnualizedPct,
        twrAnnualizedPct,
        rangeTwrAnnualizedPct,
        totalPct,
        currency,
      ];
}

/// 单持仓收益曲线 + 盈亏明细(对应 GetHoldingPerformance RPC)。
///
/// [pricePoints] 该持仓的价格曲线;foot 三项(realized/unrealized/total cents)。
/// currency 默认 'CNY'。
class HoldingPerformance extends Equatable {
  const HoldingPerformance({
    this.pricePoints = const [],
    required this.realizedCents,
    required this.unrealizedCents,
    required this.totalCents,
    this.annualizedPct, // double?(全期 XIRR 原币 资金加权)
    this.rangeAnnualizedPct, // double?(区间 XIRR 原币 资金加权)
    this.twrAnnualizedPct, // double?(全期 TWR 原币 时间加权)
    this.currency = 'CNY',
  });

  final List<PerfPoint> pricePoints;
  final int realizedCents;
  final int unrealizedCents;
  final int totalCents;
  final double? annualizedPct;
  final double? rangeAnnualizedPct;
  /// 全期 TWR(时间加权年化,原币)。null=server 未算/数据不足 → UI 显「—」。
  /// 与 [annualizedPct](XIRR 资金加权)并列,提供双维度收益视角。
  final double? twrAnnualizedPct;
  final String currency;

  @override
  List<Object?> get props => [
        pricePoints,
        realizedCents,
        unrealizedCents,
        totalCents,
        annualizedPct,
        rangeAnnualizedPct,
        twrAnnualizedPct,
        currency,
      ];
}
