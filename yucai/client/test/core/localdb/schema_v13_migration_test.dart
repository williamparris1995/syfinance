// schema v12→v13 迁移测试(F50 卡贷额度占用):Debts 加
// counts_toward_card_limit(INTEGER NOT NULL DEFAULT 1,存量行 = 计入,
// 行为零变化)。机制照 schema_v8_migration_test 先例:v13 建库并埋行,
// 剥离 v13 增量(DROP 新列)+ 版本回拨 12 得忠实 v12 旧库,重开触发
// onUpgrade(12→13)断言。
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v13_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV12ToV13() async {
    // 1) 当前 schema 建库 + 埋既有债务行(v12 代表数据)。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.debtDao.insertDebt(DebtsCompanion.insert(
        id: 'd1',
        accountId: 'a1',
        counterparty: '银行',
        interestRate: 0.05,
        amortizationMethod: 1,
        startDate: DateTime.utc(2026, 9, 1),
        dueDate: DateTime.utc(2027, 9, 1),
        totalPrincipalCents: 1000000,
        debtType: 1,
        subtype: 'card_loan',
        contact: '',
        contractRef: '',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ));
      await db.close();
    }
    // 2) 伪造 v12 旧库:剥离 v13 增量列 + 版本回拨 12。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
          'ALTER TABLE debts DROP COLUMN counts_toward_card_limit');
      await db.customStatement('PRAGMA user_version = 12');
      await db.close();
    }
    // 3) 重开:onUpgrade(12→13) 补列(DEFAULT 1 回填 = 计入)。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('v12→v13 迁移 开关列存在且旧行回填 1(计入,行为零变化)', () async {
    final db = await migrateV12ToV13();
    final rows = await db.customSelect(
      'SELECT counts_toward_card_limit FROM debts WHERE id = ?',
      variables: [Variable.withString('d1')],
    ).get();
    expect(rows, hasLength(1));
    // INTEGER 列(bool 落 1/0):存量行回填默认 1 = true。
    expect(rows.first.read<int>('counts_toward_card_limit'), 1);
  });

  test('v12→v13 迁移 新写入行开关值往返(true/false 各一)', () async {
    final db = await migrateV12ToV13();
    Future<void> insertOn(String id, Value<bool> flag) =>
        db.debtDao.insertDebt(DebtsCompanion.insert(
          id: id,
          accountId: 'a1',
          counterparty: '银行$id',
          interestRate: 0.06,
          amortizationMethod: 1,
          startDate: DateTime.utc(2026, 9, 1),
          dueDate: DateTime.utc(2027, 9, 1),
          totalPrincipalCents: 1000000,
          debtType: 1,
          subtype: 'card_loan',
          contact: '',
          contractRef: '',
          countsTowardCardLimit: flag,
          version: 1,
          createdAt: DateTime.utc(2026, 9, 2),
          updatedAt: DateTime.utc(2026, 9, 2),
        ));
    await insertOn('d2', const Value(false));
    await insertOn('d3', const Value(true));
    expect((await db.debtDao.getDebtById('d2'))!.countsTowardCardLimit, false);
    expect((await db.debtDao.getDebtById('d3'))!.countsTowardCardLimit, true);
    // 缺省(不携带)→ DEFAULT 1 = true。
    await insertOn('d4', const Value.absent());
    expect((await db.debtDao.getDebtById('d4'))!.countsTowardCardLimit, true);
  });
}
