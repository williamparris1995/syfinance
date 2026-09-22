/// 到期催办策略(2026-09 重构为催办模式):配置化提前天数 + 重复间隔。
/// 纯逻辑、无插件/IO 依赖(design ADR-2 port 隔离)。
///
/// 语义(用户定案):
/// - 进入提醒窗口(到期前 [DueReminderConfig.advanceDays] 天,含当天)后
///   **持续提醒直到事项处理完** —— 信用卡欠款还清/债务期次标记已付后,
///   候选从数据源消失,催办自然终止。
/// - 重复间隔可配置(1/2/3/6 小时),**最长不超过 6 小时**
///   (maxRepeatHours 上限,「每次提醒最长间隔 6 小时」)。
/// - 同一事项两次提醒用「桶 token」去重:epochMs ÷ (repeatHours·3600e3),
///   同桶只发一次;换桶即再发。桶 token 写入 ReminderLogs.sentDate 文本列,
///   与旧版 yyyy-MM-dd 日粒度格式天然不冲突,无需迁移。
library;

/// 催办档位:advance(窗口内含当天)/ overdue(已过期)。两档独立去重,
/// 过期当天会再发一条 overdue(催办升级)。
enum DueTier { advance, overdue }

/// 一条待发通知的标题与正文。
class DueNotificationCopy {
  const DueNotificationCopy(this.title, this.body);
  final String title;
  final String body;
}

/// 催办配置(设置页可调;默认 = 旧行为的提前 3 天 + 上限间隔 6 小时)。
class DueReminderConfig {
  const DueReminderConfig({this.advanceDays = 3, this.repeatHours = 6});

  /// 提前提醒天数(进入窗口 = 到期日差 ≤ advanceDays)。
  final int advanceDays;

  /// 重复提醒间隔小时数。需求上限 6:配置面只允许 1/2/3/6,
  /// 构造侧不硬拦(测试/默认值可信),UI 选项收敛。
  final int repeatHours;

  /// 需求「每次提醒最长间隔 6 小时」的单点定义。
  static const int maxRepeatHours = 6;
}

class DueReminderPolicy {
  DueReminderPolicy([this.config = const DueReminderConfig()]);

  final DueReminderConfig config;

  /// 差值分类:paymentDate 相对 today 的天数决定档位。
  /// 已过 → overdue;0 ≤ 差 ≤ advanceDays → advance;更远 → null(不发)。
  DueTier? tierFor(DateTime today, DateTime paymentDate) {
    final days = _daysBetween(today, paymentDate);
    if (days < 0) return DueTier.overdue;
    if (days <= config.advanceDays) return DueTier.advance;
    return null;
  }

  /// 桶内幂等:同桶已发 → 不发。
  static bool shouldSend({required bool alreadySentInBucket}) =>
      !alreadySentInBucket;

  /// 去重桶 token:epochMs ÷ 桶宽。同桶同档当日只发一次;跨桶自然再发。
  String bucketToken(DateTime now) =>
      '${now.millisecondsSinceEpoch ~/ (config.repeatHours * 3600 * 1000)}';

  /// 组装文案:「御财·{名称}」+「{相对天数}到期/逾期,应还 ¥{金额}」。
  DueNotificationCopy compose({
    required String debtName,
    required int totalCents,
    required DueTier tier,
    required DateTime today,
    required DateTime paymentDate,
  }) {
    final amount = _formatYuan(totalCents);
    final days = _daysBetween(today, paymentDate);
    final String when;
    switch (tier) {
      case DueTier.advance:
        when = days == 0 ? '今日到期' : '$days 天后到期';
      case DueTier.overdue:
        when = '已逾期 ${-days} 天';
    }
    return DueNotificationCopy('御财·$debtName', '$when,应还 ¥$amount');
  }

  /// 日粒度差值(a-b 的天数,按本地日期截断;与 drift 查询的日期语义一致)。
  static int _daysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  /// 分 → 「1,234.56」式元字符串(千分位;通知/记账文案共用,R7-C 提升)。
  static String formatYuan(int totalCents) => _formatYuan(totalCents);

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
