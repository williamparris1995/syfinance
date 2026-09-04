// F10 T1(2026-09-03):account repo 三态写路由轻测(路由分支各 1 条)。
// guest / boundOfflineLocal → 本地零远端;boundRemote + NetworkFailure →
// FR-1b 降级落本地。深测范式见 transaction/tag offline_write_routing_test。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Account;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

class _MockRemote extends Mock implements AccountRemoteDataSource {}

const _params = CreateAccountParams(
  name: '现金',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  ownership: Ownership.personal,
);

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late AccountLocalDataSource local;
  late AccountRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    local = AccountLocalDataSource(database);
    tracker = SessionModeTracker();
    repo = AccountRepositoryImpl(remote, local, tracker);
    registerFallbackValue(_params);
  });

  tearDown(() => database.close());

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    final result = await repo.create(_params);
    expect(result.isRight(), isTrue);
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((a) => a.name), contains('现金'));
  });

  test('boundOfflineLocal(断网)→ 本地写,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    final result = await repo.create(_params);
    expect(result.isRight(), isTrue);
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((a) => a.name), contains('现金'));
  });

  test('boundRemote + NetworkFailure → 降级落本地(FR-1b)', () async {
    tracker.isGuest = false;
    when(() => remote.create(any()))
        .thenThrow(const GrpcError.unavailable('down'));
    final result = await repo.create(_params);
    expect(result.isRight(), isTrue);
    verify(() => remote.create(any())).called(1);
    expect((await local.list()).map((a) => a.name), contains('现金'));
  });
}
