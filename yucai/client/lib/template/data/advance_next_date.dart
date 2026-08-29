/// 周期模板 nextDate 推进算法(FR-5;oracle=server template/domain 用例移植)。
/// 语义:weekly +7d;monthly 月加+billingDay 钳制月末(server addMonthsClamped);
/// yearly +1y(闰日钳制);custom +cycleDays 天(client 语义,纠正 server +1d 存根,
/// spec grill #3 记档)。UTC 日粒度。
library;

DateTime advanceNextDate(
  DateTime current, {
  required int cycle,
  required int cycleDays,
  required int billingDay,
}) {
  switch (cycle) {
    case 1: // weekly
      return DateTime.utc(current.year, current.month, current.day + 7);
    case 2: // monthly
      return _addMonthsClamped(current, 1, billingDay);
    case 3: // yearly
      final next = DateTime.utc(current.year + 1, current.month, current.day);
      // 2/29 → 次年 2/28:DateTime 构造器对非法日会滚动到 3/1,需钳回。
      return next.month == current.month
          ? next
          : DateTime.utc(current.year + 1, current.month + 1, 0);
    case 4: // custom
      final days = cycleDays > 0 ? cycleDays : 1;
      return DateTime.utc(current.year, current.month, current.day + days);
    default:
      return DateTime.utc(current.year, current.month, current.day + 1);
  }
}

/// 月加 + billingDay(≤0 取发生日)+ 目标月末钳制。
DateTime _addMonthsClamped(DateTime base, int months, int billingDay) {
  final total = base.month - 1 + months;
  final year = base.year + total ~/ 12;
  final month = total % 12 + 1;
  var day = billingDay > 0 ? billingDay : base.day;
  // 月末日 = 下月 1 号的前一天。
  final lastDay = DateTime.utc(year, month + 1, 0).day;
  if (day > lastDay) day = lastDay;
  return DateTime.utc(year, month, day);
}
