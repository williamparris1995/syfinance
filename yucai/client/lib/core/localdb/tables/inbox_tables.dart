import 'package:drift/drift.dart';

/// 收件箱条目表(2026-09 到期常显提醒,design ADR-4):状态真相驱动的
/// 提醒中心台账,候选进入提醒窗口即入箱(唯一键 entryKey 复用候选
/// entryId:期次裸 id / cc:acc:yyyy-MM),状态流转仅由读侧 syncer 写,
/// 无用户手工标态动线(spec FR-6)。历史永久保留(月个位数量级)。
/// state/targetKind 存 int 保持 localdb 与 notifications 模块解耦
/// (映射在 InboxStore,照 ReminderLogs.tier 先例)。
class InboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryKey => text()(); // 候选 entryId(期次裸 id / cc:acc:yyyy-MM)
  TextColumn get type => text()(); // 恒 'due_reminder'(类型预留)
  TextColumn get title => text()();
  IntColumn get amountCents => integer()();
  TextColumn get dueDate => text()(); // yyyy-MM-dd
  IntColumn get state => integer()(); // 0 待处理/1 已处理/2 已挂失
  IntColumn get createdAt => integer()(); // epochMs(小圆点基准)
  IntColumn get handledAt => integer().nullable()(); // 定态时刻 epochMs
  IntColumn get targetKind => integer()(); // 0 account/1 debt
  TextColumn get targetId => text()();

  @override
  Set<Column> get primaryKey => {id};

  /// entryKey 唯一:入窗 upsert 不重复插的约束基础。
  @override
  List<Set<Column>> get uniqueKeys => [
        {entryKey}
      ];
}
