// F17-T2(spec FR-3,design ADR-3):协调器拉取编排 —— `_pullAndApply`。
// - 回网/触发:**pull 先于 push**(收最新再发);push 成功后 pull(他设备
//   变更感知);
// - 分页循环:since=游标 → 应用 → 游标=页尾 logVersion → hasMore 续拉;
// - own-echo 过滤:自设备推送的回声不回灌应用(游标仍推进);
// - 失败容忍:拉失败不阻断 push 流、不破状态(游标不动,幂等重拉无害);
// - 构造补扫 online 分支经同一触发管道,同样先拉(事件序钉死)。
// F18-T2(2026-09-08)增:毒丸吸收(FR-4/ADR-4 —— 页内坏条目不再钉死游标)。
// 真件:真 drift 库 + 真 PendingCollector + 真 PullApplier(applier 单测
// 已深钉);fake 仅 port(可编程 pull 页队列 + 事件序记录)。
import 'dart:async';
import 'dart:convert' show jsonEncode, utf8;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

/// 可编程 fake port:push 结果可设;pull 按页队列出队(since 记录),事件
/// 序 `events` 钉「先拉后推 / 推后再拉」。
class _FakePort implements OfflineSyncPort {
  final batches = <SyncBatch>[];
  SyncResult nextResult = const SyncResult.success();

  /// pull 页队列(每次 pull 调用出队一页;队空 → 空页)。
  final pullPages = <PullBatch>[];
  final pullSinceCalls = <int>[];
  Object? pullError;

  /// 事件序:'pull' / 'push'(顺序断言用)。
  final events = <String>[];

  @override
  Future<void> registerDevice(String deviceName) async {}

  // F18-T2:冲突解决面替身 —— 拉取编排链路不触(面板 bloc 才消费),空页。
  @override
  Future<ConflictPage> listConflicts({String? pageToken}) async =>
      const ConflictPage(items: [], totalCount: 0);

  @override
  Future<void> resolveConflict(String conflictId, String resolution,
      {List<int>? mergedPayload}) async {}

  @override
  Future<SyncResult> push(SyncBatch batch) async {
    events.add('push');
    batches.add(batch);
    return nextResult;
  }

  @override
  Future<PullBatch> pull(int sinceVersion,
      {List<String>? entityTypes, int? pageSize}) async {
    if (pullError != null) throw pullError!;
    events.add('pull');
    pullSinceCalls.add(sinceVersion);
    if (pullPages.isEmpty) {
      return PullBatch(
          changes: const [], latestVersion: sinceVersion, hasMore: false);
    }
    return pullPages.removeAt(0);
  }
}

void main() {
  late db.AppDatabase database;
  late _FakePort port;
  late SessionModeTracker tracker;
  late StreamController<bool> online;
  late SyncCoordinatorBloc bloc;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    port = _FakePort();
    tracker = SessionModeTracker()..isGuest = false;
    online = StreamController<bool>.broadcast();
    bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      null,
      null,
      PullApplier(database),
      () async => 'me-device',
    );
  });

  tearDown(() async {
    await bloc.close();
    await online.close();
    await database.close();
  });

  /// 他设备账户行变更(envelope 行 payload,与真实 push 编码同源)。
  PulledChange foreignAccount(String id, String name,
          {int logVersion = 1, String deviceId = 'device-A'}) =>
      PulledChange(
        module: SyncModule.account,
        entityId: id,
        isDelete: false,
        payload: Uint8List.fromList(utf8.encode(jsonEncode({
          'ID': id,
          'Name': name,
          'AccountType': 1,
          'Category': 2,
          'CurrencyCode': 'CNY',
          'Version': 1,
          'CreatedAt': '2026-09-05T00:00:00.000Z',
          'UpdatedAt': '2026-09-05T00:00:00.000Z',
        }))),
        logVersion: logVersion,
        deviceId: deviceId,
      );

  Future<void> seedPendingTag() async {
    await database.tagDao.insertTag(db.TagsCompanion.insert(
      id: 'tag-local',
      name: '本地离线标签',
      color: '#000000',
      version: 1,
      createdAt: DateTime.utc(2026, 9, 5),
      updatedAt: DateTime.utc(2026, 9, 5),
      syncState: const Value(SyncState.pending),
    ));
  }

  Future<void> until(bool Function() cond,
      [String reason = 'condition not met within timeout']) async {
    final sw = Stopwatch()..start();
    while (!cond() && sw.elapsed < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue, reason: reason);
  }

  test('回网:pull 先于 push(收最新再发),push 成功后再拉一次;下行数据落库',
      () async {
    await seedPendingTag();
    port.pullPages.add(PullBatch(
      changes: [foreignAccount('acc-9', '他设备账户', logVersion: 2)],
      latestVersion: 2,
      hasMore: false,
    ));

    online.add(true);
    await until(() => bloc.state.status == SyncStatus.clean);

    // 事件序:pull(先收)→ push(后发)→ pull(推后感知)。
    expect(port.events, ['pull', 'push', 'pull']);
    expect(port.pullSinceCalls, [0, 2]); // 第二次以页尾游标续拉
    expect(port.batches, hasLength(1)); // 本地 pending 照常上行

    // 下行应用:他设备账户落库(envelope→drift 真链)。
    final acc = await database.accountDao.getAccountById('acc-9');
    expect(acc, isNotNull);
    expect(acc!.name, '他设备账户');
    expect(acc.syncState, SyncState.synced);

    // 游标推进到页尾。
    expect(await database.syncCursorDao.readLastPulledVersion(), 2);
  });

  test('空批次(无 pending)同样先拉:下行数据照常应用,收敛 clean', () async {
    port.pullPages.add(PullBatch(
      changes: [foreignAccount('acc-8', '空批次下行', logVersion: 1)],
      latestVersion: 1,
      hasMore: false,
    ));

    online.add(true);
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(port.batches, isEmpty); // 无本地变更:不 push
    expect(port.events, ['pull']); // pull 先行;无 push → 无推后拉
    expect(await database.accountDao.getAccountById('acc-8'), isNotNull);
  });

  test('分页续拉:hasMore → since=页尾续页;游标逐页推进到末页', () async {
    port.pullPages.addAll([
      PullBatch(
        changes: [
          foreignAccount('p1', '页1', logVersion: 1),
          foreignAccount('p2', '页2', logVersion: 2),
        ],
        latestVersion: 3,
        hasMore: true,
      ),
      PullBatch(
        changes: [foreignAccount('p3', '页3', logVersion: 3)],
        latestVersion: 3,
        hasMore: false,
      ),
    ]);

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(port.pullSinceCalls, [0, 2]); // 页尾续拉(server ADR-3 契约)
    expect(await database.accountDao.getAccountById('p3'), isNotNull);
    expect(await database.syncCursorDao.readLastPulledVersion(), 3);
  });

  test('own-echo 过滤:自设备回声不应用(本地权威),游标仍推进', () async {
    port.pullPages.add(PullBatch(
      changes: [
        foreignAccount('own-1', '自设备回声', logVersion: 1,
            deviceId: 'me-device'),
        foreignAccount('peer-1', '他设备', logVersion: 2),
      ],
      latestVersion: 2,
      hasMore: false,
    ));

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(await database.accountDao.getAccountById('own-1'), isNull);
    expect(await database.accountDao.getAccountById('peer-1'), isNotNull);
    // 游标推进含被过滤条目(否则永远重拉同一窗口)。
    expect(await database.syncCursorDao.readLastPulledVersion(), 2);
  });

  test('拉失败容忍:不阻断 push 流、不破状态(照常 clean);游标不动',
      () async {
    await seedPendingTag();
    port.pullError = StateError('pull blew up');

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    expect(port.batches, hasLength(1)); // push 照常
    expect((await database.tagDao.getPendingTags()), isEmpty); // 回写照常
    expect(await database.syncCursorDao.readLastPulledVersion(), 0); // 游标不动
  });

  test('push 失败:不触发推后拉(仅 push 前拉一次);failed 语义不变',
      () async {
    await seedPendingTag();
    port.nextResult = const SyncResult.failure('server down');

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.failed);

    expect(port.events, ['pull', 'push']);
    expect(port.batches, hasLength(1));
    expect(await database.tagDao.getPendingTags(), hasLength(1)); // pending 保留
  });

  test('F18-T2 毒丸吸收:页内坏条目不再钉死 —— 后续条目应用 + 游标前进',
      () async {
    // 页内一条坏 payload(非 JSON)+ 一条好行:applier per-change 隔离吞掉
    // 毒丸(apply 正常返回),协调器照常推进游标 —— F17 整批事务下此页
    // 会因 apply 抛出被容忍吞掉,游标停在 0 永久重拉同一毒丸页。
    port.pullPages.add(PullBatch(
      changes: [
        PulledChange(
          module: SyncModule.account,
          entityId: 'acc-poison',
          isDelete: false,
          payload: Uint8List.fromList(utf8.encode('not-json-at-all')),
          logVersion: 1,
          deviceId: 'device-A',
        ),
        foreignAccount('acc-good', '毒丸后好行', logVersion: 2),
      ],
      latestVersion: 2,
      hasMore: false,
    ));

    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    // 好行照常落库;毒丸条目跳过(不阻批);游标推进过毒丸(页尾 = 2)。
    expect(await database.accountDao.getAccountById('acc-good'), isNotNull);
    expect(await database.accountDao.getAccountById('acc-poison'), isNull);
    expect(await database.syncCursorDao.readLastPulledVersion(), 2);
  });
}
