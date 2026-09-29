import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/r2_budget_overrun.dart';
import 'package:yucai_client/report/domain/report_document.dart';

import '../mda_fixtures.dart';

/// F44 T1:R2 预算超支(FR-2)。
///
/// 任一预算项超支 → warn;超支比例 ≥20% → risk;未超支项不触发;
/// 无预算章节(budget == null)整规则不触发。
/// spec oracle:餐饮 2,850/3,000 未超支不触发;购物 4,120/3,500(118%)
/// → warn(超支但 <20%)。
void main() {
  const rule = R2BudgetOverrun();

  test('spec FR-2 场景:餐饮未超支不触发;购物 4,120/3,500 → warn(超支 17.7% <20%)', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        budget: BudgetSection(items: [
          ReportBudgetItem.create(
              name: '餐饮', actualCents: 285_000, limitCents: 300_000),
          ReportBudgetItem.create(
              name: '购物', actualCents: 412_000, limitCents: 350_000),
        ]),
      ),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'R2');
    expect(findings.single.severity, MdaSeverity.warn);
    // 溯源数字:超支 ¥620.00、使用率 117.7%(手算:620000/3500000=17.71%)。
    expect(findings.single.conclusion, contains('购物'));
    expect(findings.single.conclusion, contains('¥620.00'));
    expect(findings.single.conclusion, contains('117.7%'));
    // 视觉对齐批次(原型 v9 .diag-row 行尾 chip.neg「超支 620.00」)。
    expect(findings.single.chip, isNotNull);
    expect(findings.single.chip!.label, '超支 620.00');
    expect(findings.single.chip!.tone, MdaChipTone.negative);
  });

  test('超支 ≥20% → risk(购物 4,200/3,500 = 超支 20.0%)', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        budget: BudgetSection(items: [
          ReportBudgetItem.create(
              name: '购物', actualCents: 420_000, limitCents: 350_000),
        ]),
      ),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, MdaSeverity.risk);
    expect(findings.single.conclusion, contains('20.0%'));
    expect(findings.single.conclusion, contains('¥700.00'));
  });

  test('边界:超支恰 19.9% → warn 而非 risk', () {
    // 419,650/350,000 cents = 使用率 119.9%(超支 19.9%,严格小于 20%)。
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        budget: BudgetSection(items: [
          ReportBudgetItem.create(
              name: '购物', actualCents: 419_650, limitCents: 350_000),
        ]),
      ),
      mdaSupplement(),
    );

    expect(findings.single.severity, MdaSeverity.warn);
  });

  test('全部未超支 → 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_000_000,
        expenseCents: 800_000,
        budget: BudgetSection(items: [
          ReportBudgetItem.create(
              name: '餐饮', actualCents: 285_000, limitCents: 300_000),
        ]),
      ),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });

  test('budget == null(本期无预算)→ 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });
}
