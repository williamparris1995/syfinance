/// F6 FR-5 预算(含跨月隔离)+ FR-6 目标链 E2E(管道链路,真实本地数据源)。
///
/// 链路:预算行绑定分类账户 → recordTransaction 直配复式记支出 →
/// getBudgetByMonth 读时聚合 actual = max(Σdebit, Σcredit)(月窗口来自
/// 预算行 month,UTC 月界,无 wall-clock);目标:无链 recordContribution
/// 只加存储列不动账户,Savings 目标读时聚合 Σ关联账户余额覆盖存储值。
/// 模式照 link_receivable_collect_test.dart:夹具独立前缀(预链*),断言用前后差值。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_budget_goal_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide TransactionEntry;
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/goal/data/goal_local_ds.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AccountLocalDataSource accounts;
  late TransactionLocalDataSource txns;
  late BudgetLocalDataSource budgets;
  late GoalLocalDataSource goals;

  late String fundsId; // 预链资金(CNY 储蓄,初始 5,000.00)
  late String catId; // 预链餐饮(expense 分类账户,预算行绑定它)
  late String incomeCatId; // 预链工资(income 分类账户,④ 注资交易用)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_receivable_collect_test.dart)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    accounts = AccountLocalDataSource(db);
    txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    budgets = BudgetLocalDataSource(db);
    goals = GoalLocalDataSource(db, HoldingLocalDataSource(db, txns));

    // ---- 自包含夹具(预链* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('预链资金', 500000); // 5,000.00
    final cat = await accounts.create(const CreateAccountParams(
      name: '预链餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    catId = cat.id;
    final incomeCat = await accounts.create(const CreateAccountParams(
      name: '预链工资',
      accountType: AccountType.income,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    incomeCatId = incomeCat.id;

    // demo 种子在「真实运行当月」建了「本月预算」,而 getBudgetByMonth 按
    // month 取首行 —— 为使固定月窗口(2026-08/09)读数确定,先删同月演示
    // 预算(仅测试库,走生产 deleteBudget API)。
    for (final b in await budgets.listBudgets()) {
      if (b.month == '2026-08' || b.month == '2026-09') {
        await budgets.deleteBudget(b.id);
      }
    }
  });

  tearDownAll(deleteTestDb);

  // 记一笔支出:debit 分类账户 / credit 资金(参数形态照 demo_seed /
  // template_local_ds._createTxnForRow 的 expense 配对;日期取月中避月界)。
  Future<void> recordExpense(DateTime date, int amountCents) => txns
      .recordTransaction(RecordTransactionParams(
        transactionDate: date,
        description: '预链支出',
        entries: [
          TransactionEntry(
              accountId: catId, debitCents: amountCents, creditCents: 0),
          TransactionEntry(
              accountId: fundsId, debitCents: 0, creditCents: amountCents),
        ],
      ));

  testWidgets('预链①当月消耗:9 月支出入列 actual,余额差值 oracle', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 5,000.00

    await budgets.createBudget(
      name: '预链九月伙食',
      month: '2026-09',
      currencyCode: 'CNY',
      items: [
        (accountId: catId, plannedAmountCents: 200000, notes: null), // 2,000.00
      ],
    );

    // 9 月 15 日(月中,UTC)支出 450.00。
    await recordExpense(DateTime.utc(2026, 9, 15), 45000);

    final view = await budgets.getBudgetByMonth('2026-09');
    final item = view.items.single;
    expect(item.accountId, catId);
    // oracle:该账户 9 月窗口内 Σdebit=45,000、Σcredit=0 → max=45,000。
    expect(item.actualAmountCents, 45000, reason: 'actual = max(Σdebit, Σcredit)');
    expect(view.totalActualCents, 45000);
    // oracle:45,000 / 200,000 × 100 = 22.5%。
    expect(view.usagePct, closeTo(22.5, 0.001));

    // oracle:expense 复式 credit 资金 → 余额 −45,000 分。
    expect(await balanceOf(db, fundsId), beforeFunds - 45000,
        reason: '支出复式:资金 −金额');
  });

  testWidgets('预链②跨月隔离:8 月支出不进 9 月预算,8 月预算窗口含它', (t) async {
    final sepBefore = await budgets.getBudgetByMonth('2026-09');

    // 8 月 15 日(上月,月中)再支出 300.00。
    await recordExpense(DateTime.utc(2026, 8, 15), 30000);

    // 9 月预算不含它:actual 仍为 45,000(月窗口隔离,无滚动累加)。
    final sepAfter = await budgets.getBudgetByMonth('2026-09');
    expect(sepAfter.items.single.actualAmountCents, 45000,
        reason: '9 月窗口不含 8 月交易');
    expect(sepAfter.items.single.actualAmountCents,
        sepBefore.items.single.actualAmountCents,
        reason: '跨月交易不改变 9 月 actual');

    // 另建 8 月预算(同账户)→ 8 月窗口读到那笔。
    await budgets.createBudget(
      name: '预链八月伙食',
      month: '2026-08',
      currencyCode: 'CNY',
      items: [
        (accountId: catId, plannedAmountCents: 100000, notes: null), // 1,000.00
      ],
    );
    final augView = await budgets.getBudgetByMonth('2026-08');
    expect(augView.items.single.actualAmountCents, 30000,
        reason: '8 月窗口含 8 月交易');
  });

  testWidgets('预链③手动注资:无链目标 currentAmount +额且资金余额不变,≥100% 进度翻转', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 4,250.00(①② 之后)

    // 无链目标(不挂任何账户/债务)。
    final goal = await goals.createGoal(
      name: '预链旅行基金',
      type: GoalType.savings,
      targetAmountCents: 100000, // 1,000.00
    );

    final after1 = await goals.recordContribution(
        id: goal.id, amountCents: 40000); // 400.00
    expect(after1.currentAmountCents, 40000, reason: '注资入存储列');
    // oracle:注资不动资金账户(recordContribution 只改 goals 行)。
    expect(await balanceOf(db, fundsId), beforeFunds,
        reason: '手动注资:资金账户余额不变');

    // 累计 400+600 = 1,000 = 目标额 → 进度翻转。
    // 读代码确认:isCompleted 列仅 completeGoal 显式置位;recordContribution
    // 不自动完成 —— 进度口径看派生 getter progressPct / remainingCents。
    final after2 = await goals.recordContribution(
        id: goal.id, amountCents: 60000); // 600.00
    expect(after2.currentAmountCents, 100000, reason: '累计注资');
    expect(after2.progressPct, closeTo(100.0, 0.001), reason: '进度 ≥100%');
    expect(after2.remainingCents, 0, reason: '剩余归零');
    expect(after2.isCompleted, isFalse,
        reason: '照实断言:recordContribution 不自动完成,仅 completeGoal 显式'
            '置位(spec FR-6 文字与实现偏差,钉死为受保护语义)');
    expect(await balanceOf(db, fundsId), beforeFunds,
        reason: '累计注资仍不动资金账户');
  });

  testWidgets('预链④关联读时聚合:Savings 目标 actual = 关联账户余额(非存储列)', (t) async {
    // 先记一笔 9 月收入 1,500.00:debit 资金 / credit 收入分类
    // (income 配对复式,参数形态照 template_local_ds._createTxnForRow)。
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 9, 20), // 月中避月界
      description: '预链收入',
      entries: [
        TransactionEntry(
            accountId: fundsId, debitCents: 150000, creditCents: 0),
        TransactionEntry(
            accountId: incomeCatId, debitCents: 0, creditCents: 150000),
      ],
    ));

    // B1 = 交易后资金余额(raw drift 直读)。
    // oracle:500,000 −45,000(9 月)−30,000(8 月)+150,000 = 575,000 分
    //= 5,750.00 元。
    final b1 = await balanceOf(db, fundsId);
    expect(b1, 500000 - 45000 - 30000 + 150000,
        reason: 'sanity:B1 = 初始 − 支出合计 + 收入');

    final goal = await goals.createGoal(
      name: '预链买房首付',
      type: GoalType.savings,
      targetAmountCents: 5000000, // 50,000.00
      linkedAccountIds: [fundsId],
    );
    expect(goal.currentAmountCents, b1,
        reason: 'Savings 目标读时聚合 = Σ关联账户余额');

    // 再手动注资:存储列 +123.00,但有关联时读时聚合覆盖存储值 → actual 仍 B1。
    final after = await goals.recordContribution(
        id: goal.id, amountCents: 12300); // 123.00
    expect(after.currentAmountCents, b1,
        reason: '有关联时读时聚合覆盖存储列(非存储值)');
  });
}
