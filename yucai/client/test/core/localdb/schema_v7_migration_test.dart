// schema v6→v7 迁移测试(2026-09-17「上传卡住」修复)。
// - contract_attachments 整表重建:去掉 debt_id 对本地 debts 的外键
//   (在线创建的债务头行由镜像异步回填,先到的附件行命中 FK 打断表单 pop);
// - 既有附件行数据无损迁入新表;
// - 重建后附件行容忍指向不在本地 debts 表的服务端 id(v7 核心语义)。
// 机制照 schema_v5/v6:先以当前 schema 建库,把附件表手工还原为 v6 带 FK
// 形态并回拨 user_version=6,重开触发 onUpgrade(6→7)断言。
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
    dir = await Directory.systemTemp.createTemp('yucai_v7_migration');
    file = File('${dir.path}/mig.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// 伪造 v6 旧库:当前 schema 建库 + 埋债务行,再把附件表还原为 v6 带 FK
  /// 形态(手写 DDL 含 REFERENCES debts)+ 埋一行合法附件 + 版本回拨 6。
  /// 第二阶段打开时 user_version 已是当前版,不触发迁移,可安全改表降版。
  Future<void> buildFakeV6() async {
    // 1) 当前 schema 建库 + 埋债务行。
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
    // 2) 附件表还原为 v6 带 FK 形态 + 埋一行合法附件(debt_id 指向存在
    //    的债务,否则 v6 FK 下插不进)+ 版本回拨 6。
    {
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('DROP TABLE contract_attachments');
      await db.customStatement('''
        CREATE TABLE contract_attachments (
          "id" TEXT NOT NULL PRIMARY KEY,
          "debt_id" TEXT NOT NULL CONSTRAINT contract_attachments_debt_id_fkey
            REFERENCES "debts" ("id") ON DELETE CASCADE,
          "original_name" TEXT NOT NULL,
          "stored_name" TEXT NOT NULL,
          "size_bytes" INTEGER NOT NULL,
          "attached_at" TEXT NOT NULL
        )
      ''');
      await db.customStatement(
          "INSERT INTO contract_attachments VALUES ('att-old', 'd1', '旧借条.pdf', 'old.pdf', 2048, '2026-09-16T00:00:00.000Z')");
      await db.customStatement(
          'ALTER TABLE debts DROP COLUMN interest_waived_cents');
      await db.customStatement('PRAGMA user_version = 6');
      await db.close();
    }
  }

  group('v6→v7 迁移', () {
    test('附件表重建:既有行数据无损迁入', () async {
      await buildFakeV6();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(() => db.close());
      final rows = await db.select(db.contractAttachments).get();
      expect(rows, hasLength(1));
      expect(rows.first.id, 'att-old');
      expect(rows.first.debtId, 'd1');
      expect(rows.first.originalName, '旧借条.pdf');
      expect(rows.first.sizeBytes, 2048);
    });

    test('FK 已移除:附件行容忍指向不在本地 debts 的服务端 id(修复核心)',
        () async {
      await buildFakeV6();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(() => db.close());
      // 在线创建债务的头行尚未经镜像落到本地 —— v7 下必须可插(v6 会
      // FOREIGN KEY constraint failed,即「上传卡住」缺陷)。
      await db.into(db.contractAttachments).insert(
          ContractAttachmentsCompanion.insert(
            id: 'att-new',
            debtId: 'server-side-uuid-not-in-local-debts',
            originalName: '借条.pdf',
            storedName: 'uuid.pdf',
            sizeBytes: 1024,
            attachedAt: DateTime.utc(2026, 9, 17),
          ));
      final rows = await db.select(db.contractAttachments).get();
      expect(rows, hasLength(2));
    });

    test('v6 旧临时表已清理', () async {
      await buildFakeV6();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(() => db.close());
      final tables = await db.customSelect(
          "SELECT name FROM sqlite_master WHERE type='table' "
          "AND name LIKE 'contract_attachments%'").get();
      expect(tables.map((r) => r.read<String>('name')),
          ['contract_attachments']); // 仅主表,v6 备份表已 drop。
    });

    test('债务行与既有数据无损', () async {
      await buildFakeV6();
      final db = AppDatabase(NativeDatabase(file));
      addTearDown(() => db.close());
      final debt = await db.debtDao.getDebtById('d1');
      expect(debt, isNotNull);
      expect(debt!.counterparty, '银行');
      expect(debt.syncState, SyncState.synced);
    });
  });
}
