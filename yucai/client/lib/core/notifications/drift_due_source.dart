/// drift 侧实现(design ADR-3):未付期次候选源 + 当日去重记录。
library;

import 'package:drift/drift.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';

/// 未付期次候选:paymentDate ≤ today+windowDays(档位细分留给 policy),
/// join Debts 取 counterparty 作债务展示名。
class DriftDueSource implements DueScheduleSource {
  DriftDueSource(this.db, {int? windowDays})
      : windowDays = windowDays ?? DueReminderPolicy.advanceDays;
  final AppDatabase db;
  final int windowDays;

  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async {
    final now = DateTime.now();
    final windowEnd = DateTime(now.year, now.month, now.day)
        .add(Duration(days: windowDays + 1));
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

/// 当日已发记录:ReminderLogs(entryId+tier 序数+yyyy-MM-dd)。
class DriftReminderLogStore implements ReminderLogStore {
  DriftReminderLogStore(this.db);
  final AppDatabase db;

  static String _day(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<bool> wasSentToday(String entryId, DueTier tier, DateTime today) async {
    final q = db.select(db.reminderLogs)
      ..where((t) =>
          t.entryId.equals(entryId) &
          t.tier.equals(tier.index) &
          t.sentDate.equals(_day(today)));
    // 唯一索引保证至多一行;用 isNotEmpty 而非 getSingleOrNull,
    // 历史脏数据(重复行)不再炸扫描(review R1)。
    return (await q.get()).isNotEmpty;
  }

  @override
  Future<void> markSent(String entryId, DueTier tier, DateTime today) async {
    await db.into(db.reminderLogs).insert(
          ReminderLogsCompanion.insert(
            entryId: entryId,
            tier: tier.index,
            sentDate: _day(today),
          ),
          mode: InsertMode.insertOrIgnore, // 同日同档幂等
        );
  }
}
