// F65-T1 TDD RED → GREEN:goals_list 只读工具(FR-2,目标进度)。
// 真库夹具:内存 drift + goalDao/debtDao 直插,当前金额由 GoalLocalDataSource
// 读时三源 actuals 计算(investment=Σ持仓市值 / savings=Σ账户余额 /
// debtPayoff=Σ期次已还)—— 工具经**真实** GoalRepositoryImpl(guest 路由)
// 供数,与目标页同一条读路径。期望值独立手算。
// 「预计达成」:域内无该派生(GoalView 无投影字段,页面也不算)→ 工具
// 只如实输出 deadline,不编造预测(FR-5 禁编造)。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/assistant/data/tools/goals_list_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/data/goal_remote_ds.dart';
import 'package:yucai_client/goal/data/goal_repository_impl.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockGoalRemote extends Mock implements GoalRemoteDataSource {}

class _MockGoalRepo extends Mock implements GoalRepository {}

void main() {
  late db.AppDatabase database;
  late GoalRepositoryImpl repo;
  late GoalsListTool tool;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    repo = GoalRepositoryImpl(
      _MockGoalRemote(),
      GoalLocalDataSource(
        database,
        HoldingLocalDataSource(database,
            TransactionLocalDataSource(database, BalanceLocalUpdater(database))),
      ),
      tracker,
    );

    // g1:savings 目标,挂 acc-cash(余额 350,000)→ 读时 actuals 350,000。
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-cash',
      name: '现金',
      accountType: 1,
      category: 1,
      currencyCode: 'CNY',
      initialBalanceCents: 350000,
      currentBalanceCents: 350000,
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

    // g2:debtPayoff 目标,挂 d1(期次已还 100,000)→ actuals 100,000。
    await database.debtDao.insertDebt(db.DebtsCompanion.insert(
      id: 'd1',
      accountId: 'acc-cash',
      counterparty: 'cp-d1',
      interestRate: 0.5,
      amortizationMethod: 1,
      startDate: DateTime.utc(2026, 8, 1),
      dueDate: DateTime.utc(2027, 8, 1),
      totalPrincipalCents: 200000,
      debtType: 1,
      subtype: DebtSubtypes.creditLoan,
      contact: '',
      contractRef: '',
      version: 1,
      createdAt: DateTime.utc(2026, 8, 1),
      updatedAt: DateTime.utc(2026, 8, 1),
    ));
    await database.debtDao.insertScheduleEntry(
        db.PaymentScheduleEntriesCompanion.insert(
      id: 'e1',
      debtId: 'd1',
      paymentDate: DateTime.utc(2026, 9, 1),
      principalCents: 100000,
      interestCents: 0,
      totalCents: 100000,
      paidCents: 100000,
      paid: true,
    ));

    Future<void> seedGoal(String id,
        {required int goalType,
        required int target,
        int current = 0,
        DateTime? deadline,
        bool completed = false}) async {
      await database.goalDao.insertGoal(db.GoalsCompanion.insert(
        id: id,
        name: 'goal-$id',
        goalType: goalType,
        targetAmountCents: target,
        currentAmountCents: current,
        currencyCode: 'CNY',
        deadline: Value(deadline),
        notes: '',
        isCompleted: completed,
        version: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
    }

    await seedGoal('g1', goalType: 1, target: 1000000,
        deadline: DateTime.utc(2026, 12, 31));
    await database.goalDao.insertAccountLink(
        db.GoalAccountLinksCompanion.insert(goalId: 'g1', linkedId: 'acc-cash'));

    await seedGoal('g2', goalType: 2, target: 200000);
    await database.goalDao.insertDebtLink(
        db.GoalDebtLinksCompanion.insert(goalId: 'g2', linkedId: 'd1'));

    // g3:无挂接手工目标(存储 current 直读),已完成。
    await seedGoal('g3', goalType: 1, target: 50000,
        current: 50000, completed: true);

    tool = GoalsListTool(repo);
  });

  tearDown(() => database.close());

  Map<String, Object?> run(ToolResult r) => (r as ToolData).json;

  test('per-goal rows: target/current/remaining/progress/deadline/completed',
      () async {
    final json = run(await tool.execute(const {}));
    final goals = (json['goals'] as List).cast<Map<String, Object?>>();

    final g1 = goals.singleWhere((g) => g['name'] == 'goal-g1');
    expect(g1['type'], 'savings');
    expect(g1['targetAmountCents'], 1000000);
    expect(g1['targetAmountYuan'], '10,000.00');
    expect(g1['currentAmountCents'], 350000,
        reason: '读时 actuals = 挂接账户余额');
    expect(g1['currentAmountYuan'], '3,500.00');
    expect(g1['remainingCents'], 650000);
    expect(g1['progressPct'], closeTo(35.0, 0.001));
    expect(g1['deadline'], contains('2026-12-31'));
    expect(g1['isCompleted'], isFalse);

    final g2 = goals.singleWhere((g) => g['name'] == 'goal-g2');
    expect(g2['type'], 'debtPayoff');
    expect(g2['currentAmountCents'], 100000, reason: '读时 actuals = 期次已还');
    expect(g2['progressPct'], closeTo(50.0, 0.001));
    expect(g2['deadline'], isNull, reason: '未设截止 → null,不编造');

    final g3 = goals.singleWhere((g) => g['name'] == 'goal-g3');
    expect(g3['currentAmountCents'], 50000, reason: '无挂接 → 存储值直读');
    expect(g3['progressPct'], closeTo(100.0, 0.001));
    expect(g3['isCompleted'], isTrue);
  });

  test('summary: count/active/completed + totals dual caliber', () async {
    final json = run(await tool.execute(const {}));
    final summary = json['summary'] as Map<String, Object?>;
    expect(summary['count'], 3);
    expect(summary['activeCount'], 2);
    expect(summary['completedCount'], 1);
    expect(summary['totalTargetCents'], 1250000);
    expect(summary['totalTargetYuan'], '12,500.00');
    expect(summary['totalCurrentCents'], 350000 + 100000 + 50000);
    expect(summary['totalCurrentYuan'], '5,000.00');
  });

  test('empty goal list → well-formed empty output', () async {
    final empty = db.AppDatabase(NativeDatabase.memory());
    try {
      final tracker = SessionModeTracker()..isGuest = true;
      final emptyRepo = GoalRepositoryImpl(
        _MockGoalRemote(),
        GoalLocalDataSource(
          empty,
          HoldingLocalDataSource(empty,
              TransactionLocalDataSource(empty, BalanceLocalUpdater(empty))),
        ),
        tracker,
      );
      final json = run(await GoalsListTool(emptyRepo).execute(const {}));
      expect(json['goals'], isEmpty);
      expect((json['summary'] as Map)['count'], 0);
      expect((json['summary'] as Map)['totalTargetCents'], 0);
    } finally {
      await empty.close();
    }
  });

  test('repository failure → ToolError, no throw', () async {
    final failing = _MockGoalRepo();
    when(() => failing.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
    final result = await GoalsListTool(failing).execute(const {});
    expect(result, isA<ToolError>());
  });
}
