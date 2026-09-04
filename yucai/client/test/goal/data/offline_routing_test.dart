// F10 T1(2026-09-03):goal repo 三态写路由轻测(路由分支各 1 条)。
// guest / boundOfflineLocal → 本地零远端;boundRemote + NetworkFailure →
// FR-1b 降级落本地(本 repo 由 F10 补 unavailable → NetworkFailure 分类)。
// 深测范式见 transaction/tag offline_write_routing_test。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/data/goal_remote_ds.dart';
import 'package:yucai_client/goal/data/goal_repository_impl.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements GoalRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late GoalLocalDataSource local;
  late GoalRepositoryImpl repo;

  setUpAll(() => registerFallbackValue(GoalType.savings));

  setUp(() {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    final txns =
        TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    local = GoalLocalDataSource(database, HoldingLocalDataSource(database, txns));
    tracker = SessionModeTracker();
    repo = GoalRepositoryImpl(remote, local, tracker);
  });

  tearDown(() => database.close());

  Future<void> createOne() async {
    final result = await repo.createGoal(
      name: '应急基金',
      type: GoalType.savings,
      targetAmountCents: 1000000,
    );
    expect(result.isRight(), isTrue);
  }

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.listGoals()).map((g) => g.name), contains('应急基金'));
  });

  test('boundOfflineLocal(断网)→ 本地写,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.listGoals()).map((g) => g.name), contains('应急基金'));
  });

  test('boundRemote + NetworkFailure → 降级落本地(FR-1b)', () async {
    tracker.isGuest = false;
    when(() => remote.createGoal(
          name: any(named: 'name'),
          type: any(named: 'type'),
          targetAmountCents: any(named: 'targetAmountCents'),
          currencyCode: any(named: 'currencyCode'),
          deadline: any(named: 'deadline'),
          linkedAccountIds: any(named: 'linkedAccountIds'),
          linkedDebtIds: any(named: 'linkedDebtIds'),
          notes: any(named: 'notes'),
        )).thenThrow(const GrpcError.unavailable('down'));
    await createOne();
    verify(() => remote.createGoal(
          name: '应急基金',
          type: GoalType.savings,
          targetAmountCents: 1000000,
        )).called(1);
    expect((await local.listGoals()).map((g) => g.name), contains('应急基金'));
  });
}
