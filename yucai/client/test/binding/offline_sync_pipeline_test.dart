// F10 T3(2026-09-04):回网同步管线集成断言(spec FR-5/FR-6,design ADR-5)。
// 单测级完整链(真 drift 内存库 + 真 local DS + 真 repo 路由 + 真 mirror +
// fake port):
// 1. bound-offline 写几笔(跨 2+ 模块)+ 删一笔(墓碑)→ pending/墓碑在库;
// 2. 注入回网 true 边沿触发 coordinator → fake port 收到批次(内容断言);
// 3. push 成功 → synced 回写 + 墓碑清 + 镜像刷新(真 mirror + mock 远端);
// 4. 镜像刷新后数据仍在(T2 保护语义闭环);
// 5. push 失败路径 → failed 态 + pending 保留 → 再触发成功。
import 'dart:async';

import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';

final getIt = GetIt.instance;

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}
class _MockTagRemote extends Mock implements TagRemoteDataSource {}

/// fake port:记录批次,结果可编程(模拟 server 收到 PushChanges)。
class _FakePort implements OfflineSyncPort {
  final batches = <SyncBatch>[];
  SyncResult nextResult = const SyncResult.success();

  // F17-T1:接口新增成员的替身实现(本管线链路不触注册,绑定流程才调)。
  @override
  Future<void> registerDevice(String deviceName) async {}

  @override
  Future<SyncResult> push(SyncBatch batch) async {
    batches.add(batch);
    return nextResult;
  }
}

void main() {
  late db.AppDatabase database;
  late _FakePort port;
  late SessionModeTracker tracker;
  late StreamController<bool> online;
  late SyncCoordinatorBloc bloc;
  late AccountRepositoryImpl accounts;
  late TagRepositoryImpl tags;
  final serverAccounts = <Account>[];
  final serverTags = <Tag>[];

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    port = _FakePort();
    tracker = SessionModeTracker()
      ..isGuest = false
      ..online = false; // bound + 断网 → boundOfflineLocal
    online = StreamController<bool>.broadcast();

    final accountRemote = _MockAccountRemote();
    final tagRemote = _MockTagRemote();
    serverAccounts.clear();
    serverTags.clear();
    when(() => accountRemote.list()).thenAnswer((_) async => serverAccounts);
    when(() => tagRemote.list()).thenAnswer((_) async => serverTags);

    // 真 repo(三态路由)+ 真 local DS:离线写即 boundOfflineLocal 路由落点。
    accounts = AccountRepositoryImpl(
        accountRemote, AccountLocalDataSource(database), tracker);
    tags = TagRepositoryImpl(
        tagRemote, TagLocalDataSource(database, uuid: const Uuid()), tracker);
    // 真 mirror:刷新经 getIt 解析上面的真 repo(回网后路由 boundRemote →
    // mock 远端,server 侧状态由 serverAccounts/serverTags 列表承载)。
    getIt.registerSingleton<AccountRepository>(accounts);
    getIt.registerSingleton<TagRepository>(tags);

    bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      BoundMirror(database),
    );
  });

  tearDown(() async {
    await bloc.close();
    await online.close();
    await database.close();
    getIt.reset();
  });

  Future<void> until(bool Function() cond) async {
    final sw = Stopwatch()..start();
    while (!cond() && sw.elapsed < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue, reason: 'condition not met within timeout');
  }

  /// 步骤 1:bound-offline 写(account ×2 + tag ×2)+ 删一笔 tag(墓碑)。
  Future<(List<String>, List<String>)> writeOffline() async {
    T ok<T>(dz.Either<Failure, T> r) =>
        r.fold((f) => throw StateError('offline write failed: $f'), (v) => v);
    final a1 = ok(await accounts.create(const CreateAccountParams(
      name: '离线现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 1000,
      ownership: Ownership.personal,
    )));
    final a2 = ok(await accounts.create(const CreateAccountParams(
      name: '离线储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 2000,
      ownership: Ownership.personal,
    )));
    final t1 = ok(await tags.create(name: '离线标签A', color: '#aa0000'));
    final t2 = ok(await tags.create(name: '离线标签B', color: '#00aa00'));
    ok<void>(await tags.delete(t2.id));
    return ([a1.id, a2.id], [t1.id, t2.id]);
  }

  test('完整链:离线写 → 回网收集上行 → synced+清墓碑+镜像刷新不抹', () async {
    final (accountIds, tagIds) = await writeOffline();

    // 步骤 1 断言:pending 行 + 墓碑在库。
    expect(await database.accountDao.getPendingAccounts(), hasLength(2));
    expect(await database.tagDao.getPendingTags(), hasLength(1));
    final tombstones = await database.syncTombstoneDao.getAllTombstones();
    expect(tombstones, hasLength(1));
    expect(tombstones.single.module, SyncModule.tag);
    expect(tombstones.single.entityId, tagIds[1]);

    // server 侧预置同 id 状态(fake port push 成功 = server 已收到)。
    for (final (id, name) in [
      (accountIds[0], '离线现金'),
      (accountIds[1], '离线储蓄'),
    ]) {
      serverAccounts.add(Account(
        id: id,
        name: name,
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 1000,
        currentBalanceCents: 1000,
        ownership: Ownership.personal,
        status: AccountStatus.active,
        version: 1,
        createdAt: DateTime.utc(2026, 9, 4),
      ));
    }
    serverTags.add(Tag(id: tagIds[0], name: '离线标签A', color: '#aa0000', version: 1));

    // 步骤 2:回网 true 边沿触发。
    tracker.online = true;
    online.add(true);
    await until(() => bloc.state.status == SyncStatus.clean);

    // fake port 收到的批次(内容断言):跨 2 模块实体 + 1 墓碑。
    expect(port.batches, hasLength(1));
    final batch = port.batches.single;
    expect(batch.entitiesByModule.keys, {SyncModule.account, SyncModule.tag});
    expect(batch.entitiesByModule[SyncModule.account]!
            .map((e) => e.entityId)
            .toSet(),
        accountIds.toSet());
    expect(batch.entitiesByModule[SyncModule.tag]!.single.entityId, tagIds[0]);
    expect(batch.tombstones.single.entityId, tagIds[1]);
    expect(batch.changeCount, 4);

    // 步骤 3:synced 回写 + 墓碑清。
    expect(await database.accountDao.getPendingAccounts(), isEmpty);
    expect(await database.tagDao.getPendingTags(), isEmpty);
    expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);

    // 步骤 4:镜像刷新(delete-all + rebuild)后数据仍在(T2 保护闭环:
    // 上行成功的行不再靠 pending 保护,而靠 server 侧回读)。
    final accountsAfter = await database.accountDao.getAllAccounts();
    expect(accountsAfter.map((a) => a.id).toSet(), accountIds.toSet());
    final byName = {for (final a in accountsAfter) a.id: a.name};
    expect(byName[accountIds[0]], '离线现金');
    expect(byName[accountIds[1]], '离线储蓄');
    expect(accountsAfter.every((a) => a.syncState == SyncState.synced), isTrue);
    final tagAfter = await database.tagDao.getTagById(tagIds[0]);
    expect(tagAfter, isNotNull);
    expect(tagAfter!.name, '离线标签A');
    // 被删 tag 未被镜像复活(墓碑清了但 server 侧本就无此行)。
    expect(await database.tagDao.getTagById(tagIds[1]), isNull);
  });

  test('失败路径:failed 态 + pending 保留 → 再触发成功', () async {
    final (accountIds, _) = await writeOffline();
    serverAccounts.clear();
    serverTags.clear();

    tracker.online = true;
    port.nextResult = const SyncResult.failure('gRPC unavailable');
    online.add(true);
    await until(() => bloc.state.status == SyncStatus.failed);

    expect(bloc.state.failureReason, contains('gRPC unavailable'));
    // pending + 墓碑保留。
    expect(await database.accountDao.getPendingAccounts(), hasLength(2));
    expect(await database.tagDao.getPendingTags(), hasLength(1));
    expect(await database.syncTombstoneDao.getAllTombstones(), hasLength(1));

    // server 恢复 + 手动 retry 再触发 → 成功收敛。
    for (final (id, name) in [
      (accountIds[0], '离线现金'),
      (accountIds[1], '离线储蓄'),
    ]) {
      serverAccounts.add(Account(
        id: id,
        name: name,
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 1000,
        currentBalanceCents: 1000,
        ownership: Ownership.personal,
        status: AccountStatus.active,
        version: 1,
        createdAt: DateTime.utc(2026, 9, 4),
      ));
    }
    port.nextResult = const SyncResult.success();
    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(port.batches, hasLength(2));
    expect(await database.accountDao.getPendingAccounts(), isEmpty);
    expect(await database.syncTombstoneDao.getAllTombstones(), isEmpty);
    expect((await database.accountDao.getAllAccounts()).map((a) => a.id).toSet(),
        accountIds.toSet());
  });
}
