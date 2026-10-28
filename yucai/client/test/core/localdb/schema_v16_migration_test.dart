// schema v15→v16 迁移测试(F71 durable 审计):增 agent_audit 表 +
// created_millis 倒序索引。机制照 schema_v14_migration_test 先例:v16
// 建库,剥离 v16 增量(DROP 新表)+ 版本回拨 15 得忠实 v15 旧库,重开
// 触发 onUpgrade(15→16)断言;同时钉「schemaVersion 与迁移步同步」与
// spec FR-1 迁移幂等场景(表建立零数据丢失,重复启动无副作用)。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v16_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// v15 旧库(带一行存量账户数据)→ 重开迁移到 v16。
  Future<AppDatabase> migrateV15ToV16() async {
    // 1) 当前 schema(v16)建库 + 存量数据(迁移零丢断言素材)。
    {
      final database = AppDatabase(NativeDatabase(file));
      await database.customSelect('SELECT 1').get();
      await database.into(database.accounts).insert(AccountsCompanion.insert(
            id: 'acc-keep',
            name: 'Cash',
            accountType: 1,
            category: 1,
            currencyCode: 'CNY',
            initialBalanceCents: 500,
            currentBalanceCents: 500,
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
            createdAt: DateTime.utc(2026, 10, 1),
            updatedAt: DateTime.utc(2026, 10, 1),
          ));
      await database.close();
    }
    // 2) 伪造 v15 旧库:剥离 v16 增量表(索引随表级联删除)+ 回拨 15。
    {
      final database = AppDatabase(NativeDatabase(file));
      await database.customStatement('DROP TABLE agent_audit');
      await database.customStatement('PRAGMA user_version = 15');
      await database.close();
    }
    // 3) 重开:onUpgrade(15→16) 建表 + 建索引。
    final database = AppDatabase(NativeDatabase(file));
    addTearDown(() => database.close());
    await database.customSelect('SELECT 1').get();
    return database;
  }

  Future<int> userVersion(AppDatabase database) async => (await database
          .customSelect('PRAGMA user_version')
          .get())
      .first
      .read<int>('user_version');

  test('v15→v16 迁移:agent_audit 表+索引就位,存量数据零丢失', () async {
    final database = await migrateV15ToV16();

    expect(await userVersion(database), greaterThanOrEqualTo(16),
        reason: 'schemaVersion 必须 ≥ 16 才会触发本步迁移');
    // 表 + 索引各恰一个(sqlite_master 钉死,不重复建)。
    final tables = await database.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='agent_audit'",
        readsFrom: {database.agentAudits}).get();
    expect(tables, hasLength(1));
    final indexes = await database.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name='agent_audit_created_millis_idx'",
        readsFrom: {database.agentAudits}).get();
    expect(indexes, hasLength(1));
    // 迁移零丢:v15 存量账户行原样健在。
    final accounts = await database.accountDao.getAllAccounts();
    expect(accounts.where((a) => a.id == 'acc-keep'), hasLength(1));
  });

  test('迁移幂等:重复启动无副作用,审计行不丢不重', () async {
    final database = await migrateV15ToV16();

    // 迁移后写一行审计留痕。
    await database.agentAuditDao.insertEvent(AgentAuditsCompanion.insert(
      createdMillis: 1770000000000,
      tool: 'transaction_add',
      summary: 'TransactionAdd(direction=out, amountCents=3500)',
      ok: true,
      idempotencyKey: 'key-mig-1',
    ));
    await database.close();

    // 重复启动:版本已 16,onUpgrade 不再触发(无 duplicate index/表风险),
    // 既有行(审计 + 账户)不丢不重。
    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(() => reopened.close());
    await reopened.customSelect('SELECT 1').get();

    expect(await userVersion(reopened), greaterThanOrEqualTo(16));
    expect(await reopened.agentAuditDao.count(), 1,
        reason: '重开不丢审计行,也不重复迁移产出幽灵行');
    expect(
      (await reopened.accountDao.getAllAccounts())
          .where((a) => a.id == 'acc-keep'),
      hasLength(1),
    );
  });
}
