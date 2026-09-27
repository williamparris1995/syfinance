import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/r6_runway.dart';

import '../mda_fixtures.dart';

/// F44 T1:R6 runway 备用金(FR-2)。
///
/// trailing3m(3 月合计)>0 时:月数 = cashEnd ÷(trailing3m÷3);
/// <1 → risk;<3 → warn;≥3 通过;trailing3m==0 不触发。
/// spec oracle:期末现金 45,200/近 3 月均支出 17,000 → 2.66 个月 → warn
/// 「现金可支撑约 2.7 个月」。
void main() {
  const rule = R6Runway();

  // 近 3 月均支出 ¥17,000/月 → 合计 ¥51,000 = 5_100_000 cents。
  const trailing = 5_100_000;

  test('spec FR-2 场景:现金 45,200 ÷ 月均 17,000 = 2.66 个月 → warn,结论逐字含「现金可支撑约 2.7 个月」', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(trailing3mExpenseCents: trailing, cashEndCents: 4_520_000),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'R6');
    expect(findings.single.severity, MdaSeverity.warn);
    expect(findings.single.conclusion, contains('现金可支撑约 2.7 个月'));
    // 溯源数字:期末现金 ¥45,200.00、月均支出 ¥17,000.00(手算)。
    expect(findings.single.conclusion, contains('¥45,200.00'));
    expect(findings.single.conclusion, contains('¥17,000.00'));
  });

  test('月数 <1 → risk(现金 ¥1,500 ÷ 月均 ¥17,000 = 0.09 个月)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(trailing3mExpenseCents: trailing, cashEndCents: 150_000),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, MdaSeverity.risk);
    expect(findings.single.conclusion, contains('现金可支撑约 0.1 个月'));
  });

  test('月数 ≥3 → 不触发(现金 ¥60,000 ÷ 月均 ¥17,000 = 3.53 个月)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(trailing3mExpenseCents: trailing, cashEndCents: 6_000_000),
    );

    expect(findings, isEmpty);
  });

  test('边界:恰 3.0 个月 → 不触发(warn 线为严格小于)', () {
    // 月均 ¥20,000(trailing ¥60,000)、现金 ¥60,000 → 恰 3.0 个月。
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(trailing3mExpenseCents: 6_000_000, cashEndCents: 6_000_000),
    );

    expect(findings, isEmpty);
  });

  test('trailing3m == 0 → 不触发(无支出基数,无法定义月数)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(trailing3mExpenseCents: 0, cashEndCents: 4_520_000),
    );

    expect(findings, isEmpty);
  });
}
