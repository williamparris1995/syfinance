/// 周期规则推进算法(共享内核;镜像 server
/// internal/shared/domain/recurrence.Rule.NextAfter,两侧用例保持对齐)。
///
/// 语义:nextAfter 返回严格晚于 from 的首个发生日;UTC 日粒度。
/// weekly:mask 命中 + 距 from 周数 % interval == 0(周一为一周之首);
/// monthly byDate:月加 + billingDay(≤0 锚发生日)+ 月末钳制(31=每月末);
/// monthly byNthWeekday:第 nth 个星期几(nth=5 取最后一个);
/// yearly:年加 + 2/29 钳 2/28;custom:+cycleDays 天。
library;

import 'recurrence_rule.dart';

/// 严格晚于 [from] 的首个发生日。
DateTime nextAfter(DateTime from, RecurrenceRule rule) {
  from = DateTime.utc(from.year, from.month, from.day);
  switch (rule.cycle) {
    case RecurrenceCycle.weekly:
      return _nextWeekly(from, rule);
    case RecurrenceCycle.monthly:
      if (rule.monthlyMode == RecurrenceMonthlyMode.byNthWeekday &&
          rule.nth >= 1 &&
          rule.nth <= 5) {
        final w = _maskWeekday(rule.weekdayMask);
        if (w != null) return _nextNthWeekday(from, rule, w);
      }
      return _addMonthsClamped(from, _intervalOf(rule), rule.billingDay);
    case RecurrenceCycle.yearly:
      return _addYearsClamped(from, _intervalOf(rule));
    case RecurrenceCycle.custom:
      final days = rule.cycleDays > 0 ? rule.cycleDays : 1;
      return DateTime.utc(from.year, from.month, from.day + days);
  }
}

/// [start] 之后(不含)的 n 个发生日。
List<DateTime> occurrences(DateTime start, RecurrenceRule rule, int n) {
  if (n <= 0) return const [];
  final out = <DateTime>[];
  var d = DateTime.utc(start.year, start.month, start.day);
  for (var i = 0; i < n; i++) {
    d = nextAfter(d, rule);
    out.add(d);
  }
  return out;
}

/// (start, end] 内的全部发生日;[atLeastOne] 为 true 时至少返回一个
/// (即使越过 end,保证调用方永远得到非空计划)。
List<DateTime> occurrencesBetween(
  DateTime start,
  DateTime end,
  RecurrenceRule rule, {
  bool atLeastOne = false,
}) {
  final last = DateTime.utc(end.year, end.month, end.day);
  var d = DateTime.utc(start.year, start.month, start.day);
  final out = <DateTime>[];
  while (true) {
    d = nextAfter(d, rule);
    if (!d.isAfter(last)) {
      out.add(d);
      continue;
    }
    if (atLeastOne && out.isEmpty) out.add(d);
    return out;
  }
}

/// 一个周期的年化长度(月=interval/12、周=7*interval/365、年=interval、
/// 天=cycleDays/365);用于把年利率折算为期利率。
double periodYears(RecurrenceRule rule) {
  switch (rule.cycle) {
    case RecurrenceCycle.weekly:
      return _intervalOf(rule) * 7 / 365;
    case RecurrenceCycle.monthly:
      return _intervalOf(rule) / 12;
    case RecurrenceCycle.yearly:
      return _intervalOf(rule).toDouble();
    case RecurrenceCycle.custom:
      return (rule.cycleDays > 0 ? rule.cycleDays : 1) / 365;
  }
}

/// 月度锚定步进:每个日期都重新锚定 start 自身的日(月末钳制),
/// Jan 31 → Feb 28 → Mar 31(无漂移)。借贷分期月度沿用此语义
/// (镜像 server Rule.MonthlyDates / 旧 addMonths(start, k))。
List<DateTime> monthlyDates(DateTime start, RecurrenceRule rule, int n) {
  if (n <= 0) return const [];
  final interval = _intervalOf(rule);
  return [
    for (var k = 1; k <= n; k++)
      _addMonthsClamped(
          DateTime.utc(start.year, start.month, start.day), k * interval, 0)
  ];
}

/// 旧「月差」期数(>=1;镜像 server monthsBetween/TermInMonths)。
int monthsBetween(DateTime from, DateTime to) {
  final months = (to.year - from.year) * 12 + to.month - from.month;
  return months <= 0 ? 1 : months;
}

/// 借贷分期日期序列(镜像 server ScheduleDatesFrom):
/// - termPeriods>0(按期数):恰好 n 个发生日,due 忽略(调用方取末位推 due);
/// - 月度按日期:ceil(月差/间隔) 个,锚定起始日(interval=1 与旧算法逐位一致);
/// - 月度第 N 个星期几:链式推进;
/// - 其余周期:(anchor, due] 内全部发生日(至少一个)。
List<DateTime> scheduleDatesFrom(
  RecurrenceRule rule,
  DateTime anchor,
  DateTime due,
  int termPeriods,
) {
  if (termPeriods > 0) return occurrences(anchor, rule, termPeriods);
  if (rule.cycle == RecurrenceCycle.monthly) {
    final interval = _intervalOf(rule);
    var n = (monthsBetween(anchor, due) + interval - 1) ~/ interval;
    if (n < 1) n = 1;
    if (rule.monthlyMode == RecurrenceMonthlyMode.byNthWeekday &&
        rule.nth >= 1 &&
        rule.nth <= 5 &&
        _singleBitMask(rule.weekdayMask) != null) {
      return occurrences(anchor, rule, n);
    }
    return monthlyDates(anchor, rule, n);
  }
  return occurrencesBetween(anchor, due, rule, atLeastOne: true);
}

/// 单比特掩码位序(0-6);非单比特返回 null。
int? _singleBitMask(int mask) {
  if (mask == 0 || (mask & (mask - 1)) != 0) return null;
  var m = mask, i = 0;
  while (m & 1 == 0) {
    m >>= 1;
    i++;
  }
  return i;
}

int _intervalOf(RecurrenceRule rule) =>
    rule.interval > 0 ? rule.interval : 1;

DateTime _nextWeekly(DateTime from, RecurrenceRule rule) {
  final interval = _intervalOf(rule);
  var mask = rule.weekdayMask;
  if (mask == 0) mask = 1 << (from.weekday - 1);
  final anchor = _weekStart(from);
  final limit = 7 * interval + 7;
  var d = from;
  for (var i = 0; i < limit; i++) {
    d = DateTime.utc(d.year, d.month, d.day + 1);
    if (mask & (1 << (d.weekday - 1)) == 0) continue;
    final weeks = _weekStart(d).difference(anchor).inDays ~/ 7;
    if (weeks % interval == 0) return d;
  }
  return d; // 不可达:from 的星期在 interval 周内必再现
}

DateTime _nextNthWeekday(DateTime from, RecurrenceRule rule, int weekday) {
  final interval = _intervalOf(rule);
  for (var k = 0; k < 3; k++) {
    final total = from.month - 1 + interval * k;
    final year = from.year + total ~/ 12;
    final month = total % 12 + 1;
    final target = _nthWeekdayOfMonth(year, month, rule.nth, weekday);
    if (target.isAfter(from)) return target;
  }
  return from; // 不可达:下一个 interval 月必有更晚日期
}

/// 单比特掩码 → Dart weekday(周一=1..周日=7);非单比特返回 null。
int? _maskWeekday(int mask) {
  if (mask == 0 || (mask & (mask - 1)) != 0) return null;
  var m = mask, i = 0;
  while (m & 1 == 0) {
    m >>= 1;
    i++;
  }
  return i + 1;
}

/// t 所在周的周一(UTC 零点)。
DateTime _weekStart(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day - ((t.weekday - 1) % 7));

DateTime _addMonthsClamped(DateTime base, int months, int billingDay) {
  final total = base.month - 1 + months;
  final year = base.year + total ~/ 12;
  final month = total % 12 + 1;
  var day = billingDay > 0 ? billingDay : base.day;
  final last = DateTime.utc(year, month + 1, 0).day;
  if (day > last) day = last;
  return DateTime.utc(year, month, day);
}

DateTime _addYearsClamped(DateTime base, int years) {
  final year = base.year + years;
  final last = DateTime.utc(year, base.month + 1, 0).day;
  return DateTime.utc(year, base.month, base.day > last ? last : base.day);
}

/// 月内第 nth 个 weekday(nth=5 取最后一个)。
DateTime _nthWeekdayOfMonth(int year, int month, int nth, int weekday) {
  if (nth == 5) {
    var d = DateTime.utc(year, month + 1, 0); // 月末
    while (d.weekday != weekday) {
      d = DateTime.utc(d.year, d.month, d.day - 1);
    }
    return d;
  }
  var d = DateTime.utc(year, month, 1);
  while (d.weekday != weekday) {
    d = DateTime.utc(d.year, d.month, d.day + 1);
  }
  return DateTime.utc(d.year, d.month, d.day + 7 * (nth - 1));
}
