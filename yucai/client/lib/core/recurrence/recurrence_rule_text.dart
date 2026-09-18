/// 周期规则 → 人话文案(表单入口行 / 卡片展示 / 编辑器预览三处共用)。
library;

import 'recurrence_rule.dart';

String recurrenceRuleText(RecurrenceRule rule) {
  final interval = rule.interval > 0 ? rule.interval : 1;
  switch (rule.cycle) {
    case RecurrenceCycle.custom:
      final days = rule.cycleDays > 0 ? rule.cycleDays : 1;
      return days == 1 ? '每天' : '每 $days 天';
    case RecurrenceCycle.weekly:
      if (rule.weekdayMask == RecurrenceRule.maskAll && interval == 1) {
        return '每天';
      }
      if (rule.weekdayMask == RecurrenceRule.maskWeekdays && interval == 1) {
        return '工作日(周一至周五)';
      }
      final names = _weekdayNames(rule.weekdayMask);
      if (names.isEmpty) return interval == 1 ? '每周' : '每 $interval 周';
      final joined = names.join('、');
      return interval == 1 ? '每$joined' : '每 $interval 周的$joined';
    case RecurrenceCycle.monthly:
      if (interval == 1) {
        return '每月${_monthlyDesc(rule, compactEnd: true)}';
      }
      final desc = _monthlyDesc(rule, compactEnd: false);
      return desc.isEmpty ? '每 $interval 个月' : '每 $interval 个月的$desc';
    case RecurrenceCycle.yearly:
      return interval == 1 ? '每年' : '每 $interval 年';
  }
}

/// 月度修饰片段(空 = 无修饰)。如「 15 日」「末/月末」「第 2 个周二」。
String _monthlyDesc(RecurrenceRule rule, {required bool compactEnd}) {
  if (rule.monthlyMode == RecurrenceMonthlyMode.byNthWeekday) {
    final w = _singleWeekdayName(rule.weekdayMask);
    if (w != null && rule.nth >= 1 && rule.nth <= 5) {
      return rule.nth == 5 ? '最后一个$w' : '第 ${rule.nth} 个$w';
    }
  }
  if (rule.billingDay == 31) return compactEnd ? '末' : '月末';
  if (rule.billingDay > 0) return ' ${rule.billingDay} 日';
  return '';
}

List<String> _weekdayNames(int mask) {
  final out = <String>[];
  for (var i = 0; i < 7; i++) {
    if (mask & (1 << i) != 0) out.add(kWeekdayNames[i]);
  }
  return out;
}

String? _singleWeekdayName(int mask) {
  if (mask == 0 || (mask & (mask - 1)) != 0) return null;
  var m = mask, i = 0;
  while (m & 1 == 0) {
    m >>= 1;
    i++;
  }
  return kWeekdayNames[i];
}
