import 'dart:convert';

import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_row_codec.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

/// F17-T2(spec FR-3,design ADR-2)一次应用的结果计数。
class PullApplyResult {
  const PullApplyResult({required this.applied, required this.skipped});

  /// 应用条数(upsert + delete)。
  final int applied;

  /// pending 保护跳过条数(本地未上行编辑不被下行覆盖)。
  final int skipped;
}

/// F17-T2(spec FR-3,design ADR-2):增量下行应用器 —— PullChanges 的
/// changes(原始 payload 流)逐条应用到本地 drift。
///
/// 与 mirror 的分工(design ADR-2):mirror=全量重建(登录/绑定/推送后按
/// 模块刷新);applier=运行时增量(push 成功后/回网的窄幅下行)。与
/// archive_importer 的分工:importer=purge+全量 insert(备份恢复);
/// applier=**单行 upsert**(同 id insertOnConflictUpdate)+ 按头行 id 替换
/// 子表 —— 行→Companion 映射两处共享 `envelope_row_codec.dart`(2026-09-06
/// 从 importer 原位抽取,单一事实源,防字段漂移)。
///
/// 逐条语义:
/// - `CREATE/UPDATE`(客户端合并为同一 upsert 面):payload jsonDecode →
///   envelope 行 → drift upsert。**pending 保护**:同 id 本地 pending →
///   跳过 + 计 skipped(本地未上行编辑是更新的本地事实,下行不得覆盖 ——
///   与 mirror ADR-3 的 delete-all 排除 pending 同族语义;server 现行随后
///   会在本地 pending 上行后经镜像刷新收敛)。
/// - `DELETE`:本地硬删,**不写墓碑**。墓碑表的两个职责(F10 ADR-4)对
///   下行删除均不成立:①防镜像 rebuild 复活 —— rebuild 的数据源是 server
///   列表,而 server 侧该行已删(pulled delete 的源头就是 server log),
///   无复活面;②携带删除上行 —— 它已在上游生效,再上行是纯回声。且回声
///   在多设备下**不是幂等无害**而是乒乓:A 拉到 B 的删除 → 写墓碑 → A 下
///   次触发把墓碑再推 → server 追加新 log 条目 → B 拉到(A 的回声,非
///   own-echo)→ 再应用再写墓碑 → 再推……每次触发每设备一条垃圾 log + 
///   墓碑常驻 pendingCount(F12 badge 永久噪音,违背 F10-F13 零回归)。
///   本地离线删除(BoundOfflineLocal 路由)照旧在删除当时写墓碑,上行
///   语义闭环不变 —— 「照上行对称」的准确形态即:上行删除的本地起点是
///   墓碑,下行删除的本地终点是硬删。pending 行的 DELETE 不跳过(简报
///   口径:pending 跳过仅限 CREATE/UPDATE —— 存在性的终局裁决权在
///   server,本地未上行编辑随行消亡)。
/// - 子表(分录/期次/预算项/目标链接)随头行**整体替换**:按头行 id 删
///   旧插新(单行 upsert 语义在子表集合上的推广;与 importer 的 purge+
///   insert 终态等价)。
/// - holding_ledger(ADR-4 台账查证裁决=实施):台账行无 syncState →
///   无 pending 保护面,恒应用;第二设备由此补齐 origin 设备的分红/买卖
///   台账记录。
///
/// **整批单 drift 事务(原子应用)**:任一条失败(坏 payload/未知模块
/// fail-closed 抛出,与 server 未知 entityType 哲学一致)全批回滚 ——
/// 半应用状态不存在,下次触发以同游标幂等重拉重放。
///
/// guest 态:applier 本身**无门控**(纯数据应用组件);guest 不下行由
/// 协调器门控(guest 触发即 return,见 SyncCoordinatorBloc 类 doc)。
class PullApplier {
  PullApplier(this._db);

  final db.AppDatabase _db;

  /// 应用一批变更(按 server 契约的 logVersion 升序由调用方保证);
  /// 抛出=整批失败(已回滚)。
  Future<PullApplyResult> apply(List<PulledChange> changes) async {
    var applied = 0;
    var skipped = 0;
    await _db.transaction(() async {
      for (final c in changes) {
        if (c.isDelete) {
          await _applyDelete(c);
          applied++;
        } else {
          if (await _isLocalPending(c.module, c.entityId)) {
            skipped++;
            continue;
          }
          await _applyUpsert(c);
          applied++;
        }
      }
    });
    return PullApplyResult(applied: applied, skipped: skipped);
  }

  /// 同 id 本地行是否 pending(下行不覆盖未上行编辑;holding_ledger 无
  /// syncState → 恒 false)。
  Future<bool> _isLocalPending(String module, String entityId) async {
    switch (module) {
      case SyncModule.account:
        return (await _db.accountDao.getAccountById(entityId))?.syncState ==
            SyncState.pending;
      case SyncModule.transaction:
        return (await _db.transactionDao.getTransactionById(entityId))
                ?.syncState ==
            SyncState.pending;
      case SyncModule.debt:
        return (await _db.debtDao.getDebtById(entityId))?.syncState ==
            SyncState.pending;
      case SyncModule.budget:
        return (await _db.budgetDao.getBudgetById(entityId))?.syncState ==
            SyncState.pending;
      case SyncModule.goal:
        return (await _db.goalDao.getGoalById(entityId))?.syncState ==
            SyncState.pending;
      case SyncModule.holding:
        return (await _db.holdingDao.getHoldingById(entityId))?.syncState ==
            SyncState.pending;
      case SyncModule.tag:
        return (await _db.tagDao.getTagById(entityId))?.syncState ==
            SyncState.pending;
      case SyncModule.template:
        return (await _db.templateDao.getTemplateById(entityId))?.syncState ==
            SyncState.pending;
      case SyncModule.holdingLedger:
        return false; // 台账行无 syncState(append-only)
      default:
        // fail-closed:未知模块与 server 的 entityType 门同哲学。
        throw StateError('pull applier: unknown module "$module"');
    }
  }

  Future<void> _applyUpsert(PulledChange c) async {
    final row =
        jsonDecode(utf8.decode(c.payload)) as Map<String, dynamic>;
    switch (c.module) {
      case SyncModule.account:
        await _db
            .into(_db.accounts)
            .insertOnConflictUpdate(accountRowFromEnvelope(row));
      case SyncModule.transaction:
        await _db.into(_db.transactions).insertOnConflictUpdate(
            transactionRowFromEnvelope(row));
        // 分录整体替换(单行 upsert 的子表推广)。
        await (_db.delete(_db.transactionEntries)
              ..where((t) => t.transactionId.equals(c.entityId)))
            .go();
        for (final e in (row['Entries'] as List? ?? [])) {
          await _db.transactionDao.insertEntry(entryRowFromEnvelope(
              c.entityId, e as Map<dynamic, dynamic>));
        }
      case SyncModule.debt:
        await _db
            .into(_db.debts)
            .insertOnConflictUpdate(debtRowFromEnvelope(row));
        await (_db.delete(_db.paymentScheduleEntries)
              ..where((t) => t.debtId.equals(c.entityId)))
            .go();
        for (final s in (row['Schedule'] as List? ?? [])) {
          await _db.debtDao.insertScheduleEntry(scheduleRowFromEnvelope(
              c.entityId, s as Map<dynamic, dynamic>));
        }
      case SyncModule.budget:
        await _db
            .into(_db.budgets)
            .insertOnConflictUpdate(budgetRowFromEnvelope(row));
        await (_db.delete(_db.budgetItems)
              ..where((t) => t.budgetId.equals(c.entityId)))
            .go();
        for (final i in (row['Items'] as List? ?? [])) {
          await _db.budgetDao.insertItem(budgetItemRowFromEnvelope(
              c.entityId, i as Map<dynamic, dynamic>));
        }
      case SyncModule.goal:
        await _db
            .into(_db.goals)
            .insertOnConflictUpdate(goalRowFromEnvelope(row));
        // 目标链接整体替换(链接表已折叠为 uuid 数组随行)。
        await (_db.delete(_db.goalAccountLinks)
              ..where((t) => t.goalId.equals(c.entityId)))
            .go();
        await (_db.delete(_db.goalDebtLinks)
              ..where((t) => t.goalId.equals(c.entityId)))
            .go();
        for (final a in (row['LinkedAccountIDs'] as List? ?? [])) {
          await _db.goalDao.insertAccountLink(
              db.GoalAccountLinksCompanion.insert(
                  goalId: c.entityId, linkedId: a as String));
        }
        for (final d in (row['LinkedDebtIDs'] as List? ?? [])) {
          await _db.goalDao.insertDebtLink(db.GoalDebtLinksCompanion.insert(
              goalId: c.entityId, linkedId: d as String));
        }
      case SyncModule.holding:
        // 单持仓行形态(台账行不嵌套,走 holding_ledger)。
        await _db
            .into(_db.holdings)
            .insertOnConflictUpdate(holdingRowFromEnvelope(row));
      case SyncModule.holdingLedger:
        await _db.holdingDao
            .upsertHoldingTransaction(holdingTxnRowFromEnvelope(row));
      case SyncModule.tag:
        await _db
            .into(_db.tags)
            .insertOnConflictUpdate(tagRowFromEnvelope(row));
      case SyncModule.template:
        await _db
            .into(_db.transactionTemplates)
            .insertOnConflictUpdate(templateRowFromEnvelope(row));
      default:
        throw StateError('pull applier: unknown module "${c.module}"');
    }
  }

  Future<void> _applyDelete(PulledChange c) async {
    switch (c.module) {
      case SyncModule.account:
        await _db.accountDao.deleteAccountById(c.entityId);
      case SyncModule.transaction:
        // 分录经 FK cascade 清(PRAGMA foreign_keys=ON)。
        await _db.transactionDao.deleteTransactionById(c.entityId);
      case SyncModule.debt:
        await _db.debtDao.deleteDebtById(c.entityId);
      case SyncModule.budget:
        await _db.budgetDao.deleteBudgetById(c.entityId);
      case SyncModule.goal:
        await _db.goalDao.deleteGoalById(c.entityId);
      case SyncModule.holding:
        await _db.holdingDao.deleteHoldingById(c.entityId);
      case SyncModule.holdingLedger:
        await (_db.delete(_db.holdingTransactions)
              ..where((t) => t.id.equals(c.entityId)))
            .go();
      case SyncModule.tag:
        await _db.tagDao.deleteTagById(c.entityId);
      case SyncModule.template:
        await _db.templateDao.deleteTemplateById(c.entityId);
      default:
        throw StateError('pull applier: unknown module "${c.module}"');
    }
    // 不写墓碑(论证见类 doc DELETE 段):pulled delete 的源头即 server
    // log,再上行是回声;多设备回声乒乓见类 doc。
  }
}
