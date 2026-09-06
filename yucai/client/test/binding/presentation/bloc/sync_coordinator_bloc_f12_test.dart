// F12 T1(2026-09-05):SyncCoordinatorBloc 扩展(spec FR-2/FR-3,design
// ADR-2/ADR-3)—— 在 F10 协调器上零破坏增量:
// - pendingCount 全态携带(idle/clean/syncing/failed);
// - 计数更新走专属事件管道(不触发同步、不占 flight 闸门);
// - 构造补扫:online → 触发一次 push;offline → 仅计数;
// - guest 构造:不订阅计数流、不补扫;guest→bound 翻转后首个触发事件惰性重订。
// 既有 7 测(sync_coordinator_bloc_test.dart)零改零红 = F10 语义守门。
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/pending_count_watcher.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

class _MockMirror extends Mock implements BoundMirror {}

/// fake port:记录批次(照既有测试替身形态)。
class _FakePort implements OfflineSyncPort {
  final batches = <SyncBatch>[];
  SyncResult nextResult = const SyncResult.success();

  // F17-T1:接口新增成员的替身实现(协调器链路不触注册,绑定流程才调)。
  @override
  Future<void> registerDevice(String deviceName) async {}

  @override
  Future<SyncResult> push(SyncBatch batch) async {
    batches.add(batch);
    return nextResult;
  }
}

void main() {
  setUpAll(() => registerFallbackValue(MirrorModule.account));

  Future<void> until(bool Function() cond,
      [String reason = 'condition not met within timeout']) async {
    final sw = Stopwatch()..start();
    while (!cond() && sw.elapsed < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue, reason: reason);
  }

  /// 落 1 条 pending 头行 + 1 条墓碑(changeCount = 2)。
  Future<void> seedPending(db.AppDatabase database) async {
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
      createdAt: DateTime.utc(2026, 9, 5),
      updatedAt: DateTime.utc(2026, 9, 5),
      syncState: const Value(SyncState.pending),
    ));
    await database.syncTombstoneDao.upsertTombstone(
        db.SyncTombstonesCompanion.insert(
            module: SyncModule.tag,
            entityId: 'tag-del',
            deletedAt: DateTime.utc(2026, 9, 5)));
  }

  test('计数全态携带:idle 态 watcher 发射更新 pendingCount,不触发同步', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final port = _FakePort();
    final mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    final tracker = SessionModeTracker()..isGuest = false;
    final online = StreamController<bool>.broadcast();
    final counts = StreamController<int>();
    final watcher = PendingCountWatcher([counts.stream]);
    final bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
      watcher,
    );

    counts.add(5);
    await until(() => bloc.state.pendingCount == 5);
    expect(bloc.state.status, SyncStatus.idle);
    expect(port.batches, isEmpty); // 纯状态,不触发同步动作。

    counts.add(2);
    await until(() => bloc.state.pendingCount == 2);

    counts.add(7);
    await bloc.close();
    await online.close();
    await counts.close();
    await database.close();
  });

  test('计数全态携带:clean 态携带实时计数(模拟 clean 后新增离线写)', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final port = _FakePort();
    final mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    final tracker = SessionModeTracker()..isGuest = false;
    final online = StreamController<bool>.broadcast();
    final counts = StreamController<int>();
    final watcher = PendingCountWatcher([counts.stream]);
    final bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
      watcher,
    );

    await seedPending(database); // 空库构造(补扫无动作),随后落 pending。
    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.clean);

    // clean 后新增离线写 → 计数流发射 → clean 态携带(隐藏即隐藏,有值即展示)。
    counts.add(1);
    await until(() =>
        bloc.state.status == SyncStatus.clean && bloc.state.pendingCount == 1);

    await bloc.close();
    await online.close();
    await counts.close();
    await database.close();
  });

  test('计数全态携带:failed 态计数更新保留 failureReason', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final port = _FakePort()..nextResult = const SyncResult.failure('无法连接服务器');
    final mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    final tracker = SessionModeTracker()..isGuest = false;
    final online = StreamController<bool>.broadcast();
    final counts = StreamController<int>();
    final watcher = PendingCountWatcher([counts.stream]);
    final bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
      watcher,
    );

    await seedPending(database);
    bloc.add(SyncRetryRequested());
    await until(() => bloc.state.status == SyncStatus.failed);
    expect(bloc.state.failureReason, contains('无法连接服务器'));

    // 计数流发射 → failed 态携带新计数且不丢原因。
    counts.add(2);
    await until(() =>
        bloc.state.status == SyncStatus.failed && bloc.state.pendingCount == 2);
    expect(bloc.state.failureReason, contains('无法连接服务器'));

    await bloc.close();
    await online.close();
    await counts.close();
    await database.close();
  });

  test('构造补扫(online):构造前已有 pending → 触发一次 push → clean', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    await seedPending(database); // 构造前已有 2 条待同步。
    final port = _FakePort();
    final mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    final tracker = SessionModeTracker()..isGuest = false; // online 缺省 true。
    final online = StreamController<bool>.broadcast();
    final counts = StreamController<int>();
    final watcher = PendingCountWatcher([counts.stream]);
    final bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
      watcher,
    );

    await until(() => port.batches.isNotEmpty, '构造补扫未触发 push');
    await until(() => bloc.state.status == SyncStatus.clean);
    expect(port.batches.single.changeCount, 2);

    // 恰一次(补扫触发一次,无重复)。
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(port.batches, hasLength(1));
    verify(() => mirror.refreshModule(MirrorModule.account)).called(1);

    await bloc.close();
    await online.close();
    await counts.close();
    await database.close();
  });

  test('构造补扫(offline):仅更新计数不 push,状态保持 idle', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    await seedPending(database);
    final port = _FakePort();
    final mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    final tracker = SessionModeTracker()
      ..isGuest = false
      ..online = false; // 离线:补扫仅计数。
    final online = StreamController<bool>.broadcast();
    final counts = StreamController<int>();
    final watcher = PendingCountWatcher([counts.stream]);
    final bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
      watcher,
    );

    await until(() =>
        bloc.state.pendingCount == 2 && bloc.state.status == SyncStatus.idle);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(port.batches, isEmpty); // 离线不 push。
    verifyNever(() => mirror.refreshModule(any()));

    await bloc.close();
    await online.close();
    await counts.close();
    await database.close();
  });

  test('guest 构造:不订阅计数流、不补扫', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    await seedPending(database);
    final port = _FakePort();
    final mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    final tracker = SessionModeTracker()..isGuest = true; // guest 构造。
    final online = StreamController<bool>.broadcast();
    final counts = StreamController<int>();
    final watcher = PendingCountWatcher([counts.stream]);
    final bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
      watcher,
    );

    counts.add(7); // 未订阅 → 计数事件永不进 bloc。
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.pendingCount, 0);
    expect(bloc.state.status, SyncStatus.idle);
    expect(port.batches, isEmpty); // 不补扫(不收集不 push)。
    verifyNever(() => mirror.refreshModule(any()));

    await bloc.close();
    await online.close();
    await counts.close();
    await database.close();
  });

  test('guest→bound 翻转:首个触发事件惰性重订计数流', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    final port = _FakePort();
    final mirror = _MockMirror();
    when(() => mirror.refreshModule(any())).thenAnswer((_) async {});
    final tracker = SessionModeTracker()..isGuest = true; // guest 期构造。
    final online = StreamController<bool>.broadcast();
    final counts = StreamController<int>();
    final watcher = PendingCountWatcher([counts.stream]);
    final bloc = SyncCoordinatorBloc(
      port,
      PendingCollector(database),
      tracker,
      database,
      online.stream,
      mirror,
      watcher,
    );

    counts.add(9); // guest 期发射:无订阅,读不到。
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(bloc.state.pendingCount, 0);

    await seedPending(database); // guest 期写入(直插库,不走路由)。
    tracker.isGuest = false; // 翻转为 bound。
    counts.add(4);
    bloc.add(SyncRetryRequested()); // 首个触发事件 → 惰性重订 + 既有同步链。
    await until(() => port.batches.isNotEmpty);
    await until(() => bloc.state.status == SyncStatus.clean);
    // 重订后计数流可读(缓冲的 9/4 重放,最新值 4 生效)。
    await until(() =>
        bloc.state.status == SyncStatus.clean && bloc.state.pendingCount == 4);

    await bloc.close();
    await online.close();
    await counts.close();
    await database.close();
  });
}
