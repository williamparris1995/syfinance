// F17-T2(spec FR-3,design ADR-3):schema v3→v4 迁移测试 —— 新表
// sync_cursors(拉取游标,单行);旧库升级无损。手法照 schema_v3_migration_
// test 先例:先以 v4 建库并埋行,剥离 v4 增量(DROP 游标表)并回拨
// user_version=3 得到忠实 v3 旧库,重开触发 onUpgrade(3→4) 断言。
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v4_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV3ToV4() async {
    // 1) v4 建库 + 埋既有业务行。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.tagDao.insertTag(TagsCompanion.insert(
        id: 't1',
        name: '旧库标签',
        color: '#000000',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
        syncState: const Value(SyncState.synced),
      ));
      await db.close();
    }
    // 2) 伪造 v3 旧库:剥离 v4 增量 + 版本回拨 3。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('DROP TABLE sync_cursors');
      // v5 增量(担保人两列)一并剥离(重开走 3→最新 完整链)。
      await db.customStatement(
          'ALTER TABLE debts DROP COLUMN guarantor_name');
      await db.customStatement(
          'ALTER TABLE debts DROP COLUMN guarantor_contact');
      // v6 增量(周期规则统一列)一并剥离:重开的 onUpgrade 链会一路补到
      // 最新版本,旧库不得残留任何后续版本列(否则 addColumn 撞重名)。
      for (final stmt in [
        'ALTER TABLE debts DROP COLUMN cycle',
        'ALTER TABLE debts DROP COLUMN interval',
        'ALTER TABLE debts DROP COLUMN weekday_mask',
        'ALTER TABLE debts DROP COLUMN monthly_mode',
        'ALTER TABLE debts DROP COLUMN nth',
        'ALTER TABLE debts DROP COLUMN interest_waived_cents',
        'ALTER TABLE transaction_templates DROP COLUMN interval',
        'ALTER TABLE transaction_templates DROP COLUMN weekday_mask',
        'ALTER TABLE transaction_templates DROP COLUMN monthly_mode',
        'ALTER TABLE transaction_templates DROP COLUMN nth',
      ]) {
        await db.customStatement(stmt);
      }
      await db.customStatement('PRAGMA user_version = 3');
      await db.close();
    }
    // 3) 重开:onUpgrade(3→4) 建游标表。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    return db;
  }

  test('v3→v4:sync_cursors 建出且可读写;既有业务行无损', () async {
    final db = await migrateV3ToV4();

    // 既有行无损。
    final tag = await db.tagDao.getTagById('t1');
    expect(tag, isNotNull);
    expect(tag!.name, '旧库标签');

    // 游标表就绪:缺省读 0(since=0 全量重拉,幂等无害);写入读回。
    expect(await db.syncCursorDao.readLastPulledVersion(), 0);
    await db.syncCursorDao.writeLastPulledVersion(42);
    expect(await db.syncCursorDao.readLastPulledVersion(), 42);
  });
}
