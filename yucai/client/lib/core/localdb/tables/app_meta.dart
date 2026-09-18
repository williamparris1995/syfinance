import 'package:drift/drift.dart';

/// 单行/键值元数据表(应用级一次性标记,如历史数据修复 v1 已执行)。
/// 不参与备份/同步,仅本地。
class AppMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
