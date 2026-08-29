import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/template/data/advance_next_date.dart';

void main() {
  // oracle:server domain_test.go TestCalculateNextDate_* 用例移植。
  test('monthly:1/15 → 2/15(server oracle)', () {
    final next = advanceNextDate(DateTime.utc(2026, 1, 15), cycle: 2, cycleDays: 0, billingDay: 15);
    expect((next.year, next.month, next.day), (2026, 2, 15));
  });

  test('monthly 月末钳制:1/31 → 2/28(server oracle,非闰年)', () {
    final next = advanceNextDate(DateTime.utc(2026, 1, 31), cycle: 2, cycleDays: 0, billingDay: 31);
    expect((next.month, next.day), (2, 28));
  });

  test('monthly 闰年:1/31 → 2/29', () {
    final next = advanceNextDate(DateTime.utc(2028, 1, 31), cycle: 2, cycleDays: 0, billingDay: 31);
    expect((next.year, next.month, next.day), (2028, 2, 29));
  });

  test('monthly billingDay<=0 取发生日:3/10 → 4/10', () {
    final next = advanceNextDate(DateTime.utc(2026, 3, 10), cycle: 2, cycleDays: 0, billingDay: 0);
    expect((next.month, next.day), (4, 10));
  });

  test('monthly 跨年:12/15 → 次年 1/15', () {
    final next = advanceNextDate(DateTime.utc(2026, 12, 15), cycle: 2, cycleDays: 0, billingDay: 15);
    expect((next.year, next.month), (2027, 1));
  });

  test('weekly:+7 天(server oracle 1/1 → 1/8)', () {
    final next = advanceNextDate(DateTime.utc(2026, 1, 1), cycle: 1, cycleDays: 0, billingDay: 0);
    expect(next.day, 8);
  });

  test('yearly:+1 年(2/29 闰日 → 次年 2/28 钳制)', () {
    final next = advanceNextDate(DateTime.utc(2028, 2, 29), cycle: 3, cycleDays: 0, billingDay: 0);
    expect((next.year, next.month, next.day), (2029, 2, 28));
  });

  test('custom:按 cycleDays 天(client 语义;server 为 +1d 存根,spec grill #3 记档)', () {
    final next = advanceNextDate(DateTime.utc(2026, 1, 1), cycle: 4, cycleDays: 10, billingDay: 0);
    expect((next.month, next.day), (1, 11));
  });
}
