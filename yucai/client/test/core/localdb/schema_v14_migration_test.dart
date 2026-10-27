// schema v13→v14 迁移测试(2026-10-20 广发账单日变更):增
// CardBillingCycleOverrides 账单周期过渡覆盖表(breakdown 消费,行由
// repairs 播种)。机制照 schema_v13_migration_test 先例:v14 建库,剥离
// v14 增量(DROP 新表)+ 版本回拨 13 得忠实 v13 旧库,重开触发
// onUpgrade(13→14)断言 —— 本测试同时钉死「schemaVersion 与迁移步
// 同步」(2026-10-20 曾漏 bump 版本号致迁移静默跳过,线上表缺失)。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v14_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV13ToV14() async {
    // 1) 当前 schema(v14)建库。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customSelect('SELECT 1').get();
      await db.close();
    }
    // 2) 伪造 v13 旧库:剥离 v14 增量表 + 版本回拨 13。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('DROP TABLE card_billing_cycle_overrides');
      await db.customStatement('PRAGMA user_version = 13');
      await db.close();
    }
    // 3) 重开:onUpgrade(13→14) 建表。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('v13→v14 迁移 过渡覆盖表存在且行可写读(版本号同步钉死)', () async {
    final db = await migrateV13ToV14();
    final version =
        (await db.customSelect('PRAGMA user_version').get()).first.read<int>('user_version');
    // v15 后 user_version 走到 15;本步只钉「v13 库迁上来 ≥14 且覆盖表
    // 可用」,不钉死当前版本(避免每次 bump 都改此断言)。
    expect(version, greaterThanOrEqualTo(14),
        reason: 'schemaVersion 必须 ≥ 14 才会触发本步迁移');
    await db.into(db.cardBillingCycleOverrides).insert(
          CardBillingCycleOverridesCompanion.insert(
            accountId: 'card-1',
            cycleStart: DateTime.utc(2026, 9, 19),
            nextBillingDate: DateTime.utc(2026, 11, 6),
          ),
        );
    final row = await (db.select(db.cardBillingCycleOverrides)
          ..where((t) => t.accountId.equals('card-1')))
        .getSingle();
    expect(DateTime(row.cycleStart.year, row.cycleStart.month, row.cycleStart.day),
        DateTime(2026, 9, 19));
    expect(
        DateTime(row.nextBillingDate.year, row.nextBillingDate.month,
            row.nextBillingDate.day),
        DateTime(2026, 11, 6));
  });
}
