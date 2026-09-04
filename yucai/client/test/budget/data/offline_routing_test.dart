// F10 T1(2026-09-03):budget repo 三态写路由轻测(路由分支各 1 条)。
// guest / boundOfflineLocal → 本地零远端;boundRemote + NetworkFailure →
// FR-1b 降级落本地。深测范式见 transaction/tag offline_write_routing_test。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/data/budget_repository_impl.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

class _MockRemote extends Mock implements BudgetRemoteDataSource {}

const _items = <({String accountId, int plannedAmountCents, String? notes})>[];

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late BudgetLocalDataSource local;
  late BudgetRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    local = BudgetLocalDataSource(database);
    tracker = SessionModeTracker();
    repo = BudgetRepositoryImpl(remote, local, tracker);
    registerFallbackValue(_items);
  });

  tearDown(() => database.close());

  Future<void> createOne() async {
    final result = await repo.createBudget(
      name: '九月预算',
      month: '2026-09',
      currencyCode: 'CNY',
      items: _items,
    );
    expect(result.isRight(), isTrue);
  }

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.listBudgets()).map((b) => b.name), contains('九月预算'));
  });

  test('boundOfflineLocal(断网)→ 本地写,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.listBudgets()).map((b) => b.name), contains('九月预算'));
  });

  test('boundRemote + NetworkFailure → 降级落本地(FR-1b)', () async {
    tracker.isGuest = false;
    when(() => remote.createBudget(
          name: any(named: 'name'),
          month: any(named: 'month'),
          currencyCode: any(named: 'currencyCode'),
          items: any(named: 'items'),
        )).thenThrow(const GrpcError.unavailable('down'));
    await createOne();
    verify(() => remote.createBudget(
          name: '九月预算',
          month: '2026-09',
          currencyCode: 'CNY',
          items: _items,
        )).called(1);
    expect((await local.listBudgets()).map((b) => b.name), contains('九月预算'));
  });
}
