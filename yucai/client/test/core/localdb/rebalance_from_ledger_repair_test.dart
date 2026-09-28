// 余额重推导一次性修复(2026-09-28,用户 dev 实测反馈②,取证定案)验证:
// _repaymentHistorySettlementOnce(2026-09-17)用裸 SQL 改账绕过
// BalanceLocalUpdater —— 删旧还款交易未回滚余额、插 settle-* 结转分录未
// 应用余额 —— 致 3 账户 current_balance_cents 漂移(报告页回放口径
// initial + Σ存活分录是对的,账户页存储值偏的)。rebalanceFromLedger 以
// 回放口径重推全部账户余额;app_meta 'repair_rebalance_from_ledger_v1'
// 幂等;聚合+改值+标记单事务。风格照 f36_liability_balance_repair_test
// (首开空库已置标记,清标记模拟「升级时已有漂移数据」的首跑路径;
// 修复无跨连接语义,内存库即可)。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/localdb/repairs.dart';

void main() {
  // 漂移 fixture(复刻取证机制,数字取整便于核对):
  // 旧还款 2 笔(各 350,000)历史上经余额联动落账 —— a-icbc(资产)侧
  // credit / a-gf(负债)侧 debit —— 后被裸 SQL 删除未回滚余额;
  // settle-* 结转 2 笔(500,000 + 300,000)裸 SQL 插入未应用余额。
  //   a-icbc(asset,initial 1,000,000):存活分录无 → 真值 1,000,000,
  //     存储 300,000(少 700,000 —— 方向同工行卡实测「少」);
  //   a-gf(liability,initial 0):存活分录 Σdebit 800,000 → 真值
  //     credit−debit = −800,000,存储 −700,000(多 100,000 —— 方向同
  //     广发实测「多」);
  //   sys-hist-settlement(equity,initial 0):Σcredit 800,000 → 真值
  //     +800,000,存储 0(少 —— 方向同实测);
  //   a-clean / a-income:无漂移(存储 == initial + Σ存活分录)→ 原值不动
  //     (对应实测「其余 25 账户一致」)。
  Future<void> seed(AppDatabase db) async {
    Future<void> acc(String id, String name, int type, int initial, int cur) =>
        db.accountDao.insertAccount(AccountsCompanion.insert(
          id: id,
          name: name,
          accountType: type,
          category: 2,
          currencyCode: 'CNY',
          initialBalanceCents: initial,
          currentBalanceCents: cur,
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
    await acc('a-icbc', '工行储蓄卡', 1, 1000000, 300000);
    await acc('a-gf', '广发财智金', 2, 0, -700000);
    await acc('sys-hist-settlement', '历史还款结转', 3, 0, 0);
    await acc('a-clean', '零钱', 1, 50000, 75000);
    await acc('a-income', '工资', 4, 0, 25000);

    // 存活分录:settle-* ×2(裸 SQL 插入、未联动余额 —— 复刻事故)+ 正常
    // 对账交易 ×1(借贷平衡,同样裸插但存储值与真值一致)。
    Future<void> txn(String id, String dateIso) => db.customStatement(
        'INSERT INTO transactions (id, transaction_date, description, '
        'version, created_at, updated_at) VALUES (?, ?, ?, 1, ?, ?)',
        [id, dateIso, '结转', dateIso, dateIso]);
    Future<void> entry(String id, String txnId, String accId, int d, int c) =>
        db.customStatement(
            'INSERT INTO transaction_entries (id, transaction_id, account_id, '
            "chart_of_account_code, debit_cents, credit_cents, note) "
            "VALUES (?, ?, ?, '', ?, ?, '历史还款结转')",
            [id, txnId, accId, d, c]);
    await txn('settle-e1', '2026-08-10T00:00:00.000Z');
    await entry('se1-1', 'settle-e1', 'a-gf', 500000, 0);
    await entry('se1-2', 'settle-e1', 'sys-hist-settlement', 0, 500000);
    await txn('settle-e2', '2026-09-05T00:00:00.000Z');
    await entry('se2-1', 'settle-e2', 'a-gf', 300000, 0);
    await entry('se2-2', 'settle-e2', 'sys-hist-settlement', 0, 300000);
    await txn('t-clean', '2026-09-20T00:00:00.000Z');
    await entry('tc-1', 't-clean', 'a-clean', 25000, 0);
    await entry('tc-2', 't-clean', 'a-income', 0, 25000);
  }

  Future<AppDatabase> open() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // 首个查询触发 beforeOpen:空库上管道全空跑(三标记俱置),再播种。
    await seed(db);
    return db;
  }

  Future<int> bal(AppDatabase db, String id) async =>
      (await db.accountDao.getAccountById(id))!.currentBalanceCents;

  Future<DateTime> updatedAt(AppDatabase db, String id) async =>
      (await db.accountDao.getAccountById(id))!.updatedAt;

  Future<void> clearMarker(AppDatabase db) => db.customStatement(
      "DELETE FROM app_meta WHERE key = 'repair_rebalance_from_ledger_v1'");

  test('漂移库修复:三账户按回放口径归位,一致账户原值不动', () async {
    final db = await open();
    await clearMarker(db);
    await rebalanceFromLedger(db);

    // 三漂移账户归位(current = initial + Σ存活分录 delta)。
    expect(await bal(db, 'a-icbc'), 1000000);
    expect(await bal(db, 'a-gf'), -800000);
    expect(await bal(db, 'sys-hist-settlement'), 800000);
    // 一致账户:余额与 updated_at 都不动(对齐即跳过)。
    expect(await bal(db, 'a-clean'), 75000);
    expect(await bal(db, 'a-income'), 25000);
    expect(await updatedAt(db, 'a-clean'), DateTime.utc(2026, 9, 1));
    // 漂移账户 updated_at 被刷新。
    expect(await updatedAt(db, 'a-icbc'), isNot(DateTime.utc(2026, 9, 1)));
    // 只改余额/updated_at:version 与 sync_state 不动(不 bump 乐观锁、
    // 不制造上行信号;bound 模式镜像 rebuild 由 server 真相覆盖)。
    final icbc = await db.customSelect(
        "SELECT version v, sync_state s FROM accounts WHERE id = 'a-icbc'",
      ).getSingle();
    expect(icbc.read<int>('v'), 1);
    expect(icbc.read<String>('s'), 'synced');
    // 标记置位。
    final marker = await db.customSelect(
        "SELECT value FROM app_meta "
        "WHERE key = 'repair_rebalance_from_ledger_v1'",
      ).getSingle();
    expect(marker.read<String>('value'), 'done');
  });

  test('幂等:重跑(带/不带清标记)余额与 updated_at 零变化', () async {
    final db = await open();
    await clearMarker(db);
    await rebalanceFromLedger(db);
    final ids = [
      'a-icbc',
      'a-gf',
      'sys-hist-settlement',
      'a-clean',
      'a-income',
    ];
    final before = <String, (int, DateTime)>{
      for (final id in ids) id: (await bal(db, id), await updatedAt(db, id)),
    };

    // 标记在 → 直接跳过。
    await rebalanceFromLedger(db);
    // 清标记重跑(模拟中断重入)→ 全部对齐,零改写。
    await clearMarker(db);
    await rebalanceFromLedger(db);
    for (final id in ids) {
      expect(await bal(db, id), before[id]!.$1);
      expect(await updatedAt(db, id), before[id]!.$2);
    }
  });

  test('挂点:runRepaymentHistoryRepairOnce 启动管道串跑本修复', () async {
    final db = await open();
    // 只清本修复标记(repay/f36 标记已置位 → 管道前两步跳过),
    // 验证 beforeOpen 管道入口(runRepaymentHistoryRepairOnce)驱动本修复。
    await clearMarker(db);
    await runRepaymentHistoryRepairOnce(db);

    expect(await bal(db, 'a-icbc'), 1000000);
    expect(await bal(db, 'a-gf'), -800000);
    expect(await bal(db, 'sys-hist-settlement'), 800000);
    final marker = await db.customSelect(
        "SELECT value FROM app_meta "
        "WHERE key = 'repair_rebalance_from_ledger_v1'",
      ).getSingle();
    expect(marker.read<String>('value'), 'done');
  });
}
