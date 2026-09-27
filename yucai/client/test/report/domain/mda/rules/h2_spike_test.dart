import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/h2_spike.dart';

import '../mda_fixtures.dart';

/// F44 T1:H2 环比突增(FR-2 双门槛)。
///
/// 类别环比 +50% 且增加额 ≥ 当期总支出 5%(防小基数)→ warn;
/// 环比口径 = supplement.priorExpense(前期分类构成,T2 喂,
/// ReportDocument 无前期构成故降级至此通道)。
void main() {
  const rule = H2Spike();

  test('购物 5,600 vs 上月 3,000:+86.7% 且增加额占本期支出 13.0% → warn 含双溯源数字', () {
    // 手算:delta=¥2,600=260,000 分;260,000/300,000=86.67% → 86.7%;
    // 260,000/2,000,000(本期总支出 ¥20,000)=13.0%。
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 2_500_000,
        expenseCents: 2_000_000,
        expenseBreakdown: [
          expenseRow('shop', '购物', 560_000, 2_000_000),
          expenseRow('food', '餐饮', 1_440_000, 2_000_000),
        ],
      ),
      mdaSupplement(priorExpense: [
        expenseRow('shop', '购物', 300_000, 1_740_000),
        expenseRow('food', '餐饮', 1_440_000, 1_740_000),
      ]),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'H2');
    expect(findings.single.severity, MdaSeverity.warn);
    expect(findings.single.conclusion, contains('购物'));
    expect(findings.single.conclusion, contains('+86.7%'));
    expect(findings.single.conclusion, contains('¥2,600.00'));
    expect(findings.single.conclusion, contains('13.0%'));
  });

  test('门槛①单边:环比 +43.3%(<50%)→ 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 2_500_000,
        expenseCents: 2_000_000,
        expenseBreakdown: [
          expenseRow('shop', '购物', 430_000, 2_000_000),
          expenseRow('food', '餐饮', 1_570_000, 2_000_000),
        ],
      ),
      mdaSupplement(priorExpense: [
        expenseRow('shop', '购物', 300_000, 1_870_000),
        expenseRow('food', '餐饮', 1_570_000, 1_870_000),
      ]),
    );

    expect(findings, isEmpty);
  });

  test('门槛②单边:+80% 但增加额仅占本期总支出 4%(<5%)→ 不触发(防小基数)', () {
    // delta=¥1,600=160,000 分;160,000/200,000=80%;本期总支出 ¥40,000
    // → 160,000/4,000,000=4% <5%。
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 4_500_000,
        expenseCents: 4_000_000,
        expenseBreakdown: [
          expenseRow('shop', '购物', 360_000, 4_000_000),
          expenseRow('food', '餐饮', 3_640_000, 4_000_000),
        ],
      ),
      mdaSupplement(priorExpense: [
        expenseRow('shop', '购物', 200_000, 3_840_000),
        expenseRow('food', '餐饮', 3_640_000, 3_840_000),
      ]),
    );

    expect(findings, isEmpty);
  });

  test('边界:环比恰 +50.0% 且占 5.0% → 触发(双门槛均含等号)', () {
    // prior ¥2,000 → cur ¥3,000:+50.0%;delta ¥1,000 = 本期总支出
    // ¥20,000 的 5.0%。
    final findings = rule.evaluate(
      mdaDoc(
        incomeCents: 2_500_000,
        expenseCents: 2_000_000,
        expenseBreakdown: [
          expenseRow('shop', '购物', 300_000, 2_000_000),
          expenseRow('food', '餐饮', 1_700_000, 2_000_000),
        ],
      ),
      mdaSupplement(priorExpense: [
        expenseRow('shop', '购物', 200_000, 1_900_000),
        expenseRow('food', '餐饮', 1_700_000, 1_900_000),
      ]),
    );

    expect(findings, hasLength(1));
    expect(findings.single.conclusion, contains('+50.0%'));
    expect(findings.single.conclusion, contains('5.0%'));
  });

  test('前期为 0 的新类别(无基准)与环比下降 → 均不触发', () {
    final newCategory = rule.evaluate(
      mdaDoc(
        incomeCents: 2_500_000,
        expenseCents: 2_000_000,
        expenseBreakdown: [
          expenseRow('pet', '宠物', 400_000, 2_000_000), // 上月无此类别
          expenseRow('food', '餐饮', 1_600_000, 2_000_000),
        ],
      ),
      mdaSupplement(priorExpense: [
        expenseRow('food', '餐饮', 1_600_000, 1_600_000),
      ]),
    );
    final down = rule.evaluate(
      mdaDoc(
        incomeCents: 2_500_000,
        expenseCents: 2_000_000,
        expenseBreakdown: [
          expenseRow('shop', '购物', 150_000, 2_000_000),
          expenseRow('food', '餐饮', 1_850_000, 2_000_000),
        ],
      ),
      mdaSupplement(priorExpense: [
        expenseRow('shop', '购物', 300_000, 2_150_000),
        expenseRow('food', '餐饮', 1_850_000, 2_150_000),
      ]),
    );

    expect(newCategory, isEmpty);
    expect(down, isEmpty);
  });
}
