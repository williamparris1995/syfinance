// schema v10→v11 迁移测试(2026-09 到期常显提醒,design ADR-4):新表
// inbox_entries(收件箱台账);仅建表,旧库升级无损。手法照 schema_v4_
// migration_test 先例:先以 v11 建库并埋行,剥离 v11 增量(DROP 收件箱表)
// 并回拨 user_version=10 得到忠实 v10 旧库,重开触发 onUpgrade(10→11) 断言。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v11_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV10ToV11() async {
    // 1) v11 建库 + 埋既有业务行(挂失表行:上一版 v10 的代表数据)。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
          "INSERT INTO reminder_dismissals (entry_id, dismissed_at) "
          "VALUES ('cc:a1:2026-09', '2026-09-20T10:00:00.000')");
      await db.close();
    }
    // 2) 伪造 v10 旧库:剥离 v11 增量(收件箱表)+ 版本回拨 10。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('DROP TABLE inbox_entries');
      await db.customStatement('PRAGMA user_version = 10');
      await db.close();
    }
    // 3) 重开:onUpgrade(10→11) 建收件箱表。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('v10→v11:inbox_entries 建出且可写读;既有业务行无损', () async {
    final db = await migrateV10ToV11();

    // 既有 v10 行无损。
    final dismissed = await db.customSelect(
      'SELECT entry_id FROM reminder_dismissals',
    ).get();
    expect(dismissed.single.read<String>('entry_id'), 'cc:a1:2026-09');

    // 收件箱表就绪:直插一行读回(列齐备、entryKey 唯一约束生效)。
    await db.customInsert(
      'INSERT INTO inbox_entries (entry_key, type, title, amount_cents, '
      'due_date, state, created_at, target_kind, target_id) '
      "VALUES ('e1', 'due_reminder', '房贷', 100000, '2026-09-30', 0, 1000, 1, 'd1')",
    );
    final rows = await db
        .customSelect('SELECT title, state FROM inbox_entries').get();
    expect(rows.single.read<String>('title'), '房贷');
    expect(rows.single.read<int>('state'), 0);
    // 唯一键 entryKey:同 key 二插被拒。
    expect(
      () => db.customInsert(
        'INSERT INTO inbox_entries (entry_key, type, title, amount_cents, '
        'due_date, state, created_at, target_kind, target_id) '
        "VALUES ('e1', 'due_reminder', '房贷', 1, '2026-09-30', 0, 1000, 1, 'd1')",
      ),
      throwsA(anything),
    );
  });
}
