// F19-T1(2026-09-11,spec FR-3/design ADR-3):批次拆分纯函数 —— 合并链把
// 收集批次按 200 条/批切成多个 SyncBatch(gRPC 默认 4MB 接收上限 + server
// 单事务,几千笔单批触顶;墓碑+实体混合切)。
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/data/sync_batch_splitter.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;

SyncEntityDto dto(String module, String id) => SyncEntityDto(
    module: module, entityId: id, version: 1, fields: {'ID': id});

SyncTombstoneDto tombstone(String module, String id) => SyncTombstoneDto(
    module: module, entityId: id, deletedAt: DateTime.utc(2026, 9, 11));

void main() {
  test('空批次 → 空列表(调用方 collect=null 不拆,防御面)', () {
    const batch = SyncBatch(entitiesByModule: {}, tombstones: []);
    expect(splitSyncBatch(batch, 200), isEmpty);
  });

  test('≤maxSize 单批直通,模块分桶与墓碑保持', () {
    final batch = SyncBatch(entitiesByModule: {
      SyncModule.account: [dto(SyncModule.account, 'a1')],
      SyncModule.tag: [dto(SyncModule.tag, 't1')],
    }, tombstones: [
      tombstone(SyncModule.transaction, 'x1')
    ]);

    final subs = splitSyncBatch(batch, 200);

    expect(subs, hasLength(1));
    expect(subs.single.changeCount, 3);
    expect(subs.single.entitiesByModule[SyncModule.account]
        ?.single.entityId, 'a1');
    expect(
        subs.single.entitiesByModule[SyncModule.tag]?.single.entityId, 't1');
    expect(subs.single.tombstones.single.entityId, 'x1');
  });

  test('201 条 → 2 批(200+1);条目不丢不重', () {
    final entities = [
      for (var i = 0; i < 201; i++) dto(SyncModule.account, 'a$i'),
    ];
    final batch = SyncBatch(
        entitiesByModule: {SyncModule.account: entities}, tombstones: const []);

    final subs = splitSyncBatch(batch, 200);

    expect(subs, hasLength(2));
    expect(subs.first.changeCount, 200);
    expect(subs.last.changeCount, 1);
    final allIds = [
      for (final sub in subs)
        for (final e in sub.entitiesByModule[SyncModule.account]!) e.entityId,
    ];
    expect(allIds.toSet().length, 201); // 不重
    expect(allIds.toSet(), {for (var i = 0; i < 201; i++) 'a$i'}); // 不丢
  });

  test('墓碑+实体混合切:跨界批同时含墓碑与实体(顺序墓碑在前)', () {
    final batch = SyncBatch(entitiesByModule: {
      SyncModule.account: [
        for (var i = 0; i < 195; i++) dto(SyncModule.account, 'a$i'),
      ],
    }, tombstones: [
      for (var i = 0; i < 10; i++) tombstone(SyncModule.tag, 't$i'),
    ]);

    final subs = splitSyncBatch(batch, 200);

    expect(subs, hasLength(2));
    // 首批:10 墓碑 + 190 实体;次批:余 5 实体。
    expect(subs.first.tombstones, hasLength(10));
    expect(subs.first.entitiesByModule[SyncModule.account], hasLength(190));
    expect(subs.last.tombstones, isEmpty);
    expect(subs.last.entitiesByModule[SyncModule.account], hasLength(5));
    expect(subs.first.changeCount + subs.last.changeCount, 205);
  });

  test('跨模块边界不并批错桶:同批内各模块自桶,跨批同模块续桶', () {
    final batch = SyncBatch(entitiesByModule: {
      SyncModule.account: [
        for (var i = 0; i < 150; i++) dto(SyncModule.account, 'a$i'),
      ],
      SyncModule.tag: [
        for (var i = 0; i < 150; i++) dto(SyncModule.tag, 't$i'),
      ],
    }, tombstones: const []);

    final subs = splitSyncBatch(batch, 200);

    expect(subs, hasLength(2));
    // 首批:150 account + 50 tag;次批:余 100 tag。
    expect(subs.first.entitiesByModule[SyncModule.account], hasLength(150));
    expect(subs.first.entitiesByModule[SyncModule.tag], hasLength(50));
    expect(subs.last.entitiesByModule.containsKey(SyncModule.account), isFalse);
    expect(subs.last.entitiesByModule[SyncModule.tag], hasLength(100));
  });
}
