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
}
