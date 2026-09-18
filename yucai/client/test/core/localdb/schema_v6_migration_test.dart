// schema v5→v6 迁移测试(周期规则统一:订阅 template + 借贷 debt)。
// - transaction_templates 加 interval(默认 1)/weekday_mask/monthly_mode/
//   nth(默认 0)四列;
// - debts 加 cycle(默认 2=monthly)/interval(默认 1)/weekday_mask/
//   monthly_mode/nth(默认 0)五列;
// - 旧行零迁移(默认值即旧「按月/单间隔」行为),既有行无损。
// 机制照 schema_v5_migration_test:先以当前 schema 建库埋行,剥离 v6 增量
// 并回拨 user_version=5 得忠实 v5 旧库,重开触发 onUpgrade(5→6) 断言。
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v6_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV5ToV6() async {
    // 1) 当前 schema 建库 + 埋既有模板/债务行。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.templateDao.insertTemplate(TransactionTemplatesCompanion.insert(
        id: 'tpl1',
        name: '房租',
        description: '',
        amountCents: 300000,
        direction: 1,
        sourceAccountId: 'a1',
        cycle: 2,
        cycleDays: 0,
        billingDay: 1,
        nextDate: DateTime.utc(2026, 10, 1),
        startDate: DateTime.utc(2026, 9, 1),
        autoRecord: false,
        paused: false,
        category: '',
        version: 1,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 1),
      ));
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
    // 2) 伪造 v5 旧库:剥离 v6 增量(9 列)+ 版本回拨 5。
    {
      final db = AppDatabase(NativeDatabase(file));
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
      await db.customStatement('PRAGMA user_version = 5');
      await db.close();
    }
    // 3) 重开:onUpgrade(5→6) 补 9 列(默认值回填旧行)。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    await db.customSelect('SELECT 1').get();
    return db;
  }

  test('v5→v6 迁移 模板 4 列存在且旧行回填默认(1/0/0/0)', () async {
    final db = await migrateV5ToV6();
    final rows = await db.customSelect(
      'SELECT interval, weekday_mask, monthly_mode, nth '
      'FROM transaction_templates WHERE id = ?',
      variables: [Variable.withString('tpl1')],
    ).get();
    expect(rows, hasLength(1));
    expect(rows.first.read<int>('interval'), 1);
    expect(rows.first.read<int>('weekday_mask'), 0);
    expect(rows.first.read<int>('monthly_mode'), 0);
    expect(rows.first.read<int>('nth'), 0);
  });

  test('v5→v6 迁移 债务 5 列存在且旧行回填默认(2/1/0/0/0)', () async {
    final db = await migrateV5ToV6();
    final rows = await db.customSelect(
      'SELECT cycle, interval, weekday_mask, monthly_mode, nth '
      'FROM debts WHERE id = ?',
      variables: [Variable.withString('d1')],
    ).get();
    expect(rows, hasLength(1));
    expect(rows.first.read<int>('cycle'), 2, reason: '旧行 = 按月');
    expect(rows.first.read<int>('interval'), 1);
    expect(rows.first.read<int>('weekday_mask'), 0);
    expect(rows.first.read<int>('monthly_mode'), 0);
    expect(rows.first.read<int>('nth'), 0);
  });

  test('v5→v6 迁移 新写入行携带规则值往返', () async {
    final db = await migrateV5ToV6();
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: 'd2',
      accountId: 'a1',
      counterparty: '亲友',
      interestRate: 0,
      amortizationMethod: 1,
      startDate: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2026, 12, 1),
      totalPrincipalCents: 500000,
      debtType: 1,
      subtype: '',
      contact: '',
      contractRef: '',
      cycle: const Value(1), // weekly
      interval: const Value(2),
      weekdayMask: const Value(1),
      monthlyMode: const Value(0),
      nth: const Value(0),
      version: 1,
      createdAt: DateTime.utc(2026, 9, 2),
      updatedAt: DateTime.utc(2026, 9, 2),
    ));
    final row = await db.debtDao.getDebtById('d2');
    expect(row, isNotNull);
    expect(row!.cycle, 1);
    expect(row.interval, 2);
    expect(row.weekdayMask, 1);
  });
}
