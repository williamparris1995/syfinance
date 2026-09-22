import 'package:drift/drift.dart';

/// 通知模块契约表(B1):当日提醒去重记录。
/// tier 为 DueTier 枚举序数(0=t3/1=t0/2=overdue),存 int 保持 localdb
/// 与 notifications 模块解耦(映射在 DriftReminderLogStore)。
class ReminderLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId => text()();
  IntColumn get tier => integer()();
  TextColumn get sentDate => text()(); // yyyy-MM-dd(本地日)

  @override
  Set<Column> get primaryKey => {id};

  /// 同日同档唯一(insertOrIgnore 幂等的约束基础;review R1:无索引则
  /// 并发扫描可插重行,消费端 getSingleOrNull 会抛错)。
  @override
  List<Set<Column>> get uniqueKeys => [
        {entryId, tier, sentDate}
      ];
}

/// 「不再提醒」挂失记录(2026-09 信用卡还款催办):按提醒条目 id 挂失,
/// 未还清也可手动/自动(最低还款、分期后)停掉本期催办。本地表(提醒
/// 本就是客户端本地行为,服务端无 reminder 域,不上行同步)。下一个
/// 周期月生成新 entryId,挂失自然过期。
class ReminderDismissals extends Table {
  TextColumn get entryId => text()();
  DateTimeColumn get dismissedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {entryId};
}
