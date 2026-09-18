// F10 T2(2026-09-04):schema v2→v3 迁移测试(spec FR-3/FR-4,design ADR-2/4)。
// - 8 头表加 sync_state TEXT NOT NULL DEFAULT 'synced'(旧行回填 synced);
// - 新表 sync_tombstones(module+entityId 主键);
// - 旧库升级无损(既有行原样保留)。
//
// 库内无 drift 迁移测试先例,按任务简报走「NativeDatabase + 手动
// schemaVersion 步进」:先以 v3 建库并埋行,再剥离 v3 增量(DROP 列/墓碑表)
// 并把 user_version 回拨为 2(drift 原生以该 pragma 记版本),得到忠实的
// v2 旧库;重开触发 onUpgrade(2→3) 断言迁移效果。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v3_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV2ToV3() async {
    // 1) v3 建库 + 埋既有行(此时列尚存在,行值无关紧要)。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.accountDao.insertAccount(_accountRow('a1'));
      await db.tagDao.insertTag(TagsCompanion.insert(
        id: 't1',
        name: 'n',
        color: '#000000',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ));
      await db.close();
    }
    // 2) 伪造 v2 旧库:剥离全部 v3 增量 + 版本回拨 2。
    {
      final db = AppDatabase(NativeDatabase(file));
      for (final table in const [
        'accounts',
        'transactions',
        'debts',
        'budgets',
        'goals',
        'holdings',
        'tags',
        'transaction_templates',
      ]) {
        await db.customStatement('ALTER TABLE $table DROP COLUMN sync_state');
      }
      await db.customStatement('DROP TABLE sync_tombstones');
      // v5 增量(担保人两列)也一并剥离:重开触发的是 2→最新 的完整
      // onUpgrade 链,旧库不得残留任何后续版本列(否则 addColumn 撞重名)。
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
      await db.customStatement('PRAGMA user_version = 2');
      await db.close();
    }
    // 3) 重开:onUpgrade(2→3) 补列(回填默认)+ 建墓碑表。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    return db;
  }

  group('v2→v3 迁移', () {
    test('8 头表 sync_state 列存在且旧行回填 synced', () async {
      final db = await migrateV2ToV3();
      // 既有行无损 + 回填默认 synced。
      final account = await db.accountDao.getAccountById('a1');
      expect(account, isNotNull);
      expect(account!.name, '现金');
      expect(account.syncState, 'synced');
      final tag = await db.tagDao.getTagById('t1');
      expect(tag!.syncState, 'synced');
      // 其余 6 头表加列成功(空表也有列,PRAGMA 断言列存在)。
      for (final table in const [
        'transactions',
        'debts',
        'budgets',
        'goals',
        'holdings',
        'transaction_templates',
      ]) {
        final cols = await db
            .customSelect('PRAGMA table_info($table)')
            .get();
        expect(
          cols.map((r) => r.data['name']),
          contains('sync_state'),
          reason: '$table 缺少 sync_state 列',
        );
      }
    });

    test('墓碑表随迁移建出且可读写', () async {
      final db = await migrateV2ToV3();
      expect(await db.syncTombstoneDao.getAllTombstones(), isEmpty);
      await db.syncTombstoneDao.upsertTombstone(
          SyncTombstonesCompanion.insert(
              module: 'account', entityId: 'a1', deletedAt: DateTime.now()));
      expect((await db.syncTombstoneDao.getAllTombstones()).length, 1);
    });
  });

  group('新库(onCreate)即 v3', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase(file));
      addTearDown(() => db.close());
    });

    test('插入缺省 syncState 的行走列默认 synced', () async {
      await db.accountDao.insertAccount(_accountRow('a2'));
      expect((await db.accountDao.getAccountById('a2'))!.syncState, 'synced');
    });

    test('墓碑 upsert 幂等(同键覆盖不重行)', () async {
      final dao = db.syncTombstoneDao;
      await dao.upsertTombstone(SyncTombstonesCompanion.insert(
          module: 'transaction',
          entityId: 'x1',
          deletedAt: DateTime.utc(2026, 9, 4, 1)));
      await dao.upsertTombstone(SyncTombstonesCompanion.insert(
          module: 'transaction',
          entityId: 'x1',
          deletedAt: DateTime.utc(2026, 9, 4, 2)));
      final all = await dao.getAllTombstones();
      expect(all, hasLength(1));
      expect(all.single.deletedAt, DateTime.utc(2026, 9, 4, 2));
    });
  });
}

AccountsCompanion _accountRow(String id) => AccountsCompanion.insert(
      id: id,
      name: '现金',
      accountType: 1,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 100,
      currentBalanceCents: 100,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: false,
      sortOrder: 0,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    );
