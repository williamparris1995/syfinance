// F10 T2(2026-09-04):8 模块 route 感知的 pending 置位 + 墓碑写入
// (spec FR-3/FR-4,design ADR-2/ADR-4)。repo `_routedWrite` 三分支:
// - guestLocal → 本地写,行 synced(无上行语义,R6 行为不变);
// - boundOfflineLocal / boundRemote+NetworkFailure 降级 → 本地写,头行 pending;
// - update 场景:synced 行被 bound 路由本地 update → 置回 pending(整行待上行);
// - bound 路由删除 → 硬删行 + 墓碑;guest 删除不写墓碑;账户守卫语义不变。
// holding 模块无删除操作(接口无 delete),墓碑覆盖其余 7 模块。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/data/budget_repository_impl.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/data/goal_remote_ds.dart';
import 'package:yucai_client/goal/data/goal_repository_impl.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/holding/data/goal_view_ds.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/data/holding_remote_ds.dart';
import 'package:yucai_client/holding/data/holding_repository_impl.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/data/template_remote_ds.dart';
import 'package:yucai_client/template/data/template_repository_impl.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}
class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}
class _MockDebtRemote extends Mock implements DebtRemoteDataSource {}
class _MockBudgetRemote extends Mock implements BudgetRemoteDataSource {}
class _MockGoalRemote extends Mock implements GoalRemoteDataSource {}
class _MockHoldingRemote extends Mock implements HoldingRemoteDataSource {}
class _MockGoalViewDs extends Mock implements GoalViewDataSource {}
class _MockTagRemote extends Mock implements TagRemoteDataSource {}
class _MockTemplateRemote extends Mock implements TemplateRemoteDataSource {}

const _createParams = CreateAccountParams(
  name: '现金',
  accountType: AccountType.asset,
  category: AccountCategory.savings,
  currencyCode: 'CNY',
  initialBalanceCents: 0,
  ownership: Ownership.personal,
);

void main() {
  late db.AppDatabase database;
  late SessionModeTracker tracker;

  late _MockAccountRemote accountRemote;
  late _MockTxnRemote txnRemote;
  late _MockDebtRemote debtRemote;
  late _MockBudgetRemote budgetRemote;
  late _MockGoalRemote goalRemote;
  late _MockHoldingRemote holdingRemote;
  late _MockTagRemote tagRemote;
  late _MockTemplateRemote templateRemote;

  late AccountRepositoryImpl accountRepo;
  late TransactionRepositoryImpl txnRepo;
  late DebtRepositoryImpl debtRepo;
  late BudgetRepositoryImpl budgetRepo;
  late GoalRepositoryImpl goalRepo;
  late HoldingRepositoryImpl holdingRepo;
  late TemplateRepositoryImpl templateRepo;

  late String cash;
  late String food;
  late String invest;

  Future<String> seedAccount(String id, String name, int type,
      {int balance = 100000}) async {
    final existing = await database.accountDao.getAccountById(id);
    if (existing != null) return id;
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

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    tracker = SessionModeTracker();

    accountRemote = _MockAccountRemote();
    txnRemote = _MockTxnRemote();
    debtRemote = _MockDebtRemote();
    budgetRemote = _MockBudgetRemote();
    goalRemote = _MockGoalRemote();
    holdingRemote = _MockHoldingRemote();
    tagRemote = _MockTagRemote();
    templateRemote = _MockTemplateRemote();

    final txnLocal =
        TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    final accountLocal = AccountLocalDataSource(database);
    final holdingLocal = HoldingLocalDataSource(database, txnLocal);
    final debtLocal = DebtLocalDataSource(database, txnLocal);
    final goalLocal = GoalLocalDataSource(database, holdingLocal);
    final budgetLocal = BudgetLocalDataSource(database);

    accountRepo =
        AccountRepositoryImpl(accountRemote, accountLocal, tracker);
    txnRepo = TransactionRepositoryImpl(txnRemote, txnLocal, tracker);
    debtRepo = DebtRepositoryImpl(debtRemote, debtLocal, tracker);
    budgetRepo = BudgetRepositoryImpl(budgetRemote, budgetLocal, tracker);
    goalRepo = GoalRepositoryImpl(goalRemote, goalLocal, tracker);
    holdingRepo = HoldingRepositoryImpl(
        holdingRemote, holdingLocal, tracker, _MockGoalViewDs());
    templateRepo = TemplateRepositoryImpl(templateRemote,
        TemplateLocalDataSource(database, txnLocal, accounts: accountLocal),
        tracker);

    registerFallbackValue(_createParams);
    registerFallbackValue(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 4),
      expenseAccountId: '',
      assetAccountId: '',
      amountCents: 0,
    ));

    cash = await seedAccount('acc-cash', 'cash', 1);
    food = await seedAccount('acc-food', 'food', 5);
    invest = await seedAccount('acc-invest', 'invest', 1);
  });

  tearDown(() => database.close());

  Future<String?> accountState(String id) async =>
      (await database.accountDao.getAccountById(id))?.syncState;

  /// debt 建行辅助(lumpSum 单期,便于 recordPayment)。
  Future<String> createDebt(String accountId) async {
    final r = await debtRepo.create(
      accountId: accountId,
      counterparty: '银行',
      interestRate: 0,
      amortizationIndex: 2, // lumpSum:单期
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 10, 1),
      totalPrincipalCents: 10000,
      type: DebtType.borrowedIn,
    );
    return r.fold((_) => '', (d) => d.id);
  }

  group('pending 置位(route 感知)', () {
    test('guest create → synced(无上行语义,R6 行为不变)', () async {
      final r = await accountRepo.create(_createParams);
      final id = r.fold((_) => '', (a) => a.id);
      expect(await accountState(id), SyncState.synced);
    });

    test('boundOfflineLocal create → pending', () async {
      tracker
        ..isGuest = false
        ..online = false;
      final r = await accountRepo.create(_createParams);
      final id = r.fold((_) => '', (a) => a.id);
      expect(await accountState(id), SyncState.pending);
    });

    test('boundRemote + NetworkFailure 降级 create → pending(FR-1b)', () async {
      tracker.isGuest = false;
      when(() => accountRemote.create(any()))
          .thenThrow(const GrpcError.unavailable('down'));
      final r = await accountRepo.create(_createParams);
      expect(r.isRight(), isTrue);
      final id = r.fold((_) => '', (a) => a.id);
      expect(await accountState(id), SyncState.pending);
    });

    test('bound update:synced 行 → 置回 pending(整行待上行)', () async {
      final created = await accountRepo.create(_createParams);
      final id = created.fold((_) => '', (a) => a.id);
      final version = created.fold((_) => 0, (a) => a.version);
      expect(await accountState(id), SyncState.synced);

      tracker
        ..isGuest = false
        ..online = false;
      final r = await accountRepo.update(UpdateAccountParams(
          id: id, version: version, name: '改名'));
      expect(r.isRight(), isTrue);
      expect(await accountState(id), SyncState.pending);
    });

    test('guest update → 保持 synced', () async {
      final created = await accountRepo.create(_createParams);
      final id = created.fold((_) => '', (a) => a.id);
      final version = created.fold((_) => 0, (a) => a.version);
      final r = await accountRepo.update(UpdateAccountParams(
          id: id, version: version, name: '改名'));
      expect(r.isRight(), isTrue);
      expect(await accountState(id), SyncState.synced);
    });

    test('transaction:boundOffline 记账 → 头行 pending(guest 缺省 synced)',
        () async {
      tracker
        ..isGuest = false
        ..online = false;
      final r = await txnRepo.recordExpense(RecordExpenseParams(
        transactionDate: DateTime(2026, 9, 4),
        description: '午餐',
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      ));
      expect(r.isRight(), isTrue);
      final id = r.fold((_) => '', (t) => t.id);
      final head = await database.transactionDao.getTransactionById(id);
      expect(head!.syncState, SyncState.pending);
    });

    test('budget:boundOffline createBudget → pending', () async {
      tracker
        ..isGuest = false
        ..online = false;
      final r = await budgetRepo.createBudget(
          name: '九月', month: '2026-09', currencyCode: 'CNY', items: []);
      expect(r.isRight(), isTrue);
      final id = r.fold((_) => '', (b) => b.id);
      final row = await database.budgetDao.getBudgetById(id);
      expect(row!.syncState, SyncState.pending);
    });

    test('goal:boundOffline createGoal → pending', () async {
      tracker
        ..isGuest = false
        ..online = false;
      final r = await goalRepo.createGoal(
          name: '应急金', type: GoalType.savings, targetAmountCents: 100000);
      expect(r.isRight(), isTrue);
      final id = r.fold((_) => '', (g) => g.id);
      final row = await database.goalDao.getGoalById(id);
      expect(row!.syncState, SyncState.pending);
    });

    test('tag:boundOffline create → pending', () async {
      tracker
        ..isGuest = false
        ..online = false;
      final repo = TagRepositoryImpl(
          tagRemote, TagLocalDataSource(database), tracker);
      final r = await repo.create(name: '餐饮', color: '#FF0000');
      expect(r.isRight(), isTrue);
      final id = r.fold((_) => '', (t) => t.id);
      final row = await database.tagDao.getTagById(id);
      expect(row!.syncState, SyncState.pending);
    });

    test('template:boundOffline create → pending', () async {
      tracker
        ..isGuest = false
        ..online = false;
      final r = await templateRepo.create(
        name: '月租',
        amountCents: 300000,
        direction: TemplateDirection.expense,
        cycle: TemplateCycle.monthly,
        sourceAccountId: cash,
      );
      expect(r.isRight(), isTrue);
      final id = r.fold((_) => '', (t) => t.id);
      final row = await database.templateDao.getTemplateById(id);
      expect(row!.syncState, SyncState.pending);
    });

    test('复合写:debt recordPayment(boundOffline)→ debt 头 pending + 交易 pending',
        () async {
      tracker
        ..isGuest = false
        ..online = false;
      final debtAccount = await seedAccount('acc-debt', 'debt', 2);
      final debtId = await createDebt(debtAccount);
      final entryId =
          (await database.debtDao.watchScheduleByDebt(debtId).first).first.id;

      final r = await debtRepo.recordPayment(
          debtId: debtId, scheduleEntryId: entryId, fromAccountId: cash);
      expect(r.isRight(), isTrue);

      // debt 头行 pending(期次已还的本地事实需被镜像协调保护)。
      final debtRow = await database.debtDao.getDebtById(debtId);
      expect(debtRow!.syncState, SyncState.pending);
      // 还款双分录交易头行 pending。
      final txnId =
          (await database.debtDao.watchScheduleByDebt(debtId).first)
              .first
              .transactionId!;
      final head = await database.transactionDao.getTransactionById(txnId);
      expect(head!.syncState, SyncState.pending);
    });

    test('复合写:holding buy(boundOffline)→ holding 头 pending + 交易 pending',
        () async {
      tracker
        ..isGuest = false
        ..online = false;
      final r = await holdingRepo.buy(
        accountId: invest,
        securityId: 'sec-1',
        fromAccountId: cash,
        quantity: 10,
        priceCents: 100,
        tradeDate: '2026-09-04',
      );
      expect(r.isRight(), isTrue);

      final holdings = await database.holdingDao.watchAllHoldings().first;
      expect(holdings, hasLength(1));
      expect(holdings.single.syncState, SyncState.pending);

      // 买入现金流交易头行 pending。
      final txns = await database.transactionDao.getAllTransactions();
      expect(txns, hasLength(1));
      expect(txns.single.syncState, SyncState.pending);
    });

    test('复合写:template record(boundOffline)→ template 头 pending + 交易 pending',
        () async {
      final created = await templateRepo.create(
        name: '月租',
        amountCents: 300000,
        direction: TemplateDirection.expense,
        cycle: TemplateCycle.monthly,
        sourceAccountId: cash,
        startDate: '2026-08-01',
      );
      final id = created.fold((_) => '', (t) => t.id);

      tracker
        ..isGuest = false
        ..online = false;
      final r = await templateRepo.record(id);
      expect(r.isRight(), isTrue);

      final row = await database.templateDao.getTemplateById(id);
      expect(row!.syncState, SyncState.pending);
      final txns = await database.transactionDao.getAllTransactions();
      expect(txns, hasLength(1));
      expect(txns.single.syncState, SyncState.pending);
    });
  });

  group('墓碑写入(FR-4/ADR-4)', () {
    Future<List<db.SyncTombstone>> tombstones(String module) async =>
        database.syncTombstoneDao.getTombstonesByModule(module);

    test('boundOffline 删账户 → 硬删行 + 墓碑;guest 删 → 无墓碑', () async {
      final created = await accountRepo.create(_createParams);
      final id = created.fold((_) => '', (a) => a.id);

      tracker
        ..isGuest = false
        ..online = false;
      final r = await accountRepo.delete(id);
      expect(r.isRight(), isTrue);
      expect(await database.accountDao.getAccountById(id), isNull);
      expect((await tombstones(SyncModule.account)).map((t) => t.entityId),
          [id]);

      // guest 删除:不写墓碑(绑定走全量首传)。切回 guest 路由。
      tracker
        ..isGuest = true
        ..online = true;
      final guest = await accountRepo.create(_createParams);
      final gid = guest.fold((_) => '', (a) => a.id);
      final r2 = await accountRepo.delete(gid);
      expect(r2.isRight(), isTrue);
      expect(await database.accountDao.getAccountById(gid), isNull);
      expect(await tombstones(SyncModule.account), hasLength(1));
    });

    test('boundRemote + NetworkFailure 降级删 → 墓碑(同为 bound 路由)',
        () async {
      final created = await accountRepo.create(_createParams);
      final id = created.fold((_) => '', (a) => a.id);

      tracker.isGuest = false;
      when(() => accountRemote.delete(any()))
          .thenThrow(const GrpcError.unavailable('down'));
      final r = await accountRepo.delete(id);
      expect(r.isRight(), isTrue);
      expect(await database.accountDao.getAccountById(id), isNull);
      expect((await tombstones(SyncModule.account)).map((t) => t.entityId),
          [id]);
    });

    test('账户非零余额守卫不变:拒绝删除且不写墓碑', () async {
      final accountLocal = AccountLocalDataSource(database);
      final created = await accountLocal.create(const CreateAccountParams(
        name: '有余额',
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 500,
        ownership: Ownership.personal,
      ));

      tracker
        ..isGuest = false
        ..online = false;
      final r = await accountRepo.delete(created.id);

      expect(r.isLeft(), isTrue);
      // 守卫通过后的删除才墓碑:行仍在、无墓碑。
      expect(
          await database.accountDao.getAccountById(created.id), isNotNull);
      expect(await tombstones(SyncModule.account), isEmpty);
    });

    test('transaction/budget/goal/tag/template/debt boundOffline 删 → 各自墓碑',
        () async {
      tracker
        ..isGuest = false
        ..online = false;

      // transaction
      final txn = await txnRepo.recordExpense(RecordExpenseParams(
        transactionDate: DateTime(2026, 9, 4),
        description: 'x',
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 100,
      ));
      final txnId = txn.fold((_) => '', (t) => t.id);
      expect((await txnRepo.delete(txnId)).isRight(), isTrue);
      expect((await tombstones(SyncModule.transaction)).map((t) => t.entityId),
          [txnId]);

      // budget
      final budget = await budgetRepo.createBudget(
          name: '九月', month: '2026-09', currencyCode: 'CNY', items: []);
      final budgetId = budget.fold((_) => '', (b) => b.id);
      expect((await budgetRepo.deleteBudget(budgetId)).isRight(), isTrue);
      expect((await tombstones(SyncModule.budget)).map((t) => t.entityId),
          [budgetId]);

      // goal
      final goal = await goalRepo.createGoal(
          name: 'g', type: GoalType.savings, targetAmountCents: 1);
      final goalId = goal.fold((_) => '', (g) => g.id);
      expect((await goalRepo.deleteGoal(goalId)).isRight(), isTrue);
      expect((await tombstones(SyncModule.goal)).map((t) => t.entityId),
          [goalId]);

      // tag
      final tagRepo = TagRepositoryImpl(
          tagRemote, TagLocalDataSource(database), tracker);
      final tag = await tagRepo.create(name: 't', color: '#000000');
      final tagId = tag.fold((_) => '', (t) => t.id);
      expect((await tagRepo.delete(tagId)).isRight(), isTrue);
      expect((await tombstones(SyncModule.tag)).map((t) => t.entityId),
          [tagId]);

      // template
      final template = await templateRepo.create(
        name: 'tpl',
        amountCents: 100,
        direction: TemplateDirection.expense,
        cycle: TemplateCycle.monthly,
        sourceAccountId: cash,
      );
      final templateId = template.fold((_) => '', (t) => t.id);
      expect((await templateRepo.delete(templateId)).isRight(), isTrue);
      expect((await tombstones(SyncModule.template)).map((t) => t.entityId),
          [templateId]);

      // debt
      final debtAccount = await seedAccount('acc-debt2', 'debt2', 2);
      final debtId = await createDebt(debtAccount);
      expect((await debtRepo.delete(debtId)).isRight(), isTrue);
      expect((await tombstones(SyncModule.debt)).map((t) => t.entityId),
          [debtId]);
    });
  });
}
