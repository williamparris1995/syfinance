import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/envelope_codec.dart';
import 'package:yucai_client/core/localdb/sync_state.dart';

/// F10 T3(spec FR-5,design ADR-5):pending 收集器 —— 回网时从 DAO 读取
/// 各模块待上行头行 + 墓碑,构造 [SyncBatch] 交协调器上行。
///
/// F11 T3 编码路径定案(简报第 4 节,选 (b) 的变体、映射落在收集器):
/// `fields` = drift 头行经 **envelope_codec**(与备份导出同一份映射,ADR-2
/// 单一事实源)产出的 server 兼容行形态 —— PascalCase/int 枚举/RFC3339 Z/
/// 无 tenant 键/剔 syncState,子表(交易分录/债务期次/预算项/目标链接)
/// 在此随头行嵌套;gRPC port 只做 `jsonEncode(fields) → payload bytes`,
/// 不再触库。未选简报 (a)(收集器改产 domain 实体)的理由:local_snapshot_
/// exporter 的行序列化**事实源本来就是 drift 行**(其模块 mapper 从 DAO 行
/// 直达 PascalCase map,domain 实体从不参与备份链);改产 domain 实体要么
/// 另写一套 domain→envelope 序列化(违背单一事实源),要么把 exporter 整链
/// 重走 domain(改造面远大于本路径)。
///
/// F17-T2(ADR-4 台账查证裁决=实施):holding 台账行随批上行 ——
/// entityType=holding_ledger(server 第 9 个 writer 已注册,entitywriter/
/// holding_ledger.go),行形态=envelope_codec 的 holdingTxnRowToEnvelope。
/// **关联口径(ADR-4 留给 T2 的决策)**:台账行无 syncState,以 pending
/// 持仓头行为**收集锚** —— 头行 pending ⇒ 同 (account,security) pair 的
/// 台账**全量**随批(含历史已上行行)。代价是重复上行旧行;无害论证:
/// server UpsertForSync 按 id 幂等(重推=同内容覆盖),pull 面他设备按
/// logVersion 顺序应用同样幂等 —— 相比为台账行加 syncState 列(表结构
/// 迁移 + 8 头表语义外扩)或跟踪「头行 pending 期间新增」的窄窗口(需
/// 额外时间戳协议),全量重收是最小而正确的口径。孤儿分红由此闭环:
/// 第二设备 pull 到 holding_ledger 行后由 PullApplier 补齐分红记录(spec
/// FR-4),F11 时代「台账行不出 origin 设备」的缺口消除;台账无本地删除
/// 路径,墓碑面不适用。
///
/// DTO 的 entityId 与 fields 内 `ID` 同源于 drift 行主键(构造即一致 ——
/// server T1 对不一致 fail-closed,该不变量由 port 测试钉死)。
///
/// DI:injection.dart 手工注册(照 ConnectivityGateway 先例,免 build_runner)。
class PendingCollector {
  PendingCollector(this._db);

  final db.AppDatabase _db;

  /// 收集一次完整批次;空批次(无 pending 无墓碑)返回 null。
  Future<SyncBatch?> collect() async {
    final buckets = <String, List<SyncEntityDto>>{};

    // 8 头表逐一收集(空模块不落桶);行形态经 envelope_codec(单一事实源)。
    for (final row in await _db.accountDao.getPendingAccounts()) {
      _put(buckets, SyncModule.account,
          entityId: row.id, version: row.version,
          fields: accountRowToEnvelope(row));
    }

    final pendingTxns = await _db.transactionDao.getPendingTransactions();
    if (pendingTxns.isNotEmpty) {
      // 分录子表随头行上行(与备份导出同构:全量分录按 transactionId 分组)。
      final entriesByTxn = <String, List<db.TransactionEntry>>{};
      for (final e in await _db.transactionDao.getAllEntries()) {
        entriesByTxn.putIfAbsent(e.transactionId, () => []).add(e);
      }
      for (final row in pendingTxns) {
        _put(buckets, SyncModule.transaction,
            entityId: row.id, version: row.version,
            fields:
                transactionRowToEnvelope(row, entriesByTxn[row.id] ?? const []));
      }
    }

    for (final row in await _db.debtDao.getPendingDebts()) {
      _put(buckets, SyncModule.debt,
          entityId: row.id, version: row.version,
          fields: debtRowToEnvelope(
              row, await _db.debtDao.getScheduleByDebt(row.id)));
    }
    for (final row in await _db.budgetDao.getPendingBudgets()) {
      _put(buckets, SyncModule.budget,
          entityId: row.id, version: row.version,
          fields:
              budgetRowToEnvelope(row, await _db.budgetDao.getItemsByBudget(row.id)));
    }
    for (final row in await _db.goalDao.getPendingGoals()) {
      final (accounts, debts) = await _db.goalDao.linksFor(row.id);
      _put(buckets, SyncModule.goal,
          entityId: row.id, version: row.version,
          fields: goalRowToEnvelope(row, accounts, debts));
    }
    final pendingHoldings = await _db.holdingDao.getPendingHoldings();
    for (final row in pendingHoldings) {
      // 单持仓行形态(server HoldingWriter 契约;台账行不嵌套,走下方
      // holding_ledger 独立 entityType)。
      _put(buckets, SyncModule.holding,
          entityId: row.id, version: row.version,
          fields: holdingRowToEnvelope(row));
    }
    // F17-T2 台账联动:pending 头行为锚,同 (account,security) pair 的台账
    // 全量随批(关联口径论证见类 doc)。version 恒 1:台账 append-only 无
    // 乐观锁版本,客户端恒 CREATE(server 对 CREATE 不做冲突检查)。
    if (pendingHoldings.isNotEmpty) {
      final pendingPairs = <String>{
        for (final h in pendingHoldings) '${h.accountId}|${h.securityId}',
      };
      for (final t in await _db.holdingDao.getAllHoldingTransactions()) {
        if (!pendingPairs.contains('${t.accountId}|${t.securityId}')) continue;
        _put(buckets, SyncModule.holdingLedger,
            entityId: t.id, version: 1, fields: holdingTxnRowToEnvelope(t));
      }
    }
    for (final row in await _db.tagDao.getPendingTags()) {
      _put(buckets, SyncModule.tag,
          entityId: row.id, version: row.version, fields: tagRowToEnvelope(row));
    }
    for (final row in await _db.templateDao.getPendingTemplates()) {
      _put(buckets, SyncModule.template,
          entityId: row.id, version: row.version,
          fields: templateRowToEnvelope(row));
    }

    final tombstones = (await _db.syncTombstoneDao.getAllTombstones())
        .map((t) => SyncTombstoneDto(
              module: t.module,
              entityId: t.entityId,
              deletedAt: t.deletedAt,
            ))
        .toList();

    if (buckets.isEmpty && tombstones.isEmpty) return null;
    return SyncBatch(entitiesByModule: buckets, tombstones: tombstones);
  }

  void _put(Map<String, List<SyncEntityDto>> buckets, String module,
      {required String entityId,
      required int version,
      required Map<String, dynamic> fields}) {
    (buckets[module] ??= []).add(SyncEntityDto(
      module: module,
      entityId: entityId,
      version: version,
      fields: fields,
    ));
  }
}
