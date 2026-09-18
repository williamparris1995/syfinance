import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/recurrence/next_after.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule.dart';

/// 共享周期内核推进算法(镜像 server
/// internal/shared/domain/recurrence/recurrence_test.go 的用例集,
/// 两侧语义必须保持一致 —— 改动任一侧须同步另一侧)。
DateTime d(String s) => DateTime.parse('${s}T00:00:00Z');

void main() {
  const mon = 1 << 0, tue = 1 << 1, wed = 1 << 2, fri = 1 << 4;
  const monToFri = mon | tue | wed | 1 << 3 | fri;

  group('nextAfter', () {
    final cases = <String, List<dynamic>>{
      // Weekly.
      'weekly legacy mask0 keeps weekday': [
        const RecurrenceRule(cycle: RecurrenceCycle.weekly),
        '2026-01-07', '2026-01-14',
      ],
      'weekly monday mask': [
        const RecurrenceRule(cycle: RecurrenceCycle.weekly, weekdayMask: mon),
        '2026-01-05', '2026-01-12',
      ],
      'weekly multi weekday next hit': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.weekly, weekdayMask: mon | fri),
        '2026-01-05', '2026-01-09',
      ],
      'weekly multi weekday same week wrap': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.weekly, weekdayMask: mon | fri),
        '2026-01-09', '2026-01-12',
      ],
      'weekly interval 2 skips week': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.weekly, interval: 2, weekdayMask: mon),
        '2026-01-05', '2026-01-19',
      ],
      'weekly interval 2 mask0 anchors own weekday': [
        const RecurrenceRule(cycle: RecurrenceCycle.weekly, interval: 2),
        '2026-01-07', '2026-01-21',
      ],
      'weekly weekdays only': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.weekly, weekdayMask: monToFri),
        '2026-01-09', '2026-01-12',
      ],
      'weekly sunday bit6': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.weekly, weekdayMask: 1 << 6),
        '2026-01-04', '2026-01-11',
      ],
      // Monthly by date.
      'monthly legacy billing0 keeps day': [
        const RecurrenceRule(cycle: RecurrenceCycle.monthly),
        '2026-01-15', '2026-02-15',
      ],
      'monthly billing day': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly, billingDay: 10),
        '2026-01-15', '2026-02-10',
      ],
      'monthly month-end clamp from jan31': [
        const RecurrenceRule(cycle: RecurrenceCycle.monthly),
        '2026-01-31', '2026-02-28',
      ],
      'monthly leap year clamp': [
        const RecurrenceRule(cycle: RecurrenceCycle.monthly),
        '2028-01-31', '2028-02-29',
      ],
      'monthly billing 31 means month end': [
        const RecurrenceRule(cycle: RecurrenceCycle.monthly, billingDay: 31),
        '2026-01-15', '2026-02-28',
      ],
      'monthly billing 31 april': [
        const RecurrenceRule(cycle: RecurrenceCycle.monthly, billingDay: 31),
        '2026-03-31', '2026-04-30',
      ],
      'monthly interval 3 quarterly': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly, interval: 3, billingDay: 15),
        '2026-01-15', '2026-04-15',
      ],
      'monthly cross year': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly, billingDay: 15),
        '2025-12-15', '2026-01-15',
      ],
      // Monthly nth weekday.
      'monthly nth 2nd tuesday': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
            nth: 2,
            weekdayMask: tue),
        '2026-01-01', '2026-01-13',
      ],
      'monthly nth skips current when passed': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
            nth: 2,
            weekdayMask: tue),
        '2026-01-13', '2026-02-10',
      ],
      'monthly nth 5 last friday': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
            nth: 5,
            weekdayMask: fri),
        '2026-01-01', '2026-01-30',
      ],
      'monthly nth last wednesday of month': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
            nth: 5,
            weekdayMask: wed),
        '2026-01-01', '2026-01-28',
      ],
      'monthly nth interval 2': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            interval: 2,
            monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
            nth: 1,
            weekdayMask: mon),
        '2026-01-05', '2026-03-02',
      ],
      'monthly nth invalid mask falls back to date': [
        const RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
            nth: 2,
            weekdayMask: mon | tue),
        '2026-01-15', '2026-02-15',
      ],
      // Yearly.
      'yearly keeps date': [
        const RecurrenceRule(cycle: RecurrenceCycle.yearly),
        '2026-05-20', '2027-05-20',
      ],
      'yearly feb29 clamps to feb28': [
        const RecurrenceRule(cycle: RecurrenceCycle.yearly),
        '2024-02-29', '2025-02-28',
      ],
      'yearly interval 2': [
        const RecurrenceRule(cycle: RecurrenceCycle.yearly, interval: 2),
        '2026-05-20', '2028-05-20',
      ],
      // Custom.
      'custom uses cycle days': [
        const RecurrenceRule(cycle: RecurrenceCycle.custom, cycleDays: 30),
        '2026-01-01', '2026-01-31',
      ],
      'custom daily': [
        const RecurrenceRule(cycle: RecurrenceCycle.custom, cycleDays: 1),
        '2026-01-01', '2026-01-02',
      ],
      'custom zero days treated as daily': [
        const RecurrenceRule(cycle: RecurrenceCycle.custom),
        '2026-01-01', '2026-01-02',
      ],
    };

    for (final entry in cases.entries) {
      test(entry.key, () {
        final rule = entry.value[0] as RecurrenceRule;
        final from = entry.value[1] as String;
        final want = entry.value[2] as String;
        final got = nextAfter(d(from), rule);
        expect(got.toUtc().toIso8601String().substring(0, 10), want,
            reason: '${entry.key}: $from + $rule');
      });
    }
  });

  group('occurrences', () {
    test('n occurrences every monday', () {
      final got = occurrences(
          d('2026-01-05'),
          const RecurrenceRule(
              cycle: RecurrenceCycle.weekly, weekdayMask: 1 << 0),
          3);
      expect(
          got.map((e) => e.toIso8601String().substring(0, 10)).toList(),
          ['2026-01-12', '2026-01-19', '2026-01-26']);
    });

    test('between counts hits in range', () {
      final got = occurrencesBetween(
          d('2026-01-01'),
          d('2026-03-26'),
          const RecurrenceRule(
              cycle: RecurrenceCycle.weekly, weekdayMask: 1 << 0));
      expect(got.length, 12);
    });

    test('between atLeastOne returns one past end', () {
      final got = occurrencesBetween(
          d('2026-01-05'),
          d('2026-01-06'),
          const RecurrenceRule(
              cycle: RecurrenceCycle.weekly, weekdayMask: 1 << 0),
          atLeastOne: true);
      expect(got.length, 1);
      expect(got.first.toIso8601String().substring(0, 10), '2026-01-12');
    });
  });

  group('periodYears', () {
    test('derives period length per cycle', () {
      expect(
          periodYears(
              const RecurrenceRule(cycle: RecurrenceCycle.monthly)),
          closeTo(1 / 12, 1e-12));
      expect(
          periodYears(const RecurrenceRule(
              cycle: RecurrenceCycle.monthly, interval: 3)),
          closeTo(3 / 12, 1e-12));
      expect(
          periodYears(
              const RecurrenceRule(cycle: RecurrenceCycle.weekly)),
          closeTo(7 / 365, 1e-12));
      expect(
          periodYears(const RecurrenceRule(
              cycle: RecurrenceCycle.weekly, interval: 2)),
          closeTo(14 / 365, 1e-12));
      expect(periodYears(const RecurrenceRule(cycle: RecurrenceCycle.yearly)),
          1.0);
      expect(
          periodYears(const RecurrenceRule(
              cycle: RecurrenceCycle.custom, cycleDays: 30)),
          closeTo(30 / 365, 1e-12));
    });
  });
}
