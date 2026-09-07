// F10 T3(2026-09-04):SyncCoordinatorBloc(spec FR-5,design ADR-5/LLD)。
// - 仅 bound 态生效(guest 不触发);
// - 空批次 → clean 且不 push;
// - 成功链:syncing(n) → 回写 synced + 清墓碑 + 按模块刷新镜像 → clean;
// - 失败链:failed(reason)+ pending 保留 → 再触发成功;
// - 进行中幂等:flight 期间重入触发被丢弃(push 恰一次);
// - 回网 true 边沿(注入流)触发。
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

class _MockMirror extends Mock implements BoundMirror {}

/// 可编程 fake port:记录批次;gate 悬住 push 制造 flight 窗口。
class _FakePort implements OfflineSyncPort {
  final batches = <SyncBatch>[];
  SyncResult nextResult = const SyncResult.success();
  Completer<void>? gate;
  bool inFlight = false;

  // F17-T1:接口新增成员的替身实现(协调器链路不触注册,绑定流程才调)。
  @override
  Future<void> registerDevice(String deviceName) async {}

  // F17-T2:pull 替身 —— 本组测试不注入 applier(拉取编排不生效),
  // 恒空页即可(接口完备性)。
  @override
  Future<PullBatch> pull(int sinceVersion,
      {List<String>? entityTypes, int? pageSize}) async {
    return PullBatch(
        changes: const [], latestVersion: sinceVersion, hasMore: false);
  }

  @override
  Future<SyncResult> push(SyncBatch batch) async {
    batches.add(batch);
    inFlight = true;
    await gate?.future;
    inFlight = false;
    return nextResult;
  }
}

void main() {
  late db.AppDatabase database;
  late _FakePort port;
  late _MockMirror mirror;
  late SessionModeTracker tracker;
  late StreamController<bool> online;
  late SyncCoordinatorBloc bloc;
  final states = <SyncCoordinatorState>[];

  setUpAll(() => registerFallbackValue(MirrorModule.account));

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    port = _FakePort();
    mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    tracker = SessionModeTracker()..isGuest = false; // bound(在线快照缺省 true)
    online = StreamController<bool>.broadcast();
    bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
    );
    states
      ..clear()
      ..addAll([bloc.state]);
    bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await bloc.close();
    await online.close();
    await database.close();
  });

  Future<void> seedPending() async {
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-1',
      name: '离线账户',
      accountType: 1,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
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
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
      syncState: const Value(SyncState.pending),
    ));
    await database.tagDao.insertTag(db.TagsCompanion.insert(
      id: 'tag-1',
      name: '离线标签',
      color: '#000000',
      version: 1,
      createdAt: DateTime.utc(2026, 9, 4),
      updatedAt: DateTime.utc(2026, 9, 4),
      syncState: const Value(SyncState.pending),
    ));
    await database.syncTombstoneDao.upsertTombstone(
        db.SyncTombstonesCompanion.insert(
            module: SyncModule.tag,
            entityId: 'tag-del',
            deletedAt: DateTime.utc(2026, 9, 4)));
  }

  Future<void> until(bool Function() cond,
      [String reason = 'condition not met within timeout']) async {
    final sw = Stopwatch()..start();
    while (!cond() && sw.elapsed < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue, reason: reason);
  }

  test('guest 态不触发:事件到达后保持 idle,port 未被调用', () async {
    tracker.isGuest = true;
    await seedPending();

    bloc.add(SyncRetryRequested());
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.status, SyncStatus.idle);
    expect(port.batches, isEmpty);
    verifyNever(() => mirror.refreshModule(any()));
  });

  test('bound + 空批次 → clean 且不 push', () async {
    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(port.batches, isEmpty);
    expect(bloc.state.pendingCount, 0);
  });

  test('成功链:syncing(n) → 回写 synced + 清墓碑 + 按模块刷新镜像 → clean',
      () async {
    await seedPending();

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    // fake port 收到的批次:跨模块实体 + 墓碑。
    expect(port.batches, hasLength(1));
    final batch = port.batches.single;
    expect(batch.entitiesByModule[SyncModule.account]!.single.entityId, 'acc-1');
    expect(batch.entitiesByModule[SyncModule.tag]!.single.entityId, 'tag-1');
    expect(batch.tombstones.single.entityId, 'tag-del');
    expect(batch.changeCount, 3);

    // 状态流转:syncing(3) → clean。
    expect(
        states.map((s) => (s.status, s.pendingCount)),
        contains(const (SyncStatus.syncing, 3)));
    expect(states.last.status, SyncStatus.clean);

    // 回写:pending → synced;墓碑清除。
    final accounts = await database.accountDao.getPendingAccounts();
    final tags = await database.tagDao.getPendingTags();
    expect(accounts, isEmpty);
    expect(tags, isEmpty);
    expect((await database.accountDao.getAccountById('acc-1'))!.syncState,
        SyncState.synced);
    expect((await database.tagDao.getTagById('tag-1'))!.syncState,
        SyncState.synced);
    expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);

    // 镜像按批次涉及模块刷新(account 实体 + tag 实体/墓碑)。
    verify(() => mirror.refreshModule(MirrorModule.account)).called(1);
    verify(() => mirror.refreshModule(MirrorModule.tag)).called(1);
    verifyNever(() => mirror.refreshModule(MirrorModule.debt));
  });

  test('失败链:failed(reason)+ pending 保留 → 再触发成功 → clean', () async {
    await seedPending();
    port.nextResult = const SyncResult.failure('无法连接服务器');

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.failed);

    expect(bloc.state.failureReason, contains('无法连接服务器'));
    // pending 保留(下次触发重试)。
    expect(await database.accountDao.getPendingAccounts(), hasLength(1));
    expect(await database.tagDao.getPendingTags(), hasLength(1));
    expect(await database.syncTombstoneDao.getAllTombstones(), hasLength(1));
    verifyNever(() => mirror.refreshModule(any()));

    // 再触发(手动 retry,port 换成功)。
    port.nextResult = const SyncResult.success();
    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(port.batches, hasLength(2));
    expect(await database.accountDao.getPendingAccounts(), isEmpty);
    expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);
  });

  test('F17-T1 冲突透传:push 成功携带 conflicts → clean 态 conflictCount 携带',
      () async {
    await seedPending();
    port.nextResult = const SyncResult.success(conflicts: [
      SyncConflictInfo(
          module: SyncModule.tag,
          entityId: 'tag-1',
          conflictType: 'version_conflict'),
      SyncConflictInfo(
          module: SyncModule.account,
          entityId: 'acc-9',
          conflictType: 'version_conflict'),
    ]);

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    // ok 语义不变(clean,回写照常);冲突计数仅状态携带 —— F12 badge 组件
    // 不改(F18 面板消费),协调器只透传。
    expect(bloc.state.conflictCount, 2);
    expect(await database.accountDao.getPendingAccounts(), isEmpty);
  });

  test('进行中幂等:flight 期间重入触发被丢弃(push 恰一次)', () async {
    await seedPending();
    port.gate = Completer<void>();
    port.nextResult = const SyncResult.failure('模拟断网');

    bloc.add(SyncRetryRequested());
    online.add(true); // 回网边沿通道(经订阅转发,双通道重入)
    await until(() => port.inFlight, 'push 未进入 flight');

    // flight 中再补一路手动 retry → 三路重入均被丢弃。
    bloc.add(SyncRetryRequested());

    port.gate!.complete();
    await until(() => bloc.state.status == SyncStatus.failed);

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(port.batches, hasLength(1)); // 恰一次 push
    expect(states.where((s) => s.status == SyncStatus.syncing), hasLength(1));
    // pending 保留,可再触发。
    expect(await database.accountDao.getPendingAccounts(), hasLength(1));
  });

  test('回网 true 边沿(注入流)触发完整链', () async {
    await seedPending();

    online.add(true);
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(port.batches, hasLength(1));
    expect(bloc.state.status, SyncStatus.clean);
  });

  test('版本守卫:push 在途的本地再更新(FR-1b 降级,版本推进)不被陈旧快照误标 synced',
      () async {
    await seedPending(); // tag-1 version=1 pending(快照进批次)
    port.gate = Completer<void>();

    bloc.add(SyncRetryRequested());
    await until(() => port.inFlight, 'push 未进入 flight');

    // 在途模拟:FR-1b 再次降级 update —— 版本推进到 2、行保持 pending。
    await database.tagDao.updateTag(db.TagsCompanion(
      id: const Value('tag-1'),
      name: const Value('在途更新'),
      version: const Value(2),
      updatedAt: Value(DateTime.utc(2026, 9, 5)),
      syncState: const Value(SyncState.pending),
    ));

    port.gate!.complete();
    await until(() => bloc.state.status == SyncStatus.clean);

    // 未被在途触碰的行照常回写(account v1 快照匹配)。
    expect((await database.accountDao.getAccountById('acc-1'))!.syncState,
        SyncState.synced);
    // 在途更新的行:陈旧快照(v1)不误标 —— 保持 pending/version=2/新内容。
    final tag = await database.tagDao.getTagById('tag-1');
    expect(tag!.syncState, SyncState.pending);
    expect(tag.version, 2);
    expect(tag.name, '在途更新');
    // 墓碑无版本概念:批内墓碑照常清。
    expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);

    // 再触发 → 新批次携带该行 v2 快照上行 → 回写 synced 收敛。
    port.gate = null;
    bloc.add(SyncRetryRequested());
    await until(() =>
        bloc.state.status == SyncStatus.clean && port.batches.length == 2,
        '第二次上行未完成');
    expect(port.batches.last.entitiesByModule[SyncModule.tag]!.single.version, 2);
    expect((await database.tagDao.getTagById('tag-1'))!.syncState,
        SyncState.synced);
  });
}
