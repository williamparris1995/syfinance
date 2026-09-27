import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_engine.dart';
import 'package:yucai_client/report/domain/report_document.dart';

import 'mda_fixtures.dart';

/// F44 T1:引擎(FR-1)——全规则遍历 + severity(risk>warn>info)稳定排序
/// (同 severity 保持规则表序 [R1,R6,R2,R3,R4,H1,H2,R5])+ 计数汇总。
void main() {
  const engine = MdaEngine();

  test('多规则同发:risk 在前,同 severity 保持规则表序,info 殿后', () {
    // 触发组合(手算):
    //  R1 risk(储蓄率 4.6%)、R6 warn(2.7 个月)、R2 warn(超支 17.7%)、
    //  R3 warn(55%)、R5 info(单笔 ¥7,000 = 日均 ¥1,000 的 7 倍、占 22.6%)。
    final section = engine.evaluate(
      mdaDoc(
        incomeCents: 3_250_000,
        expenseCents: 3_100_000,
        assetsCents: 1_000_000,
        liabilitiesCents: 550_000,
        budget: BudgetSection(items: [
          ReportBudgetItem.create(
              name: '购物', actualCents: 412_000, limitCents: 350_000),
        ]),
      ),
      mdaSupplement(
        trailing3mExpenseCents: 5_100_000,
        cashEndCents: 4_520_000,
        transactions: [txn('t1', DateTime(2026, 8, 15), '家电', 700_000)],
      ),
    );

    expect(section.findings.map((f) => f.ruleId).toList(),
        ['R1', 'R6', 'R2', 'R3', 'R5']);
    expect(section.riskCount, 1);
    expect(section.warnCount, 3);
    expect(section.infoCount, 1);
  });

  test('规则表序在 risk 内同样生效(R1 与 R2 risk 同发 → R1 在前)', () {
    // R1 risk(透支)+ R2 risk(超支 ≥20%)。
    final section = engine.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 1_200_000,
        budget: BudgetSection(items: [
          ReportBudgetItem.create(
              name: '购物', actualCents: 420_000, limitCents: 350_000),
        ]),
      ),
      mdaSupplement(),
    );

    expect(section.findings.map((f) => f.ruleId).toList(), ['R1', 'R2']);
    expect(section.riskCount, 2);
  });

  test('spec FR-2 场景:投资绩效数据(市值 10,000→12,000/净买入 5,000)不触发任何支出类规则', () {
    final section = engine.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000, // 储蓄率 20% 恰通过
        investment: InvestmentSection.create(
          mvStartCents: 1_000_000,
          mvEndCents: 1_200_000,
          netBuyCents: 500_000,
          twr: null,
        ),
      ),
      mdaSupplement(),
    );

    expect(section.findings, isEmpty);
    expect(section.riskCount, 0);
    expect(section.warnCount, 0);
    expect(section.infoCount, 0);
  });

  test('健康态 + 缺省 supplement(空模板/空交易/零 trailing)→ 零发现', () {
    final section = engine.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 700_000),
      mdaSupplement(),
    );

    expect(section.findings, isEmpty);
    expect(section.riskCount, 0);
    expect(section.warnCount, 0);
    expect(section.infoCount, 0);
  });

  // ---- T3 评审 round 1:健康摘要 runway 经引擎入章节(supplement 单点)----

  test('evaluate 回填 healthyRunwayMonths(cashEnd ÷ trailing3m 月均手算)', () {
    // 手算:4,520,000 ÷ (5,100,000 ÷ 3) = 832,800,000 ÷ 5,100,000
    // ≈ 2.663… → 1 位小数 2.7。
    final section = engine.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 700_000),
      mdaSupplement(trailing3mExpenseCents: 5_100_000, cashEndCents: 4_520_000),
    );
    expect(section.healthyRunwayMonths, 2.7);
  });

  test('evaluate:trailing3m = 0(无基数)→ healthyRunwayMonths null', () {
    final section = engine.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 700_000),
      mdaSupplement(cashEndCents: 4_520_000),
    );
    expect(section.healthyRunwayMonths, isNull);
  });
}
