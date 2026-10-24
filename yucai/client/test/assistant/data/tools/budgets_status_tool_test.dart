// F65-T1 TDD RED → GREEN:budgets_status 只读工具(FR-2,预算执行度)。
// 真库夹具:内存 drift + budgetDao/transactionDao 直插,实际发生额由
// BudgetLocalDataSource 读时 actuals 计算(账户级 max(Σdebit,Σcredit) 大边
// 口径,server 规则)—— 工具经**真实** BudgetRepositoryImpl(guest 路由)
// 供数,与预算页同一条读路径。期望值独立手算(预算 item 均挂支出分类
// 账户,对手现金腿不计入 item actual —— 账户级大边只看本账户行)。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/assistant/data/tools/budgets_status_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/data/budget_repository_impl.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

class _MockBudgetRemote extends Mock implements BudgetRemoteDataSource {}

class _MockBudgetRepo extends Mock implements BudgetRepository {}

void main() {
  late db.AppDatabase database;
  late BudgetRepositoryImpl repo;
  late BudgetsStatusTool tool;

  Future<void> seedAccount(db.AppDatabase db_, String id, String name,
      int type, int category) async {
    await db_.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: type,
      category: category,
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
  }

  /// 双腿交易直插:debit `accId` amount / credit `acc-cash` amount。
  Future<void> seedTxn(db.AppDatabase db_, String id, String accId,
      DateTime date, int amount) async {
    await db_.transactionDao.insertTransaction(db.TransactionsCompanion.insert(
      id: id,
      transactionDate: date,
      description: 'seed-$id',
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    await db_.transactionDao.insertEntry(db.TransactionEntriesCompanion.insert(
      id: '$id-d',
      transactionId: id,
      accountId: accId,
      chartOfAccountCode: '',
      debitCents: amount,
      creditCents: 0,
      note: '',
    ));
    await db_.transactionDao.insertEntry(db.TransactionEntriesCompanion.insert(
      id: '$id-c',
      transactionId: id,
      accountId: 'acc-cash',
      chartOfAccountCode: '',
      debitCents: 0,
      creditCents: amount,
      note: '',
    ));
  }

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    repo = BudgetRepositoryImpl(
        _MockBudgetRemote(), BudgetLocalDataSource(database), tracker);

    await seedAccount(database, 'acc-cash', '现金', 1, 1);
    // 分类账户 category = otherAsset(int 8 = AccountCategory.index+1)。
    await seedAccount(database, 'acc-food', '餐饮', 5, 8);
    await seedAccount(database, 'acc-transport', '交通', 5, 8);

    Future<void> seedBudget(String id, String name, String month,
        int totalAmount) async {
      await database.budgetDao.insertBudget(db.BudgetsCompanion.insert(
        id: id,
        name: name,
        month: month,
        totalAmountCents: totalAmount,
        currencyCode: 'CNY',
        isActive: true,
        version: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
    }

    Future<void> seedItem(
            String id, String budgetId, String accountId, int planned) =>
        database.budgetDao.insertItem(db.BudgetItemsCompanion.insert(
          id: id,
          budgetId: budgetId,
          accountId: accountId,
          plannedAmountCents: planned,
          actualAmountCents: 0,
          notes: '',
        ));

    // b1:2026-10 预算 100,000(餐饮 60,000 + 交通 40,000)。
    await seedBudget('b1', '十月预算', '2026-10', 100000);
    await seedItem('i1', 'b1', 'acc-food', 60000);
    await seedItem('i2', 'b1', 'acc-transport', 40000);

    // b2:2026-09 预算 50,000(仅餐饮)。
    await seedBudget('b2', '九月预算', '2026-09', 50000);
    await seedItem('i3', 'b2', 'acc-food', 50000);

    // 实际发生额:10 月餐饮 72,000 + 交通 10,000;9 月餐饮 45,000。
    await seedTxn(database, 't1', 'acc-food', DateTime.utc(2026, 10, 3), 72000);
    await seedTxn(database, 't2', 'acc-transport', DateTime.utc(2026, 10, 8), 10000);
    await seedTxn(database, 't3', 'acc-food', DateTime.utc(2026, 9, 12), 45000);

    tool = BudgetsStatusTool(repo);
  });

  tearDown(() => database.close());

  Map<String, Object?> run(ToolResult r) => (r as ToolData).json;

  test('per-budget rows: limit/actual/remaining/usagePct/overBudget, dual caliber',
      () async {
    final json = run(await tool.execute(const {}));
    final budgets = (json['budgets'] as List).cast<Map<String, Object?>>();

    // 读时 actuals(账户级大边):b1 = food 72,000 + transport 10,000。
    final oct = budgets.singleWhere((b) => b['month'] == '2026-10');
    expect(oct['name'], '十月预算');
    expect(oct['limitCents'], 100000);
    expect(oct['limitYuan'], '1,000.00');
    expect(oct['actualCents'], 82000);
    expect(oct['actualYuan'], '820.00');
    expect(oct['remainingCents'], 18000);
    expect(oct['remainingYuan'], '180.00');
    expect(oct['usagePct'], closeTo(82.0, 0.001));
    expect(oct['overBudget'], isFalse);

    final sep = budgets.singleWhere((b) => b['month'] == '2026-09');
    expect(sep['actualCents'], 45000);
    expect(sep['usagePct'], closeTo(90.0, 0.001));
    expect(sep['overBudget'], isFalse);
  });

  test('summary aggregates across budgets; full usage is not over-budget',
      () async {
    // 追加 10 月餐饮 18,000 → b1 actual = 90,000 + 10,000 = 100,000(满额)。
    await seedTxn(database, 't4', 'acc-food', DateTime.utc(2026, 10, 20), 18000);

    final json = run(await tool.execute(const {}));
    final budgets = (json['budgets'] as List).cast<Map<String, Object?>>();
    final oct = budgets.singleWhere((b) => b['month'] == '2026-10');
    expect(oct['actualCents'], 100000);
    expect(oct['usagePct'], closeTo(100.0, 0.001));
    expect(oct['overBudget'], isFalse, reason: '恰好用满不超支(> 才超)');

    final summary = json['summary'] as Map<String, Object?>;
    expect(summary['count'], 2);
    expect(summary['overBudgetCount'], 0);
    expect(summary['totalLimitCents'], 150000);
    expect(summary['totalLimitYuan'], '1,500.00');
    expect(summary['totalActualCents'], 100000 + 45000);
    expect(summary['totalRemainingCents'], 5000);
  });

  test('overBudget marked when actual exceeds limit; remaining goes negative',
      () async {
    // 追加 10 月餐饮 29,000 → b1 actual = 72,000+18,000+29,000+10,000 = 129,000。
    await seedTxn(database, 't4', 'acc-food', DateTime.utc(2026, 10, 20), 18000);
    await seedTxn(database, 't5', 'acc-food', DateTime.utc(2026, 10, 21), 29000);

    final json = run(await tool.execute(const {}));
    final oct = (json['budgets'] as List)
        .cast<Map<String, Object?>>()
        .singleWhere((b) => b['month'] == '2026-10');
    expect(oct['actualCents'], 129000);
    expect(oct['overBudget'], isTrue);
    expect(oct['remainingCents'], -29000, reason: '剩余可为负');
    expect((json['summary'] as Map)['overBudgetCount'], 1);
  });

  test('empty budget list → well-formed empty output', () async {
    final empty = db.AppDatabase(NativeDatabase.memory());
    try {
      await seedAccount(empty, 'acc-cash', '现金', 1, 1);
      final tracker = SessionModeTracker()..isGuest = true;
      final emptyRepo = BudgetRepositoryImpl(
          _MockBudgetRemote(), BudgetLocalDataSource(empty), tracker);
      final json = run(await BudgetsStatusTool(emptyRepo).execute(const {}));
      expect(json['budgets'], isEmpty);
      expect((json['summary'] as Map)['count'], 0);
      expect((json['summary'] as Map)['totalLimitCents'], 0);
    } finally {
      await empty.close();
    }
  });

  test('repository failure → ToolError, no throw', () async {
    final failing = _MockBudgetRepo();
    when(() => failing.listBudgets(activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
    final result = await BudgetsStatusTool(failing).execute(const {});
    expect(result, isA<ToolError>());
  });
}
