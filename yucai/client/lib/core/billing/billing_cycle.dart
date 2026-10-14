// F60 账单周期计算 —— 全仓单一事实源(R20 Decisions:周期锚=建户账单日;
// 拍板 A:账单日当天交易归下期)。
//
// 归位 core/billing(照 core/recurrence 先例):跨模块纯日历算术
// (account 卡详情/debt 分期落期/report 分组在 F61 接线消费),零 IO/零
// Flutter 依赖。本文件在 F60 周期内暂无 lib 调用方 —— 消费面归 F61;
// 广发对账推演(ts-gf-closeout.md)先行以本函数为计算基准。
//
// 语义:
//  - 区间 [start, end) 左闭右开,分量恒为 date-only(零时);
//  - 实际账单日 = min(billingDay, 当月天数)(30/31 号过短月钳为月末);
//  - 日期 ≥ 当月实际账单日(含当天)→ 区间起于当月账单日(当天归下期:
//    账单日当天账单已出,当天消费进下一期 —— 拍板 A,与 F50「M 月消费
//    进 M+1 月 1 号账单」归属方向一致);
//  - billingDay 为 null 或越界(∉ 1..31)→ 回落自然月(非信用卡/未填,
//    行为与 F50 逐分一致;账单日 1 号卡与自然月等价,兼容零迁移)。
library;

/// 一个账单周期区间。值语义:按 [start]/[end] 判等。
///
/// 时区口径:分量恒为**本地** date-only(零时,非 isUtc)——与构造入参的
/// 时区无关按日历分量归一;与 UTC 日期对象直接 == 会因 isUtc 不等而判否
/// (F61 接线时如需跨时区比较,先做分量归一)。
class BillingCycle {
  const BillingCycle({required this.start, required this.end});

  /// 周期起点(上期账单日,含)。
  final DateTime start;

  /// 周期终点(本期账单日,不含)。
  final DateTime end;

  /// [date] 是否落在本周期内。
  bool contains(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(start) && d.isBefore(end);
  }

  @override
  bool operator ==(Object other) =>
      other is BillingCycle && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'BillingCycle[$start, $end)';
}

int _daysInMonth(int year, int month) {
  // DateTime 构造对 month+1 取 0 日 = 当月末日,天然处理闰年。
  return DateTime(year, month + 1, 0).day;
}

/// (year, month) 的实际账单日(钳制:账单日 > 当月天数 → 当月最后一天)。
DateTime _billingDateOf(int year, int month, int billingDay) =>
    DateTime(year, month, billingDay > _daysInMonth(year, month)
        ? _daysInMonth(year, month)
        : billingDay);

/// [date] 在账单日为 [billingDay] 的卡上所属的账单周期。
///
/// [billingDay] 为 null 或 ∉ 1..31 时回落自然月。见库注释的边界语义。
BillingCycle billingCycleOf(DateTime date, {int? billingDay}) {
  final d = DateTime(date.year, date.month, date.day);
  final day = billingDay;
  if (day == null || day < 1 || day > 31) {
    return BillingCycle(
        start: DateTime(d.year, d.month, 1),
        end: DateTime(d.year, d.month + 1, 1));
  }
  final thisMonthBillingDay = _billingDateOf(d.year, d.month, day);
  // 当天归下期(拍板 A):date ≥ 当月实际账单日(含相等)即以当月账单日
  // 为起点 —— 含「钳制日当天」(如 31 号卡的 2/28)同规则。
  final start = d.isBefore(thisMonthBillingDay)
      ? _billingDateOf(d.month == 1 ? d.year - 1 : d.year,
          d.month == 1 ? 12 : d.month - 1, day)
      : thisMonthBillingDay;
  final end = _billingDateOf(
      start.month == 12 ? start.year + 1 : start.year,
      start.month == 12 ? 1 : start.month + 1,
      day);
  return BillingCycle(start: start, end: end);
}
