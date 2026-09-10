// F19-T1(2026-09-11,spec FR-1/FR-2/FR-3,design ADR-1/ADR-2/ADR-3):
// BindingBloc 状态机 —— 守卫采集摘要(空→readyToUpload/非空→readyToMerge)
// + 统一合并链(markAllPending → collect → 200 拆批 → push → 版本守卫回写
// → refreshAll → markBound → registerDevice)+ 断点续传(批间失败重试只推
// 剩余)+ 冲突透传 + 进度事件。uploadBackup/exporter 路径退出向导(ADR-1:
// 库内保留,绑定向导不再调用)。
import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockAccounts extends Mock implements AccountRepository {}

class _MockTxns extends Mock implements TransactionRepository {}

class _MockHoldings extends Mock implements HoldingRepository {}

class _StubBoundMarker extends Fake implements BoundMarker {
  @override
  Future<bool> isBound() async => false;

  @override
  Future<void> markBound(String tenantId) async {}
}

/// 可编程 fake port:记录每批 push;按 push 序号弹预设结果(缺省成功);
/// registerDevice 记录 deviceName,可注错(fire-and-forget 容错面)。
class _FakePort implements OfflineSyncPort {
  final batches = <SyncBatch>[];
  final results = <SyncResult>[];
  final conflictsByPush = <int, List<SyncConflictInfo>>{};
  final registerNames = <String>[];
  Object? registerError;

  @override
  Future<SyncResult> push(SyncBatch batch) async {
    final ordinal = batches.length;
    batches.add(batch);
    if (ordinal < results.length) return results[ordinal];
    return SyncResult.success(
        conflicts: conflictsByPush[ordinal] ?? const []);
  }

  @override
  Future<void> registerDevice(String deviceName) async {
    registerNames.add(deviceName);
    final error = registerError;
    if (error != null) throw error;
  }

  // 绑定向导不消费的面(接口完备性替身):
  @override
  Future<PullBatch> pull(int sinceVersion,
          {List<String>? entityTypes, int? pageSize}) async =>
      PullBatch(changes: const [], latestVersion: sinceVersion, hasMore: false);

  @override
  Future<ConflictPage> listConflicts({String? pageToken}) async =>
      const ConflictPage(items: [], totalCount: 0);

  @override
  Future<void> resolveConflict(String conflictId, String resolution,
      {List<int>? mergedPayload}) async {}
}

const _account = Account(
  id: 'a1',
  name: 'x',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  currentBalanceCents: 0,
  ownership: Ownership.personal,
  status: AccountStatus.active,
);

void main() {
  late _MockAccounts accounts;
  late _MockTxns txns;
  late _MockHoldings holdings;
  late _FakePort port;
  late db.AppDatabase database;
  late BindingBloc bloc;
  late List<BindingState> states;

  setUp(() {
    accounts = _MockAccounts();
    txns = _MockTxns();
    holdings = _MockHoldings();
    port = _FakePort();
    database = db.AppDatabase(NativeDatabase.memory());
    bloc = BindingBloc(accounts, txns, holdings, database,
        _StubBoundMarker(), port, PendingCollector(database));
    registerFallbackValue(const ListTransactionsParams());
    states = [bloc.state];
    bloc.stream.listen(states.add);
  });

  tearDown(() async {
    await bloc.close();
    await database.close();
  });

  Future<void> until(bool Function() cond,
      [String reason = 'condition not met within timeout']) async {
    final sw = Stopwatch()..start();
    while (!cond() && sw.elapsed < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(cond(), isTrue, reason: reason);
  }

  /// 守卫三面全部空(远端账号无数据)。
  void stubEmptyRemote() {
      when(() => accounts.list()).thenAnswer((_) async => const Right([]));
    when(() => txns.list(any())).thenAnswer((_) async =>
        const Right(ListTransactionsResult(transactions: [], totalCount: 0)));
    when(() => holdings.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const Right(<Holding>[]));
  }

  /// guest 本地种子:账户/标签各 N 行(默认 synced —— guest 写入语义)。
  Future<void> seedAccounts(int n, {String state = SyncState.synced}) async {
    final now = DateTime.utc(2026, 9, 11);
    for (var i = 0; i < n; i++) {
      await database.accountDao.insertAccount(db.AccountsCompanion.insert(
        id: 'acc-$i',
        name: 'n-$i',
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
        createdAt: now,
        updatedAt: now,
        syncState: Value(state),
      ));
    }
  }

  Future<void> seedTag(String id) async {
    final now = DateTime.utc(2026, 9, 11);
    await database.tagDao.insertTag(db.TagsCompanion.insert(
      id: id,
      name: 't-$id',
      color: '#000000',
      version: 1,
      createdAt: now,
      updatedAt: now,
    ));
  }

  group('守卫(摘要采集)', () {
    test('三面全空 → readyToUpload(全 0 摘要)', () async {
      stubEmptyRemote();

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);

      expect(bloc.state.serverSummary, isNotNull);
      expect(bloc.state.serverSummary!.isEmpty, isTrue);
    });

    test('任一面非空 → readyToMerge 携带计数摘要(账户/交易/持仓)', () async {
      when(() => accounts.list())
          .thenAnswer((_) async => const Right([_account, _account]));
      when(() => txns.list(any())).thenAnswer((_) async => const Right(
          ListTransactionsResult(transactions: [], totalCount: 3)));
      when(() => holdings.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => const Right(<Holding>[]));

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToMerge);

      final summary = bloc.state.serverSummary!;
      expect(summary.accountCount, 2);
      expect(summary.transactionCount, 3);
      expect(summary.holdingCount, 0);
      expect(summary.isEmpty, isFalse);
    });

    test('守卫 facet 失败 → failed(fail-closed),不 push;重试重走守卫',
        () async {
      when(() => accounts.list())
          .thenAnswer((_) async => const Left(NetworkFailure('远端不可达')));
      when(() => txns.list(any())).thenAnswer((_) async =>
          const Right(ListTransactionsResult(transactions: [], totalCount: 0)));
      when(() => holdings.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => const Right(<Holding>[]));

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.failed);

      expect(bloc.state.failureMessage, contains('无法确认账号状态'));
      // fix round 1:守卫面失败 canResume=false → 重试 = 重走守卫。
      expect(bloc.state.canResume, isFalse);
      expect(port.batches, isEmpty);

      // 恢复后重试 → 重走守卫(而非续跑合并链)。
      stubEmptyRemote();
      bloc.add(BindingRetryRequested());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      expect(port.batches, isEmpty);
    });
  });

  group('合并链(统一 push 路径,ADR-1/ADR-3)', () {
    test('upload 确认(空账号)→ markAll + 单批 push + 回写 synced + success 摘要',
        () async {
      stubEmptyRemote();
      await seedAccounts(2);
      await seedTag('tag-1');

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.success);

      // guest synced 行已进 push 批(markAll 生效)。
      expect(port.batches, hasLength(1));
      final pushed = port.batches.single;
      expect(
          pushed.entitiesByModule[SyncModule.account]
              ?.map((e) => e.entityId)
              .toSet(),
          {'acc-0', 'acc-1'});
      expect(pushed.entitiesByModule[SyncModule.tag]?.single.entityId, 'tag-1');

      // 批成功回写:全行 synced(版本守卫 markXSynced)。
      final rows = await database.accountDao.getAllAccounts();
      expect(rows.map((a) => a.syncState), everyElement(SyncState.synced));

      // success 摘要:上行总数(实体+墓碑)与冲突计数。
      expect(bloc.state.uploadedEntities, 3);
      expect(bloc.state.conflictCount, 0);
      // 绑定收尾:markBound + fire-and-forget registerDevice。
      expect(port.registerNames, hasLength(1));
      expect(port.registerNames.single, isNotEmpty);
    });

    test('merge 确认(非空账号)→ 同链推送(等价纯上传 + 并集收敛)', () async {
      when(() => accounts.list()).thenAnswer((_) async => const Right([_account]));
      when(() => txns.list(any())).thenAnswer((_) async =>
          const Right(ListTransactionsResult(transactions: [], totalCount: 0)));
      when(() => holdings.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async => const Right(<Holding>[]));
      await seedAccounts(1);

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToMerge);
      bloc.add(BindingMergeConfirmed());
      await until(() => bloc.state.status == BindingStatus.success);

      expect(port.batches, hasLength(1));
      expect(
          port.batches.single.entitiesByModule[SyncModule.account]
              ?.single.entityId,
          'acc-0');
      expect(bloc.state.uploadedEntities, 1);
    });

    test('201 条 → 2 批(200+1)+ 进度事件序列(第 i/N 批·已上行 N 条)',
        () async {
      stubEmptyRemote();
      await seedAccounts(201);

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.success);

      expect(port.batches, hasLength(2));
      expect(port.batches.first.changeCount, 200);
      expect(port.batches.last.changeCount, 1);

      // 进度事件序列:批 1/2(200 条)→ 批 2/2(201 条)→ success。
      final uploading = states
          .where((s) => s.status == BindingStatus.uploading && s.progress != null)
          .map((s) => s.progress!)
          .toList();
      expect(uploading, hasLength(2));
      expect(uploading.first.batchIndex, 1);
      expect(uploading.first.totalBatches, 2);
      expect(uploading.first.uploadedChanges, 200);
      expect(uploading.last.batchIndex, 2);
      expect(uploading.last.totalBatches, 2);
      expect(uploading.last.uploadedChanges, 201);

      expect(bloc.state.uploadedEntities, 201);
    });

    test('批间失败 → failed + 重试只推剩余(断点续传:已推批已 synced)',
        () async {
      stubEmptyRemote();
      await seedAccounts(201);
      port.results.addAll([
        const SyncResult.success(),
        const SyncResult.failure('网络中断'),
      ]);

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.failed);

      expect(bloc.state.failureMessage, contains('网络中断'));
      // fix round 1:链内失败 canResume=true → 重试 = 断点续传。
      expect(bloc.state.canResume, isTrue);
      // 首批 200 已回写 synced;第 201 行仍 pending(未推)。
      var synced = 0;
      var pending = 0;
      for (final a in await database.accountDao.getAllAccounts()) {
        a.syncState == SyncState.synced ? synced++ : pending++;
      }
      expect(synced, 200);
      expect(pending, 1);

      // 重试:不再全量标记(markAll 跳过),collect 只收剩余 pending ——
      // 断言重试批不含首批 200 实体。
      port.results.clear();
      bloc.add(BindingRetryRequested());
      await until(() => bloc.state.status == BindingStatus.success);

      expect(port.batches, hasLength(3)); // 200 + 1(失败批)+ 1(重试批)
      final retryIds = port.batches.last
          .entitiesByModule[SyncModule.account]!
          .map((e) => e.entityId)
          .toSet();
      expect(retryIds, hasLength(1));
      expect(retryIds.intersection({
        for (var i = 0; i < 200; i++) 'acc-$i'
      }), isEmpty, reason: '重试批不得包含已推实体');
      // 收敛:全行 synced。
      expect((await database.accountDao.getAllAccounts())
          .map((a) => a.syncState),
          everyElement(SyncState.synced));
    });

    test('冲突响应透传:conflictCount 计入 success,冲突实体一并标 synced',
        () async {
      stubEmptyRemote();
      await seedAccounts(2);
      port.conflictsByPush[0] = const [
        SyncConflictInfo(
          module: SyncModule.account,
          entityId: 'acc-0',
          conflictType: 'version_conflict',
        ),
      ];

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.success);

      // ok 语义不变:conflicts 非空仍成功,计数透传给成功摘要。
      expect(bloc.state.conflictCount, 1);
      // 冲突实体(acc-0)与正常实体同 versionsById 标 synced(防重推堆冲突)。
      expect((await database.accountDao.getAccountById('acc-0'))!.syncState,
          SyncState.synced);
      expect((await database.accountDao.getAccountById('acc-1'))!.syncState,
          SyncState.synced);
    });

    test('本地全空 → 直通 success(无 push 调用,零上行)', () async {
      stubEmptyRemote();

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.success);

      expect(port.batches, isEmpty);
      expect(bloc.state.uploadedEntities, 0);
      expect(bloc.state.conflictCount, 0);
      expect(port.registerNames, hasLength(1));
    });

    test('registerDevice 抛错 → fire-and-forget 容错,绑定仍 success', () async {
      stubEmptyRemote();
      await seedAccounts(1);
      port.registerError = Exception('register outage');

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.success);

      expect(port.registerNames, hasLength(1));
    });

    test('push 异常炸穿 → failed 可重试(本地 pending 保留)', () async {
      stubEmptyRemote();
      await seedAccounts(1);
      port.results.add(const SyncResult.failure('同步失败(Exception: boom)'));

      bloc.add(BindingStarted());
      await until(() => bloc.state.status == BindingStatus.readyToUpload);
      bloc.add(BindingUploadConfirmed());
      await until(() => bloc.state.status == BindingStatus.failed);

      // 未推成功 → 行保持 pending(下次重试再推)。
      expect((await database.accountDao.getAllAccounts()).single.syncState,
          SyncState.pending);

      port.results.clear();
      bloc.add(BindingRetryRequested());
      await until(() => bloc.state.status == BindingStatus.success);
    });
  });
}
