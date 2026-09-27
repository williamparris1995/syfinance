// T3(F43 R16 sprint-1)—— LocalPerformanceAssembler 区间扩展:
// assemble({rangeStart, rangeEnd}) 的区间分解输出(PeriodPerformance,
// 财务报告 FR-6)+ 缺省参数行为不变护栏。全部为新增用例,不改既有文件。
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/holding/data/local_performance_assembler.dart';

DateTime d(String s) => DateTime.parse('${s}T00:00:00Z');

/// FR-6 主场景 oracle(cents 口径手算):
/// - 07-01 买 10 股@4,277(窗口前建仓,期初 ffill 价);
/// - 08-02 买 10 股@4,777(金额 47,770)、08-15 卖 10 股@4,577(金额 45,770)
///   —— 净买入 = 47,770 − 45,770 = 2,000;
/// - 期末持仓 10 股(20 − 10),ffill 价 4,577(08-15 卖价,≤ 期末最近成交)。
/// 窗口 [08-01, 08-31]:
///   期初市值 = 10 × 4,277 = 42,770;
///   期末市值 = 10 × 4,577 = 45,770;
///   估算收益 = 45,770 − 42,770 − 2,000 = 1,000。
LocalPerformanceAssembler fr6Assembler() => LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 10, 4777)],
      trades: [
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 10, priceCents: 4277,
            amountCents: 42770, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-07-01')),
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 10, priceCents: 4777,
            amountCents: 47770, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-08-02')),
        AssemblerTrade(
            securityId: 'sec1', tradeType: 2, quantity: 10, priceCents: 4577,
            amountCents: 45770, feeCents: 0, realizedPnlCents: 3000,
            tradeDate: d('2026-08-15')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 4577)},
      now: d('2026-09-15'),
    );

void main() {
  test('FR-6 区间分解:期初/期末市值/净买入/估算收益(42,770→45,770 +2,000 → +1,000)', () {
    final p = fr6Assembler()
        .assemble(rangeStart: d('2026-08-01'), rangeEnd: d('2026-08-31'));
    expect(p.period, isNotNull);
    expect(p.period!.beginMvCents, 42770);
    expect(p.period!.endMvCents, 45770);
    expect(p.period!.netBuyCents, 2000);
    expect(p.period!.estimatedGainCents, 1000);
  });

  test('FR-6 区间 TWR:现金流子期链式 ×100 百分比(累计,非年化)', () {
    final p = fr6Assembler()
        .assemble(rangeStart: d('2026-08-01'), rangeEnd: d('2026-08-31'));
    expect(p.period!.twrPct, isNotNull);
    // 手算链(ffill 价:两笔成交把窗口切成两个现金流子期 + 尾段):
    // 子期1 08-01→08-02(买前):10 股×4,777 / 开盘 10 股×4,277;
    // 子期2 08-02(买后 20 股×4,777=95,540)→08-15(卖前 20 股×4,577=91,540);
    // 尾段 08-15(卖后 45,770)→ 期末(10 股×4,577=45,770)。
    const want = ((47770 / 42770) * (91540 / 95540) * (45770 / 45770) - 1) * 100;
    expect(p.period!.twrPct!, closeTo(want, 0.001));
  });

  test('期内无买卖市值不变 → TWR=0、估算收益 0', () {
    // 窗口 [08-01, 08-31] 无任何成交:期初=期末=10 股×4,277,ffill 价不变。
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 10, 4277)],
      trades: [
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 10, priceCents: 4277,
            amountCents: 42770, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-07-01')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 4577)},
      now: d('2026-09-15'),
    );
    final p = a.assemble(rangeStart: d('2026-08-01'), rangeEnd: d('2026-08-31'));
    expect(p.period!.beginMvCents, 42770);
    expect(p.period!.endMvCents, 42770);
    expect(p.period!.netBuyCents, 0);
    expect(p.period!.estimatedGainCents, 0);
    expect(p.period!.twrPct, 0.0);
  });

  test('期初市值为 0(窗口内首建仓)→ 区间 TWR 按约定报 0', () {
    // 窗口起点无持仓 → 期初 MV=0。窗内 08-05 买 10@4,000、08-20 买 1@5,000:
    // 若按清仓重建(gap-restart)口径链式会得 +25%(50,000/40,000),但区间
    // TWR 以期初市值为基期 —— 0 基期收益率无定义,按报告口径约定报 0。
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 11, 4090)],
      trades: [
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 10, priceCents: 4000,
            amountCents: 40000, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-08-05')),
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 1, priceCents: 5000,
            amountCents: 5000, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-08-20')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 5000)},
      now: d('2026-09-15'),
    );
    final p = a.assemble(rangeStart: d('2026-08-01'), rangeEnd: d('2026-08-31'));
    expect(p.period!.beginMvCents, 0);
    expect(p.period!.endMvCents, 55000); // 11 股 × 5,000
    expect(p.period!.netBuyCents, 45000);
    expect(p.period!.estimatedGainCents, 10000); // 55,000 − 0 − 45,000
    expect(p.period!.twrPct, 0.0); // 约定口径:0 基期 → 0(非 gap-restart 的 25%)
  });

  test('只有期末之后的成交/价格数据不影响区间锚定 [start, end]', () {
    // 07-01 买 10@4,277(窗前);09-10(期末后)再买 5@9,999 —— 窗口
    // [08-01, 08-31] 的期初/期末/净买入/TWR 必须与「无 09-10 数据」一致:
    // 期末 ffill 只取 ≤ end 的成交,期末后的高价不渗入区间。
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 15, 4591)],
      trades: [
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 10, priceCents: 4277,
            amountCents: 42770, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-07-01')),
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 5, priceCents: 9999,
            amountCents: 49995, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-09-10')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 9999)},
      now: d('2026-09-15'),
    );
    final p = a.assemble(rangeStart: d('2026-08-01'), rangeEnd: d('2026-08-31'));
    expect(p.period!.beginMvCents, 42770);
    expect(p.period!.endMvCents, 42770); // 10 股 × 4,277(9,999 价被锚定排除)
    expect(p.period!.netBuyCents, 0);
    expect(p.period!.estimatedGainCents, 0);
    expect(p.period!.twrPct, 0.0);
  });

  test('FR-6 负值估算收益(spec.md:54 逐字):期初 10000→期末 12000、净买入 5000 → −3000', () {
    // T2 补测(T3 评审 Minor MISSING)。手算 oracle(双证券,金额单位 cents):
    // - 07-01(窗前)买 sec1 10 股@1,000 → 期初市值 = 10 × 1,000 = 10,000;
    // - 窗内 08-05 买 sec2 6.4 股@1,000(金额 6,400)、08-25 卖 sec1 2 股@700
    //   (金额 1,400)→ 净买入 = 6,400 − 1,400 = 5,000;
    // - 期末:sec1 余 8 股 × ffill 700 = 5,600 + sec2 6.4 股 × 1,000 = 6,400
    //   → 期末市值 12,000;
    // - 估算收益 = 12,000 − 10,000 − 5,000 = **−3,000**(下跌市加仓,负值)。
    final a = LocalPerformanceAssembler(
      holdings: const [
        AssemblerHolding('sec1', 8, 1000),
        AssemblerHolding('sec2', 6.4, 1000),
      ],
      trades: [
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 10, priceCents: 1000,
            amountCents: 10000, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-07-01')),
        AssemblerTrade(
            securityId: 'sec2', tradeType: 1, quantity: 6.4, priceCents: 1000,
            amountCents: 6400, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2026-08-05')),
        AssemblerTrade(
            securityId: 'sec1', tradeType: 2, quantity: 2, priceCents: 700,
            amountCents: 1400, feeCents: 0, realizedPnlCents: -600,
            tradeDate: d('2026-08-25')),
      ],
      securities: const {
        'sec1': AssemblerSecurity('sec1', 700),
        'sec2': AssemblerSecurity('sec2', 1000),
      },
      now: d('2026-09-15'),
    );
    final p = a.assemble(rangeStart: d('2026-08-01'), rangeEnd: d('2026-08-31'));
    expect(p.period!.beginMvCents, 10000);
    expect(p.period!.endMvCents, 12000);
    expect(p.period!.netBuyCents, 5000);
    // spec 钉死负值:估算收益 −3,000,不为 0、不为正。
    expect(p.period!.estimatedGainCents, -3000);
    // 方向一致:亏钱窗口 TWR 必为负(链式精确值已由本文件其他用例钉死)。
    expect(p.period!.twrPct, isNotNull);
    expect(p.period!.twrPct!, lessThan(0));
  });

  test('缺省 rangeStart/rangeEnd:输出与旧签名一致,period 恒为 null', () {
    // 与既有 assemble 用例同款 fixture(100 股@成本 100 → 现价 120)做
    // 等价断言:无参调用的关键输出仍是旧口径手算值。
    final a = LocalPerformanceAssembler(
      holdings: const [AssemblerHolding('sec1', 100, 10000)],
      trades: [
        AssemblerTrade(
            securityId: 'sec1', tradeType: 1, quantity: 100, priceCents: 10000,
            amountCents: 1000000, feeCents: 0, realizedPnlCents: 0,
            tradeDate: d('2025-09-01')),
      ],
      securities: const {'sec1': AssemblerSecurity('sec1', 12000)},
      now: d('2026-09-01'),
    );
    final p = a.assemble();
    expect(p.period, isNull); // 旧调用形态不产区间分解
    expect(p.realizedCents, 0);
    expect(p.unrealizedCents, 200000);
    expect(p.totalPct, closeTo(20.0, 0.001));
    // 显式传 null 与缺省逐位相同(Equatable 全字段等价)。
    expect(a.assemble(rangeStart: null, rangeEnd: null), p);
    // rangeStart-only(既有 range 字符串调用形态的 assembler 路径):
    // period 仍 null,且 rangeEnd 显式 null 与不传等价。用 FR-6 fixture
    // (rangeStart 后仍有窗内现金流日 → 旧区间 TWR 照常产出非 null)。
    final b = fr6Assembler();
    final q1 = b.assemble(rangeStart: d('2026-08-05'));
    final q2 = b.assemble(rangeStart: d('2026-08-05'), rangeEnd: null);
    expect(q1.period, isNull);
    expect(q1, q2);
    expect(q1.rangeTwrAnnualizedPct, isNotNull); // 旧区间输出仍照常产出
  });
}
