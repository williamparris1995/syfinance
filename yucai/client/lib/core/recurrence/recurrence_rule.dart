import 'package:equatable/equatable.dart';

/// 周期频率(对齐 proto RecurrenceCycle/TemplateCycle 值 1-4;客户端独立枚举,
/// 消费方 mapper 负责转换)。custom = 每 N 天。
enum RecurrenceCycle { weekly, monthly, yearly, custom }

/// 月度规则的取日方式(对齐 proto MonthlyMode 值 0/1)。
enum RecurrenceMonthlyMode { byDate, byNthWeekday }

/// 日历式周期规则(template 订阅 / debt 分期共用;镜像 server
/// internal/shared/domain/recurrence.Rule)。
///
/// 零值即旧行为:interval<=0 视为 1;weekdayMask==0 沿用起始日星期;
/// cycleDays<=0 视为 1;byDate 且 billingDay<=0 锚定发生日自身(月末钳制)。
class RecurrenceRule extends Equatable {
  const RecurrenceRule({
    this.cycle = RecurrenceCycle.monthly,
    this.interval = 0,
    this.cycleDays = 0,
    this.billingDay = 0,
    this.weekdayMask = 0,
    this.monthlyMode = RecurrenceMonthlyMode.byDate,
    this.nth = 0,
  });

  /// 频率单位。
  final RecurrenceCycle cycle;

  /// 每 N 周/月/年(1-100;<=0 视为 1)。
  final int interval;

  /// custom:每 N 天(1-3650;<=0 视为 1)。
  final int cycleDays;

  /// 月度按日期锚点 1-31(31 在短月钳制到月末 = 「每月末」语义);
  /// <=0 锚定发生日自身。仅订阅用;借贷按起始日对齐(恒 0)。
  final int billingDay;

  /// 星期位掩码:bit0=周一 … bit6=周日;0 = 沿用起始日星期。
  final int weekdayMask;

  /// 月度取日方式。
  final RecurrenceMonthlyMode monthlyMode;

  /// 1-4=第 N 个;5=最后一个(byNthWeekday 时配 weekdayMask 单比特)。
  final int nth;

  /// 从 proto/落库整数构造(cycle 1-4 对齐 proto;monthlyMode 0/1;
  /// 非法 cycle 回退 monthly)。零值即旧行为。
  factory RecurrenceRule.fromInts({
    required int cycle,
    int interval = 0,
    int cycleDays = 0,
    int billingDay = 0,
    int weekdayMask = 0,
    int monthlyMode = 0,
    int nth = 0,
  }) =>
      RecurrenceRule(
        cycle: cycle >= 1 && cycle <= 4
            ? RecurrenceCycle.values[cycle - 1]
            : RecurrenceCycle.monthly,
        interval: interval,
        cycleDays: cycleDays,
        billingDay: billingDay,
        weekdayMask: weekdayMask,
        monthlyMode: monthlyMode == 1
            ? RecurrenceMonthlyMode.byNthWeekday
            : RecurrenceMonthlyMode.byDate,
        nth: nth,
      );

  /// proto/落库用的整数视图(cycle 1-4;monthlyMode 0/1)。
  int get cycleInt => cycle.index + 1;
  int get monthlyModeInt =>
      monthlyMode == RecurrenceMonthlyMode.byNthWeekday ? 1 : 0;

  /// 星期掩码:全周(周一至周日)。
  static const int maskAll = 0x7F;

  /// 星期掩码:工作日(周一至周五)。
  static const int maskWeekdays = 0x1F;

  RecurrenceRule copyWith({
    RecurrenceCycle? cycle,
    int? interval,
    int? cycleDays,
    int? billingDay,
    int? weekdayMask,
    RecurrenceMonthlyMode? monthlyMode,
    int? nth,
  }) =>
      RecurrenceRule(
        cycle: cycle ?? this.cycle,
        interval: interval ?? this.interval,
        cycleDays: cycleDays ?? this.cycleDays,
        billingDay: billingDay ?? this.billingDay,
        weekdayMask: weekdayMask ?? this.weekdayMask,
        monthlyMode: monthlyMode ?? this.monthlyMode,
        nth: nth ?? this.nth,
      );

  @override
  List<Object?> get props => [
        cycle,
        interval,
        cycleDays,
        billingDay,
        weekdayMask,
        monthlyMode,
        nth,
      ];
}

/// 周一..周日短名(下标 = weekdayMask 位序)。
const List<String> kWeekdayNames = [
  '周一',
  '周二',
  '周三',
  '周四',
  '周五',
  '周六',
  '周日',
];
