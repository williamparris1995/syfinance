/// 到期扫描器:编排 source → policy → 挂失过滤 → log 桶去重 → notifier。
/// 三抽象注入(design ADR-2),插件/存储隔离在 adapter。
library;

import 'due_reminder_policy.dart';
import 'due_target.dart';
import 'reminder_dismissal_store.dart';

/// 一条未付期次候选(由数据层组装,含债务名)。
/// 信用卡还款候选复用同一形态:debtName=卡名,totalCents=欠款(credit-正)。
/// [target] 为强类型路由目标(design ADR-2),两源构造时各自填。
class DueScheduleEntry {
  const DueScheduleEntry({
    required this.id,
    required this.debtName,
    required this.totalCents,
    required this.paymentDate,
    required this.target,
  });
  final String id;
  final String debtName;
  final int totalCents;
  final DateTime paymentDate;

  /// 直达目标:期次 → 债务详情页;信用卡 → 还款对话框。
  final DueTarget target;
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

/// 一条活跃候选(窗口内 + 未挂失)及其口径化分档结果。
/// 写侧 scanner(去重/发送)与读侧 DueCandidateProvider(视图广播)共用,
/// 「什么算一条待办」由此单一函数定义(design ADR-1 / 风险 R1 同源契约)。
class ActiveDueCandidate {
  const ActiveDueCandidate({
    required this.entry,
    required this.tier,
    required this.daysLeft,
  });
  final DueScheduleEntry entry;
  final DueTier tier;

  /// 到期日差([DueReminderPolicy.daysBetween] 同口径;负 = 逾期天数)。
  final int daysLeft;
}

/// 源候选 → 活跃候选的共享纯函数:窗口分档(policy.tierFor,null = 窗口外
/// 剔除)+ 挂失过滤([dismissedIds] 含 entry.id 则剔)。scanner 与读侧
/// provider 都调它,两管线候选口径不得分叉(同源契约测试钉死)。
List<ActiveDueCandidate> filterActiveCandidates(
  List<DueScheduleEntry> raw,
  Set<String>? dismissedIds, {
  required DueReminderPolicy policy,
  required DateTime today,
}) {
  final out = <ActiveDueCandidate>[];
  for (final e in raw) {
    final tier = policy.tierFor(today, e.paymentDate);
    if (tier == null) continue;
    if (dismissedIds != null && dismissedIds.contains(e.id)) continue;
    out.add(ActiveDueCandidate(
      entry: e,
      tier: tier,
      daysLeft: DueReminderPolicy.daysBetween(today, e.paymentDate),
    ));
  }
  return out;
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
  /// 候选口径(窗口 + 挂失)走 [filterActiveCandidates] 共享纯函数
  /// (与读侧 provider 同源;行为与内联版逐字等价,FR-8)。
  Future<ScanResult> scan(DateTime today) async {
    final policy = policyProvider();
    final entries = await source.unpaidDueCandidates();
    final dismissed =
        dismissalStore == null ? null : await dismissalStore!.dismissedEntryIds();
    final active = filterActiveCandidates(entries, dismissed,
        policy: policy, today: today);
    var sent = 0;
    for (final c in active) {
      final token = policy.bucketToken(DateTime.now());
      if (await logStore.wasSent(c.entry.id, c.tier, token)) continue;
      final copy = policy.compose(
        debtName: c.entry.debtName,
        totalCents: c.entry.totalCents,
        tier: c.tier,
        today: today,
        paymentDate: c.entry.paymentDate,
      );
      await notifier.show(copy);
      await logStore.markSent(c.entry.id, c.tier, token);
      sent++;
    }
    return ScanResult(scanned: entries.length, sent: sent);
  }
}
