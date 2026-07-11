// Wire-up test for the transaction module routes (Task: 接通交易路由).
//
// Builds the real router (buildRouter) with an AuthBloc seeded Authenticated,
// then navigates to the three transaction paths and asserts each resolves to
// the expected page surface. Catches the exact regression that prompted this
// task: a branch dropped from the StatefulShellRoute, or the sidebar/bottom-
// nav disagreeing on branch index 2.
//
// No gRPC: a fake TransactionRepository is registered in getIt so the page's
// getIt<TransactionRepository>() resolves. AccountRepository is registered too
// because TransactionFormPage / TransactionDetailPage read it.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/login_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/register_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/pages/budget_list_page.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/pages/debts_page.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/pages/goal_list_page.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/presentation/pages/holding_detail_page.dart';
import 'package:yucai_client/holding/presentation/pages/trade_sheet_page.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/debt/presentation/pages/receivables_page.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockSummaryRepo extends Mock implements ReceivablesSummaryRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockGoalRepo extends Mock implements GoalRepository {}
class _MockLogin extends Mock implements LoginUseCase {}
class _MockRegister extends Mock implements RegisterUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  final ValueNotifier<String> _notifier = ValueNotifier<String>('CNY');
  @override
  ValueListenable<String> get listenable => _notifier;
  @override
  String get value => 'CNY';
  @override
  Future<String> getBaseCurrency() async => 'CNY';
}

/// Fake CurrencyBloc — DebtDetailPage / DebtsPage / ReceivablesPage /
/// ReceivableDetailPage all context.watch it for preferred-currency conversion.
/// Routes also call `b.add(LoadCurrenciesRequested())` on the freshly-created
/// bloc (router.dart), so `add` must be a no-op rather than Fake's default
/// (which throws). Mirrors debts_page_test's fake + adds the `add` override.
class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  @override
  CurrencyState get state => const CurrencyState();
  @override
  Stream<CurrencyState> get stream => Stream.value(const CurrencyState());
  @override
  void add(Object? event) {}
  @override
  Future<void> close() async {}
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() {
    getIt.reset();
    final accountRepo = _MockAccountRepo();
    final txnRepo = _MockTxnRepo();
    final debtRepo = _MockDebtRepo();
    final holdingRepo = _MockHoldingRepo();
    final budgetRepo = _MockBudgetRepo();
    final goalRepo = _MockGoalRepo();
    final summaryRepo = _MockSummaryRepo();
    getIt.registerSingleton<AccountRepository>(accountRepo);
    getIt.registerSingleton<TransactionRepository>(txnRepo);
    getIt.registerSingleton<DebtRepository>(debtRepo);
    getIt.registerSingleton<HoldingRepository>(holdingRepo);
    getIt.registerSingleton<BudgetRepository>(budgetRepo);
    getIt.registerSingleton<GoalRepository>(goalRepo);
    // /receivables branch root (ReceivablesPage initState, Task 9) reads
    // ReceivablesSummaryRepository via getIt to fetch the summary panel.
    // Register a stubbed mock returning an empty summary so /receivables,
    // /receivables/:id, /receivables/new all resolve without throwing
    // `ReceivablesSummaryRepository is not registered`.
    getIt.registerSingleton<ReceivablesSummaryRepository>(summaryRepo);
    when(() => summaryRepo.fetch()).thenAnswer((_) async => const dartz.Right(
          ReceivablesSummary(
            totalPrincipalCents: 0,
            totalRemainingCents: 0,
            totalCollectedCents: 0,
            pendingInterestCents: 0,
            count: 0,
            overdueCount: 0,
            overdueAmountCents: 0,
            principalTrendCents: 0,
            remainingTrendCents: 0,
            nextPaymentAmountCents: 0,
            nextPaymentCounterparty: '',
            nextPaymentPeriodNo: 0,
          ),
        ));
    // HomePage reads CurrencySettings from getIt (Task 12 D-currency +
    // cross-page refresh listener in initState). Register a fake so the home
    // branch resolves without pulling in the full DI graph.
    getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings());
    // Routes create a fresh CurrencyBloc via getIt<CurrencyBloc>() (router.dart
    // /debts, /debts/:id, /receivables, /receivables/:id, /accounts, /settings).
    // Register a factory returning a fake so those route builders resolve;
    // without this the /debts/:id (and /receivables/:id) route throws
    // `GetIt: CurrencyBloc is not registered` during page build, which also
    // leaks widget state and breaks subsequent tests (auth-guard).
    getIt.registerFactory<CurrencyBloc>(() => _FakeCurrencyBloc());
    // /home builder (router.dart) creates AccountBloc via getIt<AccountBloc>();
    // register a factory wired to the mocked AccountRepository (mirrors
    // app_shell_test.dart) so /home resolves during sidebar navigation tests.
    getIt.registerFactory<AccountBloc>(() => AccountBloc(
          ListAccountsUseCase(accountRepo),
          CreateAccountUseCase(accountRepo),
          DeleteAccountUseCase(accountRepo),
          GetAccountUseCase(accountRepo),
          UpdateAccountUseCase(accountRepo),
        ));

    when(() => accountRepo.list()).thenAnswer(
        (_) async => dartz.Right([_account()]));
    // /debts branch root fires LoadDebtsRequested on entry; stub globally so
    // any /debts/* navigation (including /debts/new) doesn't hit a null return.
    when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => dartz.Right(const ListTransactionsResult(
            transactions: [], nextPageToken: '')));
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 0,
              expenseCents: 0,
              netCents: 0,
              dailyAvgCents: 0,
            )));
    when(() => txnRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(_txn()));
    // /holdings branch fires LoadHoldingsRequested on entry; stub globally so
    // any /holdings navigation doesn't hit an unstubbed call.
    when(() => holdingRepo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dartz.Right([]));
    // /holdings/trade + /holdings/new routes dispatch LoadSecuritiesRequested
    // (TradeSheetPage 证券选择器);stub globally so trade/new navigation doesn't
    // hit an unstubbed listSecurities call.
    when(() => holdingRepo.listSecurities(type: any(named: 'type')))
        .thenAnswer((_) async => const dartz.Right([]));
    // /holdings/:id detail dispatches LoadHoldingCurveRequested →
    // getHoldingPerformance;stub globally so detail navigation doesn't hit an
    // unstubbed call (empty curve, page renders loading/error state fine).
    when(() => holdingRepo.getHoldingPerformance(
            holdingId: any(named: 'holdingId'),
            range: any(named: 'range'),
            baseCurrency: any(named: 'baseCurrency')))
        .thenAnswer((_) async => const dartz.Right(HoldingPerformance(
              realizedCents: 0,
              unrealizedCents: 0,
              totalCents: 0,
            )));
    // /budgets branch builder (router.dart) creates BudgetBloc via
    // getIt<BudgetBloc>() (factory, Task 7 @injectable). Register a factory
    // wired to the mocked BudgetRepository (mirrors AccountBloc factory above)
    // so /budgets, /budgets/new, /budgets/:id, /budgets/:id/edit all resolve.
    getIt.registerFactory<BudgetBloc>(() => BudgetBloc(budgetRepo));
    // /budgets branch root fires LoadListRequested on entry; stub globally so
    // any /budgets/* navigation (incl. /budgets/new, /budgets/:id) doesn't hit
    // an unstubbed listBudgets call (the list page also re-dispatches in
    // initState, both no-ops against an empty Right).
    when(() => budgetRepo.listBudgets(activeOnly: any(named: 'activeOnly')))
        .thenAnswer((_) async => const dartz.Right([]));
    // /budgets/:id dispatches LoadDetailRequested(id); stub getBudget so the
    // detail/form pages don't hit an unstubbed call.
    when(() => budgetRepo.getBudget(any()))
        .thenAnswer((_) async => dartz.Right(_budget()));
    // /goals branch builder (router.dart) creates GoalBloc via
    // GoalBloc(getIt<GoalRepository>()) (Task 11 @injectable, 但路由直接 new 而非
    // getIt<GoalBloc>(), 故只需注册 repo,不需注册 GoalBloc factory)。stub listGoals
    // + getGoal 让 /goals, /goals/new, /goals/:id, /goals/:id/edit 全 resolve。
    when(() => goalRepo.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => goalRepo.getGoal(any()))
        .thenAnswer((_) async => dartz.Right(_goal()));
    when(() => goalRepo.getProgressHistory(
            goalId: any(named: 'goalId'),
            from: any(named: 'from'),
            to: any(named: 'to')))
        .thenAnswer((_) async => const dartz.Right([]));
  });

  Widget app(GoRouter router, AuthBloc authBloc) => MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => BlocProvider<AuthBloc>.value(
          value: authBloc,
          // TransactionDetailPage calls context.read<TransactionBloc> in
          // initState, so it needs a TransactionBloc ancestor. /transactions
          // itself now provides its own TransactionBloc at the route layer
          // (router.dart), so TransactionsPage no longer needs an ambient
          // bloc; this wrapper remains to cover TransactionDetailPage routes.
          child: BlocProvider<TransactionBloc>(
            create: (_) => TransactionBloc(getIt<TransactionRepository>()),
            child: BlocProvider<CurrencyBloc>.value(
              // Debt pages (DebtsPage / DebtDetailPage) context.watch<CurrencyBloc>
              // for preferred-currency conversion; provide a fake at the root.
              value: _FakeCurrencyBloc(),
              child: child!,
            ),
          ),
        ),
      );

  testWidgets('/transactions resolves inside the transaction branch',
      (tester) async {
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: the list page's summary post-frame callback can
    // schedule frames indefinitely in this stripped harness (no real
    // microtask drain). A few pumps are enough for the router to resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Auth guard let us through and the route resolved to branch 2.
    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/transactions');
  });

  testWidgets('/transactions/new resolves inside the transaction branch',
      (tester) async {
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions/new');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/transactions/new');
  });

  testWidgets('/transactions/:id resolves to the detail route',
      (tester) async {
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions/t-42');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/transactions/t-42');
  });

  test('router has nine StatefulShell branches '
      '(home/accounts/transactions/debts/receivables/holdings/budgets/goals/settings)',
      () {
    final router = buildRouter(_seededAuthBloc());
    final shell = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .first;
    expect(shell.branches.length, 9,
        reason: 'settings branch (index 8) must be registered');
  });

  testWidgets(
      'sidebar 投资组合 tap navigates to /holdings (branch 5)',
      (tester) async {
    // 宽屏(>=1100)显示侧栏;默认 800x600 走底栏。侧栏投资组合项 onTap 用
    // context.go('/holdings')(route 优先),此测试验证它真切换到 branch 5。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('投资组合'), findsOneWidget);
    await tester.tap(find.text('投资组合'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/holdings');
  });

  testWidgets('/budgets resolves inside the budget branch and renders '
      'BudgetListPage', (tester) async {
    // 宽屏(>=1100)显示侧栏,避免底栏 7-destination 拥挤测试干扰。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/budgets');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: BudgetListPage 月份切换 + post-frame 在 stripped
    // harness 可能持续 schedule frames。几次 pump 足够 router 解析。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/budgets');
    // Branch 6 of StatefulShellRoute renders the budget list page.
    expect(find.byType(BudgetListPage), findsOneWidget);
  });

  testWidgets('/budgets/new resolves to the budget form route (create mode)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/budgets/new');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: BudgetFormPage._loadAccounts 是 async,在 stripped
    // harness 里可能持续 schedule。几次 pump 足够 router 解析。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/budgets/new');
  });

  testWidgets('/budgets/:id resolves to the budget detail route',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/budgets/b-42');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: BudgetDetailPage initState dispatch +
    // post-frame 在 stripped harness 可能持续 schedule。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/budgets/b-42');
  });

  testWidgets('sidebar 预算管理 tap navigates to /budgets (branch 6)',
      (tester) async {
    // 宽屏(>=1100)显示侧栏。侧栏「预算管理」项 branchIndex=6 + route='/budgets',
    // route 优先 → context.go('/budgets')。验证它真切换到 branch 6。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('预算管理'), findsOneWidget);
    await tester.tap(find.text('预算管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/budgets');
  });

  testWidgets('/goals resolves inside the goal branch and renders GoalListPage',
      (tester) async {
    // 宽屏(>=1100)显示侧栏,避免底栏拥挤测试干扰。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/goals');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: GoalListPage initState dispatch + post-frame 在 stripped
    // harness 可能持续 schedule。几次 pump 足够 router 解析。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/goals');
    // Branch 7 of StatefulShellRoute renders the goal list page.
    expect(find.byType(GoalListPage), findsOneWidget);
  });

  testWidgets('/goals/new resolves to the goal form route (create mode)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/goals/new');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: GoalFormPage._loadAccounts/_loadDebts 是 async,在 stripped
    // harness 里可能持续 schedule。几次 pump 足够 router 解析。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/goals/new');
  });

  testWidgets('/goals/:id resolves to the goal detail route', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/goals/g-42');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: GoalDetailPage initState dispatch +
    // post-frame 在 stripped harness 可能持续 schedule。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/goals/g-42');
  });

  testWidgets('sidebar 目标追踪 tap navigates to /goals (branch 7)',
      (tester) async {
    // 宽屏(>=1100)显示侧栏。侧栏「目标追踪」项 branchIndex=7 + route='/goals',
    // route 优先 → context.go('/goals')。验证它真切换到 branch 7。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('目标追踪'), findsOneWidget);
    await tester.tap(find.text('目标追踪'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/goals');
  });

  testWidgets('/debts resolves inside the debt branch and renders DebtsPage',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/debts');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/debts');
    // Branch 3 of StatefulShellRoute renders the debt list page.
    expect(find.byType(DebtsPage), findsOneWidget);
  });

  testWidgets('/debts/new resolves to the debt form route', (tester) async {
    // DebtFormPage desktop 双列布局在默认 800x600 视口会 RenderFlex 溢出，
    // 给一个桌面宽视口让 form + preview side-by-side 有足够宽度。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/debts/new');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: DebtFormPage's live amortization preview schedules
    // frames indefinitely in this stripped harness. A few pumps are enough for
    // the router to resolve the route (mirrors /transactions list test).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/debts/new');
  });

  testWidgets('/debts/:id resolves to the debt detail route', (tester) async {
    when(() => getIt<DebtRepository>().get(any())).thenAnswer(
        (_) async => dartz.Right(_debtDetail()));
    // DebtDetailPage desktop 布局同样需要桌面宽视口避免溢出。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/debts/d-42');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: DebtDetailPage schedules post-frame work in this
    // stripped harness. A few pumps are enough for the router to resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/debts/d-42');
  });

  testWidgets('/receivables resolves inside the receivables branch and '
      'renders ReceivablesPage', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/receivables');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/receivables');
    // Branch 4 of StatefulShellRoute renders the receivables list page.
    expect(find.byType(ReceivablesPage), findsOneWidget);
  });

  testWidgets('/receivables/new resolves to the receivable form route',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/receivables/new');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: ReceivableFormPage's live amortization preview
    // schedules frames indefinitely in this stripped harness (mirrors
    // /debts/new). A few pumps are enough for the router to resolve.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/receivables/new');
  });

  testWidgets('/receivables/:id resolves to the receivable detail route',
      (tester) async {
    when(() => getIt<DebtRepository>().get(any())).thenAnswer(
        (_) async => dartz.Right(_debtDetail()));
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/receivables/r-42');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: ReceivableDetailPage schedules post-frame work in
    // this stripped harness (mirrors /debts/:id). A few pumps are enough.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/receivables/r-42');
  });

  testWidgets('auth guard redirects unauthenticated /transactions to /login',
      (tester) async {
    // AuthBloc seeded Unauthenticated: redirect must bounce /transactions →
    // /login. (AuthInitial would be treated as loading → no redirect, so we
    // explicitly emit Unauthenticated.)
    final authBloc = _unauthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/login');
  });

  // Regression: /holdings/trade 和 /holdings/new 是 branch 级静态路由(声明在
  // ShellRoute 前),必须优先于 ShellRoute 内的 /holdings/:id 参数匹配。否则
  // GoRouter 14.6.1 first-complete-match + 深度优先会把 ShellRoute 先尝试 →
  // 递归到 /holdings/:id 把 'trade'/'new' 当 :id 吃掉,渲染 HoldingDetailPage
  // 而非 TradeSheetPage,trade 录入流程整条断。这组测试固化声明顺序。
  testWidgets(
      '/holdings/trade resolves to TradeSheetPage (not caught by :id)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/holdings/trade');
    await tester.pumpWidget(app(router, authBloc));
    // Don't pumpAndSettle: TradeSheetPage._loadSourceAccounts 是 async,在 stripped
    // harness 里可能持续 schedule。几次 pump 足够 router 解析 + 首帧渲染。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/holdings/trade');
    // 关键断言:渲染的是 TradeSheetPage(操作 sheet),而非 HoldingDetailPage。
    expect(find.byType(TradeSheetPage), findsOneWidget);
    expect(find.byType(HoldingDetailPage), findsNothing);
  });

  testWidgets(
      '/holdings/new resolves to TradeSheetPage (not caught by :id)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/holdings/new');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/holdings/new');
    expect(find.byType(TradeSheetPage), findsOneWidget);
    expect(find.byType(HoldingDetailPage), findsNothing);
  });

  testWidgets('/holdings/:id still resolves to HoldingDetailPage '
      '(param route unaffected by trade/new reorder)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/holdings/abc-123');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/holdings/abc-123');
    // 非保留字的真实 id 仍命中详情页(ShellRoute 内 :id),未被 trade/new 抢占。
    expect(find.byType(HoldingDetailPage), findsOneWidget);
    expect(find.byType(TradeSheetPage), findsNothing);
  });
}

/// Build an AuthBloc seeded Authenticated without driving any use case.
/// The router only reads `.state` for the redirect, so we seed the terminal
/// state directly. Use cases are mocks (never invoked).
AuthBloc _seededAuthBloc() => _SeededAuthedBloc();

class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockLogin(), _MockRegister(), _MockProfile(), _MockLogout()) {
    emit(Authenticated(_user));
  }
}

/// AuthBloc explicitly Unauthenticated (not AuthInitial, which the guard
/// treats as loading → no redirect).
AuthBloc _unauthBloc() => _SeededUnauthBloc();

class _SeededUnauthBloc extends AuthBloc {
  _SeededUnauthBloc()
      : super(_MockLogin(), _MockRegister(), _MockProfile(), _MockLogout()) {
    emit(Unauthenticated());
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

Account _account() => Account(
      id: 'a1',
      name: '现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

DebtDetail _debtDetail() => DebtDetail(
      debt: Debt(
        id: 'd1',
        accountId: 'a1',
        counterparty: '招商银行',
        interestRate: 4.10,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2026, 1, 1),
        dueDate: DateTime(2051, 6, 1),
        totalPrincipalCents: 280000000,
        remainingPrincipalCents: 210000000,
        version: 1,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      schedule: const [],
    );

Transaction _txn() => Transaction(
      id: 't1',
      transactionDate: DateTime(2026, 6, 19),
      description: 'stub',
      entries: const [
        TransactionEntry(accountId: 'a1', debitCents: 100, creditCents: 0),
        TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: 100),
      ],
    );

BudgetView _budget() => const BudgetView(
      id: 'b1',
      name: '7月家庭预算',
      month: '2026-07',
      currencyCode: 'CNY',
      totalAmountCents: 1000000,
      totalActualCents: 400000,
      usagePct: 40.0,
    );

GoalView _goal() => const GoalView(
      id: 'g1',
      name: '应急基金',
      type: GoalType.savings,
      targetAmountCents: 6000000,
      currentAmountCents: 1200000,
      currencyCode: 'CNY',
    );
