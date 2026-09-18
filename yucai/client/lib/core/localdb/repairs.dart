import 'package:drift/drift.dart';

import 'app_database.dart';
import 'sync_state.dart' show SyncState;

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
Future<void> runRepaymentHistoryRepairOnce(AppDatabase db) async {
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
