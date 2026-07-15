# Dashboard/Report 测试补全 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为已实现的 dashboard-report(`commit 68508b2..4440f77`)补齐 widget 测试,兑现 [`2026-07-15-dashboard-report-tests-design.md`](../specs/2026-07-15-dashboard-report-tests-design.md) §3,标准覆盖。

**Architecture:** 5 task —— Report 3 chart 单测(纯数据 fixture,无 mock)→ ReportPage 集成(mock `getIt<TransactionRepository>.summary`)→ Home `_harness` 改造可注入 → Home 5 panel 非空态 → 快捷操作 onTap(独立 router harness)。**生产代码零改动**;Task 3 改的是 test helper(`home_page_test.dart` 的 `_harness`),不动生产代码。

**Tech Stack:** Flutter(`flutter_test`)+ mocktail(`Mock`/`Fake`)+ fl_chart(`LineChart`/`PieChart`/`BarChart`)+ getIt(`registerSingleton`)+ go_router + dartz(`Either`)。

## Global Constraints

- **生产代码零改动** —— 本 plan 只新增 test 文件 + 改 `home_page_test.dart` 的 `_harness`(test helper)。若 test FAIL 暴露生产 bug,记录为 follow-up,**不在本 plan 修生产代码**(除非断言本身写错)。
- **mock 范式** —— `class _MockX extends Mock implements X` + `getIt.registerSingleton<X>(mock)` + `setUp(getIt.reset())`;`when(() => m.method(any())).thenAnswer(...)`;`any()` 的非原始参数需 `registerFallbackValue`。
- **中文 UI 文本直写断言** —— `find.text('收入')` 等;跨 RichText 用 `_textContaining` helper。
- **pump 时机** —— 默认 `pumpAndSettle`;若遇永不完成的 Future(持续动画/timer),改 `pump(Duration)`。
- **回归基线** —— `flutter test` 预存 **1 fail**(`account_detail_page_test` + `receivable_detail_page_test` 漂移,out-of-scope);`flutter analyze` 22 error 全 `*.pbserver.dart`(不受影响)。新测试必须**全绿**(除预存 1 fail)。
- **运行目录** —— 所有 `flutter` 命令在 `yucai/client/` 下执行(`cd yucai/client && flutter test ...`)。

---

## File Structure

| 文件 | 职责 | 动作 |
|---|---|---|
| `yucai/client/test/report/presentation/widgets/income_expense_trend_chart_test.dart` | 收支趋势 LineChart 单测(渲染/空态/图例) | Create |
| `yucai/client/test/report/presentation/widgets/category_breakdown_pie_test.dart` | 分类占比 PieChart 单测(渲染/空态) | Create |
| `yucai/client/test/report/presentation/widgets/monthly_comparison_bar_test.dart` | 月度对比 BarChart 单测(渲染/空态) | Create |
| `yucai/client/test/report/presentation/pages/report_page_test.dart` | ReportPage 集成(success/error/period 切换) | Create |
| `yucai/client/test/auth/presentation/pages/home_page_test.dart` | `_harness` 改造可注入 + 5 panel 非空态 + 快捷操作 onTap | Modify |

---

### Task 1: Report 3 chart widget 单测

**Files:**
- Create: `yucai/client/test/report/presentation/widgets/income_expense_trend_chart_test.dart`
- Create: `yucai/client/test/report/presentation/widgets/category_breakdown_pie_test.dart`
- Create: `yucai/client/test/report/presentation/widgets/monthly_comparison_bar_test.dart`

**Interfaces:**
- Consumes: `IncomeExpenseTrendChart({required List<DailySummary> byDay, SummaryScope scope})` / `CategoryBreakdownPie({required List<CategorySlice> slices})` / `MonthlyComparisonBar({required List<MonthlySummary> months})`;数据类型 `MonthlySummary`/`DailySummary`/`CategoryTotal` 来自 `package:yucai_client/transaction/domain/value_objects.dart`;`CategorySlice` 来自 `category_breakdown_pie.dart`。
- Produces: 验证 3 chart 的渲染契约(find.byType + 空态文本),Task 2 ReportPage 集成复用这些契约。

- [ ] **Step 1: 写 income_expense_trend_chart_test.dart**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/widgets/income_expense_trend_chart.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 构造单日 summary(byCategory 拆 income/expense,对齐 _incomeOf/_expenseOf 逻辑)。
DailySummary _day(String date, {int income = 0, int expense = 0}) => DailySummary(
      date: date,
      byCategory: [
        if (income > 0)
          CategoryTotal(
              categoryId: 'inc',
              name: '收入',
              accountType: 'income',
              amountCents: income),
        if (expense > 0)
          CategoryTotal(
              categoryId: 'exp',
              name: '支出',
              accountType: 'expense',
              amountCents: expense),
      ],
    );

void main() {
  testWidgets('有数据(≥2 点含正金额):渲染 LineChart + 收入/支出图例', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IncomeExpenseTrendChart(byDay: [
          _day('2026-07-01', income: 10000, expense: 5000),
          _day('2026-07-02', income: 8000, expense: 3000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
  });

  testWidgets('空数据(<2 点):显示空态,无 LineChart', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IncomeExpenseTrendChart(byDay: [
          _day('2026-07-01', income: 1000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('所选区间暂无收支记录'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行,期望 PASS(生产代码已实现该行为)**

Run: `cd yucai/client && flutter test test/report/presentation/widgets/income_expense_trend_chart_test.dart`
Expected: `00:00 +2: All tests passed!`(2 test)。若 FAIL,核对空态文本/图例字样是否与 `income_expense_trend_chart.dart` 一致。

- [ ] **Step 3: 写 category_breakdown_pie_test.dart**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/widgets/category_breakdown_pie.dart';

void main() {
  testWidgets('有 slices:渲染 PieChart + 图例分类名', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategoryBreakdownPie(slices: [
          CategorySlice(id: 'c1', name: '餐饮', amountCents: 60000),
          CategorySlice(id: 'c2', name: '交通', amountCents: 30000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    // total>0 → 渲染真实 PieChart sections(非空态灰环)。
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
  });

  testWidgets('空 slices(total=0):空态提示', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: CategoryBreakdownPie(slices: const [])),
    ));
    await t.pumpAndSettle();

    // total≤0 → centerText 显示 emptyLabel(默认「暂无支出记录」)+ 图例「暂无分类数据」。
    expect(find.text('暂无支出记录'), findsOneWidget);
    expect(find.text('暂无分类数据'), findsOneWidget);
  });
}
```

- [ ] **Step 4: 运行,期望 PASS**

Run: `cd yucai/client && flutter test test/report/presentation/widgets/category_breakdown_pie_test.dart`
Expected: `All tests passed!`(2 test)。

- [ ] **Step 5: 写 monthly_comparison_bar_test.dart**

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/widgets/monthly_comparison_bar.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

void main() {
  testWidgets('有 months:渲染 BarChart + 收入/支出图例', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MonthlyComparisonBar(months: [
          MonthlySummary(
              year: 2026, month: 2, incomeCents: 10000, expenseCents: 6000),
          MonthlySummary(
              year: 2026, month: 3, incomeCents: 11000, expenseCents: 7000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
  });

  testWidgets('空 months:空态提示,无 BarChart', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: MonthlyComparisonBar(months: const [])),
    ));
    await t.pumpAndSettle();

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('暂无月度数据'), findsOneWidget);
  });
}
```

- [ ] **Step 6: 运行,期望 PASS**

Run: `cd yucai/client && flutter test test/report/presentation/widgets/monthly_comparison_bar_test.dart`
Expected: `All tests passed!`(2 test)。

- [ ] **Step 7: Commit**

```bash
git add yucai/client/test/report/presentation/widgets/
git commit -m "test(report): 3 chart widget 单测(LineChart/PieChart/BarChart 渲染+空态+图例)"
```

---

### Task 2: ReportPage 集成测试

**Files:**
- Create: `yucai/client/test/report/presentation/pages/report_page_test.dart`

**Interfaces:**
- Consumes: `ReportPage`(无参,内部 `getIt<TransactionRepository>().summary(year, month, scope:)`);`TransactionRepository.summary(int, int, {required SummaryScope scope}) → Future<Either<Failure, MonthlySummary>>`;`Failure` 是 sealed 抽象类,用具体子类 `ServerFailure(message)`;ReportPage initState 会调 summary month scope 1 次 + `_loadMonthlyComparison` month scope 6 次(背景调用),period 切换"年"再调 year scope 1 次。
- Produces: 无(Task 2 是叶子测试)。

- [ ] **Step 1: 写 report_page_test.dart**

```dart
import 'package:dartz/dartz.dart' as dartz;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/report/presentation/pages/report_page.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockTxnRepo extends Mock implements TransactionRepository {}

/// 非空 summary(≥2 byDay 含 income/expense,触发 chart 渲染分支)。
MonthlySummary _summary({int income = 100000, int expense = 60000}) =>
    MonthlySummary(
      year: 2026,
      month: 7,
      incomeCents: income,
      expenseCents: expense,
      netCents: income - expense,
      dailyAvgCents: (income - expense) ~/ 30,
      byDay: [
        DailySummary(date: '2026-07-01', byCategory: [
          CategoryTotal(
              categoryId: 'c1',
              name: '工资',
              accountType: 'income',
              amountCents: income),
          CategoryTotal(
              categoryId: 'c2',
              name: '餐饮',
              accountType: 'expense',
              amountCents: expense),
        ]),
        DailySummary(date: '2026-07-02', byCategory: [
          CategoryTotal(
              categoryId: 'c2',
              name: '餐饮',
              accountType: 'expense',
              amountCents: 20000),
        ]),
      ],
      scope: SummaryScope.month,
    );

Widget _harness(TransactionRepository repo) {
  GetIt.instance.registerSingleton<TransactionRepository>(repo);
  return const MaterialApp(home: ReportPage());
}

/// 跨 RichText 文本查找(对齐 home_page_test 范式)。
Finder _textContaining(String needle) => find.byWidgetPredicate((w) {
      if (w is Text) {
        return (w.data ?? '').contains(needle) ||
            (w.textSpan?.toPlainText() ?? '').contains(needle);
      }
      if (w is RichText) return w.text.toPlainText().contains(needle);
      return false;
    });

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    // summary 的 scope: 命名参数用 any(),需 fallback(SummaryScope 枚举)。
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() => getIt.reset());

  testWidgets('success:渲染汇总条 + 3 section 标题 + LineChart', (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(), scope: any(named: 'scope')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    // 汇总条 4 stat label。
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('结余'), findsOneWidget);
    // 3 section 标题。
    expect(find.text('收支趋势'), findsOneWidget);
    expect(find.text('支出分类占比'), findsOneWidget);
    expect(find.text('近 6 月对比'), findsOneWidget);
    // 趋势图渲染(月度对比 chart 在独立 FutureBuilder,有数据时也渲染)。
    expect(find.byType(LineChart), findsWidgets);
  });

  testWidgets('error:summary 返 Left → 显示错误消息 + 重试', (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(), scope: any(named: 'scope')))
        .thenAnswer((_) async =>
            dartz.Left<Failure, MonthlySummary>(ServerFailure('连接失败')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    // ReportPage 显示 f.message(非空)。
    expect(find.text('连接失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('period 切换:点「年」→ summary 以 scope:year 再次调用',
      (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(), scope: any(named: 'scope')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    await t.tap(find.text('年'));
    await t.pumpAndSettle();

    // initState 只调 month scope;year scope 仅在 _switchScope → _load 后调用。
    verify(() => repo.summary(any(), any(), scope: SummaryScope.year))
        .called(greaterOrEqual(1));
  });
}
```

- [ ] **Step 2: 运行,期望 PASS**

Run: `cd yucai/client && flutter test test/report/presentation/pages/report_page_test.dart`
Expected: `All tests passed!`(3 test)。若 period 切换 test 的 verify 计数失败,改为 `called(greaterOrEqual(1))`(已用);若 `_loadMonthlyComparison` 的 month 背景调用干扰,确认 verify 只针对 `scope: SummaryScope.year`(精确 matcher 已排除 month)。

- [ ] **Step 3: Commit**

```bash
git add yucai/client/test/report/presentation/pages/report_page_test.dart
git commit -m "test(report): ReportPage 集成(success/error/period 切换 verify)"
```

---

### Task 3: Home `_harness` 改造为可注入

**Files:**
- Modify: `yucai/client/test/auth/presentation/pages/home_page_test.dart`(现有 `_harness` L141-192 + import 区)

**Interfaces:**
- Consumes: 现有 `_harness({netWorthResult, baseCurrency})` + 现有 mock 类 `_MockTxnRepo`/`_MockDebtRepo`/`_MockHoldingRepo`/`_MockAccountRepo` + `_account()` helper(L93-108)。
- Produces: 改造后 `_harness({netWorthResult, baseCurrency, accounts, txns, holdings, debts})` —— Task 4/5 依赖此签名注入非空数据。现有 3 NetWorth test **不传新参数**(默认值)保持原行为。

- [ ] **Step 1: 在 import 区补 entity 导入**

在 `home_page_test.dart` 顶部 import 区(现有 transaction/holding/debt repository import 之后)追加:

```dart
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart' as holding_vo;
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart' as debt_vo;
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';
```

> 注:`holding/domain/value_objects.dart` 与 `debt/domain/value_objects.dart` 都可能定义枚举名(如 `SecurityType`/`AmortizationMethod`),用 `as holding_vo` / `as debt_vo` 前缀避免与其它 import 冲突;Task 4 fixture 用 `holding_vo.SecurityType.stock` / `debt_vo.AmortizationMethod.equalPrincipalInterest`。

- [ ] **Step 2: 改造 `_harness` 签名 + 内部 mock 返回值**

把现有 `_harness` 函数(整体替换):

```dart
Widget _harness({
  required Future<NetWorthView> Function() netWorthResult,
  required String baseCurrency,
  List<Account>? accounts,
  List<Transaction> txns = const [],
  List<Holding> holdings = const [],
  List<Debt> debts = const [],
}) {
  final getIt = GetIt.instance;
  getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs(netWorthResult));
  getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings(baseCurrency));

  // accounts: null → 默认 1 笔储蓄(维持现有 NetWorth test 的流动资产断言)。
  final accs = accounts ?? [_account()];
  final accountRepo = _MockAccountRepo();
  when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(accs));

  final accountBloc = AccountBloc(
    ListAccountsUseCase(accountRepo),
    CreateAccountUseCase(accountRepo),
    DeleteAccountUseCase(accountRepo),
    GetAccountUseCase(accountRepo),
    UpdateAccountUseCase(accountRepo),
  );

  // 近期交易 panel。
  final txnRepo = _MockTxnRepo();
  when(() => txnRepo.list(any())).thenAnswer(
    (_) async => dartz.Right(ListTransactionsResult(transactions: txns)),
  );
  getIt.registerSingleton<TransactionRepository>(txnRepo);

  // 即将到期 panel。
  final debtRepo = _MockDebtRepo();
  when(() => debtRepo.upcomingPayments(any()))
      .thenAnswer((_) async => dartz.Right(debts));
  getIt.registerSingleton<DebtRepository>(debtRepo);

  // 资产配置 panel(HoldingBloc 内部 getIt<HoldingRepository>)。
  final holdingRepo = _MockHoldingRepo();
  when(() => holdingRepo.listHoldings())
      .thenAnswer((_) async => dartz.Right(holdings));
  getIt.registerSingleton<HoldingRepository>(holdingRepo);

  final authBloc = _SeededAuthedBloc();
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<AccountBloc>.value(value: accountBloc),
      ],
      child: const HomePage(),
    ),
  );
}
```

- [ ] **Step 3: 运行现有 3 NetWorth test,期望仍 PASS(行为不变)**

Run: `cd yucai/client && flutter test test/auth/presentation/pages/home_page_test.dart`
Expected: `All tests passed!`(3 test —— CNY/USD/error)。`accounts` 默认 `null → [_account()]`,流动资产仍 ¥12,000,断言不变。

- [ ] **Step 4: Commit**

```bash
git add yucai/client/test/auth/presentation/pages/home_page_test.dart
git commit -m "test(home): _harness 改造可注入(accounts/txns/holdings/debts),现有 3 NetWorth test 不变"
```

---

### Task 4: Home dashboard 5 panel 非空态测试

**Files:**
- Modify: `yucai/client/test/auth/presentation/pages/home_page_test.dart`(在 `main()` 内、现有 3 test 之后追加 fixture helper + 4 test)

**Interfaces:**
- Consumes: Task 3 改造后的 `_harness({... accounts, txns, holdings, debts})`;entity 构造器 `Transaction`/`Holding`/`Debt`/`Account`;枚举 `holding_vo.SecurityType`(stock/fund/etf/bond/gold/option/other)、`debt_vo.AmortizationMethod`(equalPrincipalInterest/equalPrincipal/lumpSum)、`AccountCategory`(investment/fixedDeposit/goldFx/realEstate/...)。
- Produces: 无。

- [ ] **Step 1: 在 `main()` 之前追加 fixture helper**

```dart
Transaction _txn({String desc = '咖啡消费', int debit = 2500}) => Transaction(
      id: 't1',
      transactionDate: DateTime(2026, 7, 1),
      description: desc,
      entries: [
        TransactionEntry(accountId: 'a1', debitCents: debit, creditCents: 0),
      ],
    );

Holding _holding(
        {holding_vo.SecurityType type = holding_vo.SecurityType.stock,
        int mv = 500000}) =>
    Holding(
      id: 'h1',
      accountId: 'a1',
      securityId: 's1',
      securityName: '贵州茅台',
      securitySymbol: '600519',
      quantity: 10,
      avgCostCents: 50000,
      marketValueCents: mv,
      unrealizedPnlCents: 0,
      version: 1,
      securityType: type,
    );

Debt _debt({String name = '招商银行', int amt = 300000}) => Debt(
      id: 'd1',
      accountId: 'a1',
      counterparty: name,
      interestRate: 4.5,
      amortization: debt_vo.AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2030, 1, 1),
      totalPrincipalCents: 1000000,
      remainingPrincipalCents: 900000,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      nextPaymentDate: DateTime(2026, 8, 1),
      nextPaymentAmountCents: amt,
    );

Account _catAccount(AccountCategory cat, {int balance = 800000}) => Account(
      id: 'a-${cat.name}',
      name: 'test',
      accountType: cat.accountType,
      category: cat,
      currencyCode: 'CNY',
      initialBalanceCents: balance,
      currentBalanceCents: balance,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
```

- [ ] **Step 2: 在 `main()` 内追加 4 个 panel 测试**

```dart
  testWidgets('投资/固定资产:汇总非零(非 ¥ 0.00)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      accounts: [
        _catAccount(AccountCategory.investment, balance: 1200000),
        _catAccount(AccountCategory.fixedDeposit, balance: 500000),
      ],
    ));
    await t.pumpAndSettle();

    expect(find.text('投资资产'), findsOneWidget);
    expect(find.text('固定资产'), findsOneWidget);
    // 投资 1200000 cents = ¥12,000.00;固定 500000 = ¥5,000.00(grouped 整数部分)。
    expect(_textContaining('12,000'), findsWidgets);
    expect(_textContaining('5,000'), findsWidgets);
  });

  testWidgets('近期交易非空:显示交易描述(非「暂无交易记录」)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      txns: [_txn(desc: '星巴克拿铁')],
    ));
    await t.pumpAndSettle();

    expect(find.text('星巴克拿铁'), findsOneWidget);
    expect(find.text('暂无交易记录'), findsNothing);
  });

  testWidgets('资产配置非空:渲染 HoldingPieChart(非「暂无持仓数据」)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      holdings: [_holding()],
    ));
    await t.pumpAndSettle();

    expect(find.byType(HoldingPieChart), findsOneWidget);
    expect(find.text('暂无持仓数据'), findsNothing);
  });

  testWidgets('即将到期非空:显示债权方(非「暂无待办账单」)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      debts: [_debt(name: '招商银行房贷')],
    ));
    await t.pumpAndSettle();

    expect(find.text('招商银行房贷'), findsOneWidget);
    expect(find.text('暂无待办账单'), findsNothing);
  });
```

- [ ] **Step 3: 运行,期望 PASS(共 7 test:3 NetWorth + 4 panel)**

Run: `cd yucai/client && flutter test test/auth/presentation/pages/home_page_test.dart`
Expected: `All tests passed!`(7 test)。若 `pumpAndSettle` 卡住(HoldingBloc 加载/多 FutureBuilder interleave),对该 test 改 `await t.pump(const Duration(milliseconds: 500))` 替代 `pumpAndSettle`(对齐 CLAUDE.md「永不完成的 Future 用 pump」)。

- [ ] **Step 4: Commit**

```bash
git add yucai/client/test/auth/presentation/pages/home_page_test.dart
git commit -m "test(home): dashboard 5 panel 非空态(投资/固定资产值+近期交易/资产配置/即将到期)"
```

---

### Task 5: 快捷操作 onTap(router harness)

**Files:**
- Modify: `yucai/client/test/auth/presentation/pages/home_page_test.dart`(追加 `_routerHarness` + 1 test)

**Interfaces:**
- Consumes: 现有 mock 类 + `_FakeNetWorthDs`/`_FakeCurrencySettings`/`_SeededAuthedBloc`;`HomePage` 4 快捷操作 tile 文本「记一笔」/「转账」/「买入投资」/「生成报表」→ onTap `context.go('/transactions/new'|'/holdings/new'|'/reports')`。
- Produces: 无。

> **降级条件** —— 若 `MaterialApp.router + GoRouter + MultiBlocProvider` 与 HomePage 的 `getIt`/`context.read<AccountBloc>` 注入冲突导致 pump 卡死或抛,执行本 task 末尾的「降级方案」(仅断言 4 tile 文本存在,不 tap)。

- [ ] **Step 1: 追加 import(go_router + navigator observer 基类)**

在 import 区追加:

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 2: 在 `main()` 之前追加 `_MockNavigatorObserver` + `_routerHarness`**

```dart
class _MockNavigatorObserver extends Mock implements NavigatorObserver {}

/// 快捷操作 onTap 需 router(context.go)。独立 harness(MaterialApp.router +
/// GoRouter + MockNavigatorObserver),不复用 _harness(隔离,避免与 NetWorth
/// harness 的 MaterialApp 冲突)。mock 注册对齐 _harness(空数据)。
Widget _routerHarness(_MockNavigatorObserver observer) {
  final getIt = GetIt.instance;
  getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs(() async => _view()));
  getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings('CNY'));

  final accountRepo = _MockAccountRepo();
  when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(<Account>[]));
  final accountBloc = AccountBloc(
    ListAccountsUseCase(accountRepo),
    CreateAccountUseCase(accountRepo),
    DeleteAccountUseCase(accountRepo),
    GetAccountUseCase(accountRepo),
    UpdateAccountUseCase(accountRepo),
  );

  final txnRepo = _MockTxnRepo();
  when(() => txnRepo.list(any())).thenAnswer(
    (_) async => dartz.Right(const ListTransactionsResult(transactions: [])),
  );
  getIt.registerSingleton<TransactionRepository>(txnRepo);

  final debtRepo = _MockDebtRepo();
  when(() => debtRepo.upcomingPayments(any()))
      .thenAnswer((_) async => dartz.Right(<Debt>[]));
  getIt.registerSingleton<DebtRepository>(debtRepo);

  final holdingRepo = _MockHoldingRepo();
  when(() => holdingRepo.listHoldings())
      .thenAnswer((_) async => dartz.Right(<Holding>[]));
  getIt.registerSingleton<HoldingRepository>(holdingRepo);

  final router = GoRouter(
    initialLocation: '/home',
    observers: [observer],
    routes: [
      GoRoute(
          path: '/home',
          builder: (_, __) => const HomePage()),
      GoRoute(
          path: '/transactions/new',
          builder: (_, __) => const Scaffold(body: Center(child: Text('txn_new')))),
      GoRoute(
          path: '/holdings/new',
          builder: (_, __) => const Scaffold(body: Center(child: Text('holdings_new')))),
      GoRoute(
          path: '/reports',
          builder: (_, __) => const Scaffold(body: Center(child: Text('reports_page')))),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    builder: (context, child) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _SeededAuthedBloc()),
        BlocProvider<AccountBloc>.value(value: accountBloc),
      ],
      child: child!,
    ),
  );
}
```

- [ ] **Step 3: 在 `main()` 内追加快捷操作 test**

```dart
  testWidgets('快捷操作:点「生成报表」→ 导航 /reports', (t) async {
    final observer = _MockNavigatorObserver();
    await t.pumpWidget(_routerHarness(observer));
    await t.pumpAndSettle();

    await t.tap(find.text('生成报表'));
    await t.pumpAndSettle();

    // /reports builder 渲染 'reports_page'。
    expect(find.text('reports_page'), findsOneWidget);
  });
```

- [ ] **Step 4: 运行,期望 PASS**

Run: `cd yucai/client && flutter test test/auth/presentation/pages/home_page_test.dart`
Expected: `All tests passed!`(8 test:7 + 快捷操作)。若 FAIL(见降级),执行 Step 5。

- [ ] **Step 5(仅降级时):改用仅断言 tile 存在**

若 Step 4 因 router 与 BlocProvider/getIt 注入冲突失败或卡死,删除 Step 2/3 的 `_routerHarness` + 快捷操作 test,改为只追加一个轻量 test(用现有 `_harness`,不 tap,仅 verify 4 tile 渲染):

```dart
  testWidgets('快捷操作:4 tile 渲染(记一笔/转账/买入投资/生成报表)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('转账'), findsOneWidget);
    expect(find.text('买入投资'), findsOneWidget);
    expect(find.text('生成报表'), findsOneWidget);
  });
```

> 降级放弃 `onTap verify 路由路径`,但保留 tile 渲染断言(spec §6「快捷操作」的最小覆盖)。在 commit message 注明「降级:onTap verify 因 router harness 冲突 defer」。

- [ ] **Step 6: Commit**

```bash
git add yucai/client/test/auth/presentation/pages/home_page_test.dart
git commit -m "test(home): 快捷操作 onTap(生成报表→/reports,router harness+NavigatorObserver)"
```
(降级则:`"test(home): 快捷操作 4 tile 渲染(降级:onTap verify defer)"`)

---

## 全量回归(最后)

- [ ] **Run: `cd yucai/client && flutter test`**
Expected: 除预存 1 fail(`account_detail_page_test` + `receivable_detail_page_test` 漂移,out-of-scope)外全绿;**新增 14 test 全 PASS**(Report chart 单测 6 + ReportPage 集成 3 + Home panel 4 + 快捷操作 1);Home 现有 3 NetWorth test 不变。

- [ ] **Run: `cd yucai/client && flutter analyze`**
Expected: 22 error 基线全 `*.pbserver.dart`(不变),无新 error。
