import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';

/// F10 T3(spec FR-5,design ADR-5):pending 收集器 —— 回网时从 DAO 读取
/// 各模块待上行头行 + 墓碑,构造 [SyncBatch] 交协调器上行。
///
/// DTO 形态取 drift 行的 toJson 快照(mirror_mappers 的逆向即实体→行,上行
/// 直接用行裸值更无损;对齐 sync proto SyncPayload 语义走向见 port 文件头)。
/// 子表数据(交易分录/债务期次/持仓台账等)随头行模块上行,F11 编码 payload
/// 时按模块补齐子集合 —— 本任务的 fake port 只消费头行 id/版本即足。
///
/// DI:injection.dart 手工注册(照 ConnectivityGateway 先例,免 build_runner)。
class PendingCollector {
  PendingCollector(this._db);

  final db.AppDatabase _db;

  /// 收集一次完整批次;空批次(无 pending 无墓碑)返回 null。
  Future<SyncBatch?> collect() async {
    final buckets = <String, List<SyncEntityDto>>{};

    // 8 头表逐一收集(空模块不落桶)。
    for (final row in await _db.accountDao.getPendingAccounts()) {
      _put(buckets, SyncModule.account,
          entityId: row.id, version: row.version, fields: row.toJson());
    }
    for (final row in await _db.transactionDao.getPendingTransactions()) {
      _put(buckets, SyncModule.transaction,
          entityId: row.id, version: row.version, fields: row.toJson());
    }
    for (final row in await _db.debtDao.getPendingDebts()) {
      _put(buckets, SyncModule.debt,
          entityId: row.id, version: row.version, fields: row.toJson());
    }
    for (final row in await _db.budgetDao.getPendingBudgets()) {
      _put(buckets, SyncModule.budget,
          entityId: row.id, version: row.version, fields: row.toJson());
    }
    for (final row in await _db.goalDao.getPendingGoals()) {
      _put(buckets, SyncModule.goal,
          entityId: row.id, version: row.version, fields: row.toJson());
    }
    for (final row in await _db.holdingDao.getPendingHoldings()) {
      _put(buckets, SyncModule.holding,
          entityId: row.id, version: row.version, fields: row.toJson());
    }
    for (final row in await _db.tagDao.getPendingTags()) {
      _put(buckets, SyncModule.tag,
          entityId: row.id, version: row.version, fields: row.toJson());
    }
    for (final row in await _db.templateDao.getPendingTemplates()) {
      _put(buckets, SyncModule.template,
          entityId: row.id, version: row.version, fields: row.toJson());
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
      {required String entityId, required int version, required Map<String, dynamic> fields}) {
    (buckets[module] ??= []).add(SyncEntityDto(
      module: module,
      entityId: entityId,
      version: version,
      fields: fields,
    ));
  }
}
