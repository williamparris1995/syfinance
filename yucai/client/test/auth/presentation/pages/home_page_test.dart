// Task 11 (holding-D) — widget tests for HomePage _NetWorthCard.
//
// HomePage reads NetWorthDataSource + CurrencySettings from getIt (both
// @LazySingleton in production), so we register fakes before pumping.
// AccountBloc is provided via BlocProvider with a mock AccountRepository
// (empty account list — net worth no longer folds account balances; it comes
// from the DS).
//
// Coverage:
// - success (CNY base): renders 折算后 net worth (¥ + grouped) + 总资产/总负债
// - success (USD base): symbol switches to $ (非硬编码 ¥)
// - error: shows 加载失败 (graceful, not crash)
//
// _NetWorthCard is private; we drive it via the public HomePage.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/widgets/debt_detail_widgets.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/holding/domain/value_objects.dart' as holding_vo;
import 'package:yucai_client/debt/domain/value_objects.dart' as debt_vo;
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';

class _MockLogin extends Mock implements LoginUseCase {}
class _MockRegister extends Mock implements RegisterUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}

/// Fake NetWorthDataSource — overrides getNetWorth to return a fixed view or
/// throw. (Fake, not Mock: getNetWorth is a real method we want to stub via an
/// injected callback.)
class _FakeNetWorthDs extends Fake implements NetWorthDataSource {
  _FakeNetWorthDs(this._result);
  final Future<NetWorthView> Function() _result;

  @override
  Future<NetWorthView> getNetWorth({required String baseCurrency}) =>
      _result();
}

/// Fake CurrencySettings — returns a fixed base currency code.
class _FakeCurrencySettings extends Fake implements CurrencySettings {
  _FakeCurrencySettings(this._base) : _notifier = ValueNotifier<String>(_base);
  final String _base;
  final ValueNotifier<String> _notifier;

  @override
  ValueListenable<String> get listenable => _notifier;

  @override
  String get value => _base;

  @override
  Future<String> getBaseCurrency() async => _base;
}

class _MockAccountRepo extends Mock implements AccountRepository {}

/// HomePage 仪表盘现在(占位修复)直接经 getIt 拉 TransactionRepository /
/// DebtRepository(lazySingleton)+ 构造 HoldingBloc(getIt<HoldingRepository>)。
/// 这些 mock 返回空结果,让 3 个面板渲染空态而不崩。
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}

/// 3 摘要卡(P0-1)新增:BudgetRepository + GoalRepository mock。默认 stub 在
/// _harness / _routerHarness 中,返回 Left / 空列表(隐藏对应卡)。
class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockGoalRepo extends Mock implements GoalRepository {}

/// 构造一笔账户(默认储蓄/1200000 cents)驱动 _SummaryRow 流动资产拆分。
Account _account({
  int balance = 1200000,
  AccountCategory category = AccountCategory.savings,
}) {
  return Account(
    id: 'a-${category.name}',
    name: 'test',
    accountType: category.accountType,
    category: category,
    currencyCode: 'CNY',
    initialBalanceCents: balance,
    currentBalanceCents: balance,
    ownership: Ownership.personal,
    status: AccountStatus.active,
  );
}

/// AuthBloc seeded Authenticated (HomePage watches state for display name).
class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockLogin(), _MockRegister(), _MockProfile(), _MockLogout()) {
    emit(Authenticated(_user));
  }
}

final _user = User(
  id: 'u1',
  tenantId: 't1',
  email: 't@example.com',
  displayName: '测试用户',
  avatarUrl: '',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

NetWorthView _view({
  int assets = 1200000, // ¥12,000.00
  int liabilities = 300000, // ¥3,000.00
  String currency = 'CNY',
}) {
  final net = assets - liabilities;
  return NetWorthView(
    totalAssetsCents: assets,
    totalLiabilitiesCents: liabilities,
    netWorthCents: net,
    currency: currency,
  );
}

Widget _harness({
  required Future<NetWorthView> Function() netWorthResult,
  required String baseCurrency,
  List<Account>? accounts,
  List<Transaction> txns = const [],
  List<Holding> holdings = const [],
  List<Debt> debts = const [],
  MonthlySummary? summary,
  bool summaryFail = false,
  BudgetView? budget,
  List<GoalView> goals = const [],
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
  // 3 摘要卡 summary:summaryFail=true → Left(对齐生产 RPC 错误)→ home_page
  // fold 到 null → 隐藏收支卡(I3);否则 Right(summary ?? 零值)→ 渲染(¥0 也显)。
  when(() => txnRepo.summary(any(), any(),
          accountId: any(named: 'accountId'),
          scope: any(named: 'scope'),
          day: any(named: 'day')))
      .thenAnswer((_) async => summaryFail
          ? const dartz.Left(ServerFailure('rpc unavailable'))
          : dartz.Right(
              summary ?? const MonthlySummary(year: 2026, month: 7),
            ));
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

  // 3 摘要卡预算:budget==null(默认)→ Left(对齐生产 server 当月无 budget 的
  // 404 NotFound 语义)→ home_page fold 到 null → 隐藏卡;budget 提供 → Right。
  final budgetRepo = _MockBudgetRepo();
  when(() => budgetRepo.getBudgetByMonth(any())).thenAnswer((_) async =>
      budget == null
          ? dartz.Left(const ServerFailure('not found'))
          : dartz.Right(budget));
  getIt.registerSingleton<BudgetRepository>(budgetRepo);

  // 3 摘要卡目标:goals(默认空)→ 隐藏卡。
  final goalRepo = _MockGoalRepo();
  when(() => goalRepo.listGoals(
          type: any(named: 'type'), completed: any(named: 'completed')))
      .thenAnswer((_) async => dartz.Right(goals));
  getIt.registerSingleton<GoalRepository>(goalRepo);

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

/// Finds a widget whose rendered text (plain Text or RichText.toPlainText)
/// contains [needle]. find.textContaining does not reliably traverse nested
/// TextSpans in this flutter_test version, so we check RichText explicitly.
Finder _textContaining(String needle) => find.byWidgetPredicate(
      (w) {
        if (w is Text) {
          return (w.data ?? '').contains(needle) ||
              (w.textSpan?.toPlainText() ?? '').contains(needle);
        }
        if (w is RichText) {
          return w.text.toPlainText().contains(needle);
        }
        return false;
      },
    );

// ───────────────────── Task 4: 5 panel 非空态 fixture helpers ─────────────────────

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

// ───────────────────── P0-1: 3 摘要卡 fixture helpers ─────────────────────

/// 月度收支 summary fixture(单位:分)。income 850000 = ¥8,500.00;expense
/// 520000 = ¥5,200.00;net 自动 = income − expense。
MonthlySummary _summary({
  int income = 850000,
  int expense = 520000,
  int year = 2026,
  int month = 7,
}) =>
    MonthlySummary(
      year: year,
      month: month,
      incomeCents: income,
      expenseCents: expense,
      netCents: income - expense,
    );

/// 预算 fixture(单位:分)。actual 520000=¥5,200 / planned 800000=¥8,000 →
/// usagePct = 65%。month 必须为当前月以触发 budget card 的 footer "还剩 N 天"
/// 文案(对齐 _BudgetCard._monthDaysLeft 逻辑)。
BudgetView _budget({
  int actual = 520000,
  int planned = 800000,
  String month = '2026-07',
  String name = '7 月日常预算',
}) =>
    BudgetView(
      id: 'b1',
      name: name,
      month: month,
      currencyCode: 'CNY',
      totalAmountCents: planned,
      totalActualCents: actual,
      // usagePct 在 entity 上是派生 getter,但构造器入参显式传入。构造器默认 0,
      // 故显式计算一遍与 entity getter 一致。
      usagePct: planned == 0 ? 0 : actual / planned * 100,
    );

/// 目标 fixture。current 420000=¥4,200 / target 1000000=¥10,000 → progressPct
/// = 42%。deadline 设为 2027-03-15 触发 "预计 2027 年 3 月达成" 文案。
GoalView _goal({
  String name = '存款目标',
  int current = 420000,
  int target = 1000000,
  DateTime? deadline,
}) =>
    GoalView(
      id: 'g1',
      name: name,
      type: GoalType.savings,
      targetAmountCents: target,
      currentAmountCents: current,
      currencyCode: 'CNY',
      deadline: deadline ?? DateTime(2027, 3, 15),
    );

/// 快捷操作 onTap 需 router(context.go)。独立 harness(MaterialApp.router +
/// GoRouter),不复用 _harness(隔离,避免与 NetWorth harness 的 MaterialApp
/// 冲突)。mock 注册对齐 _harness(空数据)。导航验证靠 find.text(目标路由
/// builder 渲染),无需 NavigatorObserver。
Widget _routerHarness() {
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
  // 3 摘要卡 income/expense summary 默认零值(_routerHarness 不驱动摘要卡
  // 断言,仅需 stub 避免 null Future 崩溃)。
  when(() => txnRepo.summary(any(), any(),
          accountId: any(named: 'accountId'),
          scope: any(named: 'scope'),
          day: any(named: 'day')))
      .thenAnswer((_) async =>
          const dartz.Right(MonthlySummary(year: 2026, month: 7)));
  getIt.registerSingleton<TransactionRepository>(txnRepo);

  final debtRepo = _MockDebtRepo();
  when(() => debtRepo.upcomingPayments(any()))
      .thenAnswer((_) async => dartz.Right(<Debt>[]));
  getIt.registerSingleton<DebtRepository>(debtRepo);

  final holdingRepo = _MockHoldingRepo();
  when(() => holdingRepo.listHoldings())
      .thenAnswer((_) async => dartz.Right(<Holding>[]));
  getIt.registerSingleton<HoldingRepository>(holdingRepo);

  // 3 摘要卡 budget/goals 默认 Left/空 → 隐藏卡(_routerHarness 不驱动断言)。
  final budgetRepo = _MockBudgetRepo();
  when(() => budgetRepo.getBudgetByMonth(any()))
      .thenAnswer((_) async => const dartz.Left(ServerFailure('not found')));
  getIt.registerSingleton<BudgetRepository>(budgetRepo);

  final goalRepo = _MockGoalRepo();
  when(() => goalRepo.listGoals(
          type: any(named: 'type'), completed: any(named: 'completed')))
      .thenAnswer((_) async => const dartz.Right(<GoalView>[]));
  getIt.registerSingleton<GoalRepository>(goalRepo);

  final router = GoRouter(
    initialLocation: '/home',
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

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    // mocktail any() 需要非原始类型的 fallback 值。
    registerFallbackValue(const ListTransactionsParams());
    // 3 摘要卡 summary stub 的 scope 命名参数也需要 fallback。
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() {
    getIt.reset();
  });

  tearDown(() {
    if (getIt.isRegistered<NetWorthDataSource>()) {
      getIt.unregister<NetWorthDataSource>();
    }
    if (getIt.isRegistered<CurrencySettings>()) {
      getIt.unregister<CurrencySettings>();
    }
  });

  testWidgets(
      'success (CNY base): renders 折算后 net worth ¥9,000.00 + 总资产/总负债',
      (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    // net worth = assets(1200000) − liab(300000) = 900000 cents = ¥9,000.00
    // grouped → '9,000' (整数部分),fen '.00'。
    expect(_textContaining('9,000'), findsWidgets);
    // base 符号 ¥(非硬编码 — 来自 NetWorthView.currency=CNY → currencySymbol)。
    expect(_textContaining('¥'), findsWidgets);
    // 资产分解 4 卡:流动资产 / 总负债 label + 折算后金额。
    expect(find.text('流动资产'), findsOneWidget);
    expect(find.text('总负债'), findsOneWidget);
    // 流动资产 = ¥12,000.00(1200000 cents)。
    expect(_textContaining('12,000'), findsWidgets);
  });

  testWidgets('success (USD base): symbol switches to \$ (非硬编码 ¥)',
      (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(currency: 'USD'),
      baseCurrency: 'USD',
    ));
    await t.pumpAndSettle();

    // currency=USD → currencySymbol(USD) = '$'(非 ¥)。
    expect(_textContaining(r'$'), findsWidgets);
    // 不应出现裸 ¥(硬编码检查)。
    expect(find.text('¥'), findsNothing);
  });

  testWidgets('error: shows 加载失败 (graceful, no crash)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => throw Exception('rpc unavailable'),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    // FutureBuilder error → _NetWorthCard error=true → '加载失败'。
    expect(_textContaining('加载失败'), findsWidgets);
  });

  // ───────────────────── Task 4: 5 panel 非空态测试 ─────────────────────

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

  // ───────────────────── Task 5: 快捷操作 onTap(router harness) ─────────────────────

  testWidgets('快捷操作:点「生成报表」→ 导航 /reports', (t) async {
    await t.pumpWidget(_routerHarness());
    await t.pumpAndSettle();

    // 默认 800x600 surface 下快捷操作 tile 在视口外,先滚入再 tap。
    await t.ensureVisible(find.text('生成报表'));
    await t.tap(find.text('生成报表'));
    await t.pumpAndSettle();

    // /reports builder 渲染 'reports_page'。
    expect(find.text('reports_page'), findsOneWidget);
  });

  // 快捷操作其余 3 tile(记一笔/转账→/transactions/new,买入投资→/holdings/new)
  // 补测 — Task 5 仅测 /reports;转账与记一笔同路由,测记一笔即可代表。

  testWidgets('快捷操作:点「记一笔」→ 导航 /transactions/new', (t) async {
    await t.pumpWidget(_routerHarness());
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('记一笔'));
    await t.tap(find.text('记一笔'));
    await t.pumpAndSettle();

    expect(find.text('txn_new'), findsOneWidget);
  });

  testWidgets('快捷操作:点「买入投资」→ 导航 /holdings/new', (t) async {
    await t.pumpWidget(_routerHarness());
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('买入投资'));
    await t.tap(find.text('买入投资'));
    await t.pumpAndSettle();

    expect(find.text('holdings_new'), findsOneWidget);
  });

  // ───────────────────── P0-1: 3 摘要卡(income/expense · budget · goal) ─────────────────────

  testWidgets('收支卡:summary 非零 → 显示 收入/支出/结余(¥8,500 / ¥5,200 / ¥3,300)',
      (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      summary: _summary(),
    ));
    await t.pumpAndSettle();

    expect(find.text('本月收支'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('本月结余'), findsOneWidget);
    // 8,500 / 5,200 / 3,300 grouped 整数部分。RichText/Text 混合,_textContaining
    // 兼容两者。
    expect(_textContaining('8,500'), findsWidgets);
    expect(_textContaining('5,200'), findsWidgets);
    expect(_textContaining('3,300'), findsWidgets);
    // 默认无 budget / 无 goals → 预算/目标卡应隐藏。
    expect(find.text('本月预算'), findsNothing);
    expect(find.text('目标进度'), findsNothing);
  });

  testWidgets('收支卡:summary 零值(Right)→ 仍渲染卡(¥0.00,本月无收支是有意义状态)',
      (t) async {
    // 不传 summary:_harness 默认 Right(MonthlySummary(year:2026, month:7)) 零值。
    // I3:Right(含零值)→ 显示卡;只有 Left(RPC fail)才隐藏(见下个测试)。
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    expect(find.text('本月收支'), findsOneWidget);
    // 零 summary → 收入/支出/结余 全 ¥0.00;不崩。
    expect(_textContaining('0.00'), findsWidgets);
  });

  testWidgets('收支卡:summary RPC fail(Left)→ 隐藏卡(I3:fail 不伪装成 ¥0)',
      (t) async {
    // summaryFail=true → txnRepo.summary 返 Left → home_page fold 到 null → 隐藏。
    // 关键:RPC 错误不得 fold 成 ¥0 误导用户以为本月无收支。
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      summaryFail: true,
    ));
    await t.pumpAndSettle();

    expect(find.text('本月收支'), findsNothing);
  });

  testWidgets('预算卡:budget 提供 → 显示 已用%/¥actual/planned/剩余', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      budget: _budget(),
    ));
    await t.pumpAndSettle();

    expect(find.text('本月预算'), findsOneWidget);
    // 65% = 520000/800000*100 round。
    expect(find.text('已用 65%'), findsOneWidget);
    // 5,200 / 8,000 grouped(实际显示为 prog-amt:¥5,200 / ¥8,000)。
    expect(_textContaining('5,200'), findsWidgets);
    expect(_textContaining('8,000'), findsWidgets);
    // 剩余 = 800000 − 520000 = 280000 = ¥2,800。
    expect(_textContaining('2,800'), findsWidgets);
  });

  testWidgets('预算卡:默认(无 budget)→ 隐藏(无「本月预算」label)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    expect(find.text('本月预算'), findsNothing);
  });

  testWidgets('目标卡:goals 提供 → 显示 顶级目标名/¥current/target/pct', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      goals: [_goal(name: '买房首付')],
    ));
    await t.pumpAndSettle();

    expect(find.text('目标进度'), findsOneWidget);
    expect(find.text('买房首付'), findsOneWidget);
    // 42% = 420000/1000000*100 round。
    expect(_textContaining('42%'), findsWidgets);
    // 4,200 / 10,000 grouped + 5,800 差额。
    expect(_textContaining('4,200'), findsWidgets);
    expect(_textContaining('10,000'), findsWidgets);
    expect(_textContaining('5,800'), findsWidgets);
    // deadline 2027-03-15 → "预计 2027 年 3 月达成"。
    expect(_textContaining('2027'), findsWidgets);
  });

  testWidgets('目标卡:默认(空 goals)→ 隐藏(无「目标进度」label)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    expect(find.text('目标进度'), findsNothing);
  });

  // ───────────────────── I4: 超支 / 完成态(补回归测试,行为已实现) ─────────────────────

  testWidgets('预算卡:超支(actual>planned)→ footLeft 显「超支」(I4)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      budget: _budget(actual: 900000, planned: 800000), // 112.5% 超支
    ));
    await t.pumpAndSettle();

    expect(find.text('本月预算'), findsOneWidget);
    // isOverBudget(900000>800000)→ bar 红 + footLeft '超支 ¥1,000'(remaining
    // = totalAmount-totalActual = 800000-900000 = -100000,abs=100000=¥1,000.00)。
    expect(_textContaining('超支'), findsWidgets);
    expect(_textContaining('¥1,000'), findsWidgets);
  });

  testWidgets('目标卡:已完成(current>=target)→ footLeft 显「目标已达成」(I4)',
      (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      goals: [_goal(current: 1000000, target: 1000000)], // 100% 完成
    ));
    await t.pumpAndSettle();

    expect(find.text('目标进度'), findsOneWidget);
    // remainingCents = target - current = 0 → footLeft '目标已达成'(else 分支)。
    expect(find.text('目标已达成'), findsOneWidget);
  });

  testWidgets('降级:budget/goals 空 + summary Right 零值 → 仅收支卡显 ¥0,无 crash',
      (t) async {
    // summary Right(零值)→ 收支卡显 ¥0;budget=null → 隐藏;goals=[] → 隐藏。
    // (summary Left fail 的降级见专测;此测覆盖 Right 零值 + 其余空的组合)
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
    ));
    await t.pumpAndSettle();

    expect(find.text('本月收支'), findsOneWidget);
    expect(find.text('本月预算'), findsNothing);
    expect(find.text('目标进度'), findsNothing);
    // 净资产主卡仍在(降级不影响其它卡)。
    expect(find.text('总净资产'), findsOneWidget);
  });

  testWidgets('收支卡:金额对齐 OD —— 货币符号紧贴数字无空格(I1)', (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      summary: _summary(),
    ));
    await t.pumpAndSettle();

    // OD styles.css .cur 靠 margin 留白(非空格字符);_formatCents 旧实现在 ¥ 后
    // 多一个空格字符 → 修。income 850000 cents → '+¥8,500.00'(符号紧贴整数)。
    // (Text 会内嵌一个 RichText 渲染节点,_textContaining 双重匹配 → findsWidgets。)
    expect(_textContaining('+¥8,500'), findsWidgets);
    expect(_textContaining('-¥5,200'), findsWidgets);
    // 结余同款无空格。
    expect(_textContaining('¥3,300'), findsWidgets);
  });

  testWidgets('收支卡:income/expense 间 dashed 虚线分隔(OD .ie-row border-bottom,I2)',
      (t) async {
    await t.pumpWidget(_harness(
      netWorthResult: () async => _view(),
      baseCurrency: 'CNY',
      summary: _summary(),
    ));
    await t.pumpAndSettle();

    // OD .ie-row border-bottom: 1px dashed;income/expense 两行间一条虚线分隔。
    // 复用 core/widgets DebtDashedDivider(水平虚线 CustomPaint)。
    expect(find.byType(DebtDashedDivider), findsOneWidget);
  });
}
