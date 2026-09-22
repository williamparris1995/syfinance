/// 「不再提醒」挂失存储(2026-09 信用卡还款催办):
/// 未还清也可按提醒条目 id 挂失停催(手动标记,或最低还款/分期后自动),
/// 下一个周期月生成新 entryId,挂失自然过期 —— 无需清理任务。
library;

import 'package:drift/drift.dart' show InsertMode;

import 'package:yucai_client/core/localdb/app_database.dart';

/// 信用卡还款提醒条目 id:cc:{accountId}:{yyyy-MM}(周期月,本地时区)。
/// C 部分 CreditCardDueSource 与还款对话框的「本期不再提醒」共用,
/// 保证两侧 key 单一事实源。
String creditCardCycleEntryId(String accountId, DateTime cycleMonth) =>
    'cc:$accountId:${cycleMonth.year}-'
    '${cycleMonth.month.toString().padLeft(2, '0')}';

class ReminderDismissalStore {
  ReminderDismissalStore(this._db);
  final AppDatabase _db;

  /// 挂失一个提醒条目(幂等:insertOrIgnore)。
  Future<void> dismiss(String entryId) async {
    await _db.into(_db.reminderDismissals).insert(
          ReminderDismissalsCompanion.insert(
            entryId: entryId,
            dismissedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// 已挂失条目 id 集合(扫描器过滤用)。
  Future<Set<String>> dismissedEntryIds() async => (await _db
          .select(_db.reminderDismissals)
          .get())
      .map((r) => r.entryId)
      .toSet();
}
