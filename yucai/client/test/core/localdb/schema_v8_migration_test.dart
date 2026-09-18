// schema v7→v8 迁移测试(一次性利息减免):Debts 加 interest_waived_cents
// (NOT NULL DEFAULT 0,存量行 = 无减免)。机制照 schema_v6_migration_test。
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v8_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV7ToV8() async {
    // 1) 当前 schema 建库 + 埋既有债务行。
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
        subtype: '',
        contact: '',
        contractRef: '',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ));
      await db.close();
    }
    // 2) 伪造 v7 旧库:剥离 v8 增量列 + 版本回拨 7。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
          'ALTER TABLE debts DROP COLUMN interest_waived_cents');
      await db.customStatement('PRAGMA user_version = 7');
      await db.close();
    }
    // 3) 重开:onUpgrade(7→8) 补列(默认 0 回填)。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('v7→v8 迁移 利息减免列存在且旧行回填 0', () async {
    final db = await migrateV7ToV8();
    final rows = await db.customSelect(
      'SELECT interest_waived_cents FROM debts WHERE id = ?',
      variables: [Variable.withString('d1')],
    ).get();
    expect(rows, hasLength(1));
    expect(rows.first.read<int>('interest_waived_cents'), 0);
  });

  test('v7→v8 迁移 新写入行携带减免值往返', () async {
    final db = await migrateV7ToV8();
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: 'd2',
      accountId: 'a1',
      counterparty: '银行2',
      interestRate: 0.06,
      amortizationMethod: 1,
      startDate: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2027, 9, 1),
      totalPrincipalCents: 1000000,
      debtType: 1,
      subtype: '',
      contact: '',
      contractRef: '',
      interestWaivedCents: const Value(50000),
      version: 1,
      createdAt: DateTime.utc(2026, 9, 2),
      updatedAt: DateTime.utc(2026, 9, 2),
    ));
    final row = await db.debtDao.getDebtById('d2');
    expect(row!.interestWaivedCents, 50000);
  });
}
