import 'package:drift/drift.dart';

import 'app_database.dart';
import 'sync_state.dart' show SyncState;
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart'
    as txn_entity show TransactionEntry;
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart'
    show RecordTransactionParams;

/// 启动 repair 管道(app_database.beforeOpen 挂点):串跑各一次性修复,
/// 每个修复以自己的 AppMeta 标记门控 —— 旧库升级路径下标记互不牵连
/// (repay 标记已置的库仍能触发 f36 修复,反之亦然),执行失败静默重试。
Future<void> runRepaymentHistoryRepairOnce(AppDatabase db) async {
  await _repaymentHistorySettlementOnce(db);
  await runF36LiabilityBalanceRepair(db);
}

/// F36 存量迁移(2026-09-18,design ADR-3/6):负债账户余额漂移修复。
///
/// 北极星不变式(存储口径):负债账户 current_balance_cents ==
/// +Σ(名下 borrowedIn 债 remainingPrincipalCents),其中 remaining =
/// totalPrincipalCents − Σ(entry.paidCents)(与 debt_local_ds._toEntity
/// 同式)。历史数据(如旧「标记已还」结转只插分录未联动余额)常使两者
/// 漂移 —— 本修复逐**持有 borrowedIn 债的负债账户**(account_type=2)
/// 计算 delta = target − currentBalance:
///   delta>0 → credit 负债 delta / debit 权益;
///   delta<0 → debit 负债 |delta| / credit 权益。
/// borrowedOut 应收账户(asset 侧)本票不动。对方科目 = 权益户
/// 「历史还款结转」(期初调整的会计惯例,不存在则兜底建户);分录经交易
/// 管道落账(BalanceLocalUpdater 联动余额),置 pending 随 sync 上行,
/// 多设备下 server 余额自然收敛(ADR-7)。
///
/// 恰好执行一次:AppMeta 标记 'f36_liability_balance_repair_v1';delta
/// 按当前余额重算,分录落账原子(头行+分录+余额同一 drift 事务),故中断
/// 重跑对已修复账户 delta=0 自然跳过,不会重复生成。
Future<void> runF36LiabilityBalanceRepair(AppDatabase db) async {
  const markerKey = 'f36_liability_balance_repair_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  // 逐负债账户聚合名下 borrowedIn 债的剩余本金(无借入债的负债户不动)。
  final rows = await db.customSelect('''
    SELECT a.id AS acc_id, a.name AS acc_name,
           a.current_balance_cents AS bal,
           COALESCE((SELECT SUM(d.total_principal_cents - COALESCE(pp.paid, 0))
             FROM debts d
             LEFT JOIN (SELECT debt_id, SUM(paid_cents) AS paid
                        FROM payment_schedule_entries GROUP BY debt_id) pp
               ON pp.debt_id = d.id
            WHERE d.account_id = a.id AND d.debt_type = 1), 0) AS target
    FROM accounts a
    WHERE a.account_type = 2
      AND EXISTS (SELECT 1 FROM debts d2
                  WHERE d2.account_id = a.id AND d2.debt_type = 1)
  ''').get();

  final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
  for (final r in rows) {
    final target = r.read<int>('target');
    final delta = target - r.read<int>('bal');
    if (delta == 0) continue;
    final accId = r.read<String>('acc_id');
    final settlement = await _f36SettlementAccountId(db);
    final equityIsDebit = delta > 0;
    await txns.recordTransaction(
        RecordTransactionParams(
      transactionDate: DateTime.now().toUtc(),
      description: 'F36 余额修复 ${r.read<String>('acc_name')}',
      entries: [
        txn_entity.TransactionEntry(
            accountId: equityIsDebit ? settlement : accId,
            debitCents: delta.abs(),
            creditCents: 0),
        txn_entity.TransactionEntry(
            accountId: equityIsDebit ? accId : settlement,
            debitCents: 0,
            creditCents: delta.abs()),
      ],
    ), markPending: true);
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// 权益户「历史还款结转」兜底(照 debt_local_ds._ensureSettlementAccount
/// 惯例:同名+同类型(equity)复用既有户;该私有助手不可跨文件,此处
/// 复用本文件既有 raw 兜底 [ _settlementAccountId ] 建户)。
Future<String> _f36SettlementAccountId(AppDatabase db) async {
  const name = '历史还款结转';
  const equityType = 3;
  final existing = await db.select(db.accounts).get();
  for (final a in existing) {
    if (a.name == name && a.accountType == equityType) return a.id;
  }
  return _settlementAccountId(db);
}

/// 历史数据一次性修复(2026-09-17 用户指令):
/// 「个人待还款/待收款」等债务账户与债务模块的记录不一致 —— 旧还款交易
/// (描述含 Closure 残渣的脏数据、以及一切今日之前入账的还款)被要求删除,
/// 改用「标记已还 + 历史结转」语义重建。
///
/// 规则:今天之前到期、已还款、且关联了交易的期次 ——
///   1. 删除其关联的还款交易(头行 + 分录,即"删除今日之前的还款记录");
///   2. 补记结转分录(债务/债权账户 ↔ 系统权益户「历史还款结转」,金额 =
///      该期本息合计),使债务账户余额与剩余应还保持一致;
///   3. 期次保留已还状态,transaction_id 置空(与「标记已还」语义一致)。
///
/// 恰好执行一次:靠 AppMeta 标记 'repay_history_settlement_v1'(每条转换
/// 自身亦幂等 —— 结转交易用确定性 id 'settle-<entryId>' + INSERT OR IGNORE,
/// 中断重跑不会重复)。今日及以后的还款交易不受影响。
Future<void> _repaymentHistorySettlementOnce(AppDatabase db) async {
  const markerKey = 'repay_history_settlement_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  final now = DateTime.now();
  final todayMid = DateTime(now.year, now.month, now.day);
  // customStatement 不做 DateTime 绑定转换;本项目 drift 存储口径 = ISO 文本。
  final todayMidIso = todayMid.toUtc().toIso8601String();

  final rows = await db.customSelect('''
    SELECT e.id AS eid, e.payment_date AS pdate, e.total_cents AS total,
           e.paid AS paid, e.transaction_id AS txn_id,
           d.account_id AS acc_id, d.debt_type AS dtype,
           d.counterparty AS party
    FROM payment_schedule_entries e
    JOIN debts d ON d.id = e.debt_id
    WHERE e.transaction_id IS NOT NULL
      AND e.payment_date < ?
  ''', variables: [Variable.withString(todayMidIso)]).get();

  for (final r in rows) {
    final paid = r.read<bool>('paid');
    if (!paid) continue; // 只处理已还期次(未还的关联交易不动)
    final txnId = r.read<String>('txn_id');
    final total = r.read<int>('total');
    final accId = r.read<String>('acc_id');
    final isBorrowedIn = r.read<int>('dtype') == 1; // 1 = borrowed_in
    final party = r.read<String>('party');
    final pdate = r.read<DateTime>('pdate');
    final eid = r.read<String>('eid');

    // 1) 删除旧还款交易(分录经 FK cascade 随之删除;再显式兜底)。
    await db.customStatement(
        'DELETE FROM transaction_entries WHERE transaction_id = ?',
        [txnId]);
    await db.customStatement('DELETE FROM transactions WHERE id = ?', [txnId]);

    // 2) 结转分录(确定性 id,INSERT OR IGNORE 幂等)。
    await _settlementAccountId(db);
    final settleTxnId = 'settle-$eid';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await db.customStatement('INSERT OR IGNORE INTO transactions '
        '(id, transaction_date, description, version, created_at, updated_at, sync_state) '
        'VALUES (?, ?, ?, 1, ?, ?, ?)', [
      settleTxnId,
      pdate.toUtc().toIso8601String(),
      '标记已还 $party',
      nowIso,
      nowIso,
      SyncState.pending,
    ]);
    await db.customStatement('INSERT OR IGNORE INTO transaction_entries '
        '(id, transaction_id, account_id, chart_of_account_code, '
        'debit_cents, credit_cents, note) VALUES (?, ?, ?, ?, ?, ?, ?)', [
      'settle-$eid-1',
      settleTxnId,
      accId,
      isBorrowedIn ? '2001' : '1001', // 负债户 / 资产户 科目码(仅展示用)
      isBorrowedIn ? total : 0,
      isBorrowedIn ? 0 : total,
      '历史还款结转',
    ]);
    await db.customStatement('INSERT OR IGNORE INTO transaction_entries '
        '(id, transaction_id, account_id, chart_of_account_code, '
        'debit_cents, credit_cents, note) VALUES (?, ?, ?, ?, ?, ?, ?)', [
      'settle-$eid-2',
      settleTxnId,
      await _settlementAccountId(db),
      '3001',
      isBorrowedIn ? 0 : total,
      isBorrowedIn ? total : 0,
      '历史还款结转',
    ]);

    // 3) 期次解除交易关联(保持已还状态)。
    await db.customStatement(
        'UPDATE payment_schedule_entries SET transaction_id = NULL '
        'WHERE id = ?',
        [eid]);
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// 系统权益户「历史还款结转」(固定 id,INSERT OR IGNORE 幂等),返回其 id。
Future<String> _settlementAccountId(AppDatabase db) async {
  const id = 'sys-hist-settlement';
  await db.customStatement('INSERT OR IGNORE INTO accounts '
      '(id, name, account_type, category, currency_code, '
      'initial_balance_cents, current_balance_cents, ownership, '
      'icon, color, chart_code, is_system, sort_order, institution, '
      'card_number_tail, notes, gold_product_type, status, version, '
      'created_at, updated_at, sync_state) '
      "VALUES ('$id', '历史还款结转', 3, 8, 'CNY', 0, 0, 1, '', '', '', 1, "
      "0, '', '', '', '', 1, 1, ?, ?, 'synced')",
      [
        DateTime.now().toUtc().toIso8601String(),
        DateTime.now().toUtc().toIso8601String()
      ]);
  return id;
}
