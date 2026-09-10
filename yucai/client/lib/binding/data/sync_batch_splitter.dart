/// F19-T1(2026-09-11,spec FR-3,design ADR-3):合并链批次拆分纯函数 ——
/// 把 PendingCollector 的一次全量批次按条数切成多个 [SyncBatch],逐批经
/// OfflineSyncPort.push 上行。
///
/// 为什么拆:grpc 默认 4MB 接收上限 + server PushChanges 单事务 —— 几千笔
/// 全量单批触顶(analysis 缺口②);200 条/批是序列化尺寸与事务粒度的平衡
/// (spec Grill record 定案,常量由调用方携带,可调)。
///
/// 切法:**墓碑+实体混合切**(ADR-3)—— 墓碑在前、实体按模块桶序在后的
/// 扁平流按 maxSize 定长切块,块内实体回桶、墓碑回列;server 按依赖序
/// 重排,对客户端切分序不敏感(port encodeRequest 同约定)。条目不丢
/// 不重(纯函数无状态,调用方可用 changeCount 求和断言)。
library;

import 'package:yucai_client/binding/domain/offline_sync_port.dart';

/// [batch] 按 [maxSize] 条/批切块;空批次返回空列表。
///
/// [maxSize] ≤0 防御按 1 处理(每批一条,语义退化为逐条,不另抛错)。
List<SyncBatch> splitSyncBatch(SyncBatch batch, int maxSize) {
  final size = maxSize <= 0 ? 1 : maxSize;
  final chunks = <SyncBatch>[];
  // 当前累积批的可变缓冲;flush 时冻结为不可变 SyncBatch 入列。
  var tombstones = <SyncTombstoneDto>[];
  var buckets = <String, List<SyncEntityDto>>{};
  var count = 0;

  void flush() {
    if (count == 0) return;
    chunks.add(SyncBatch(entitiesByModule: buckets, tombstones: tombstones));
    tombstones = <SyncTombstoneDto>[];
    buckets = <String, List<SyncEntityDto>>{};
    count = 0;
  }

  for (final t in batch.tombstones) {
    if (count >= size) flush();
    tombstones.add(t);
    count++;
  }
  for (final entry in batch.entitiesByModule.entries) {
    for (final e in entry.value) {
      if (count >= size) flush();
      (buckets[entry.key] ??= []).add(e);
      count++;
    }
  }
  flush();
  return chunks;
}
