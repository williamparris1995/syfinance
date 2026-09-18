// 还款描述 Closure 残渣一次性修复(beforeOpen 数据修复)验证:
// 旧版本曾把函数对象插进描述("还款 Closure: ... (row)"),修复应经
// 期次表反查债务 counterparty 回填真实名称;幂等、无关联的行不动。
import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_repay_desc_fix');
    file = File('${dir.path}/fix.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> seed() async {
    final db = AppDatabase(NativeDatabase(file));
    // 债务 + 一笔期次(挂脏描述交易)。
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: 'd1',
      accountId: 'a1',
      counterparty: '招商银行',
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
    await db.into(db.paymentScheduleEntries).insert(
          PaymentScheduleEntriesCompanion.insert(
            id: 's1',
            debtId: 'd1',
            paymentDate: DateTime.utc(2026, 8, 1), // 过去(可标已还)
            principalCents: 80000,
            interestCents: 4000,
            totalCents: 84000,
            paidCents: 84000,
            paid: true,
            transactionId: const Value('txn-garbage'),
          ),
        );
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 'txn-garbage',
          transactionDate: DateTime.utc(2026, 10, 1),
          description:
              "还款 Closure: (Debt) => String from Function 'counterpartyOf..(row)'",
          version: 1,
          createdAt: DateTime.utc(2026, 10, 1),
          updatedAt: DateTime.utc(2026, 10, 1),
        ));
    await db.close();
  }

  test('重开后旧还款交易删除,替换为「标记已还」结转交易', () async {
    await seed();
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    // 旧交易(含 Closure 残渣)已删除。
    // 首次建库时修复已空跑并写入标记;模拟「升级时已有数据」场景:
    // 清标记 → 显式重跑(真实升级路径 = 旧库带数据首次打开,天然命中)。
    await db.customStatement(
        "DELETE FROM app_meta WHERE key = 'repay_history_settlement_v1'");
    await runRepaymentHistoryRepairOnce(db);
    final old = await db.customSelect(
      'SELECT COUNT(*) c FROM transactions WHERE id = ?',
      variables: [Variable.withString('txn-garbage')],
    ).getSingle();
    expect(old.read<int>('c'), 0);
    // 结转交易存在:描述 + 债务户侧金额 = 该期本息合计。
    final settle = await db.customSelect(
      'SELECT description FROM transactions WHERE id = ?',
      variables: [Variable.withString('settle-s1')],
    ).getSingle();
    expect(settle.read<String>('description'), '标记已还 招商银行');
    final entry = await db.customSelect(
      'SELECT debit_cents, credit_cents, account_id FROM transaction_entries '
      'WHERE transaction_id = ? AND account_id = ?',
      variables: [
        Variable.withString('settle-s1'),
        Variable.withString('a1')
      ],
    ).getSingle();
    expect(entry.read<int>('debit_cents'), 84000); // borrowedIn:借记债务户
    expect(entry.read<int>('credit_cents'), 0);
    // 期次已解除交易关联。
    final link = await db.customSelect(
      'SELECT transaction_id FROM payment_schedule_entries WHERE id = ?',
      variables: [Variable.withString('s1')],
    ).getSingle();
    expect(link.data['transaction_id'], isNull);
  });

  test('幂等:再次打开不重复生成结转', () async {
    await seed();
    final first = AppDatabase(NativeDatabase(file));
    await first.close();
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() => db.close());
    // 模拟升级首跑:清标记 → 重跑。
    await db.customStatement(
        "DELETE FROM app_meta WHERE key = 'repay_history_settlement_v1'");
    await runRepaymentHistoryRepairOnce(db);
    final cnt1 = await db.customSelect(
      "SELECT COUNT(*) c FROM transactions WHERE id LIKE 'settle-%'",
    ).getSingle();
    expect(cnt1.read<int>('c'), 1);
    // 修复后再次打开:不得重复生成。
    final second = AppDatabase(NativeDatabase(file));
    await second.close();
    final cnt2 = await db.customSelect(
      "SELECT COUNT(*) c FROM transactions WHERE id LIKE 'settle-%'",
    ).getSingle();
    expect(cnt2.read<int>('c'), 1);
    // 标记存在。
    final marker = await db.customSelect(
      "SELECT value FROM app_meta WHERE key = 'repay_history_settlement_v1'",
    ).getSingle();
    expect(marker.read<String>('value'), 'done');
  });
}
