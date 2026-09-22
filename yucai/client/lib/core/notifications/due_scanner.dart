/// 到期扫描器:编排 source → policy → 挂失过滤 → log 桶去重 → notifier。
/// 三抽象注入(design ADR-2),插件/存储隔离在 adapter。
library;

import 'due_reminder_policy.dart';
import 'reminder_dismissal_store.dart';

/// 一条未付期次候选(由数据层组装,含债务名)。
/// 信用卡还款候选复用同一形态:debtName=卡名,totalCents=欠款(credit-正)。
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

/// 多源合并(债务期次 + 信用卡还款日)。
class MultiDueSource implements DueScheduleSource {
  MultiDueSource(this.sources);
  final List<DueScheduleSource> sources;

  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async => [
        for (final s in sources) ...(await s.unpaidDueCandidates()),
      ];
}

/// 通知发送器(local_notifier adapter 实现)。
abstract class ReminderNotifier {
  Future<void> show(DueNotificationCopy copy);
}

/// 桶粒度已发记录(去重持久化):token 由 policy.bucketToken 生成。
abstract class ReminderLogStore {
  Future<bool> wasSent(String entryId, DueTier tier, String bucketToken);
  Future<void> markSent(String entryId, DueTier tier, String bucketToken);
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
    this.policyProvider = _defaultPolicyProvider,
    this.dismissalStore,
  });

  /// 每轮扫描时取当前配置 —— 设置页改提前天数/重复间隔即时生效,
  /// 不必重建接线。
  static DueReminderPolicy _defaultPolicyProvider() => DueReminderPolicy();

  final DueScheduleSource source;
  final ReminderNotifier notifier;
  final ReminderLogStore logStore;
  final DueReminderPolicy Function() policyProvider;

  /// 「不再提醒」挂失(可选):挂失条目整期停催(本期不再提醒)。
  final ReminderDismissalStore? dismissalStore;

  /// 扫一轮:窗口内未付期次按档位发提醒,同档同桶幂等,挂失跳过。
  Future<ScanResult> scan(DateTime today) async {
    final policy = policyProvider();
    final entries = await source.unpaidDueCandidates();
    final dismissed =
        dismissalStore == null ? null : await dismissalStore!.dismissedEntryIds();
    var sent = 0;
    for (final e in entries) {
      final tier = policy.tierFor(today, e.paymentDate);
      if (tier == null) continue;
      if (dismissed != null && dismissed.contains(e.id)) continue;
      final token = policy.bucketToken(DateTime.now());
      if (await logStore.wasSent(e.id, tier, token)) continue;
      final copy = policy.compose(
        debtName: e.debtName,
        totalCents: e.totalCents,
        tier: tier,
        today: today,
        paymentDate: e.paymentDate,
      );
      await notifier.show(copy);
      await logStore.markSent(e.id, tier, token);
      sent++;
    }
    return ScanResult(scanned: entries.length, sent: sent);
  }
}
