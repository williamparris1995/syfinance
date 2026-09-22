/// drift 侧实现(design ADR-3):未付期次候选源 + 桶去重记录。
library;

import 'package:drift/drift.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';

/// 未付期次候选:paymentDate ≤ today+advanceDays(档位细分留给 policy),
/// join Debts 取 counterparty 作债务展示名。
class DriftDueSource implements DueScheduleSource {
  DriftDueSource(this.db, {int? windowDays, this.configProvider})
      : windowDays = windowDays ??
            (configProvider?.call() ?? const DueReminderConfig()).advanceDays;

  final AppDatabase db;

  /// 窗口天数(测试可显式钉死);缺省从 [configProvider] 实时取。
  final int? windowDays;

  /// 催办配置 provider(提前天数驱动查询窗口)。设置页改动即时生效。
  final DueReminderConfig Function()? configProvider;

  int get _effectiveWindowDays =>
      windowDays ?? configProvider?.call().advanceDays ?? 3;

  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month, now.day)
        .add(Duration(days: _effectiveWindowDays + 1));
    final rows = await (db.select(db.paymentScheduleEntries).join([
      innerJoin(db.debts, db.debts.id.equalsExp(db.paymentScheduleEntries.debtId)),
    ])
          ..where(db.paymentScheduleEntries.paid.equals(false) &
              db.paymentScheduleEntries.paymentDate.isSmallerThanValue(windowEnd)))
        .get();
    return [
      for (final r in rows)
        DueScheduleEntry(
          id: r.readTable(db.paymentScheduleEntries).id,
          debtName: r.readTable(db.debts).counterparty,
          totalCents: r.readTable(db.paymentScheduleEntries).totalCents,
          paymentDate: r.readTable(db.paymentScheduleEntries).paymentDate,
        ),
    ];
  }
}

/// 桶粒度已发记录:ReminderLogs(entryId+tier 序数+bucketToken)。
/// token 是 epochMs÷桶宽 的整数字符串,与旧版 yyyy-MM-dd 日粒度行
/// 天然不共键,旧行无需迁移(只可能多提醒一次,新桶即续催)。
class DriftReminderLogStore implements ReminderLogStore {
  DriftReminderLogStore(this.db);
  final AppDatabase db;

  @override
  Future<bool> wasSent(String entryId, DueTier tier, String bucketToken) async {
    final q = db.select(db.reminderLogs)
      ..where((t) =>
          t.entryId.equals(entryId) &
          t.tier.equals(tier.index) &
          t.sentDate.equals(bucketToken));
    // 唯一索引保证至多一行;用 isNotEmpty 而非 getSingleOrNull,
    // 历史脏数据(重复行)不再炸扫描(review R1)。
    return (await q.get()).isNotEmpty;
  }

  @override
  Future<void> markSent(String entryId, DueTier tier, String bucketToken) async {
    await db.into(db.reminderLogs).insert(
          ReminderLogsCompanion.insert(
            entryId: entryId,
            tier: tier.index,
            sentDate: bucketToken,
          ),
          mode: InsertMode.insertOrIgnore, // 同桶同档幂等
        );
  }
}
