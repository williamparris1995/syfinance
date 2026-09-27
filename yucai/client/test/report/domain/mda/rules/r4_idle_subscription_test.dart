import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/rules/r4_idle_subscription.dart';

import '../mda_fixtures.dart';

/// F44 T1:R4 闲置订阅近似口径(FR-3,四道防御)。
///
/// 触发:expense 且 !paused 且期内有应扣日且(从未记账 或 最近记账
/// 早于期内首个应扣日−1 天);grace:nextDate 在期末后 7 天内不报;
/// 文案疑问式 + 多条合计月度等价;actionLink 跳订阅中心
/// /accounts/subscriptions(router.dart 实际路由)。
/// 报告期固定 2026-08(期末 08-31 23:59:59)。
void main() {
  const rule = R4IdleSubscription();

  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  test('未暂停年付模板(期内有应扣日,从未记账)→ warn,疑问式文案含月度等价与 actionLink', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-video',
          name: '视频会员',
          amountCents: 120_000, // ¥1,200.00/年 → 月度等价 ¥100.00
          nextDate: d(2027, 8, 15),
          expectedDates: [d(2026, 8, 15)],
        ),
      ]),
    );

    expect(findings, hasLength(1));
    expect(findings.single.ruleId, 'R4');
    expect(findings.single.severity, MdaSeverity.warn);
    // 四道防御①:疑问式文案(禁断言)。
    expect(findings.single.conclusion, contains('可能闲置'));
    expect(findings.single.conclusion, contains('若仍在使用,记一笔时请关联该订阅'));
    // 溯源数字:¥1,200 年付 ÷ 12 = 月度等价 ¥100.00(手算)。
    expect(findings.single.conclusion, contains('¥100.00'));
    expect(findings.single.conclusion, contains('视频会员'));
    // 四道防御④:actionLink 跳订阅中心(router 实际路由)。
    expect(findings.single.actionLink, '/accounts/subscriptions');
  });

  test('多条闲置 → 合计月度等价(年付 ¥1,200 + 月付 ¥85 → ¥185.00/月)', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-video',
          name: '视频会员',
          amountCents: 120_000,
          nextDate: d(2027, 8, 15),
          expectedDates: [d(2026, 8, 15)],
        ),
        expenseTemplate(
          id: 't-cloud',
          name: '云盘',
          amountCents: 8_500, // ¥85.00/月
          nextDate: d(2026, 9, 20), // 期末后 20 天,超出 grace
          expectedDates: [d(2026, 8, 20)],
        ),
      ]),
    );

    expect(findings, hasLength(1));
    expect(findings.single.conclusion, contains('视频会员'));
    expect(findings.single.conclusion, contains('云盘'));
    // 手算:120,000÷12 + 8,500÷1 = 18,500 cents = ¥185.00。
    expect(findings.single.conclusion, contains('¥185.00'));
  });

  test('grace:nextDate 在期末后 3 天内 → 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-cloud',
          name: '云盘',
          amountCents: 8_500,
          nextDate: d(2026, 9, 3), // 期末 08-31 后 3 天,7 天宽限内
          expectedDates: [d(2026, 8, 1)],
        ),
      ]),
    );

    expect(findings, isEmpty);
  });

  test('已推进:最近记账日 == 期内首个应扣日 → 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-cloud',
          name: '云盘',
          amountCents: 8_500,
          nextDate: d(2026, 9, 20),
          lastRecordedDate: d(2026, 8, 20), // == 应扣日
          expectedDates: [d(2026, 8, 20)],
        ),
      ]),
    );

    expect(findings, isEmpty);
  });

  test('已推进(宽一天):最近记账日 == 应扣日前 1 天 → 不触发;前 2 天 → 触发', () {
    final slack = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-cloud',
          name: '云盘',
          amountCents: 8_500,
          nextDate: d(2026, 9, 20),
          lastRecordedDate: d(2026, 8, 19), // 应扣日 08-20 − 1 天
          expectedDates: [d(2026, 8, 20)],
        ),
      ]),
    );
    final stale = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-cloud',
          name: '云盘',
          amountCents: 8_500,
          nextDate: d(2026, 9, 20),
          lastRecordedDate: d(2026, 8, 18), // 应扣日 − 2 天,推进不足
          expectedDates: [d(2026, 8, 20)],
        ),
      ]),
    );

    expect(slack, isEmpty);
    expect(stale, hasLength(1));
  });

  test('非触发输入:paused 模板 / income 方向 / 期内无应扣日 → 均不触发', () {
    final paused = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-paused',
          name: '已暂停订阅',
          amountCents: 8_500,
          paused: true,
          nextDate: d(2026, 9, 20),
          expectedDates: [d(2026, 8, 20)],
        ),
      ]),
    );
    final income = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        TemplateRowVO(
          id: 't-salary',
          name: '工资',
          expense: false, // income 方向
          amountCents: 500_000,
          paused: false,
          autoRecord: false,
          nextDate: d(2026, 9, 20),
          lastRecordedDate: null,
          expectedDates: [d(2026, 8, 20)],
        ),
      ]),
    );
    final noExpected = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(templates: [
        expenseTemplate(
          id: 't-none',
          name: '期内无应扣日',
          amountCents: 8_500,
          nextDate: d(2026, 9, 20),
          expectedDates: const [], // 8 月无应扣日
        ),
      ]),
    );

    expect(paused, isEmpty);
    expect(income, isEmpty);
    expect(noExpected, isEmpty);
  });

  test('空模板列表(缺省 supplement)→ 不触发', () {
    final findings = rule.evaluate(
      mdaDoc(incomeCents: 1_000_000, expenseCents: 800_000),
      mdaSupplement(),
    );

    expect(findings, isEmpty);
  });
}
