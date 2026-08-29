/// 到期提醒策略(spec FR-2/FR-5):三档分类 + 当日去重 + 通知文案。
/// 纯逻辑、无插件/IO 依赖(design ADR-2 port 隔离)。
library;

/// 提醒档位:T-3(前 3 天一次)/ T-0(当天一次)/ overdue(逾期未付每日一次)。
enum DueTier { t3, t0, overdue }

/// 一条待发通知的标题与正文。
class DueNotificationCopy {
  const DueNotificationCopy(this.title, this.body);
  final String title;
  final String body;
}

class DueReminderPolicy {
  /// 提醒窗口常量(spec NFR:单点定义)。
  static const int advanceDays = 3;

  /// 差值分类:paymentDate 相对 today 的天数决定档位。
  /// 差 3 → t3;差 2/1 → null(不发);差 0 → t0;已过 → overdue;更远 → null。
  static DueTier? tierFor(DateTime today, DateTime paymentDate) {
    final days = _daysBetween(today, paymentDate);
    if (days == advanceDays) return DueTier.t3;
    if (days == 0) return DueTier.t0;
    if (days < 0) return DueTier.overdue;
    return null;
  }

  /// 当日去重:同期次同档当日只发一次(overdue 的"每日一次"由跨日新记录自然成立)。
  static bool shouldSend({required bool alreadySentToday}) => !alreadySentToday;

  /// 组装文案:「御财·{债务名}」+「{相对天数}到期/逾期,应还 ¥{金额}」。
  static DueNotificationCopy compose({
    required String debtName,
    required int totalCents,
    required DueTier tier,
    required DateTime today,
    required DateTime paymentDate,
  }) {
    final amount = _formatYuan(totalCents);
    final String when;
    switch (tier) {
      case DueTier.t3:
        when = '$advanceDays 天后到期';
      case DueTier.t0:
        when = '今日到期';
      case DueTier.overdue:
        when = '已逾期 ${-_daysBetween(today, paymentDate)} 天';
    }
    return DueNotificationCopy('御财·$debtName', '$when,应还 ¥$amount');
  }

  /// 日粒度差值(a-b 的天数,按本地日期截断;与 drift 查询的日期语义一致)。
  static int _daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// 分 → 「1,234.56」式元字符串(千分位,通知可读性)。
  static String _formatYuan(int totalCents) {
    final neg = totalCents < 0;
    final s = (totalCents.abs() / 100).toStringAsFixed(2);
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final frac = dot < 0 ? '' : s.substring(dot);
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final posFromRight = intPart.length - i;
      grouped.write(intPart[i]);
      if (posFromRight > 1 && (posFromRight - 1) % 3 == 0) {
        grouped.write(',');
      }
    }
    return '${neg ? '-' : ''}$grouped$frac';
  }
}
