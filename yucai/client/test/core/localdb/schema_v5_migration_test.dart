// schema v4→v5 迁移测试(2026-09 担保人字段 + 合同附件表)。
// - debts 加 guarantor_name / guarantor_contact(TEXT NOT NULL DEFAULT '',
//   旧行回填空串 = 无担保人);
// - 新表 contract_attachments(本地合同文件附件 v1,一债务至多一行);
// - 旧库升级无损(既有债务行原样保留)。
// 机制照 schema_v4_migration_test:先以当前 schema 建库埋行,剥离 v5 增量
// 并回拨 user_version=4 得忠实 v4 旧库,重开触发 onUpgrade(4→5)断言。
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_v5_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppDatabase> migrateV4ToV5() async {
    // 1) 当前 schema(v5)建库 + 埋既有债务行。
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
    // 2) 伪造 v4 旧库:剥离 v5 增量(担保人两列 + 附件表)+ 版本回拨 4。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement(
          'ALTER TABLE debts DROP COLUMN guarantor_name');
      await db.customStatement(
          'ALTER TABLE debts DROP COLUMN guarantor_contact');
      await db.customStatement('DROP TABLE contract_attachments');
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
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();
    }
    // 3) 重开:onUpgrade(4→5)补列(回填默认)+ 建附件表。
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    return db;
  }

  group('v4→v5 迁移', () {
    test('debts 担保人两列存在且旧行回填空串(= 无担保人)', () async {
      final db = await migrateV4ToV5();
      final debt = await db.debtDao.getDebtById('d1');
      expect(debt, isNotNull);
      expect(debt!.counterparty, '银行'); // 既有行无损。
      expect(debt.guarantorName, ''); // 回填默认。
      expect(debt.guarantorContact, '');
    });

    test('contract_attachments 建出且可读写', () async {
      final db = await migrateV4ToV5();
      await db
          .into(db.contractAttachments)
          .insert(ContractAttachmentsCompanion.insert(
            id: 'att1',
            debtId: 'd1',
            originalName: '借条.pdf',
            storedName: 'uuid.pdf',
            sizeBytes: 1024,
            attachedAt: DateTime.utc(2026, 9, 16),
          ));
      final rows = await db.select(db.contractAttachments).get();
      expect(rows, hasLength(1));
      expect(rows.first.originalName, '借条.pdf');
      expect(rows.first.debtId, 'd1');
    });

    test('新插入债务行携带担保人值往返', () async {
      final db = await migrateV4ToV5();
      await db.debtDao.insertDebt(DebtsCompanion.insert(
        id: 'd2',
        accountId: 'a2',
        counterparty: '亲友',
        interestRate: 0,
        amortizationMethod: 3,
        startDate: DateTime.utc(2026, 9, 1),
        dueDate: DateTime.utc(2027, 9, 1),
        totalPrincipalCents: 50000,
        debtType: 2,
        subtype: '',
        contact: '',
        contractRef: '',
        guarantorName: const Value('王担保'),
        guarantorContact: const Value('13800000000'),
        version: 1,
        createdAt: DateTime.utc(2026, 9, 16),
        updatedAt: DateTime.utc(2026, 9, 16),
      ));
      final debt = await db.debtDao.getDebtById('d2');
      expect(debt!.guarantorName, '王担保');
      expect(debt.guarantorContact, '13800000000');
      expect(debt.syncState, SyncState.synced);
    });
  });
}
