import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/r3_debt_ratio.dart';

import '../mda_fixtures.dart';

/// F44 T1:R3 资产负债率(FR-2)。
///
/// debtRatioPct(期末负债/期末资产,既有字段):≥70% → risk;50-70% → warn
/// (结论文案带房贷语境「若含长期房贷属常见区间」);<50% 通过;
/// 资产合计 ≤0(率无定义)不触发。
void main() {
  const rule = R3DebtRatio();

  test('26.9% → 不触发(<50%)', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        assetsCents: 1_000_000,
        liabilitiesCents: 269_000,
      ),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });

  test('55% → warn,结论含房贷语境「若含长期房贷属常见区间」与溯源数字', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        assetsCents: 1_000_000,
        liabilitiesCents: 550_000,
      ),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'R3');
    expect(findings.single.severity, MdaSeverity.warn);
    expect(findings.single.conclusion, contains('55.0%'));
    expect(findings.single.conclusion, contains('若含长期房贷属常见区间'));
    // 溯源数字:负债 ¥5,500.00 / 资产 ¥10,000.00(手算)。
    expect(findings.single.conclusion, contains('¥5,500.00'));
    expect(findings.single.conclusion, contains('¥10,000.00'));
  });

  test('75% → risk(≥70%)', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        assetsCents: 1_000_000,
        liabilitiesCents: 750_000,
      ),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, MdaSeverity.risk);
    expect(findings.single.conclusion, contains('75.0%'));
  });

  test('边界:恰 50.0% → warn 而非通过;恰 69.9% → warn 而非 risk', () {
    final at50 = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        assetsCents: 1_000_000,
        liabilitiesCents: 500_000,
      ),
      mdaSupplement(),
    );
    final at699 = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        assetsCents: 1_000_000,
        liabilitiesCents: 699_000,
      ),
      mdaSupplement(),
    );

    expect(at50.single.severity, MdaSeverity.warn);
    expect(at699.single.severity, MdaSeverity.warn);
  });

  test('资产合计 ≤0(debtRatioPct == null)→ 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });
}
