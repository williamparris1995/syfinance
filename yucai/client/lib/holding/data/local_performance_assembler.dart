/// 本地收益装配(R7-D,holding 域离线引擎):drift 行组(持仓/台账/证券
/// 现价)→ PortfolioPerformance(全期 + 区间口径)。F43 T3(R16 财务报告
/// FR-6)扩展区间分解:期初/期末市值(成交价 ffill 回放)、当期净买入、
/// 估算收益与区间 TWR —— 供 ReportAssemblyService 投资绩效章节消费。
library;

import 'dart:math' as math;

import 'package:yucai_client/holding/domain/entities/period_performance.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart' show PerfPoint;
import 'package:yucai_client/holding/domain/return_engine/twr.dart' as twr;
import 'package:yucai_client/holding/domain/return_engine/xirr.dart' as xirr;

/// 本地收益装配(R7-D FR-2/FR-4):从 drift 行组装配 PortfolioPerformance。
/// 口径(spec grill #1):TWR/曲线用**成交价前向填充**(本地无市场价序列);
/// 终值 = Σ qty×(现价>0?现价:avgCost)(无价回退成本,与列表页同语义)。
/// offlineScope=true:调用方(UI)据此展示「离线口径·按成交价」标注。

class AssemblerSecurity {
  const AssemblerSecurity(this.id, this.currentPriceCents);
  final String id;
  final int currentPriceCents;
}

class AssemblerHolding {
  const AssemblerHolding(this.securityId, this.quantity, this.avgCostCents);
  final String securityId;
  final double quantity;
  final int avgCostCents;
}

class AssemblerTrade {
  const AssemblerTrade({
    required this.securityId,
    required this.tradeType, // 1 buy / 2 sell / 3 split / 4 dividend(server 枚举对齐)
    required this.quantity,
    required this.priceCents,
    required this.amountCents,
    required this.feeCents,
    required this.realizedPnlCents,
    required this.tradeDate,
  });
  final String securityId;
  final int tradeType;
  final double quantity;
  final int priceCents;
  final int amountCents;
  final int feeCents;
  final int realizedPnlCents;
  final DateTime tradeDate;
}

class LocalPerformanceAssembler {
  const LocalPerformanceAssembler({
    required this.holdings,
    required this.trades,
    required this.securities,
    required this.now,
  });

  final List<AssemblerHolding> holdings;
  final List<AssemblerTrade> trades;
  final Map<String, AssemblerSecurity> securities;
  final DateTime now;

  static const int typeBuy = 1, typeSell = 2, typeSplit = 3, typeDividend = 4;

  DateTime get _today => DateTime(now.year, now.month, now.day);

  // ---- 价格/数量重建 ----

  int _priceOf(String securityId, DateTime at) {
    // 成交价 ffill:≤ at 最近成交价;无则现价;再无 0(坏价哨兵)。
    int? best;
    DateTime? bestDate;
    for (final t in trades) {
      if (t.securityId != securityId || t.tradeType == typeSplit) continue;
      final d = DateTime(t.tradeDate.year, t.tradeDate.month, t.tradeDate.day);
      if (!d.isAfter(at) && (bestDate == null || d.isAfter(bestDate))) {
        bestDate = d;
        best = t.priceCents;
      }
    }
    return best ?? securities[securityId]?.currentPriceCents ?? 0;
  }

  double _qtyAt(String securityId, DateTime date) {
    // G QtyAtDate 语义:严格 tradeDate < date。
    var qty = 0.0;
    for (final t in trades) {
      if (t.securityId != securityId) continue;
      final d = DateTime(t.tradeDate.year, t.tradeDate.month, t.tradeDate.day);
      if (!d.isBefore(date)) continue;
      switch (t.tradeType) {
        case typeBuy:
          qty += t.quantity;
        case typeSell:
          qty -= t.quantity;
        case typeSplit:
          qty *= t.quantity;
        case typeDividend:
          break;
      }
    }
    return qty;
  }

  /// 组合 MV(cents);-1 = 坏价哨兵(有持仓无价格)。
  double _mvAt(DateTime date) => _mvAsOf(date, date);

  /// qty 与 price 分离 as-of 的组合 MV(G computeTWR 的 AsOf 语义:
  /// BV_after(day) = qty@(day+1) × price@day —— before/after 同价不同量)。
  double _mvAsOf(DateTime qtyDate, DateTime priceDate) {
    var mv = 0.0;
    for (final h in holdings) {
      final qty = _qtyAt(h.securityId, qtyDate);
      if (qty == 0) continue;
      final price = _priceOf(h.securityId, priceDate);
      if (price == 0) return -1;
      mv += qty * price;
    }
    return mv;
  }

  double get _terminalMV {
    var mv = 0.0;
    for (final h in holdings) {
      final sec = securities[h.securityId];
      final price = (sec != null && sec.currentPriceCents > 0)
          ? sec.currentPriceCents
          : h.avgCostCents;
      mv += h.quantity * price;
    }
    return mv;
  }

  // ---- 装配 ----

  PortfolioPerformance assemble({DateTime? rangeStart, DateTime? rangeEnd}) {
    final today = _today;
    final first = _firstTradeDay();
    final start = rangeStart ?? first ?? today;

    // foot
    var realized = 0;
    for (final t in trades) {
      if (t.tradeType == typeSell) realized += t.realizedPnlCents;
      if (t.tradeType == typeDividend) realized += t.amountCents;
    }
    final costBasis = holdings.fold<int>(
        0, (s, h) => s + (h.quantity * h.avgCostCents).round());
    final terminal = _terminalMV;
    final unrealized = (terminal - costBasis).round();
    final total = realized + unrealized;
    final totalPct = costBasis > 0 ? total / costBasis * 100 : 0.0;

    // XIRR:全期
    final fullXirr = xirr.xirr([..._cashFlows(null), xirr.CashFlow(now, terminal)]);
    // XIRR:区间(期初 MV 流出 + 窗内现金流 + 终值)
    double? rangeXirr;
    if (rangeStart != null) {
      final open = _mvAt(rangeStart);
      if (open >= 0) {
        rangeXirr = xirr.xirr([
          xirr.CashFlow(rangeStart, -open),
          ..._cashFlows(rangeStart),
          xirr.CashFlow(now, terminal),
        ]);
      }
    }

    // TWR:GIPS 三态分段
    final fullTwr = _segmentedTwr(start, today, terminal);
    final rangeTwr =
        rangeStart == null ? fullTwr : _segmentedTwr(rangeStart, today, terminal);

    // CAGR(简单口径:成本/期初 → 终值)
    final fullCagr = _simpleCagr(costBasis.toDouble(), terminal, first, today);
    double? rangeCagr;
    if (rangeStart != null) {
      final open = _mvAt(rangeStart);
      if (open > 0) rangeCagr = _simpleCagr(open, terminal, rangeStart, today);
    }

    // 区间分解(FR-6,T3):仅 rangeStart+rangeEnd 同时给定时计算;缺省或
    // 半缺省 → period=null,既有输出逐位不变(rangeEnd 仅驱动该 VO,不改
    // 既有 range* 字段的 now 锚定口径)。
    PeriodPerformance? period;
    if (rangeStart != null && rangeEnd != null) {
      period = _periodDecomposition(rangeStart, rangeEnd);
    }

    return PortfolioPerformance(
      portfolioPoints: _curvePoints(start, today, terminal),
      benchmarkPoints: const [],
      benchmarkName: '',
      realizedCents: realized,
      unrealizedCents: unrealized,
      totalCents: total,
      annualizedPct: fullXirr == null ? null : fullXirr * 100,
      rangeAnnualizedPct: rangeXirr == null ? null : rangeXirr * 100,
      twrAnnualizedPct: fullTwr == null ? null : fullTwr * 100,
      rangeTwrAnnualizedPct: rangeTwr == null ? null : rangeTwr * 100,
      cagrAnnualizedPct: fullCagr == null ? null : fullCagr * 100,
      rangeCagrAnnualizedPct: rangeCagr == null ? null : rangeCagr * 100,
      totalPct: totalPct,
      currency: 'CNY',
      offlineScope: true,
      period: period,
    );
  }

  /// FR-6 区间分解:期初/期末市值、当期净买入、估算收益(、区间 TWR)。
  /// 锚定语义(复用 _qtyAt/_priceOf 回放,单源):
  /// - 期初 = qty 严格早于 start × ffill 价 ≤ start(_mvAt 语义,与
  ///   rangeXirr 的 open 同锚 —— 窗口前已建仓计入,窗口日成交不计);
  /// - 期末 = qty 含 end 日成交 × ffill 价 ≤ end(after 语义:末日交易属
  ///   窗内,市值计入);
  /// - 净买入 = 窗内 [start,end] 买卖**金额**差(费用/分红/拆股不计)。
  /// 坏价(-1 哨兵)→ 整体 null 降级(UI 显「—」,不产半截口径)。
  PeriodPerformance? _periodDecomposition(
      DateTime rangeStart, DateTime rangeEnd) {
    final startDay =
        DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
    final endDay = DateTime(rangeEnd.year, rangeEnd.month, rangeEnd.day);
    final beginMv = _mvAt(startDay);
    final endMv =
        _mvAsOf(endDay.add(const Duration(days: 1)), endDay);
    if (beginMv < 0 || endMv < 0) return null;

    var netBuy = 0;
    for (final t in trades) {
      final day = DateTime(t.tradeDate.year, t.tradeDate.month, t.tradeDate.day);
      if (day.isBefore(startDay) || day.isAfter(endDay)) continue;
      if (t.tradeType == typeBuy) netBuy += t.amountCents;
      if (t.tradeType == typeSell) netBuy -= t.amountCents;
    }

    // 区间 TWR(累计,×100):复用 _chainedTwr 现金流链 —— ffill 口径下
    // 价格仅在成交日变动,「按日粒度市值链」与现金流日子期链等价(相邻
    // 成交日间市值无变化),故不另建日循环。
    double? twrPct;
    if (beginMv == 0) {
      // 期初市值为 0(窗口起点无持仓/空仓):0 基期收益率无数学定义,
      // FR-6 报告口径**约定报 0** —— 不走 gap-restart 重建链(该口径把
      // 窗内新建仓的涨幅算进区间,与「期初起链」定义不符),UI 显示 0
      // 而非「—」,估算收益仍由 gain 分解如实呈现。
      twrPct = 0;
    } else if (_cashFlowDays(startDay, endDay).isEmpty) {
      // 窗内无现金流日:单期 TWR = 期末/期初 − 1(与 _chainedTwr 的
      // 「单尾因子段」同口径;其 days 空早退 null 的路径保留给既有
      // range 语义,不改 _segmentedTwr 行为)。
      twrPct = (endMv / beginMv - 1) * 100;
    } else {
      final chained = _chainedTwr(startDay, endDay, endMv);
      twrPct = chained == null ? null : chained.cum * 100;
    }

    return PeriodPerformance(
      beginMvCents: beginMv.round(),
      endMvCents: endMv.round(),
      netBuyCents: netBuy,
      estimatedGainCents: (endMv - beginMv - netBuy).round(),
      twrPct: twrPct,
    );
  }

  List<xirr.CashFlow> _cashFlows(DateTime? rangeStart) {
    final out = <xirr.CashFlow>[];
    for (final t in trades) {
      // 本地日归一再比(防 UTC 存量与本地 rangeStart 混比丢日,J2)。
      final day = DateTime(t.tradeDate.year, t.tradeDate.month, t.tradeDate.day);
      if (rangeStart != null && day.isBefore(rangeStart)) continue;
      switch (t.tradeType) {
        case typeBuy:
          out.add(xirr.CashFlow(
              t.tradeDate, -(t.amountCents + t.feeCents).toDouble()));
        case typeSell:
          out.add(xirr.CashFlow(
              t.tradeDate, (t.amountCents - t.feeCents).toDouble()));
        case typeDividend:
          out.add(xirr.CashFlow(t.tradeDate, t.amountCents.toDouble()));
        case typeSplit:
          break;
      }
    }
    return out;
  }

  /// GIPS 三态分段(镜像 G computeTWR):中间清仓跳段重启;终态纯清仓
  /// 链终止(不乘 0);qty>0 但无价(坏价)→ 整体 null 降级。
  double? _segmentedTwr(DateTime start, DateTime today, double terminalMV) {
    final chained = _chainedTwr(start, today, terminalMV);
    if (chained == null) return null;
    return twr.annualizeTwr(
        chained.cum, chained.totalDays < 1 ? 0 : chained.totalDays);
  }

  /// 分段链核(_segmentedTwr 的累计值 + 段天数):期初起链、现金流日子期
  /// 链接、终段收尾。T3 起由 _segmentedTwr(年化)与区间分解(累计
  /// twrPct)共用 —— 链式 TWR 单源,不得复制重写。
  ({double cum, int totalDays})? _chainedTwr(
      DateTime start, DateTime today, double terminalMV) {
    // 日算术统一本地日(测试/存量的 UTC 输入与本地 today 混比会差一天)。
    final startDay = DateTime(start.year, start.month, start.day);
    // 有意分歧(G 超集):锚点后无现金流日时本实现仍算单期 TWR(终值/开盘,
    // 经济上正确),Go computeTWR 因 effectiveDays 空而返 nil。
    final days = _cashFlowDays(startDay, today);
    if (days.isEmpty) return null;

    var chain = 1.0;
    var any = false;
    var totalDays = 0; // GIPS:gap 不计收益天数(G computeTWR 同口径,累加各段)
    final subs = <twr.SubPeriodReturn>[];

    // 开盘 = BV_after(start)(Go computeTWR 同锚:full 时 start=首个现金流日,
    // range 时 start=rangeStart —— 窗口开盘前已建仓的仓位计入期初)。
    var segBeginAfter = _mvAsOf(startDay.add(const Duration(days: 1)), startDay);
    if (segBeginAfter < 0) return null;
    DateTime segStart = startDay;

    for (final day in days) {
      if (!day.isAfter(startDay)) continue; // 全期:首现金流日即 start,自身不产 sub
      final before = _mvAsOf(day, day);
      final after = _mvAsOf(day.add(const Duration(days: 1)), day);
      if (before < 0 || after < 0) return null; // 坏价降级

      if (segBeginAfter == 0) {
        // gap:等重建(trade 后 MV>0 的首个现金流日)。
        if (after > 0) {
          segBeginAfter = after;
          segStart = day;
        }
        continue;
      }
      subs.add(twr.SubPeriodReturn(segBeginAfter, before));
      if (after == 0) {
        // 当日完全清仓 → 闭段(终止:尾因子=1);段天数累加、gap 不计。
        final cum = twr.cumulativeTwr(subs, before, before);
        if (cum == null) return null;
        chain *= 1 + cum;
        any = true;
        totalDays += day.difference(segStart).inDays;
        subs.clear();
        segBeginAfter = 0;
      } else {
        segBeginAfter = after;
      }
    }
    if (segBeginAfter > 0) {
      // 终值零守卫(G 同语义:qty>0 而终值 0 = 数据矛盾 → 降级 null)。
      if (terminalMV == 0) return null;
      // 开段收尾:尾因子 = 终值/最后 after;段天数累加。
      // 重建后无中间现金流日 → 单尾因子段(G 同语义:final/lastAfter − 1)。
      final cum = subs.isEmpty
          ? (terminalMV / segBeginAfter - 1)
          : twr.cumulativeTwr(subs, terminalMV, segBeginAfter);
      if (cum == null) return null;
      chain *= 1 + cum;
      any = true;
      totalDays += today.difference(segStart).inDays;
    }
    if (!any) return null;
    return (cum: chain - 1, totalDays: totalDays);
  }

  List<DateTime> _cashFlowDays(DateTime start, DateTime today) {
    final seen = <String>{};
    final days = <DateTime>[];
    for (final t in trades) {
      if (t.tradeType == typeSplit) continue;
      final d = DateTime(t.tradeDate.year, t.tradeDate.month, t.tradeDate.day);
      if (d.isBefore(start) || d.isAfter(today)) continue;
      if (seen.add('${d.year}-${d.month}-${d.day}')) days.add(d);
    }
    days.sort();
    return days;
  }

  DateTime? _firstTradeDay() {
    DateTime? first;
    for (final t in trades) {
      if (t.tradeType == typeSplit) continue;
      final d = DateTime(t.tradeDate.year, t.tradeDate.month, t.tradeDate.day);
      if (first == null || d.isBefore(first)) first = d;
    }
    return first;
  }

  double? _simpleCagr(double begin, double end, DateTime? startDay, DateTime today) {
    if (begin <= 0 || startDay == null) return null;
    final days = today.difference(startDay).inDays;
    if (days < 1) return end / begin - 1;
    return math.pow(end / begin, 365.0 / days).toDouble() - 1;
  }

  List<PerfPoint> _curvePoints(DateTime start, DateTime today, double terminalMV) {
    final pts = <PerfPoint>[];
    for (final d in _cashFlowDays(start, today)) {
      final mv = _mvAt(d.add(const Duration(days: 1)));
      if (mv >= 0) pts.add(PerfPoint(time: d, value: mv / 100));
    }
    if (terminalMV >= 0) pts.add(PerfPoint(time: today, value: terminalMV / 100));
    return pts;
  }
}
