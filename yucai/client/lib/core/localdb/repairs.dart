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
  await rebalanceFromLedger(db);
  await runLiabilityBalanceRepairV2(db);
  await unhookEDaiCardMerges(db);
  await seedEDaiBillDays(db);
  await reattributeEDaiCardHistory(db);
  await eDaiBillFullCycle(db);
  await eDaiRepayDatesToBillNextDay(db);
  await undoEDaiPrepayAdjustment(db);
  await eDaiBankRecordAlignment(db);
  await cleanupDanglingRefTxns(db);
  await runF49CarrierHideRepair(db);
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

/// 余额重推导一次性修复(2026-09-28,用户 dev 实测反馈②,取证定案):
/// `_repaymentHistorySettlementOnce`(2026-09-17)用裸 SQL 改账绕过了
/// BalanceLocalUpdater —— 删 20 笔旧还款交易未回滚余额、插 40 条
/// settle-* 结转分录未应用余额 —— 致 3 账户 current_balance_cents 漂移
/// (工行储蓄卡少 5,552,960 / 广发财智金多 218,328 / sys-hist-settlement
/// 少 5,771,288;其余 25 账户一致)。报告页回放口径(initial + Σ分录)是
/// 对的、账户页存储值是偏的 —— 故以回放口径为准对**全部账户**重推:
///   current_balance_cents = initial_balance_cents + Σ delta(存活分录)
/// delta 规则照抄 balance_updater._entryDelta(= balance_replay /
/// server ApplyEntryDirection 同款):asset(1)/expense(5) → debit−credit;
/// liability(2)/equity(3)/income(4) → credit−debit;未知类型 → 0。
///
/// 软删/版本口径核验(与既有余额更新器逐字一致,**无**过滤):
///  - transactions 表无 deletedAt 列 —— 删除是硬删:delete() 先
///    applyEntries(old, −1) 回滚余额,再随 FK cascade 掉头行+分录;墓碑
///    只进 sync_tombstones 旁表,不参与余额。故「存活分录」=
///    transaction_entries INNER JOIN transactions(FK cascade 保证无孤儿
///    分录),不存在也不需要 deleteAt 过滤。
///  - 不滤 sync_state / version:BalanceLocalUpdater 对每条分录无条件
///    应用(pending 行余额已联动,上行成功只改状态列);version 是乐观锁
///    序号,与余额真值无关。
///
/// 恰好执行一次:AppMeta 标记 'repair_rebalance_from_ledger_v1';聚合 +
/// 改余额 + 置标记在**单个 drift 事务**内 —— 中断安全(要么全落要么全
/// 无,失败下次打开重试),重跑对已对齐账户 delta=0 自然跳过。只改
/// current_balance_cents / updated_at:不 bump version、不置 pending
/// (账户余额是派生值非上行事实;bound 模式镜像 rebuild 走 delete-all
/// synced 不看本地 version,不制造上行信号)。
Future<void> rebalanceFromLedger(AppDatabase db) async {
  const markerKey = 'repair_rebalance_from_ledger_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  await db.transaction(() async {
    // 按账户聚合存活分录的 Σdebit/Σcredit(INNER JOIN transactions 钉死
    // 「存活头行下的分录」口径;账户类型规则在 Dart 侧套用,与
    // _entryDelta 逐字同源)。孤儿账户分录随 JOIN accounts 自然剔除
    // (报告回放同款:type 0 → delta 0,且本无账户行可写)。
    final rows = await db.customSelect('''
      SELECT a.id AS acc_id, a.account_type AS atype,
             a.initial_balance_cents AS initial,
             a.current_balance_cents AS bal,
             COALESCE(s.dsum, 0) AS dsum, COALESCE(s.csum, 0) AS csum
      FROM accounts a
      LEFT JOIN (
        SELECT e.account_id AS aid,
               SUM(e.debit_cents) AS dsum, SUM(e.credit_cents) AS csum
        FROM transaction_entries e
        JOIN transactions t ON t.id = e.transaction_id
        GROUP BY e.account_id
      ) s ON s.aid = a.id
    ''').get();

    // customStatement 不做 DateTime 绑定转换;本项目 drift 存储口径 =
    // ISO 文本(与 _settlementAccountId 同款)。
    final nowIso = DateTime.now().toUtc().toIso8601String();
    for (final r in rows) {
      final target = r.read<int>('initial') +
          _entryDelta(r.read<int>('atype'), r.read<int>('dsum'),
              r.read<int>('csum'));
      if (target == r.read<int>('bal')) continue; // 已对齐账户不动
      await db.customStatement(
          'UPDATE accounts SET current_balance_cents = ?, updated_at = ? '
          'WHERE id = ?',
          [target, nowIso, r.read<String>('acc_id')]);
    }

    await db.into(db.appMeta).insert(
          AppMetaCompanion.insert(key: markerKey, value: 'done'),
          mode: InsertMode.insertOrIgnore,
        );
  });
}

/// 分录对账户余额的增量(照抄 balance_updater._entryDelta /
/// balance_replay._entryDelta:asset(1)/expense(5) → debit−credit;
/// liability(2)/equity(3)/income(4) → credit−debit;未知类型 → 0)。
int _entryDelta(int accountType, int debitCents, int creditCents) {
  switch (accountType) {
    case 1: // asset
    case 5: // expense
      return debitCents - creditCents;
    case 2: // liability
    case 3: // equity
    case 4: // income
      return creditCents - debitCents;
    default:
      return 0;
  }
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

/// 负债余额修复 v2(2026-10-06,dev 反馈两项定案):
///
/// 1. **卡贷漂移复发**:F36(2026-09-18)对齐后,后续入账/编辑再次漂移
///    (融e借 −906.08 / e招贷 −11,707.57 / 平安分期 −7,471.04 / 财智金
///    −5,625.31,合计 −¥25,710)—— 重跑 F36 同款对齐:持 borrowedIn 债的
///    负债户 current_balance → +Σ(totalPrincipal − Σpaid),delta 走
///    「历史还款结转」权益户结转分录(经交易管道联动余额,置 pending)。
/// 2. **负余额无挂债负债户归零**:「招商银行贷款」−¥100,000(10-05 删除
///    交易时「删除清账」冲销在余额为 0 的账户上 double-debit 打穿;用户
///    确认无此债)—— 无 borrowedIn 债且余额 < 0 的负债户 credit |bal| /
///    debit 权益,归 0。credit-正不变式下负债余额恒 ≥ 0,负值必为脏数据。
///
/// 恰好执行一次:AppMeta 标记 'liability_balance_repair_v2';分录落账原子,
/// 中断重跑 delta=0 自然跳过(同 F36 幂等论证)。
Future<void> runLiabilityBalanceRepairV2(AppDatabase db) async {
  const markerKey = 'liability_balance_repair_v2';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  // (accId, accName, delta) 待修清单:挂债户对齐 + 负余额无挂债户归零。
  final fixes = <(String, String, int)>[];

  // 1) F36 同款对齐(标记不同,重算当前 delta)。
  final drifted = await db.customSelect('''
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
  for (final r in drifted) {
    final delta = r.read<int>('target') - r.read<int>('bal');
    if (delta != 0) {
      fixes.add((r.read<String>('acc_id'), r.read<String>('acc_name'), delta));
    }
  }

  // 2) 负余额且无 borrowedIn 债的负债户 → 0(delta = −bal > 0)。
  final negative = await db.customSelect('''
    SELECT a.id AS acc_id, a.name AS acc_name,
           a.current_balance_cents AS bal
    FROM accounts a
    WHERE a.account_type = 2
      AND a.current_balance_cents < 0
      AND NOT EXISTS (SELECT 1 FROM debts d
                      WHERE d.account_id = a.id AND d.debt_type = 1)
  ''').get();
  for (final r in negative) {
    fixes.add(
        (r.read<String>('acc_id'), r.read<String>('acc_name'), -r.read<int>('bal')));
  }

  final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
  for (final (accId, accName, delta) in fixes) {
    final settlement = await _f36SettlementAccountId(db);
    final equityIsDebit = delta > 0;
    await txns.recordTransaction(
        RecordTransactionParams(
      transactionDate: DateTime.now().toUtc(),
      description: '负债余额修复v2 $accName',
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

/// e招贷独立账户口径(2026-10-08 用户定案,对齐招行内部结构):e招贷是
/// 独立授信账户,与个人信用卡**分开** —— 每期不并入卡账单,到期在 e招贷
/// 自身还款。一次性解除「e招贷」名下卡贷债的挂接卡(collectionAccountId
/// → null):
///   - catchupCardLoanMerges 自动并账自此跳过(其过滤条件含挂接卡非空);
///   - 招行卡详情的还款计划面板不再纳入 e招贷 期次(同条件过滤);
///   - 债务页期次确认从「待并入账单」回到标准还款对话框。
/// 平安现金分期/广发财智金维持挂接 —— 其银行口径确为每期并入卡账单。
/// 已并账的历史分录不动(资金流结果与独立还款等价);卡上尚未还的并入
/// 额(¥666.51)随正常还款自然清零。
/// 恰好执行一次:AppMeta 标记 'card_loan_e_dai_unhook_v1';仅 UPDATE 一列,
/// 原子可重试。
Future<void> unhookEDaiCardMerges(AppDatabase db) async {
  const markerKey = 'card_loan_e_dai_unhook_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  await db.customStatement(
      "UPDATE debts SET collection_account_id = NULL, updated_at = ? "
      "WHERE subtype = 'card_loan' "
      "AND collection_account_id IS NOT NULL "
      "AND EXISTS (SELECT 1 FROM accounts la "
      "            WHERE la.id = debts.account_id AND la.name LIKE '%e招贷%')",
      [DateTime.now().toUtc().toIso8601String()]);

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// e招贷账单日/还款日种子(2026-10-08,用户口径「5号出账、23号前还」):
/// 名下含卡贷债的「e招贷」贷款账户,creditBillingDay/RepaymentDay 为空时
/// 填 5/23 —— 详情账单制面板与一键整单还款据此启用。已有值不覆盖
/// (用户经账户编辑表单改过的口径优先)。
/// marker 'e_dai_bill_days_v1'。
Future<void> seedEDaiBillDays(AppDatabase db) async {
  const markerKey = 'e_dai_bill_days_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  await db.customStatement(
      "UPDATE accounts SET credit_billing_day = 5, credit_repayment_day = 23, "
      "updated_at = ? "
      "WHERE account_type = 2 AND category = 7 AND name LIKE '%e招贷%' "
      "AND credit_billing_day IS NULL AND credit_repayment_day IS NULL "
      "AND EXISTS (SELECT 1 FROM debts d "
      "            WHERE d.account_id = accounts.id AND d.debt_type = 1)",
      [DateTime.now().toUtc().toIso8601String()]);

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// e招贷并账史整体改道(2026-10-08 用户指令「补齐 10-5 账单,相关单条
/// 交易删除或回退」):招行卡历史上只有 e招贷 并账 + 每月 22 日还款 +
/// 2026-09-16 起的自消费。手术(储蓄侧资金流一律不动):
///   1. 删除全部「信用卡分期 招商银行」并账交易(对方分录在 e招贷账户;
///      经交易管道回滚两户余额);
///   2. 全部「信用卡还款 招商银行」改道:卡侧分录账户改为 e招贷,描述改
///      「账单还款 招行e招贷」——还款成为 e招贷 直接还款(余额:卡 +X /
///      e招贷 −X,与并账删除对冲);
///   3. 净覆盖差 Σ并账−Σ还款(= 尚挂在卡上的未还并账)自最新未清期次
///      倒序解除已还标记 → 该期次回到 10-05 账单(还款日前整单还)。
/// 终态:卡只剩自消费真实欠款;e招贷 欠款 = +Σ未还(不变式保持);
/// 10-05 账单 = 未覆盖期次。
/// marker 'e_dai_card_reattribute_v1'。
Future<void> reattributeEDaiCardHistory(AppDatabase db) async {
  const markerKey = 'e_dai_card_reattribute_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  // e招贷 贷款账户(名含 e招贷,挂借入债)与其挂接过的信用卡。历史库只有
  // 一个 e招贷 户;防御性取首个,无则跳过(空库/新库)。
  final edaiRows = await db.customSelect(
      "SELECT a.id FROM accounts a WHERE a.account_type = 2 "
      "AND a.category = 7 AND a.name LIKE '%e招贷%' "
      "AND EXISTS (SELECT 1 FROM debts d WHERE d.account_id = a.id AND d.debt_type = 1) "
      "ORDER BY a.created_at LIMIT 1").get();
  if (edaiRows.isEmpty) {
    await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore);
    return;
  }
  final edaiId = edaiRows.first.read<String>('id');

  final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
  final nowIso = DateTime.now().toUtc().toIso8601String();

  // 1) 删除 e招贷 并账交易(「信用卡分期 X」且 e招贷 侧为**借方**分录 ——
  //    并账特征;注意区分「信用卡分期放款」(e招贷 侧贷方 = 放款入账,
  //    绝不可删)。经交易管道回滚两户余额;解除期次交易关联(已还标记
  //    留给第 3 步调净差)。
  var mergedTotal = 0;
  final mergeTxns = await db.customSelect('''
    SELECT DISTINCT t.id AS tid
    FROM transactions t
    JOIN transaction_entries e ON e.transaction_id = t.id
    WHERE t.description LIKE '信用卡分期%'
      AND e.account_id = ? AND e.debit_cents > 0
  ''', variables: [Variable.withString(edaiId)]).get();
  for (final r in mergeTxns) {
    final tid = r.read<String>('tid');
    final amt = await db.customSelect(
        'SELECT debit_cents d FROM transaction_entries '
        'WHERE transaction_id = ? AND account_id = ?',
        variables: [Variable.withString(tid), Variable.withString(edaiId)])
        .getSingle();
    mergedTotal += amt.read<int>('d');
    await txns.delete(tid);
  }
  await db.customStatement(
      'UPDATE payment_schedule_entries SET transaction_id = NULL '
      'WHERE transaction_id IS NOT NULL AND transaction_id NOT IN '
      '(SELECT id FROM transactions)');

  // 2) 卡还款改道为 e招贷 直接还款(仅对方为 e招贷 付款卡的「信用卡还款」;
  //    泛化:还款交易的卡侧分录账户 = 任一曾挂接 e招贷 的信用卡,此处按
  //    描述「信用卡还款 招商银行」识别 —— 历史库中该卡还款全部为 e招贷
  //    账单付款,自消费期(2026-09-16 起)后无同名还款)。
  var repaidTotal = 0;
  final repayTxns = await db.customSelect(
      "SELECT t.id AS tid FROM transactions t "
      "WHERE t.description = '信用卡还款 招商银行'").get();
  for (final r in repayTxns) {
    final tid = r.read<String>('tid');
    // 卡侧分录(debit):招行卡上的借方 = 还款冲减。改挂 e招贷。
    final cardEntry = await db.customSelect(
        "SELECT e.id AS eid, e.debit_cents d FROM transaction_entries e "
        "JOIN accounts a ON a.id = e.account_id "
        "WHERE e.transaction_id = ? AND a.category = 2 AND e.debit_cents > 0 "
        "  AND a.name = '招商银行信用卡'",
        variables: [Variable.withString(tid)]).get();
    if (cardEntry.isEmpty) continue;
    final row = cardEntry.first;
    final amt = row.read<int>('d');
    await db.customStatement(
        'UPDATE transaction_entries SET account_id = ? WHERE id = ?',
        [edaiId, row.read<String>('eid')]);
    // 余额手工联动(credit-正):还款 debit 从卡挪到 e招贷。
    await db.customStatement(
        "UPDATE accounts SET current_balance_cents = current_balance_cents + ?, "
        "updated_at = ? WHERE id = "
        "(SELECT id FROM accounts WHERE name = '招商银行信用卡' AND category = 2)",
        [amt, nowIso]);
    await db.customStatement(
        'UPDATE accounts SET current_balance_cents = current_balance_cents - ?, '
        'updated_at = ? WHERE id = ?',
        [amt, nowIso, edaiId]);
    await db.customStatement(
        "UPDATE transactions SET description = '账单还款 招行e招贷' WHERE id = ?",
        [tid]);
    repaidTotal += amt;
  }

  // 3) 净覆盖差(未还并账)自最新已还期次倒序解除标记,回账单。
  var residue = mergedTotal - repaidTotal; // 2026-10-08 取证 = 666.51
  if (residue > 0) {
    final paidEntries = await db.customSelect('''
      SELECT e.id AS eid, e.total_cents AS amt
      FROM payment_schedule_entries e
      JOIN debts d ON d.id = e.debt_id
      WHERE d.account_id = ? AND d.debt_type = 1 AND e.paid = 1
      ORDER BY e.payment_date DESC
    ''', variables: [Variable.withString(edaiId)]).get();
    for (final e in paidEntries) {
      if (residue <= 0) break;
      final amt = e.read<int>('amt');
      await db.customStatement(
          'UPDATE payment_schedule_entries SET paid = 0, paid_cents = 0, '
          'transaction_id = NULL WHERE id = ?',
          [e.read<String>('eid')]);
      residue -= amt;
    }
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// e招贷本期账单全额化(2026-10-08 用户口径:银行 10-05 账单 ¥3,987.81
/// 全额未还、10-23 前还清):改道手术(v5)后本期窗口内仍有三期
/// (09-09/09-12/09-28,共 ¥3,321.30)沿历史标记为已还 —— 历史还款时序
/// 领先账单日造成的预付。本修复把**本期账单窗口内已还期次**转回未还,
/// 差额 S 经权益户「历史还款结转」调回 e招贷 余额([借权益/贷 e招贷]),
/// 不变式(余额 == Σtotal−Σpaid)保持;储蓄资金流不动。此后面板显示
/// 本期账单全额,一键还清按全额执行(与银行对齐)。
/// marker 'e_dai_bill_full_cycle_v1'。
Future<void> eDaiBillFullCycle(AppDatabase db) async {
  const markerKey = 'e_dai_bill_full_cycle_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  final rows = await db.customSelect(
      "SELECT a.id AS acc_id, a.name AS acc_name, a.credit_billing_day AS bd "
      "FROM accounts a WHERE a.account_type = 2 "
      "AND a.category = 7 AND a.name LIKE '%e招贷%' "
      "AND a.credit_billing_day IS NOT NULL "
      "AND EXISTS (SELECT 1 FROM debts d WHERE d.account_id = a.id AND d.debt_type = 1) "
      "ORDER BY a.created_at LIMIT 1").get();
  if (rows.isEmpty) {
    await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore);
    return;
  }
  final r = rows.first;
  final edaiId = r.read<String>('acc_id');
  final billDay = r.read<int>('bd');

  // 最近已过账单日 D(与账单面板同口径)。
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime clamp(int y, int m, int d) =>
      DateTime(y, m, d < 29 ? d : (DateTime(y, m + 1, 0).day < d ? DateTime(y, m + 1, 0).day : d));
  var d = clamp(today.year, today.month, billDay);
  if (d.isAfter(today)) {
    d = clamp(today.year, today.month - 1, billDay);
  }
  final prevD = clamp(d.year, d.month - 1, billDay);
  final dIso = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final prevIso = '${prevD.year.toString().padLeft(4, '0')}-${prevD.month.toString().padLeft(2, '0')}-${prevD.day.toString().padLeft(2, '0')}';

  // 本期窗口内已还期次 → 未还;累计差额 S。
  final paid = await db.customSelect('''
    SELECT e.id AS eid, e.total_cents AS amt
    FROM payment_schedule_entries e
    JOIN debts dd ON dd.id = e.debt_id
    WHERE dd.account_id = ? AND dd.debt_type = 1 AND e.paid = 1
      AND substr(e.payment_date, 1, 10) > ? AND substr(e.payment_date, 1, 10) <= ?
  ''', variables: [
    Variable.withString(edaiId),
    Variable.withString(prevIso),
    Variable.withString(dIso),
  ]).get();
  var s = 0;
  for (final e in paid) {
    s += e.read<int>('amt');
    await db.customStatement(
        'UPDATE payment_schedule_entries SET paid = 0, paid_cents = 0, '
        'transaction_id = NULL WHERE id = ?',
        [e.read<String>('eid')]);
  }

  if (s > 0) {
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final settlement = await _f36SettlementAccountId(db);
    await txns.recordTransaction(
        RecordTransactionParams(
      transactionDate: DateTime.now().toUtc(),
      description: '账单预付调整 ${r.read<String>('acc_name')}',
      entries: [
        txn_entity.TransactionEntry(
            accountId: settlement, debitCents: s, creditCents: 0),
        txn_entity.TransactionEntry(
            accountId: edaiId, debitCents: 0, creditCents: s),
      ],
    ), markPending: true);
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// e招贷历史账单还款改期(2026-10-08 用户指令):改道后的 18 笔「账单
/// 招行e招贷」还款原日期=每月 22 日(经卡还款的实际付款日);用户口径
/// 改为**账单日次日**(账单日 5 → 每月 6 日),使历史呈现为"出账次日
/// 即还"。仅改 transactions.transaction_date(年月不变、日=账单日+1);
/// 分录无日期、余额/收支均不受影响。
/// marker 'e_dai_repay_dates_v1'。
Future<void> eDaiRepayDatesToBillNextDay(AppDatabase db) async {
  const markerKey = 'e_dai_repay_dates_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  // 账单日取自 e招贷 账户(缺省 5);还款日 = 次日 6。
  final acc = await db.customSelect(
      "SELECT credit_billing_day AS bd FROM accounts "
      "WHERE account_type = 2 AND category = 7 AND name LIKE '%e招贷%' "
      "AND credit_billing_day IS NOT NULL ORDER BY created_at LIMIT 1").get();
  final billDay = acc.isEmpty ? 5 : acc.first.read<int>('bd');
  final nextDay = (billDay + 1).toString().padLeft(2, '0');

  final rows = await db.customSelect(
      "SELECT id, substr(transaction_date, 1, 7) AS ym "
      "FROM transactions WHERE description = '账单还款 招行e招贷'").get();
  for (final r in rows) {
    await db.customStatement(
        "UPDATE transactions SET transaction_date = ? WHERE id = ?",
        ['${r.read<String>('ym')}-$nextDay${'T00:00:00.000Z'}',
          r.read<String>('id')]);
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// 撤销 e招贷「账单预付调整」(2026-10-08 用户指令:v6 的全额账单口径
/// 伴随一条调账分录,用户宁可还原还款记录也不要该分录)。步骤:
///   1. 删除「账单预付调整」交易(经交易管道回滚:e招贷 −S / 权益 +S);
///   2. 本期账单窗口内未还期次**自最早起**恢复已还标记,累计 = S
///      (09-09/09-12/09-28 三期还原;10-05 从未还过,保持未还)。
/// 终态(真实资金状态):e招贷 余额/未还 Σ 各回落 S;账单面板显示
/// 本期账单全额 + 已还 S + 剩余应还。
/// marker 'e_dai_prepay_adjust_undo_v1'。
Future<void> undoEDaiPrepayAdjustment(AppDatabase db) async {
  const markerKey = 'e_dai_prepay_adjust_undo_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  final adj = await db.customSelect(
      "SELECT t.id AS tid, "
      "COALESCE((SELECT credit_cents FROM transaction_entries e "
      "  JOIN accounts a ON a.id = e.account_id "
      "  WHERE e.transaction_id = t.id AND a.account_type = 2 "
      "    AND a.category = 7 AND a.name LIKE '%e招贷%'), 0) AS amt "
      "FROM transactions t WHERE t.description LIKE '账单预付调整%'").get();
  if (adj.isEmpty) {
    await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore);
    return;
  }
  final tid = adj.first.read<String>('tid');
  var s = adj.first.read<int>('amt');

  final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
  await txns.delete(tid);

  // 窗口内未还期次自最早起恢复已还,累计 = S(10-05 排最后,自然剩余)。
  final edai = await db.customSelect(
      "SELECT id FROM accounts WHERE account_type = 2 AND category = 7 "
      "AND name LIKE '%e招贷%' ORDER BY created_at LIMIT 1").get();
  if (edai.isNotEmpty) {
    final edaiId = edai.first.read<String>('id');
    final unpaid = await db.customSelect('''
      SELECT e.id AS eid, e.total_cents AS amt, e.principal_cents AS prin
      FROM payment_schedule_entries e
      JOIN debts d ON d.id = e.debt_id
      WHERE d.account_id = ? AND d.debt_type = 1 AND e.paid = 0
      ORDER BY e.payment_date
    ''', variables: [Variable.withString(edaiId)]).get();
    for (final e in unpaid) {
      if (s <= 0) break;
      final amt = e.read<int>('amt');
      await db.customStatement(
          'UPDATE payment_schedule_entries SET paid = 1, paid_cents = ? '
          'WHERE id = ?',
          [amt, e.read<String>('eid')]);
      s -= amt;
    }
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// e招贷还款记录对齐银行流水(2026-10-08 用户提供掌上生活实拍口径):
/// 7-5 借入 14,000 后,银行 7/8/9/10 月还款**均为 ¥3,987.81**(2-6 月
/// 3,321.30,1 月 2,860.5x)。app 差两处:7 月那笔记成 3,321.30(少
/// ¥666.51,未含新贷首期)、10 月整笔缺失。本修复:
///   1. 7 月「账单还款」金额 3,321.30 → 3,987.81(两腿 +666.51,余额
///      联动:e招贷/储蓄各 −666.51 —— 银行实际多扣了这部分);
///   2. 补记 2026-10-06「账单还款」¥3,987.81(账单次日口径,还款来源
///      = 既有还款的同一储蓄账户);
///   3. 未还期次按序标已还(10-05 → 7月笔;10-09/10-12/10-28/11-05 →
///      10月笔),合计恰为 666.51+3,987.81。
/// 终态:本期账单(10-05,含至 11-05)已还清;下期 11-05 账单 ¥3,987.81。
/// 注:1 月 2,860.50 vs 银行 2,860.52 为 2 分利息尾差,不动(避免产生
/// 无法分摊的残差)。
/// marker 'e_dai_bank_align_v1'。
Future<void> eDaiBankRecordAlignment(AppDatabase db) async {
  const markerKey = 'e_dai_bank_align_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  final edaiRows = await db.customSelect(
      "SELECT id FROM accounts WHERE account_type = 2 AND category = 7 "
      "AND name LIKE '%e招贷%' ORDER BY created_at LIMIT 1").get();
  if (edaiRows.isEmpty) {
    await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore);
    return;
  }
  final edaiId = edaiRows.first.read<String>('id');
  final nowIso = DateTime.now().toUtc().toIso8601String();

  // 1) 7 月还款 3,321.30 → 3,987.81(两腿同额 +666.51 + 余额联动)。
  final jul = await db.customSelect('''
    SELECT t.id AS tid, e.id AS edai_entry,
           (SELECT e2.id FROM transaction_entries e2
             WHERE e2.transaction_id = t.id AND e2.account_id != ?
               AND e2.credit_cents > 0 LIMIT 1) AS sav_entry,
           (SELECT e2.account_id FROM transaction_entries e2
             WHERE e2.transaction_id = t.id AND e2.account_id != ?
               AND e2.credit_cents > 0 LIMIT 1) AS sav_id,
           e.debit_cents AS amt
    FROM transactions t
    JOIN transaction_entries e ON e.transaction_id = t.id AND e.account_id = ?
    WHERE t.description = '账单还款 招行e招贷'
      AND substr(t.transaction_date, 1, 7) = '2026-07'
  ''', variables: [
    Variable.withString(edaiId),
    Variable.withString(edaiId),
    Variable.withString(edaiId),
  ]).get();
  String? savId;
  var julTid = '';
  if (jul.isNotEmpty) {
    final r = jul.first;
    final old = r.read<int>('amt');
    final delta = 398781 - old;
    if (delta > 0) {
      julTid = r.read<String>('tid');
      savId = r.readNullable<String>('sav_id');
      await db.customStatement(
          'UPDATE transaction_entries SET debit_cents = debit_cents + ? '
          'WHERE id = ?',
          [delta, r.read<String>('edai_entry')]);
      await db.customStatement(
          'UPDATE transaction_entries SET credit_cents = credit_cents + ? '
          'WHERE id = ?',
          [delta, r.readNullable<String>('sav_entry')]);
      await db.customStatement(
          'UPDATE accounts SET current_balance_cents = current_balance_cents - ?, '
          'updated_at = ? WHERE id = ?',
          [delta, nowIso, edaiId]);
      if (savId != null) {
        await db.customStatement(
            'UPDATE accounts SET current_balance_cents = current_balance_cents - ?, '
            'updated_at = ? WHERE id = ?',
            [delta, nowIso, savId]);
      }
    }
  }

  // 2) 补记 10 月还款(来源 = 7 月那笔的同一储蓄账户;缺则跳过补记)。
  if (savId != null && savId.isNotEmpty) {
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    await txns.recordTransaction(
        RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 10, 6),
      description: '账单还款 招行e招贷',
      entries: [
        txn_entity.TransactionEntry(
            accountId: edaiId, debitCents: 398781, creditCents: 0),
        txn_entity.TransactionEntry(
            accountId: savId, debitCents: 0, creditCents: 398781),
      ],
    ), markPending: true);
  }

  // 3) 未还期次按序标已还(10-05 → 7 月笔;其余 → 最新还款笔)。
  final octTidRow = await db.customSelect(
      "SELECT id FROM transactions WHERE description = '账单还款 招行e招贷' "
      "AND substr(transaction_date, 1, 7) = '2026-10' LIMIT 1").get();
  final octTid =
      octTidRow.isEmpty ? julTid : octTidRow.first.read<String>('id');
  var budget = 66651 + 398781;
  final unpaid = await db.customSelect('''
    SELECT e.id AS eid, e.total_cents AS amt
    FROM payment_schedule_entries e
    JOIN debts d ON d.id = e.debt_id
    WHERE d.account_id = ? AND d.debt_type = 1 AND e.paid = 0
    ORDER BY e.payment_date
  ''', variables: [Variable.withString(edaiId)]).get();
  for (final e in unpaid) {
    if (budget <= 0) break;
    await db.customStatement(
        'UPDATE payment_schedule_entries SET paid = 1, paid_cents = ?, '
        'transaction_id = ? WHERE id = ?',
        [e.read<int>('amt'), octTid, e.read<String>('eid')]);
    budget -= e.read<int>('amt');
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// 悬挂引用交易清理(2026-10-08 自检告警处置):guest 本地删除账户路径
/// 此前只查余额不查引用,「招商银行贷款」带 2 笔历史交易被删 → 分录成
/// 孤儿(自检横幅「本地数据异常:悬挂引用」)。本修复把引用缺失账户的
/// 交易作为**组**评估:对存活账户的净余额影响为零 → 组内整组删除
/// (余额不动);非零净额的组保留(告警如实保留,待人工处置)。
/// 本例:10-05「删除清账」与 10-08「余额修复v2」互为镜像, equity 净额 0。
/// marker 'dangling_ref_cleanup_v1';代码层守卫见 account_local_ds.delete。
Future<void> cleanupDanglingRefTxns(AppDatabase db) async {
  const markerKey = 'dangling_ref_cleanup_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  final txns = await db.customSelect('''
    SELECT DISTINCT t.id AS tid
    FROM transactions t
    JOIN transaction_entries e ON e.transaction_id = t.id
    WHERE NOT EXISTS (SELECT 1 FROM accounts a WHERE a.id = e.account_id)
  ''').get();
  if (txns.isEmpty) {
    await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore);
    return;
  }

  // 组级净额:对每个存活账户的 Σ delta(跨全部悬挂交易)。
  final netByAccount = <String, int>{};
  final types = {
    for (final r in await db.customSelect(
            'SELECT id, account_type FROM accounts').get())
      r.read<String>('id'): r.read<int>('account_type'),
  };
  for (final t in txns) {
    final entries = await db.customSelect(
        'SELECT account_id, debit_cents, credit_cents FROM transaction_entries '
        'WHERE transaction_id = ?',
        variables: [Variable.withString(t.read<String>('tid'))]).get();
    for (final e in entries) {
      final acc = e.readNullable<String>('account_id');
      if (acc == null || !types.containsKey(acc)) continue;
      final dr = e.read<int>('debit_cents');
      final cr = e.read<int>('credit_cents');
      final type = types[acc]!;
      final delta = (type == 1 || type == 5) ? dr - cr : cr - dr;
      netByAccount[acc] = (netByAccount[acc] ?? 0) + delta;
    }
  }
  final zeroNet = netByAccount.values.every((v) => v == 0);
  if (zeroNet) {
    for (final t in txns) {
      final tid = t.read<String>('tid');
      await db.customStatement(
          'DELETE FROM transaction_entries WHERE transaction_id = ?', [tid]);
      await db.customStatement('DELETE FROM transactions WHERE id = ?', [tid]);
    }
  }

  await db.into(db.appMeta).insert(
        AppMetaCompanion.insert(key: markerKey, value: 'done'),
        mode: InsertMode.insertOrIgnore,
      );
}

/// F49 载体户隐藏存量修复(2026-10-10,spec FR-2):并入模式卡贷
/// (collectionAccountId 非空)自动创建的贷款负债户是复式账管道而非用户
/// 真实账户 —— 本修复对存量库做两件事:
///   ① 语义标记:名下存在挂接卡(collectionAccountId 非空)的 card_loan
///      借入债的账户 → is_system=1(展示层过滤退出用户视野;余额/净资产/
///      报表计算零改动);
///   ② 孤儿关闭:notes 精确匹配「信用卡贷款(卡贷)自动创建」(debt_form
///      自动建户口径)且名下无任何 card_loan 借入债(含已解挂的 e招贷,
///      债仍存即非孤儿)、余额为 0、creditBillingDay 为空(排除独立账单
///      真实账户)的载体户 → status=2(archived,复用账户页关闭语义,
///      保账史不删行);
///   ③ 非零余额孤儿与带账单日账户零动作(WHERE 天然保证)。
/// 独立账单模式(e招贷)永不置位:解挂修复(unhookEDaiCardMerges)已把
/// 其 collectionAccountId 置 NULL,①不命中;其账户带账单日,②亦不命中。
/// 恰好执行一次:AppMeta 标记 'f49_carrier_hide_v1';两条 UPDATE 原子
/// 可重试(标记幂等;孤儿已达终态,重跑无新命中)。
Future<void> runF49CarrierHideRepair(AppDatabase db) async {
  const markerKey = 'f49_carrier_hide_v1';
  final done = await (db.select(db.appMeta)
        ..where((t) => t.key.equals(markerKey)))
      .getSingleOrNull();
  if (done != null) return;

  final nowIso = DateTime.now().toUtc().toIso8601String();

  // ① 并入型载体标记。
  await db.customStatement(
      "UPDATE accounts SET is_system = 1, updated_at = ? "
      "WHERE EXISTS (SELECT 1 FROM debts d "
      "              WHERE d.account_id = accounts.id "
      "                AND d.subtype = 'card_loan' "
      "                AND d.debt_type = 1 "
      "                AND d.collection_account_id IS NOT NULL)",
      [nowIso]);

  // ② 孤儿关闭:status 2 = archived(AccountStatus{active=0, archived=1}
  //    1-based 落库,同 account_local_ds update 的 index+1 口径)。
  await db.customStatement(
      "UPDATE accounts SET status = 2, updated_at = ? "
      "WHERE notes = '信用卡贷款(卡贷)自动创建' "
      "AND current_balance_cents = 0 "
      "AND credit_billing_day IS NULL "
      "AND NOT EXISTS (SELECT 1 FROM debts d "
      "                WHERE d.account_id = accounts.id "
      "                  AND d.subtype = 'card_loan' "
      "                  AND d.debt_type = 1)",
      [nowIso]);

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
