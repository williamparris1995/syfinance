import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule.dart';
import 'package:yucai_client/core/recurrence/next_after.dart';

void main() {
  final start = DateTime.utc(2026, 8, 1);
  test('probe: 3 个月周期各种参数组合', () {
    for (final billing in [0, 1]) {
      for (final interval in [3, 4]) {
        final rule = RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            interval: interval,
            monthlyMode: RecurrenceMonthlyMode.byDate,
            billingDay: billing);
        final occ = occurrences(start, rule, 3);
        // ignore: avoid_print
        print('billing=$billing interval=$interval → '
            '${occ.map((d) => "${d.year}-${d.month}-${d.day}").toList()}');
      }
    }
    // 锚点 = 今天(9/19)的链式推进(怀疑路径)
    final today = DateTime.utc(2026, 9, 19);
    final rule1 = RecurrenceRule(
        cycle: RecurrenceCycle.monthly,
        interval: 3,
        monthlyMode: RecurrenceMonthlyMode.byDate,
        billingDay: 1);
    // ignore: avoid_print
    print('anchor=today(9/19) billing=1 → ${nextAfter(today, rule1)}');
    // 按期数路径
    final dates = scheduleDatesFrom(
        RecurrenceRule(
            cycle: RecurrenceCycle.monthly,
            interval: 3,
            monthlyMode: RecurrenceMonthlyMode.byDate),
        start,
        DateTime.utc(2027, 8, 1),
        4);
    // ignore: avoid_print
    print('termPeriods=4 → ${dates.map((d) => "${d.year}-${d.month}-${d.day}").toList()}');
  });
}
