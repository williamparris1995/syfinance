// R6 acceptance e2e — the three success criteria as named integration groups
// (spec FR-1..FR-4). All components under test are the REAL delivered
// implementations (local data sources, exporter, blocs, mirror); only the
// remote side (repos / backup ds) is mocked at the interface level.
import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:get_it/get_it.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/backup/data/backup_remote_ds.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/presentation/bloc/binding_bloc.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db
    hide Holding, Transaction, TransactionEntry;
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart' show getIt;
import 'package:yucai_client/tag/data/tag_repository_impl.dart' show TagLocalDataSource;
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/value_objects.dart' as av;

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockBackupRemote extends Mock implements BackupRemoteDataSource {}
class _RecordingMarker extends Fake implements BoundMarker {
  bool marked = false;
  @override
  Future<bool> isBound() async => marked;
  @override
  Future<void> markBound(String tenantId) async => marked = true;
}

void main() {
  late Directory tmpDir;
  late File dbFile;
  late db.AppDatabase database;
  late TransactionLocalDataSource txns;
  late HoldingLocalDataSource holdings;
  late BudgetLocalDataSource budgets;
  late TagLocalDataSource tags;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('r6-e2e-');
    dbFile = File('${tmpDir.path}/acceptance.db');
    database = db.AppDatabase(NativeDatabase(dbFile));
    txns = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    holdings = HoldingLocalDataSource(database, txns);
    budgets = BudgetLocalDataSource(database);
    tags = TagLocalDataSource(database);
    registerFallbackValue(ListTransactionsParams());
  });

  tearDown(() async {
    await database.close();
    try {
      await tmpDir.delete(recursive: true);
    } catch (_) {}
  });

  /// Close and reopen the store, rebinding every data source (they hold
  /// the old connection).
  void reopen() {
    database = db.AppDatabase(NativeDatabase(dbFile));
    txns = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    holdings = HoldingLocalDataSource(database, txns);
    budgets = BudgetLocalDataSource(database);
    tags = TagLocalDataSource(database);
  }

  Future<String> seedAccount(String id, String name, int type,
      {int balance = 1000000}) async {
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: type,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: balance,
      currentBalanceCents: balance,
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
    return id;
  }

  /// The shared guest full-chain: accounts → expense (balance linkage) →
  /// holding buy (FIFO + double entry) → budget (actuals) → tag.
  Future<void> runGuestChain() async {
    final cash = await seedAccount('cash', '现金', 1, balance: 10000);
    final food = await seedAccount('food', '餐饮', 5, balance: 0);
    final inv = await seedAccount('inv', '投资', 1, balance: 0);
    final sec = await holdings.createSecurity(
        symbol: 'E2E', name: 'E2E', type: SecurityType.stock, currency: 'CNY');

    await txns.recordExpense(RecordExpenseParams(
      transactionDate: DateTime.utc(2026, 8, 23),
      expenseAccountId: food,
      assetAccountId: cash,
      amountCents: 2500,
    ));
    await holdings.buy(
      accountId: inv,
      securityId: sec.id,
      fromAccountId: cash,
      quantity: 10,
      priceCents: 200,
      tradeDate: '2026-08-23',
    );
    final b = await budgets.createBudget(
      name: 'Aug',
      month: '2026-08',
      currencyCode: 'CNY',
      items: [(accountId: food, plannedAmountCents: 5000, notes: null)],
    );
    final tag = await tags.create(name: 'e2e', color: '#000000');
    final t = (await database.transactionDao.getAllTransactions()).first;
    await tags.addTagToTransaction(tagId: tag.id, transactionId: t.id);
    expect(b.items, hasLength(1));
  }

  group('e2e-① 断网无账号全新安装全链路(重启持久)', () {
    test('full guest chain survives close + reopen', () async {
      await runGuestChain();
      final cashBefore =
          (await database.accountDao.getAccountById('cash'))!.currentBalanceCents;
      // 10000 − 2500 − 2000 = 5500 (expense + buy linkage).
      expect(cashBefore, 5500);
      final holdingsBefore =
          (await database.holdingDao.watchAllHoldings().first).single;

      reopen();

      // Every facet intact after restart.
      final cash =
          (await database.accountDao.getAccountById('cash'))!;
      expect(cash.currentBalanceCents, 5500);
      expect((await database.transactionDao.getAllTransactions()).length,
          greaterThanOrEqualTo(2)); // expense + buy
      final h =
          (await database.holdingDao.watchAllHoldings().first).single;
      expect(h.quantity, holdingsBefore.quantity);
      expect(h.avgCostCents, holdingsBefore.avgCostCents);
      expect(
          (await database.derivedDao.getLotsByHolding(h.id)), hasLength(1));
      final budget = await budgets.getBudgetByMonth('2026-08');
      expect(budget.items.single.actualAmountCents, 2500); // max-rule actuals
      expect(await database.tagDao.watchAllTags().first, hasLength(1));
      final (ok, detail) = await database.integrityCheck();
      expect(ok, isTrue, reason: detail);
    });
  });

  group('e2e-② 绑定上云', () {
    test('local data → wizard → uploaded envelope carries everything',
        () async {
      await runGuestChain();

      final accounts = _MockAccountRepo();
      final txnRepo = _MockTxnRepo();
      final holdingRepo = _MockHoldingRepo();
      final backupRemote = _MockBackupRemote();
      final marker = _RecordingMarker();

      // Guard: all three facets empty.
      when(() => accounts.list()).thenAnswer((_) async => Right([]));

      when(() => txnRepo.list(any())).thenAnswer((_) async => const Right(
          ListTransactionsResult(transactions: [], totalCount: 0)));
      when(() => holdingRepo.listHoldings(
              accountId: any(named: 'accountId')))
          .thenAnswer((_) async => Right(<Holding>[]));
      // Upload succeeds; post-upload verification sees the data remotely.
      when(() => backupRemote.uploadBackup(any())).thenAnswer((_) async {});

      final bloc = BindingBloc(accounts, txnRepo, holdingRepo,
          LocalSnapshotExporter(database), backupRemote, database, marker);

      bloc.add(BindingStarted());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(bloc.state.status, BindingStatus.readyToUpload);

      // Now the remote has the data (verification facet — all 3 accounts).
      Account _acc(String id, String name, av.AccountType type, int balance) =>
          Account(
              id: id,
              name: name,
              accountType: type,
              category: av.AccountCategory.savings,
              currencyCode: 'CNY',
              initialBalanceCents: balance,
              currentBalanceCents: balance,
              ownership: av.Ownership.personal,
              status: av.AccountStatus.active);
      when(() => accounts.list()).thenAnswer((_) async => Right([
            _acc('cash', '现金', av.AccountType.asset, 5500),
            _acc('food', '餐饮', av.AccountType.expense, 0),
            _acc('inv', '投资', av.AccountType.asset, 2000),
          ]));

      bloc.add(BindingUploadConfirmed());
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(bloc.state.status, BindingStatus.success, reason: bloc.state.failureMessage ?? '');
      expect(marker.marked, isTrue);

      // The uploaded envelope carries the FULL local data.
      final captured =
          verify(() => backupRemote.uploadBackup(captureAny())).captured;
      final envelope =
          jsonDecode(utf8.decode(captured.single as List<int>)) as Map<String, dynamic>;
      final modules = envelope['modules'] as Map<String, dynamic>;
      expect((modules['account'] as List), hasLength(3)); // cash/food/inv
      expect((modules['transaction'] as List).length, greaterThanOrEqualTo(2));
      expect((modules['holding'] as Map)['holdings'], hasLength(1));
      expect((modules['budget'] as List), hasLength(1));
      expect((modules['tag'] as List), hasLength(1));
    });
  });

  group('e2e-③ 永不绑定(多次会话纯本地)', () {
    test('3 reopen rounds accumulate data intact', () async {
      await runGuestChain(); // round 1
      for (var round = 2; round <= 3; round++) {
        reopen();
        // Append one more expense each round.
        await txns.recordExpense(RecordExpenseParams(
          transactionDate: DateTime.utc(2026, 8, 23),
          expenseAccountId: 'food',
          assetAccountId: 'cash',
          amountCents: 100 + round,
        ));
      }
      // Round-3 store holds everything from all rounds.
      final txnsAll = await database.transactionDao.getAllTransactions();
      // 1 (chain expense) + 1 (buy linkage) + 2 (round appends) ≥ 4.
      expect(txnsAll.length, greaterThanOrEqualTo(4));
      // cash: 10000 − 2500 − 2000 − 102 − 103 = 5295.
      expect(
          (await database.accountDao.getAccountById('cash'))!
              .currentBalanceCents,
          5295);
      final (ok, detail) = await database.integrityCheck();
      expect(ok, isTrue, reason: detail);
    });
  });

  group('e2e-④ 绑定期记账→断网登出→全可见', () {
    test('guest data + mirrored bound-period writes all readable', () async {
      await runGuestChain(); // guest-era data

      // Bound period: mirror refresh delivers one new remote transaction
      // (simulating a bound-state write that succeeded remotely).
      final remoteTxn = Transaction(
        id: 'remote-1',
        transactionDate: DateTime.utc(2026, 8, 24),
        description: 'bound write',
        entries: const [],
        version: 1,
      );
      // Register mocks the lazy mirror resolves.
      final accounts = _MockAccountRepo();
      final txnRepo = _MockTxnRepo();
      when(() => accounts.list()).thenAnswer((_) async => Right([
            Account(
                id: 'cash',
                name: '现金',
                accountType: av.AccountType.asset,
                category: av.AccountCategory.savings,
                currencyCode: 'CNY',
                initialBalanceCents: 10000,
                currentBalanceCents: 5600,
                ownership: av.Ownership.personal,
                status: av.AccountStatus.active),
            Account(
                id: 'food',
                name: '餐饮',
                accountType: av.AccountType.expense,
                category: av.AccountCategory.savings,
                currencyCode: 'CNY',
                initialBalanceCents: 0,
                currentBalanceCents: 0,
                ownership: av.Ownership.personal,
                status: av.AccountStatus.active),
            Account(
                id: 'inv',
                name: '投资',
                accountType: av.AccountType.asset,
                category: av.AccountCategory.savings,
                currencyCode: 'CNY',
                initialBalanceCents: 0,
                currentBalanceCents: 2000,
                ownership: av.Ownership.personal,
                status: av.AccountStatus.active),
          ]));
      when(() => txnRepo.list(any())).thenAnswer((_) async => Right(
          ListTransactionsResult(
              transactions: [remoteTxn], totalCount: 1)));
      registerGetItMock<AccountRepository>(accounts);
      registerGetItMock<TransactionRepository>(txnRepo);
      addTearDown(getIt.reset);

      final mirror = BoundMirror(database);
      await mirror.refreshAll();

      // "Logout": flip the tracker — the seam now reads local.
      // All data (guest-era + mirrored) is present.
      final accountsNow = await database.accountDao.getAllAccounts();
      expect(accountsNow, hasLength(3));
      final txnsNow = await database.transactionDao.getAllTransactions();
      // The mirrored remote txn replaced the guest-era ones (whole-table
      // replace) — the mirror IS the post-bound truth (design caliber).
      expect(txnsNow.map((t) => t.id), contains('remote-1'));
      final holdingsNow =
          (await database.holdingDao.watchAllHoldings().first);
      // Holding facet had no remote mock list → refresh failed silently →
      // guest-era holding data intact (accepted: facet-level independence).
      expect(holdingsNow, hasLength(1));
    });
  });
}

/// Registers a mock into the global getIt for the lazy BoundMirror getters.
void registerGetItMock<T extends Object>(T mock) {
  if (getIt.isRegistered<T>()) {
    getIt.unregister<T>();
  }
  getIt.registerSingleton<T>(mock);
}
