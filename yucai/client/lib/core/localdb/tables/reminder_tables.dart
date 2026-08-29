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
