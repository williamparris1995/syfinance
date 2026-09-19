// F36 存量迁移(T3,design ADR-3/6):负债账户余额漂移一次性修复验证。
// 北极星不变式(存储口径):负债账户 current_balance_cents ==
// +Σ(名下 borrowedIn 债 remainingPrincipalCents),其中 remaining =
// totalPrincipalCents − Σ(entry.paidCents)(与 _toEntity 同式)。
// repair 逐负债账户 delta 单笔调整分录(对方 = 权益户「历史还款结转」),
// app_meta `f36_liability_balance_repair_v1` 幂等;重跑不重复。
// 风格照 repayment_desc_repair_test(真 drift 文件库;首开空库已置标记,
// 清标记模拟「升级时已有漂移数据」的首跑路径)。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yucai_f36_repair');
    file = File('${dir.path}/fix.db');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> seed() async {
    final db = AppDatabase(NativeDatabase(file));
    // 负债户 a1:余额低于不变式(target 916000,bal 500000 → delta +416000)。
    // 负债户 a2:余额高于不变式(target 400000,bal 600000 → delta −200000)。
    // 资产户 a3(borrowedOut 应收挂户):余额漂移也必须不动。
    Future<void> acc(String id, int type, int bal) =>
        db.accountDao.insertAccount(AccountsCompanion.insert(
          id: id,
          name: 'acc-$id',
          accountType: type,
          category: type == 2 ? 9 : 2,
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
          createdAt: DateTime.utc(2026, 9, 1),
          updatedAt: DateTime.utc(2026, 9, 1),
        ));
    await acc('a1', 2, 500000);
    await acc('a2', 2, 600000);
    await acc('a3', 1, 777777);
    // d1@a1(borrowedIn):total 1000000,一期已还 84000(历史结转,无关联
    // 交易 → repayment-history repair 不触碰)→ remaining 916000。
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
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
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
    // d2@a2(borrowedIn):total 400000,两期全未还 → remaining 400000。
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: 'd2',
      accountId: 'a2',
      counterparty: '网贷',
      interestRate: 0.12,
      amortizationMethod: 1,
      startDate: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2027, 3, 1),
      totalPrincipalCents: 400000,
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
            id: 's-d2-1',
            debtId: 'd2',
            paymentDate: DateTime.utc(2026, 10, 1),
            principalCents: 200000,
            interestCents: 0,
            totalCents: 200000,
            paidCents: 0,
            paid: false,
          ),
        );
    // d3@a3(borrowedOut 债权):应收口径,本票不参与负债修复。
    await db.debtDao.insertDebt(DebtsCompanion.insert(
      id: 'd3',
      accountId: 'a3',
      counterparty: '老王',
      interestRate: 0.0,
      amortizationMethod: 1,
      startDate: DateTime.utc(2026, 9, 1),
      dueDate: DateTime.utc(2027, 9, 1),
      totalPrincipalCents: 900000,
      debtType: 2,
      subtype: '',
      contact: '',
      contractRef: '',
      version: 1,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 1),
    ));
    await db.close();
  }

  Future<AppDatabase> open() async {
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    return db;
  }

  Future<void> clearMarker(AppDatabase db) => db.customStatement(
      "DELETE FROM app_meta WHERE key = 'f36_liability_balance_repair_v1'");

  Future<int> repairTxnCount(AppDatabase db) async {
    final r = await db.customSelect(
      "SELECT COUNT(*) c FROM transactions WHERE description LIKE 'F36 余额修复%'",
    ).getSingle();
    return r.read<int>('c');
  }

  test('漂移库修复:每负债账户收敛到 +Σremaining,方向分侧,borrowedOut 不动',
      () async {
    await seed();
    final db = await open();
    await clearMarker(db);
    await runF36LiabilityBalanceRepair(db);

    // 每户 balance == +Σremaining(存储口径)。
    expect((await db.accountDao.getAccountById('a1'))!.currentBalanceCents,
        916000);
    expect((await db.accountDao.getAccountById('a2'))!.currentBalanceCents,
        400000);
    // borrowedOut 应收账户本票不动。
    expect((await db.accountDao.getAccountById('a3'))!.currentBalanceCents,
        777777);

    // 每漂移户一笔调整交易(固定描述前缀),方向:a1 delta>0 → 贷负债;
    // a2 delta<0 → 借负债。
    expect(await repairTxnCount(db), 2);
    final a1Entry = await db.customSelect(
      'SELECT debit_cents d, credit_cents c FROM transaction_entries '
      "WHERE account_id = 'a1' AND transaction_id IN ("
      "SELECT id FROM transactions WHERE description LIKE 'F36 余额修复%')",
    ).getSingle();
    expect(a1Entry.read<int>('d'), 0);
    expect(a1Entry.read<int>('c'), 416000);
    final a2Entry = await db.customSelect(
      'SELECT debit_cents d, credit_cents c FROM transaction_entries '
      "WHERE account_id = 'a2' AND transaction_id IN ("
      "SELECT id FROM transactions WHERE description LIKE 'F36 余额修复%')",
    ).getSingle();
    expect(a2Entry.read<int>('d'), 200000);
    expect(a2Entry.read<int>('c'), 0);

    // 权益户「历史还款结转」兜底建户;吸收两侧调整(equity 口径
    // credit−debit:+200000 − 416000 = −216000)。
    final equity = await db.customSelect(
      'SELECT id, current_balance_cents bal FROM accounts '
      "WHERE name = '历史还款结转' AND account_type = 3",
    ).getSingle();
    expect(equity.read<int>('bal'), -216000);

    // 调整交易置 pending(sync 上行,ADR-6/7)。
    final states = await db.customSelect(
      "SELECT sync_state FROM transactions WHERE description LIKE 'F36 余额修复%'",
    ).get();
    expect(states, isNotEmpty);
    for (final r in states) {
      expect(r.read<String>('sync_state'), 'pending');
    }

    // 标记置位。
    final marker = await db.customSelect(
      "SELECT value FROM app_meta WHERE key = 'f36_liability_balance_repair_v1'",
    ).getSingle();
    expect(marker.read<String>('value'), 'done');
  });

  test('幂等:重跑(带/不带清标记)分录数与余额不变', () async {
    await seed();
    final db = await open();
    await clearMarker(db);
    await runF36LiabilityBalanceRepair(db);
    final cnt1 = await repairTxnCount(db);
    final bal1 = (await db.accountDao.getAccountById('a1'))!.currentBalanceCents;
    expect(cnt1, 2);

    // 标记在 → 直接跳过。
    await runF36LiabilityBalanceRepair(db);
    expect(await repairTxnCount(db), cnt1);
    expect((await db.accountDao.getAccountById('a1'))!.currentBalanceCents,
        bal1);

    // 清标记重跑(模拟中断重入)→ delta 已归零,不得再生成调整分录。
    await clearMarker(db);
    await runF36LiabilityBalanceRepair(db);
    expect(await repairTxnCount(db), cnt1);
    expect((await db.accountDao.getAccountById('a1'))!.currentBalanceCents,
        bal1);
    expect((await db.accountDao.getAccountById('a2'))!.currentBalanceCents,
        400000);
  });

  test('挂点:runRepaymentHistoryRepairOnce 启动管道串跑 f36 修复', () async {
    await seed();
    final db = await open();
    // 既有管道入口(启动时由 beforeOpen 调用)应同时驱动 f36 修复;
    // 两个标记都清空模拟升级首跑。
    await clearMarker(db);
    await db.customStatement(
        "DELETE FROM app_meta WHERE key = 'repay_history_settlement_v1'");
    await runRepaymentHistoryRepairOnce(db);

    final marker = await db.customSelect(
      "SELECT value FROM app_meta WHERE key = 'f36_liability_balance_repair_v1'",
    ).getSingle();
    expect(marker.read<String>('value'), 'done');
    expect((await db.accountDao.getAccountById('a1'))!.currentBalanceCents,
        916000);
    expect(await repairTxnCount(db), 2);
  });
}
