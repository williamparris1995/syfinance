import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/holding/data/local_performance_assembler.dart';

DateTime d(String s) => DateTime.parse('${s}T00:00:00Z');

void main() {
  test('单笔持有:costBasis/unrealized/totalPct/XIRR 手算 oracle', () {
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 100, 10000)], // 100 股@成本 100
      trades: [
        AssemblerTrade(
          securityId: 'sec1', tradeType: 1, quantity: 100, priceCents: 10000,
          amountCents: 1000000, feeCents: 0, realizedPnlCents: 0,
          tradeDate: d('2025-09-01'),
        ),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 12000)}, // 现价 120
      now: d('2026-09-01'), // 恰 365 天
    );
    final p = a.assemble();
    expect(p.offlineScope, isTrue);
    expect(p.realizedCents, 0);
    expect(p.unrealizedCents, 200000); // (120−100)×100 股 ×100 分
    expect(p.totalPct, closeTo(20.0, 0.001));
    // XIRR:−1,000,000(365 天前)→ +1,200,000 = 20%/年
    expect(p.annualizedPct, isNotNull);
    expect(p.annualizedPct!, closeTo(20.0, 0.5));
    // CAGR 同口径
    expect(p.cagrAnnualizedPct, isNotNull);
    expect(p.cagrAnnualizedPct!, closeTo(20.0, 0.5));
  });

  test('清仓重建 TWR(G e2e oracle:链乘 1.21,段天数 10+30=40)', () {
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 50, 20000)],
      trades: [
        AssemblerTrade(securityId: 'sec1', tradeType: 1, quantity: 100, priceCents: 10000,
            amountCents: 1000000, feeCents: 0, realizedPnlCents: 0, tradeDate: d('2026-07-01')),
        AssemblerTrade(securityId: 'sec1', tradeType: 2, quantity: 100, priceCents: 11000,
            amountCents: 1100000, feeCents: 0, realizedPnlCents: 100000, tradeDate: d('2026-07-11')),
        AssemblerTrade(securityId: 'sec1', tradeType: 1, quantity: 50, priceCents: 20000,
            amountCents: 1000000, feeCents: 0, realizedPnlCents: 0, tradeDate: d('2026-08-10')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 22000)},
      now: d('2026-09-09'), // 重建后 30 天
    );
    final p = a.assemble();
    expect(p.realizedCents, 100000);
    expect(p.twrAnnualizedPct, isNotNull);
    final want = (math.pow(1.21, 365.0 / 40.0) - 1) * 100;
    expect(p.twrAnnualizedPct!, closeTo(want, 0.5));
  });

  test('gap 起点(rangeStart 在清仓 gap 内)→ 链从重建日起', () {
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 50, 20000)],
      trades: [
        AssemblerTrade(securityId: 'sec1', tradeType: 1, quantity: 100, priceCents: 10000,
            amountCents: 1000000, feeCents: 0, realizedPnlCents: 0, tradeDate: d('2026-07-01')),
        AssemblerTrade(securityId: 'sec1', tradeType: 2, quantity: 100, priceCents: 11000,
            amountCents: 1100000, feeCents: 0, realizedPnlCents: 100000, tradeDate: d('2026-07-11')),
        AssemblerTrade(securityId: 'sec1', tradeType: 1, quantity: 50, priceCents: 20000,
            amountCents: 1000000, feeCents: 0, realizedPnlCents: 0, tradeDate: d('2026-08-10')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 22000)},
      now: d('2026-09-09'),
    );
    // rangeStart=07-21(gap 中)→ 重建段 1.1,30 天年化
    final p = a.assemble(rangeStart: d('2026-07-21'));
    expect(p.rangeTwrAnnualizedPct, isNotNull);
    final want = (math.pow(1.10, 365.0 / 30.0) - 1) * 100;
    expect(p.rangeTwrAnnualizedPct!, closeTo(want, 0.5));
  });

  test('曲线:现金流日+今日 BV 点(元);split 不产点', () {
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 100, 10000)],
      trades: [
        AssemblerTrade(securityId: 'sec1', tradeType: 1, quantity: 100, priceCents: 10000,
            amountCents: 1000000, feeCents: 0, realizedPnlCents: 0, tradeDate: d('2026-08-01')),
        AssemblerTrade(securityId: 'sec1', tradeType: 3, quantity: 2, priceCents: 0,
            amountCents: 0, feeCents: 0, realizedPnlCents: 0, tradeDate: d('2026-08-05')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 11000)},
      now: d('2026-08-10'),
    );
    final p = a.assemble();
    expect(p.portfolioPoints.length, 2); // 08-01 BV 点 + 今日 11000 点(split 无点)
    expect(p.portfolioPoints.first.value, 10000.0); // 100 股@100 = 10,000 元
    expect(p.portfolioPoints.last.value, 110 * 100.0); // 现价 110×100 股(元)
  });
}
