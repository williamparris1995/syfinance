import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';

/// F44 T1:MD&A 模型 —— Severity/Finding/Section 汇总 factory。
void main() {
  test('MdaSection.create 汇总三级计数且保持入参顺序(排序责任在引擎)', () {
    final findings = [
      const MdaFinding(
        ruleId: 'R1',
        severity: MdaSeverity.risk,
        conclusion: 'c1',
        advice: 'a1',
      ),
      const MdaFinding(
        ruleId: 'R6',
        severity: MdaSeverity.warn,
        conclusion: 'c2',
        advice: 'a2',
        actionLink: '/accounts/subscriptions',
      ),
      const MdaFinding(
        ruleId: 'H1',
        severity: MdaSeverity.warn,
        conclusion: 'c3',
        advice: 'a3',
      ),
      const MdaFinding(
        ruleId: 'R5',
        severity: MdaSeverity.info,
        conclusion: 'c4',
        advice: 'a4',
      ),
    ];
    final section = MdaSection.create(findings: findings);

    expect(section.riskCount, 1);
    expect(section.warnCount, 2);
    expect(section.infoCount, 1);
    expect(section.findings, same(findings));
  });

  test('MdaSection.create 空发现 → 三级计数全 0(健康态)', () {
    final section = MdaSection.create(findings: const []);

    expect(section.riskCount, 0);
    expect(section.warnCount, 0);
    expect(section.infoCount, 0);
    expect(section.findings, isEmpty);
  });

  // ---- T3 评审 round 1:健康摘要 runway 字段 + 单点纯函数 ----

  test('MdaSection.create 带 healthyRunwayMonths:1 位小数收口;缺省 null', () {
    // 手算:1238.25 → mdaRound1 → 1238.3(渲染层零计算,构造期收口)。
    final section =
        MdaSection.create(findings: const [], healthyRunwayMonths: 1238.25);
    expect(section.healthyRunwayMonths, 1238.3);

    expect(MdaSection.create(findings: const []).healthyRunwayMonths, isNull);
  });

  test('runwayMonths 纯函数:cashEnd ÷ 月均;trailing3m ≤ 0 → null(R6 同口径)',
      () {
    // 手算:25,000 ÷ (30,000 ÷ 3) = 2.5。
    expect(
      runwayMonths(cashEndCents: 25000, trailing3mExpenseCents: 30000),
      2.5,
    );
    // 无基数(近 3 月零支出)→ null(不除零)。
    expect(
      runwayMonths(cashEndCents: 25000, trailing3mExpenseCents: 0),
      isNull,
    );
    expect(
      runwayMonths(cashEndCents: 25000, trailing3mExpenseCents: -100),
      isNull,
    );
  });
}
