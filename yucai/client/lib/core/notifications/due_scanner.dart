/// 到期扫描器(spec FR-2):编排 source → policy → log 去重 → notifier。
/// 三抽象注入(design ADR-2),插件/存储隔离在 adapter。
library;

import 'due_reminder_policy.dart';

/// 一条未付期次候选(由数据层组装,含债务名)。
class DueScheduleEntry {
  const DueScheduleEntry({
    required this.id,
    required this.debtName,
    required this.totalCents,
    required this.paymentDate,
  });
  final String id;
  final String debtName;
  final int totalCents;
  final DateTime paymentDate;
}

/// 数据源:未付期次候选(本地 drift;窗口过滤在实现侧)。
abstract class DueScheduleSource {
  Future<List<DueScheduleEntry>> unpaidDueCandidates();
}

/// 通知发送器(local_notifier adapter 实现)。
abstract class ReminderNotifier {
  Future<void> show(DueNotificationCopy copy);
}

/// 当日已发记录(去重持久化)。
abstract class ReminderLogStore {
  Future<bool> wasSentToday(String entryId, DueTier tier, DateTime today);
  Future<void> markSent(String entryId, DueTier tier, DateTime today);
}

/// 扫描结果摘要(可断言/可观测)。
class ScanResult {
  const ScanResult({required this.scanned, required this.sent});
  final int scanned;
  final int sent;
}

class DueScanner {
  DueScanner({
    required this.source,
    required this.notifier,
    required this.logStore,
  });

  final DueScheduleSource source;
  final ReminderNotifier notifier;
  final ReminderLogStore logStore;

  /// 扫一轮:窗口内未付期次按档位发提醒,同档当日幂等。
  Future<ScanResult> scan(DateTime today) async {
    final entries = await source.unpaidDueCandidates();
    var sent = 0;
    for (final e in entries) {
      final tier = DueReminderPolicy.tierFor(today, e.paymentDate);
      if (tier == null) continue;
      if (await logStore.wasSentToday(e.id, tier, today)) continue;
      final copy = DueReminderPolicy.compose(
        debtName: e.debtName,
        totalCents: e.totalCents,
        tier: tier,
        today: today,
        paymentDate: e.paymentDate,
      );
      await notifier.show(copy);
      await logStore.markSent(e.id, tier, today);
      sent++;
    }
    return ScanResult(scanned: entries.length, sent: sent);
  }
}
