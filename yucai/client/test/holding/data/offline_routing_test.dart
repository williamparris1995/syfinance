// F10 T1(2026-09-03):holding repo 三态写路由轻测(路由分支各 1 条)。
// guest / boundOfflineLocal → 本地零远端;boundRemote + NetworkFailure →
// FR-1b 降级落本地。深测范式见 transaction/tag offline_write_routing_test。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    hide Security, Holding;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements HoldingRemoteDataSource {}
class _MockGoalViewDs extends Mock implements GoalViewDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late HoldingLocalDataSource local;
  late HoldingRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    local = HoldingLocalDataSource(
        database, TransactionLocalDataSource(database, BalanceLocalUpdater(database)));
    tracker = SessionModeTracker();
    repo = HoldingRepositoryImpl(remote, local, tracker, _MockGoalViewDs());
    registerFallbackValue(SecurityType.stock);
  });

  tearDown(() => database.close());

  Future<void> createOne() async {
    final result = await repo.createSecurity(
      symbol: '600519',
      name: '贵州茅台',
      type: SecurityType.stock,
      currency: 'CNY',
    );
    expect(result.isRight(), isTrue);
  }

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.listSecurities()).map((s) => s.symbol), contains('600519'));
  });

  test('boundOfflineLocal(断网)→ 本地写,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.listSecurities()).map((s) => s.symbol), contains('600519'));
  });

  test('boundRemote + NetworkFailure → 降级落本地(FR-1b)', () async {
    tracker.isGuest = false;
    when(() => remote.createSecurity(
          symbol: any(named: 'symbol'),
          name: any(named: 'name'),
          type: any(named: 'type'),
          exchange: any(named: 'exchange'),
          currency: any(named: 'currency'),
        )).thenThrow(const GrpcError.unavailable('down'));
    await createOne();
    verify(() => remote.createSecurity(
          symbol: '600519',
          name: '贵州茅台',
          type: SecurityType.stock,
          currency: 'CNY',
        )).called(1);
    expect((await local.listSecurities()).map((s) => s.symbol), contains('600519'));
  });
}
