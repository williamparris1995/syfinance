import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/h1_concentration.dart';

import '../mda_fixtures.dart';

/// F44 T1:H1 支出集中度(FR-2)。
///
/// 支出构成首条(汇编已按金额降序)占比 ≥40% → warn,中性表述
/// 「支出集中于 XX 类别」(不用恩格尔标签);<40% 或空构成不触发。
void main() {
  const rule = H1Concentration();

  test('首条占比 45.2% ≥40% → warn,中性表述「支出集中于」+ 溯源数字', () {
    // 手算:餐饮 4,700/总 10,400 = 45.19% → 45.2%(1 位小数)。
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_500_000,
        expenseCents: 1_040_000,
        expenseBreakdown: [
          expenseRow('food', '餐饮', 470_000, 1_040_000),
          expenseRow('shop', '购物', 3_000_000 ~/ 10, 1_040_000),
          expenseRow('other', '其他', 2_700_000 ~/ 10, 1_040_000),
        ],
      ),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'H1');
    expect(findings.single.severity, MdaSeverity.warn);
    expect(findings.single.conclusion, contains('支出集中于「餐饮」类别'));
    expect(findings.single.conclusion, contains('45.2%'));
    expect(findings.single.conclusion, contains('¥4,700.00'));
  });

  test('首条占比恰 40.0% → warn(≥ 含边界)', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_500_000,
        expenseCents: 1_000_000,
        expenseBreakdown: [
          expenseRow('food', '餐饮', 400_000, 1_000_000),
          expenseRow('shop', '购物', 600_000, 1_000_000),
        ],
      ),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.severity, MdaSeverity.warn);
  });

  test('首条占比 39.9% → 不触发(严格小于)', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_500_000,
        expenseCents: 1_000_000,
        expenseBreakdown: [
          expenseRow('food', '餐饮', 399_000, 1_000_000),
          expenseRow('shop', '购物', 601_000, 1_000_000),
        ],
      ),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });

  test('空支出构成 → 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_500_000, expenseCents: 0),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });

  test('name 为 null 的类别 → 结论回退用 category 代码', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 1_500_000,
        expenseCents: 1_000_000,
        expenseBreakdown: [
          expenseRow('food', null, 500_000, 1_000_000),
          expenseRow('shop', '购物', 500_000, 1_000_000),
        ],
      ),
      mdaSupplement(),
    );

    expect(findings, hasLength(1));
    expect(findings.single.conclusion, contains('food'));
  });
}
