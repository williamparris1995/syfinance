// F10 T1(2026-09-03):debt repo 三态写路由轻测(路由分支各 1 条)。
// guest / boundOfflineLocal → 本地零远端;boundRemote + NetworkFailure →
// FR-1b 降级落本地(本 repo 由 F10 补 unavailable → NetworkFailure 分类)。
// 深测范式见 transaction/tag offline_write_routing_test。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Debt;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockRemote extends Mock implements DebtRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late DebtLocalDataSource local;
  late DebtRepositoryImpl repo;

  setUp(() async {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    // F36 T1:create(无到账)不再跳过双写 —— 必入账(借 权益结转/贷 债务户),
    // 债务账户须真实存在,否则 BalanceLocalUpdater 设计内回滚。补种 acc-debt。
    await database.accountDao.insertAccount(AccountsCompanion.insert(
      id: 'acc-debt',
      name: 'loan',
      accountType: 2, // liability
      category: 9, // otherLiability
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
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    local = DebtLocalDataSource(
        database, TransactionLocalDataSource(database, BalanceLocalUpdater(database)));
    tracker = SessionModeTracker();
    repo = DebtRepositoryImpl(remote, local, tracker);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(DebtType.borrowedIn);
  });

  tearDown(() => database.close());

  // 无 sourceAccountId:F36 起入权益结转分录(setUp 已种 acc-debt 供入账)。
  Future<void> createOne() async {
    final result = await repo.create(
      accountId: 'acc-debt',
      counterparty: 'Bank',
      interestRate: 5.0,
      amortizationIndex: 0,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 12, 31),
      totalPrincipalCents: 100000,
      type: DebtType.borrowedIn,
    );
    expect(result.isRight(), isTrue);
  }

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((d) => d.counterparty), contains('Bank'));
  });

  test('boundOfflineLocal(断网)→ 本地写,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    await createOne();
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((d) => d.counterparty), contains('Bank'));
  });

  test('boundRemote + NetworkFailure → 降级落本地(FR-1b)', () async {
    tracker.isGuest = false;
    when(() => remote.create(
          accountId: any(named: 'accountId'),
          counterparty: any(named: 'counterparty'),
          interestRate: any(named: 'interestRate'),
          amortizationIndex: any(named: 'amortizationIndex'),
          startDate: any(named: 'startDate'),
          dueDate: any(named: 'dueDate'),
          totalPrincipalCents: any(named: 'totalPrincipalCents'),
          type: any(named: 'type'),
          subtype: any(named: 'subtype'),
          sourceAccountId: any(named: 'sourceAccountId'),
          contact: any(named: 'contact'),
          contractRef: any(named: 'contractRef'),
          collectionAccountId: any(named: 'collectionAccountId'),
        )).thenThrow(const GrpcError.unavailable('down'));
    await createOne();
    verify(() => remote.create(
          accountId: 'acc-debt',
          counterparty: 'Bank',
          interestRate: 5.0,
          amortizationIndex: 0,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 12, 31),
          totalPrincipalCents: 100000,
          type: DebtType.borrowedIn,
        )).called(1);
    expect((await local.list()).map((d) => d.counterparty), contains('Bank'));
  });
}
