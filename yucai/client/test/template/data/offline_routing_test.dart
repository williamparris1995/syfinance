// F10 T1(2026-09-03):template repo 三态写路由轻测(路由分支各 1 条)。
// guest / boundOfflineLocal → 本地零远端;boundRemote + NetworkFailure →
// FR-1b 降级落本地。深测范式见 transaction/tag offline_write_routing_test。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    hide TransactionTemplate;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/data/template_remote_ds.dart';
import 'package:yucai_client/template/data/template_repository_impl.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements TemplateRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late TemplateLocalDataSource local;
  late TemplateRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(TemplateDirection.expense);
    registerFallbackValue(TemplateCycle.monthly);
  });

  setUp(() {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    local = TemplateLocalDataSource(
        database, TransactionLocalDataSource(database, BalanceLocalUpdater(database)));
    tracker = SessionModeTracker();
    repo = TemplateRepositoryImpl(remote, local, tracker);
  });

  tearDown(() => database.close());

  Future<void> createOne() async {
    final result = await repo.create(
      name: 'rent',
      amountCents: 100,
      direction: TemplateDirection.expense,
      cycle: TemplateCycle.monthly,
      sourceAccountId: 'a',
      category: 'c',
    );
    expect(result.isRight(), isTrue);
  }

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((t) => t.name), contains('rent'));
  });

  test('boundOfflineLocal(断网)→ 本地写,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((t) => t.name), contains('rent'));
  });

  test('boundRemote + NetworkFailure → 降级落本地(FR-1b)', () async {
    tracker.isGuest = false;
    when(() => remote.create(
          name: any(named: 'name'),
          description: any(named: 'description'),
          amountCents: any(named: 'amountCents'),
          direction: any(named: 'direction'),
          sourceAccountId: any(named: 'sourceAccountId'),
          destinationAccountId: any(named: 'destinationAccountId'),
          cycle: any(named: 'cycle'),
          cycleDays: any(named: 'cycleDays'),
          billingDay: any(named: 'billingDay'),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          autoRecord: any(named: 'autoRecord'),
          category: any(named: 'category'),
        )).thenThrow(const GrpcError.unavailable('down'));
    await createOne();
    verify(() => remote.create(
          name: 'rent',
          amountCents: 100,
          direction: TemplateDirection.expense,
          cycle: TemplateCycle.monthly,
          sourceAccountId: 'a',
          category: 'c',
        )).called(1);
    expect((await local.list()).map((t) => t.name), contains('rent'));
  });
}
