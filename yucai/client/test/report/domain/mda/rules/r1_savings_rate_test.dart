import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/r1_savings_rate.dart';

import '../mda_fixtures.dart';

/// F44 T1:R1 储蓄率分层(FR-2)。
///
/// 结余为负 → risk「本期透支」;<10% → risk;10-20% → warn;≥20% 通过;
/// 收入 ≤ 0 不触发(储蓄率无定义)。期望值全部手算。
void main() {
  const rule = R1SavingsRate();

  test('负结余 → risk,结论文案含「本期透支」与溯源金额', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 1_200_000),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'R1');
    expect(findings.single.severity, MdaSeverity.risk);
    expect(findings.single.conclusion, contains('本期透支'));
    // 溯源数字:结余 -¥2,000.00(手算:100 万 -120 万分 = -20 万分)。
    expect(findings.single.conclusion, contains('-¥2,000.00'));
  });

  test('spec FR-2 场景:收入 32,500/支出 31,000(储蓄率 4.6%)→ risk,结论逐字含「储蓄率 4.6%,低于 10%」', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 3_250_000, expenseCents: 3_100_000),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, MdaSeverity.risk);
    expect(findings.single.conclusion, contains('储蓄率 4.6%,低于 10%'));
    // 溯源数字:结余 ¥1,500.00 / 收入 ¥32,500.00(手算)。
    expect(findings.single.conclusion, contains('¥1,500.00'));
    expect(findings.single.conclusion, contains('¥32,500.00'));
  });

  test('储蓄率 15% → warn(10-20% 区间)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 850_000),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, MdaSeverity.warn);
    expect(findings.single.conclusion, contains('储蓄率 15.0%'));
    expect(findings.single.conclusion, contains('低于 20%'));
  });

  test('边界:储蓄率恰 10.0% → warn 而非 risk(risk 线为严格小于)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 900_000),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, MdaSeverity.warn);
  });

  test('边界:储蓄率恰 20.0% → 不触发(≥20% 通过)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });

  test('高储蓄率(30%)→ 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 700_000),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });

  test('收入 ≤ 0 → 不触发(储蓄率无定义,即使支出为正)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 0, expenseCents: 500_000),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });
}
