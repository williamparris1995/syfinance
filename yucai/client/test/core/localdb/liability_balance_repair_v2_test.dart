// 负债余额修复 v2(2026-10-06 dev 反馈定案)验证:
//   1) 挂债负债户余额对齐 +Σ(totalPrincipal − Σpaid)(F36 同式,漂移复发
//      场景重跑);
//   2) 负余额且无 borrowedIn 债的负债户归 0(「删除清账」冲销打穿场景,
//      用户确认无此债)。
// 对方科目 = 权益户「历史还款结转」;分录经交易管道联动余额;app_meta
// 'liability_balance_repair_v2' 幂等,重跑不重复。
// 风格照 f36_liability_balance_repair_test(真 drift 文件库;首开空库已置
// 标记,清标记模拟「升级时已有漂移数据」的首跑路径)。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_liab_repair_v2');
    file = File('${dir.path}/fix.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> seed() async {
    final db = AppDatabase(NativeDatabase(file));
    Future<void> acc(String id, int type, int bal,
            {int category = 9}) =>
        db.accountDao.insertAccount(AccountsCompanion.insert(
          id: id,
          name: 'acc-$id',
          accountType: type,
          category: category,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          currentBalanceCents: bal,
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
    // a1:挂债负债户,余额低于不变式(target 916000,bal 500000 → +416000)。
    await acc('a1', 2, 500000);
    // a4:无挂债负债户,负余额(删除清账打穿)→ 归 0(delta +300000)。
    await acc('a4', 2, -300000);
    // a5:无挂债负债户,正欠款(信用卡类)—— 不动。
    await acc('a5', 2, 250000, category: 2);
    // a3:资产户 —— 不动。
    await acc('a3', 1, 777777, category: 2);
    // d1@a1(borrowedIn):total 1000000,一期已还 84000 → remaining 916000。
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: 'd1',
      accountId: 'a1',
      counterparty: '招行',
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
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    ));
    await db.into(db.paymentScheduleEntries).insert(
          PaymentScheduleEntriesCompanion.insert(
            id: 's-d1-1',
            debtId: 'd1',
            paymentDate: DateTime.utc(2026, 10, 1),
            principalCents: 80000,
            interestCents: 4000,
            totalCents: 84000,
            paidCents: 84000,
            paid: true,
          ),
        );
    await db.close();
  }

  Future<AppDatabase> open() async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    return db;
  }

  Future<void> clearMarker(AppDatabase db) => db.customStatement(
      "DELETE FROM app_meta WHERE key = 'liability_balance_repair_v2'");

  Future<int> repairTxnCount(AppDatabase db) async {
    final r = await db.customSelect(
      "SELECT COUNT(*) c FROM transactions WHERE description LIKE '负债余额修复v2%'",
    ).getSingle();
    return r.read<int>('c');
  }

  test('漂移库修复:挂债户对齐 Σremaining,负余额无挂债户归 0,其余不动',
      () async {
    await seed();
    final db = await open();
    await clearMarker(db);
    await runLiabilityBalanceRepairV2(db);

    expect((await db.accountDao.getAccountById('a1'))!.currentBalanceCents,
        916000,
        reason: '挂债户对齐 +Σ(totalPrincipal−Σpaid)');
    expect((await db.accountDao.getAccountById('a4'))!.currentBalanceCents, 0,
        reason: '负余额无挂债户归 0');
    expect((await db.accountDao.getAccountById('a5'))!.currentBalanceCents,
        250000,
        reason: '正欠款无挂债户(卡类)不动');
    expect((await db.accountDao.getAccountById('a3'))!.currentBalanceCents,
        777777,
        reason: '资产户不动');

    // 两笔修复分录:a1 delta>0 → credit 负债;a4 delta>0 → credit 负债。
    expect(await repairTxnCount(db), 2);
    final a4Entry = await db.customSelect(
      'SELECT debit_cents d, credit_cents c FROM transaction_entries '
      "WHERE account_id = 'a4' AND transaction_id IN ("
      "SELECT id FROM transactions WHERE description LIKE '负债余额修复v2%')",
    ).getSingle();
    expect(a4Entry.read<int>('d'), 0);
    expect(a4Entry.read<int>('c'), 300000);

    // 幂等:重跑不再生成新分录。
    await clearMarker(db);
    await runLiabilityBalanceRepairV2(db);
    expect(await repairTxnCount(db), 2, reason: '对齐后 delta=0,重跑无新分录');
  });
}
