import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_row_codec.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

/// F17-T2(2026-09-06)/F18-T2(2026-09-08)一次应用的结果计数。
class PullApplyResult {
  const PullApplyResult({required this.applied, required this.skipped});

  /// 应用条数(upsert + delete)。坏条目不计(见 [failed] 语义的取舍:不设
  /// 独立计数,毒丸面以 debugPrint 观测 —— applied+skipped 可能 < 批量)。
  final int applied;

  /// 版本感知跳过条数(pending 行 local.version >= pulled.version;
  /// F17 时代语义 =「一刀切 pending 跳过」计数)。
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
///   envelope 行 → drift upsert。**版本感知 pending 规则(F18-T2 FR-4/
///   ADR-4,替换 F17 一刀切跳过)**:同 id 本地行存在且 pending 且
///   `local.version >= pulled.version` → 跳过 + 计 skipped(本地未上行编辑
///   是更新的本地事实,下行不得覆盖 —— 与 mirror ADR-3 的 delete-all 排除
///   pending 同族语义;单设备不变式:server 不可能有本地 pending 行的同
///   版本更新,此分支 = 原 F17 保护面唯一保留);`local.version <
///   pulled.version` → **应用**(server 已裁决/他设备更新胜出 —— 本地
///   pending 内容已在 server 冲突记录或已过时,B 设备由此收敛,F18 核心修复
///   点);本地非 pending(synced)照常 upsert(无未上行编辑事实,不设防线)。
///   **pulled.version 从 payload JSON 的 `Version` 键 probe**(F18-T1 裁决
///   警示:PulledChange.logVersion 是 tenant pull 游标,与实体乐观锁版本
///   两值,不得混用;payload 缺 Version 的防御性缺省 = 1 → 恒走保护分支)。
/// - `DELETE`:本地硬删,**不写墓碑、不问版本**(版本感知仅限 CREATE/UPDATE)
///   。墓碑表的两个职责(F10 ADR-4)对下行删除均不成立:①防镜像 rebuild
///   复活 —— rebuild 的数据源是 server 列表,而 server 侧该行已删
///   (pulled delete 的源头就是 server log),无复活面;②携带删除上行 ——
///   它已在上游生效,再上行是纯回声。且回声在多设备下**不是幂等无害**
///   而是乒乓:A 拉到 B 的删除 → 写墓碑 → A 下次触发把墓碑再推 → server
///   追加新 log 条目 → B 拉到(A 的回声,非 own-echo)→ 再应用再写墓碑 →
///   再推……每次触发每设备一条垃圾 log + 墓碑常驻 pendingCount(F12 badge
///   永久噪音,违背 F10-F13 零回归)。本地离线删除(BoundOfflineLocal
///   路由)照旧在删除当时写墓碑,上行语义闭环不变 —— 「照上行对称」的
///   准确形态即:上行删除的本地起点是墓碑,下行删除的本地终点是硬删。
///   pending 行的 DELETE 不跳过(存在性的终局裁决权在 server,本地未上行
///   编辑随行消亡)。
/// - 子表(分录/期次/预算项/目标链接)随头行**整体替换**:按头行 id 删
///   旧插新(单行 upsert 语义在子表集合上的推广;与 importer 的 purge+
///   insert 终态等价)。
/// - holding_ledger(ADR-4 台账查证裁决=实施):台账行无 syncState →
///   无 pending 保护面,恒应用;第二设备由此补齐 origin 设备的分红/买卖
///   台账记录。
///
/// **per-change 事务(F18-T2 FR-4/ADR-4,整批原子性降级)**:每条变更一个
/// drift 事务(头行+子表替换的多语句仍原子),坏条目(未知模块/坏 payload)
/// debugPrint + 条目级跳过 —— 不回滚整批、不向上抛,调用方(协调器)照常
/// 推进游标。论证:下行是 server 日志的**幂等重放**(同游标重拉即重放),
/// 单条失败不再钉死全局(F17 整批事务下一条毒丸 = 游标永久卡死);部分应用
/// 的不一致窗口由下次触发重拉自愈。事务成本裁量:N 条 = N 个事务(页大小
/// 上限 500)而非「无事务逐条」:子表整体替换是多语句,无事务会在半途留下
/// 头行新+子表旧的中间态,per-change 事务是隔离性与原子性的最小平衡。
///
/// guest 态:applier 本身**无门控**(纯数据应用组件);guest 不下行由
/// 协调器门控(guest 触发即 return,见 SyncCoordinatorBloc 类 doc)。
class PullApplier {
  PullApplier(this._db);

  final db.AppDatabase _db;

  /// 应用一批变更(按 server 契约的 logVersion 升序由调用方保证);
  /// **不抛出**(F18-T2 per-change 隔离:坏条目吞掉跳过,见类 doc)——
  /// 正常返回即调用方可安全推进游标。
  Future<PullApplyResult> apply(List<PulledChange> changes) async {
    var applied = 0;
    var skipped = 0;
    for (final c in changes) {
      try {
        await _db.transaction(() async {
          if (c.isDelete) {
            await _applyDelete(c);
            applied++;
            return;
          }
          // 解码一次供版本 probe 与 upsert 共用(单一 decode 点)。
          final row =
              jsonDecode(utf8.decode(c.payload)) as Map<String, dynamic>;
          final localPendingVersion =
              await _localPendingVersion(c.module, c.entityId);
          // 版本 probe:payload 内实体 Version(非 logVersion,论证见类 doc);
          // 缺省 1 = 防御性保守(本地 pending 行恒 >=1 → 走保护分支)。
          final pulledVersion = row['Version'] as int? ?? 1;
          if (localPendingVersion != null &&
              localPendingVersion >= pulledVersion) {
            skipped++;
            return;
          }
          // localPendingVersion == null(非 pending/不存在/台账)→ 照常
          // upsert;< pulledVersion → 应用(server 已裁决/他设备胜出)。
          await _applyUpsert(c, row);
          applied++;
        });
      } catch (e) {
        // 毒丸吸收:坏条目(未知模块/坏 payload)跳过不阻批;游标前进由
        // 调用方按「apply 正常返回」推进(English 结构化日志)。
        debugPrint('[pull-applier] change skipped (bad entry; cursor '
            'advances past it): module=${c.module} id=${c.entityId}: $e');
      }
    }
    return PullApplyResult(applied: applied, skipped: skipped);
  }

  /// 本地行 pending 时的版本(pending 保护的比较输入);非 pending/本地
  /// 不存在 → null(无保护面);holding_ledger 无 syncState → 恒 null。
  /// 未知模块抛出(由 per-change 隔离吞为毒丸跳过)。
  Future<int?> _localPendingVersion(String module, String entityId) async {
    switch (module) {
      case SyncModule.account:
        final row = await _db.accountDao.getAccountById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.transaction:
        final row = await _db.transactionDao.getTransactionById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.debt:
        final row = await _db.debtDao.getDebtById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.budget:
        final row = await _db.budgetDao.getBudgetById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.goal:
        final row = await _db.goalDao.getGoalById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.holding:
        final row = await _db.holdingDao.getHoldingById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.tag:
        final row = await _db.tagDao.getTagById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.template:
        final row = await _db.templateDao.getTemplateById(entityId);
        return row != null && row.syncState == SyncState.pending
            ? row.version
            : null;
      case SyncModule.holdingLedger:
        return null; // 台账行无 syncState(append-only)→ 恒应用
      default:
        // fail-closed:未知模块与 server 的 entityType 门同哲学(per-change
        // 隔离下 = 单条毒丸跳过,不阻批)。
        throw StateError('pull applier: unknown module "$module"');
    }
  }

  /// upsert 应用。**F18-T2 落点**:头行 companion 一律显式携带
  /// `syncState=synced` —— envelope 行无本地私有列(envelope_codec 契约),
  /// insertOnConflictUpdate 对已存在行只更新 companion 所载字段;版本感知
  /// 应用分支(本地 pending 行被 server 裁决版本覆盖)若不显式收敛,
  /// 行会残留 pending → collector 反复重推已应用的 server 内容(字节相同
  /// 靠 F18-T1 短路兜底,但 pendingCount 常驻噪音 + 永不回写)。下行应用
  /// 的语义即「server 终态已到本地」→ synced;新插入路径与列缺省同值,
  /// 原有 synced 覆盖路径无行为变化。
  Future<void> _applyUpsert(
      PulledChange c, Map<String, dynamic> row) async {
    switch (c.module) {
      case SyncModule.account:
        await _db
            .into(_db.accounts)
            .insertOnConflictUpdate(accountRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
      case SyncModule.transaction:
        await _db.into(_db.transactions).insertOnConflictUpdate(
            transactionRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
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
            .insertOnConflictUpdate(debtRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
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
            .insertOnConflictUpdate(budgetRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
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
            .insertOnConflictUpdate(goalRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
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
            .insertOnConflictUpdate(holdingRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
      case SyncModule.holdingLedger:
        await _db.holdingDao
            .upsertHoldingTransaction(holdingTxnRowFromEnvelope(row));
      case SyncModule.tag:
        await _db
            .into(_db.tags)
            .insertOnConflictUpdate(tagRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
      case SyncModule.template:
        await _db
            .into(_db.transactionTemplates)
            .insertOnConflictUpdate(templateRowFromEnvelope(row)
                .copyWith(syncState: const Value(SyncState.synced)));
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
