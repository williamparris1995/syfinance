/// 收件箱存储(2026-09 到期常显提醒,design ADR-4/ADR-6):
/// InboxEntries 表 CRUD + 小圆点 lastSeen(AppMeta)。状态由领域事实驱动
/// (spec FR-6):入窗 upsert 与定态 settle 只由读侧 syncer 调用,
/// 本 store 不做任何领域仲裁。
library;

import 'package:drift/drift.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_target.dart';

/// 条目三态:0 待处理 / 1 已处理 / 2 已挂失。存 int(枚举序数)保持
/// localdb 与 notifications 模块解耦,映射收在本文件 —— 与
/// due_reminder_policy.dart 的 DueTier ↔ ReminderLogs.tier 同一手法。
enum InboxEntryState { pending, handled, dismissed }

/// 条目类型(本期恒到期提醒;type 列为未来提醒类型预留,值即此常量)。
const String kInboxTypeDueReminder = 'due_reminder';

/// AppMeta 键:收件箱上次查看时刻(epochMs;小圆点基准,design ADR-6)。
const String kInboxLastSeenKey = 'inbox_last_seen';

/// targetKind 列编码:0 account / 1 debt(与 [DueTarget] 两子类一一对应)。
const int kInboxTargetKindAccount = 0;
const int kInboxTargetKindDebt = 1;

/// (targetKind, targetId) 列解码 → [DueTarget](收件箱行点击直达用,2026-09
/// 到期常显提醒 T4)。与 [InboxStore] 内部 _encodeTarget 互逆;未知 kind 是
/// 数据损坏信号,防御性抛 [ArgumentError](携带原值)而非静默兜底 —— 直达
/// 分派宁失败可见,不可猜错目标页。
DueTarget decodeTarget(int targetKind, String targetId) {
  if (targetKind == kInboxTargetKindAccount) return AccountTarget(targetId);
  if (targetKind == kInboxTargetKindDebt) return DebtTarget(targetId);
  throw ArgumentError.value(targetKind, 'targetKind',
      'unknown inbox targetKind (expected $kInboxTargetKindAccount account / $kInboxTargetKindDebt debt)');
}

class InboxStore {
  InboxStore(this._db);
  final AppDatabase _db;

  // 行模型二选一(design LLD):直接用 drift 生成类 InboxEntry,表列即
  // 行模型、无映射层必要;页面/同步器消费字段均为原始存储形态。

  /// 待处理条目(state=0,createdAt 升序 —— 待办清单最旧优先)。
  Future<List<InboxEntry>> activeEntries() async =>
      (_db.select(_db.inboxEntries)
            ..where((t) => t.state.equals(InboxEntryState.pending.index))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// 全部条目(历史含待处理,收件箱页两区一次取;createdAt 升序)。
  Future<List<InboxEntry>> all() async =>
      (_db.select(_db.inboxEntries)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  /// 入窗 upsert(候选进入提醒窗口时调):不存在 → 插 state=0、
  /// createdAt=now;state=0 → 更新 title/amountCents/dueDate(候选滚动
  /// 刷新,createdAt 是小圆点基准不动);state≠0 → 不动(滚动老条目已
  /// 定态就不动,不复活 —— design ADR-3)。
  Future<void> upsertActive({
    required String entryKey,
    required String title,
    required int amountCents,
    required DateTime dueDate,
    required DueTarget target,
  }) async {
    final existing = await (_db.select(_db.inboxEntries)
          ..where((t) => t.entryKey.equals(entryKey)))
        .getSingleOrNull();
    final (targetKind, targetId) = _encodeTarget(target);
    if (existing == null) {
      await _db.into(_db.inboxEntries).insert(
            InboxEntriesCompanion.insert(
              entryKey: entryKey,
              type: kInboxTypeDueReminder,
              title: title,
              amountCents: amountCents,
              dueDate: _formatDate(dueDate),
              state: InboxEntryState.pending.index,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              targetKind: targetKind,
              targetId: targetId,
            ),
          );
    } else if (existing.state == InboxEntryState.pending.index) {
      await (_db.update(_db.inboxEntries)
            ..where((t) => t.entryKey.equals(entryKey)))
          .write(InboxEntriesCompanion(
        title: Value(title),
        amountCents: Value(amountCents),
        dueDate: Value(_formatDate(dueDate)),
      ));
    }
  }

  /// 定态:state=0 → handled/dismissed(写 handledAt);其余(不存在或
  /// 已定态)静默不动 —— 定态不可逆,不复活。
  Future<void> settle(String entryKey, {required InboxEntryState state}) async {
    assert(state != InboxEntryState.pending, 'settle 仅接受终态');
    await (_db.update(_db.inboxEntries)
          ..where((t) =>
              t.entryKey.equals(entryKey) &
              t.state.equals(InboxEntryState.pending.index)))
        .write(InboxEntriesCompanion(
          state: Value(state.index),
          handledAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
  }

  /// 上次查看时刻(从未看过 → null)。
  Future<DateTime?> readLastSeen() async {
    final row = await (_db.select(_db.appMeta)
          ..where((t) => t.key.equals(kInboxLastSeenKey)))
        .getSingleOrNull();
    if (row == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(int.parse(row.value));
  }

  /// 记录查看时刻(收件箱页打开即写,覆盖旧值)。
  Future<void> writeLastSeen(DateTime at) async {
    await _db.into(_db.appMeta).insert(
          AppMetaCompanion.insert(
            key: kInboxLastSeenKey,
            value: '${at.millisecondsSinceEpoch}',
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  /// DueTarget → (targetKind, targetId) 列编码。
  (int, String) _encodeTarget(DueTarget target) => switch (target) {
        AccountTarget(:final accountId) =>
          (kInboxTargetKindAccount, accountId),
        DebtTarget(:final debtId) => (kInboxTargetKindDebt, debtId),
      };

  /// 到期日 → yyyy-MM-dd 文本(本地日,与条目 key 的周期月口径一致)。
  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
