import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/recurrence/recurrence_rule.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule_text.dart';

void main() {
  final cases = <(String, String, RecurrenceRule)>[
    (
      'custom days=1 → 每天',
      '每天',
      const RecurrenceRule(cycle: RecurrenceCycle.custom, cycleDays: 1),
    ),
    (
      'custom days=30 → 每 30 天',
      '每 30 天',
      const RecurrenceRule(cycle: RecurrenceCycle.custom, cycleDays: 30),
    ),
    (
      'weekly 全周掩码 → 每天',
      '每天',
      const RecurrenceRule(
          cycle: RecurrenceCycle.weekly, weekdayMask: RecurrenceRule.maskAll),
    ),
    (
      'weekly 工作日掩码',
      '工作日(周一至周五)',
      const RecurrenceRule(
          cycle: RecurrenceCycle.weekly,
          weekdayMask: RecurrenceRule.maskWeekdays),
    ),
    (
      'weekly 无掩码',
      '每周',
      const RecurrenceRule(cycle: RecurrenceCycle.weekly),
    ),
    (
      'weekly 单星期',
      '每周一',
      const RecurrenceRule(
          cycle: RecurrenceCycle.weekly, weekdayMask: 1 << 0),
    ),
    (
      'weekly 多星期',
      '每周一、周五',
      const RecurrenceRule(
          cycle: RecurrenceCycle.weekly, weekdayMask: (1 << 0) | (1 << 4)),
    ),
    (
      'weekly 多星期 interval 2',
      '每 2 周的周一、周五',
      const RecurrenceRule(
          cycle: RecurrenceCycle.weekly,
          interval: 2,
          weekdayMask: (1 << 0) | (1 << 4)),
    ),
    (
      'weekly 无掩码 interval 2',
      '每 2 周',
      const RecurrenceRule(cycle: RecurrenceCycle.weekly, interval: 2),
    ),
    (
      'monthly 裸',
      '每月',
      const RecurrenceRule(cycle: RecurrenceCycle.monthly),
    ),
    (
      'monthly 15 日',
      '每月 15 日',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly, billingDay: 15),
    ),
    (
      'monthly 月末',
      '每月末',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly, billingDay: 31),
    ),
    (
      'monthly interval 3 月末',
      '每 3 个月的月末',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly, interval: 3, billingDay: 31),
    ),
    (
      'monthly interval 3 15 日',
      '每 3 个月的 15 日',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly, interval: 3, billingDay: 15),
    ),
    (
      'monthly interval 3 裸',
      '每 3 个月',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly, interval: 3),
    ),
    (
      'monthly 第 2 个周二',
      '每月第 2 个周二',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly,
          monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
          nth: 2,
          weekdayMask: 1 << 1),
    ),
    (
      'monthly 最后一个周五',
      '每月最后一个周五',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly,
          monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
          nth: 5,
          weekdayMask: 1 << 4),
    ),
    (
      'monthly interval 3 第 2 个周二',
      '每 3 个月的第 2 个周二',
      const RecurrenceRule(
          cycle: RecurrenceCycle.monthly,
          interval: 3,
          monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
          nth: 2,
          weekdayMask: 1 << 1),
    ),
    (
      'yearly 裸',
      '每年',
      const RecurrenceRule(cycle: RecurrenceCycle.yearly),
    ),
    (
      'yearly interval 2',
      '每 2 年',
      const RecurrenceRule(cycle: RecurrenceCycle.yearly, interval: 2),
    ),
  ];

  for (final (name, expected, rule) in cases) {
    test(name, () {
      expect(recurrenceRuleText(rule), expected);
    });
  }
}
