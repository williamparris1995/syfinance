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
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/data/auth_remote_ds.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
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
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/pages/debts_page.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/pages/goal_list_page.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/pages/holding_detail_page.dart';
import 'package:yucai_client/holding/presentation/pages/trade_sheet_page.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/core/theme/theme_settings.dart';
import 'package:yucai_client/core/notifications/tray_settings.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/debt/presentation/pages/receivables_page.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_bloc.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/template/presentation/bloc/template_bloc.dart';
import 'package:yucai_client/template/presentation/pages/template_page.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';
import 'package:yucai_client/transaction/presentation/pages/transactions_page.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockSummaryRepo extends Mock implements ReceivablesSummaryRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockGoalRepo extends Mock implements GoalRepository {}
class _MockTagRepo extends Mock implements TagRepository {}
class _MockTemplateRepo extends Mock implements TemplateRepository {}
class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}
class _MockHasCredentials extends Mock implements HasStoredCredentialsUseCase {}
class _MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class _FakeThemeSettings extends Fake implements ThemeSettings {
  final ValueNotifier<ThemeMode> _notifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);
  @override
  ValueListenable<ThemeMode> get listenable => _notifier;
  @override
  ThemeMode get value => ThemeMode.system;
  @override
  Future<void> load() async {}
  @override
  Future<void> setThemeMode(ThemeMode mode) async {}
}

/// Fake TraySettings(F22 窗口与提醒)— 满足 SettingsPage build 期 getIt
/// 解析与 SegmentedButton/Switch 的 listenable 读取(默认 hide/minutes30/
/// 显示金额)。
class _FakeTraySettings extends Fake implements TraySettings {
  final ValueNotifier<TrayCloseBehavior> _close =
      ValueNotifier<TrayCloseBehavior>(TrayCloseBehavior.hide);
  final ValueNotifier<TrayScanInterval> _scan =
      ValueNotifier<TrayScanInterval>(TrayScanInterval.minutes30);
  final ValueNotifier<bool> _amounts = ValueNotifier<bool>(true);

  @override
  ValueListenable<TrayCloseBehavior> get closeBehaviorListenable => _close;

  @override
  ValueListenable<TrayScanInterval> get scanIntervalListenable => _scan;

  @override
  ValueListenable<bool> get showTrayAmountsListenable => _amounts;
}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  final ValueNotifier<String> _notifier = ValueNotifier<String>('CNY');
  @override
  ValueListenable<String> get listenable => _notifier;
  @override
  String get value => 'CNY';
  @override
  Future<String> getBaseCurrency() async => 'CNY';
}

/// Fake BoundMarker — SettingsPage build 期读 getIt<BoundMarker>(F21 清空
/// 入口的绑定态判定);未绑定 → 入口按 guest 形态渲染,既有断言不涉及。
class _FakeBoundMarker extends Fake implements BoundMarker {
  @override
  Future<bool> isBound() async => false;
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

/// Fake NetWorthDataSource — HomePage _loadNetWorth reads getIt<NetWorthDataSource>
/// at initState (commit 68508b2 占位修复); register a fake returning a zeroed view
/// so /home resolves without pulling the full DI graph. Mirrors home_page_test.
class _FakeNetWorthDs extends Fake implements NetWorthDataSource {
  @override
  Future<NetWorthView> getNetWorth({required String baseCurrency}) async =>
      NetWorthView(
        totalAssetsCents: 0,
        totalLiabilitiesCents: 0,
        netWorthCents: 0,
        currency: 'CNY',
      );
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
    registerFallbackValue(RecordExpenseParams(
      transactionDate: DateTime(2026, 6, 19),
      expenseAccountId: 'food',
      assetAccountId: 'cash',
      amountCents: 100,
    ));
    registerFallbackValue(const BuyParams(
      accountId: 'a1',
      securityId: 's1',
      fromAccountId: 'a1',
      quantity: 1,
      priceCents: 100,
      tradeDate: '2026-09-05',
    ));
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
    // /debts 路由现在 getIt<DebtBloc>() 取共享单例(user-acceptance 修复)。
    getIt.registerLazySingleton<DebtBloc>(() => DebtBloc(debtRepo));
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
    // HomePage 也订阅 DataRefreshNotifier(hotfix:存档导入后的全局重拉通知);
    // 注册真实例即可 —— 测试无需断言 bump,仅需 resolve 成功。
    getIt.registerSingleton<DataRefreshNotifier>(DataRefreshNotifier());
    // SettingsPage reads ThemeSettings from getIt (R8 F1 主题模式)。Register a
    // fake so the settings branch resolves without the full DI graph.
    getIt.registerSingleton<ThemeSettings>(_FakeThemeSettings());
    // SettingsPage reads TraySettings from getIt (F22 窗口与提醒)。
    getIt.registerSingleton<TraySettings>(_FakeTraySettings());
    // SettingsPage reads BoundMarker from getIt (F21 清空入口绑定态判定)。
    getIt.registerSingleton<BoundMarker>(_FakeBoundMarker());
    // HomePage _loadNetWorth reads getIt<NetWorthDataSource>() at initState
    // (68508b2); register a fake so /home resolves(P0-1 摘要卡 + 既有净资产卡 都依赖)。
    getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs());
    // Routes create a fresh CurrencyBloc via getIt<CurrencyBloc>() (router.dart
    // /debts, /debts/:id, /receivables, /receivables/:id, /accounts, /settings).
    // Register a factory returning a fake so those route builders resolve;
    // without this the /debts/:id (and /receivables/:id) route throws
    // `GetIt: CurrencyBloc is not registered` during page build, which also
    // leaks widget state and breaks subsequent tests (auth-guard).
    getIt.registerFactory<CurrencyBloc>(() => _FakeCurrencyBloc());
    // SettingsPage resolves AuthRemoteDataSource from getIt at build (guest
    // landing on /settings, R6) — a mock keeps the page resolvable.
    getIt.registerLazySingleton<AuthRemoteDataSource>(
        () => _MockAuthRemoteDataSource());
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
    // HomePage _UpcomingPaymentsPanel (dashboard 占位修复 commit 68508b2) reads
    // getIt<DebtRepository>().upcomingPayments(days) at build time; stub globally
    // so /home navigation doesn't hit an unstubbed null → Future type error.
    when(() => debtRepo.upcomingPayments(any()))
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
    // HomePage _loadSummaryCards (P0-1 dashboard 摘要卡) reads
    // getBudgetByMonth(monthStr); stub returning Left → home_page folds to null
    // → hides the budget card(当月无 budget,对齐生产 404 语义)。
    when(() => budgetRepo.getBudgetByMonth(any()))
        .thenAnswer((_) async => const dartz.Left(ServerFailure('not found')));
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

  testWidgets('broken session (Unauthenticated) bounces off business routes '
      'to /login — the recovery path (R6 FR-1 scenario 2)', (tester) async {
    // AuthBloc seeded Unauthenticated: the token is bad (not a guest choice),
    // so the guard keeps the old wall behavior — unlike Guest, which roams.
    final authBloc = _unauthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/login');
  });

  testWidgets('guest reaches /settings (binding entry lives there)', (tester) async {
    final authBloc = _guestBloc();
    final router = buildRouter(authBloc);
    router.go('/settings');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/settings');
  });

  testWidgets('guest reaching /login stays (it is the binding entry)',
      (tester) async {
    final authBloc = _guestBloc();
    final router = buildRouter(authBloc);
    router.go('/login');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/login');
  });

  testWidgets('offline-kept session reaching /login bounces to /home',
      (tester) async {
    final authBloc = _offlineBloc();
    final router = buildRouter(authBloc);
    router.go('/login');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/home');
  });

  testWidgets('server backup route stays behind the login wall (default '
      'bind-only list)', (tester) async {
    // /settings/backup + /settings/backup/auto are gRPC-bound server pages
    // that existed before R6 — guests must not reach them (FR-2 scenario 2).
    final authBloc = _guestBloc();
    final router = buildRouter(authBloc);
    router.go('/settings/backup/auto');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/login');
  });

  testWidgets('conflict panel route stays behind the login wall '
      '(F18 bind-only)', (tester) async {
    // /settings/conflicts 是 gRPC 绑定的 server 冲突面板(F18 FR-5,badge
    // 冲突 chip 的落点)—— guest 不得直达(照 backup 先例)。
    final authBloc = _guestBloc();
    final router = buildRouter(authBloc);
    router.go('/settings/conflicts');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/login');
  });

  testWidgets('bind-only prefix mechanism bounces guests to /login '
      '(injectable list)', (tester) async {
    // Pins the mechanism itself for future bound routes (R6 FR-2).
    final authBloc = _guestBloc();
    final router = buildRouter(authBloc, bindOnlyPrefixes: const ['/cloud']);
    router.go('/cloud/settings');
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
  // F8 FR-3/ADR-4:标签页卡 onTap → push /transactions(extra 携 tagId)→
  // 路由 builder 构造初始 filter 注入 TransactionsPage(首查 list 带 tagId)。
  testWidgets('标签页 tap 标签卡 → /transactions 以 tagId 初始筛选首查',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    // /settings/tags 路由 create getIt<TagBloc>() → 需注册 TagRepository +
    // TagBloc 工厂(router_test 的 getIt.reset() 不含 tag 模块注册)。
    final tagRepo = _MockTagRepo();
    when(() => tagRepo.list()).thenAnswer((_) async => const dartz.Right(
        [Tag(id: 'tag-1', name: '日常', color: '#b08d57', version: 1)]));
    getIt.registerSingleton<TagRepository>(tagRepo);
    getIt.registerFactory<TagBloc>(() => TagBloc(tagRepo));

    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/settings/tags');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('日常'), findsOneWidget);

    await tester.tap(find.text('日常'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // push 是指令式压栈(currentConfiguration 仍指向基座 location),以
    // TransactionsPage 渲染在栈顶为准。
    expect(find.byType(TransactionsPage), findsOneWidget);
    // 初始 filter 注入:首查 list 的 params.tagId = extra 携带的标签 id。
    final captured = verify(() => getIt<TransactionRepository>().list(captureAny()))
        .captured
        .cast<ListTransactionsParams>();
    expect(captured.last.tagId, 'tag-1',
        reason: '路由 builder 应把 extra tagId 转成 TxnFilterState.tagId 首查');
  });

  // ───────── F14 疑点 #1:订阅管理路由 ─────────
  // 侧栏「订阅管理」(app_shell)导航 /accounts/templates;router 曾无此静态
  // 子路由 → 'templates' 被 /accounts/:id 捕获渲染成 AccountDetailPage。
  // 修法:/accounts 下注册静态子路由 templates(必须在 :id 前,GoRouter 匹配
  // 优先级同 /holdings trade/new 先例),复用 /settings/templates 同款
  // TemplatePage + TemplateBloc(设置页入口同一页面组件)。
  testWidgets('/accounts/templates resolves to TemplatePage (订阅管理 target, '
      'not caught by /accounts/:id)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    // /accounts/templates 路由 create getIt<TemplateBloc>() → 需注册
    // TemplateRepository + TemplateBloc 工厂(对齐 /settings/tags 测试先例)。
    final templateRepo = _MockTemplateRepo();
    when(() => templateRepo.list(paused: any(named: 'paused')))
        .thenAnswer((_) async => const dartz.Right(<Template>[]));
    getIt.registerFactory<TemplateBloc>(() => TemplateBloc(templateRepo));

    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/accounts/templates');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/accounts/templates');
    // 关键断言:渲染 TemplatePage(订阅管理目标页),而非账户详情。
    expect(find.byType(TemplatePage), findsOneWidget);
    expect(find.byType(AccountDetailPage), findsNothing);
  });

  testWidgets('sidebar 订阅管理 tap navigates to /accounts/templates and '
      'renders TemplatePage', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final templateRepo = _MockTemplateRepo();
    when(() => templateRepo.list(paused: any(named: 'paused')))
        .thenAnswer((_) async => const dartz.Right(<Template>[]));
    getIt.registerFactory<TemplateBloc>(() => TemplateBloc(templateRepo));

    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('订阅管理'), findsOneWidget);
    await tester.tap(find.text('订阅管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/accounts/templates');
    expect(find.byType(TemplatePage), findsOneWidget);
    expect(find.byType(AccountDetailPage), findsNothing);
  });

  testWidgets('/accounts/:id still resolves to AccountDetailPage '
      '(templates 静态路由不影响参数路由)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    // 详情页 AccountBloc 进入即 GetAccountRequested → getById 需 stub
    // (router_test 全局 setUp 只 stub 了 list)。
    when(() => getIt<AccountRepository>().getById(any()))
        .thenAnswer((_) async => dartz.Right(_account()));
    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/accounts/acc-42');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(router.routerDelegate.currentConfiguration.uri.toString(),
        '/accounts/acc-42');
    // 非保留字的真实 id 仍命中详情页,未被 templates 静态路由抢占。
    expect(find.byType(AccountDetailPage), findsOneWidget);
    expect(find.byType(TemplatePage), findsNothing);
  });

  // ───────── F14 疑点 #3:交易列表回拉 ─────────
  // 顶栏创建表单(_TopBarCreate → context.push('/transactions/new'))提交成功
  // pop 后,列表页(IndexedStack 分支常驻)不重载 —— 页内 _openCreateForm 的
  // await-push reload 覆盖不到路由 push 路径。修法:branch 观察者 + RouteAware
  // didPopNext 触发既有 Load 路径(保留筛选,照 F7 语义)。
  testWidgets('F14 #3:顶栏创建交易提交 pop 后列表回拉(新交易可见)',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    // TransactionFormPage 自建 TransactionFormBloc(getIt<TransactionRepository>
    // + getIt<AccountRepository>);tag chip-row 读 getIt<TagRepository>。
    final tagRepo = _MockTagRepo();
    when(() => tagRepo.list()).thenAnswer((_) async => const dartz.Right([]));
    getIt.registerSingleton<TagRepository>(tagRepo);
    // 表单下拉需要 asset + expense 两个账户(支出模式:资金账户 + 支出分类)。
    final food = _account()
        .copyWith(id: 'food', name: '餐饮', accountType: AccountType.expense);
    when(() => getIt<AccountRepository>().list())
        .thenAnswer((_) async => dartz.Right([_account(), food]));
    when(() => getIt<TransactionRepository>().recordExpense(any())).thenAnswer(
        (_) async => dartz.Right(_txn(id: 't-new', description: '新咖啡')));
    // 首查 1 笔;回拉后 2 笔(计数器切换,断言「回拉真的发生」)。
    var listCalls = 0;
    when(() => getIt<TransactionRepository>().list(any())).thenAnswer((_) async {
      listCalls++;
      return dartz.Right(ListTransactionsResult(
          transactions: listCalls == 1
              ? [_txn(id: 't1', description: '交易 t1')]
              : [
                  _txn(id: 't1', description: '交易 t1'),
                  _txn(id: 't-new', description: '新咖啡'),
                ],
          nextPageToken: ''));
    });

    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('交易 t1'), findsOneWidget);
    expect(listCalls, 1);

    // 顶栏「新增交易」(_TopBarCreate,desktop 下页面 header 无创建按钮,
    // 列表非空 → 空态引导按钮也不在 → 唯一命中)。
    await tester.tap(find.text('新增交易'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionFormPage), findsOneWidget);

    // 填表:+50 快捷金额 + 资金账户(现金)+ 支出分类(餐饮)。
    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    await _openDropdownAndPick(tester, '例如：招商银行、现金', '现金');
    await _openDropdownAndPick(tester, '例如：餐饮、交通', '餐饮');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 提交成功 → 表单 pop(true) → 列表页 didPopNext 回拉:第二查数据渲染。
    expect(find.byType(TransactionFormPage), findsNothing);
    expect(listCalls, greaterThan(1), reason: 'pop 后未触发回拉重查');
    expect(find.text('新咖啡'), findsOneWidget, reason: '回拉后列表应含新交易');
  });

  // ───────── F14 疑点 #4:持仓列表回拉 ─────────
  // 顶栏「买入持仓」(_TopBarCreate → /holdings/trade)的 TradeSheet 用路由层
  // 独立 HoldingBloc,提交成功 pop 后列表页(IndexedStack 分支常驻,另一个
  // bloc 实例)不重拉。修法:同 #3 模式 —— holdings branch 观察者 + 页内
  // RouteAware didPopNext 重拉(保留 typeFilter)。
  testWidgets('F14 #4:顶栏买入持仓(TradeSheet)提交 pop 后持仓列表回拉',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    const security = Security(
      id: 's1',
      symbol: 'AAPL',
      name: '苹果',
      securityType: SecurityType.stock,
      currency: 'CNY',
      currentPriceCents: 10000,
    );
    const newHolding = Holding(
      id: 'h1',
      accountId: 'a1',
      securityId: 's1',
      securityName: '苹果',
      securitySymbol: 'AAPL',
      quantity: 10,
      avgCostCents: 10000,
      marketValueCents: 100000,
      unrealizedPnlCents: 0,
      version: 1,
    );
    final holdingRepo = getIt<HoldingRepository>();
    // 首查(路由 builder + 页面 initState 各一次)空;buy 之后的所有
    // listHoldings(sheet 自己的 bloc buy 成功后拉 + 列表页 didPopNext 回拉)
    // 返回新持仓 —— 以 buy 为界,避免对初始调用次数敏感。
    var bought = false;
    when(() => holdingRepo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async =>
            dartz.Right(bought ? [newHolding] : const <Holding>[]));
    when(() => holdingRepo.listSecurities(type: any(named: 'type')))
        .thenAnswer((_) async => const dartz.Right([security]));
    when(() => holdingRepo.buy(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
          fromAccountId: any(named: 'fromAccountId'),
          quantity: any(named: 'quantity'),
          priceCents: any(named: 'priceCents'),
          feeCents: any(named: 'feeCents'),
          tradeDate: any(named: 'tradeDate'),
          notes: any(named: 'notes'),
        )).thenAnswer((_) async {
      bought = true;
      return const dartz.Right(HoldingTransaction(
        id: 'tx1',
        accountId: 'a1',
        securityId: 's1',
        tradeType: TradeType.buy,
        quantity: 10,
        priceCents: 10000,
        amountCents: 100000,
        feeCents: 0,
        tradeDate: '2026-09-05',
      ));
    });

    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    // TradeSheet 资金账户余额 fail-fast:预置充足余额(现金账户默认 0 会被
    // 提交校验拦截)。
    when(() => getIt<AccountRepository>().list()).thenAnswer((_) async =>
        dartz.Right([_account().copyWith(currentBalanceCents: 10000000)]));
    router.go('/holdings');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // 空态(首查空)。
    expect(find.text('还没有持仓'), findsOneWidget);

    // 顶栏「买入持仓」(空态无按钮 → 唯一命中)。
    await tester.tap(find.text('买入持仓'));
    await tester.pumpAndSettle();
    expect(find.byType(TradeSheetPage), findsOneWidget);

    // 填单:证券 + 持仓账户 + 资金账户 + 数量 + 价格,提交。
    await _openDropdownAndPick(tester, '选择证券', 'AAPL · 苹果');
    await _openDropdownAndPick(tester, '选择持仓账户', '现金');
    await _openDropdownAndPick(tester, '选择资金账户', '现金');
    await tester.enterText(find.byKey(const ValueKey('qtyField')), '10');
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('priceField')), '100');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    // 提交成功 → sheet pop(true) → 列表页 didPopNext 回拉:新持仓可见。
    expect(find.byType(TradeSheetPage), findsNothing);
    expect(find.text('还没有持仓'), findsNothing,
        reason: 'TradeSheet pop 后列表未回拉');
    expect(find.text('苹果'), findsWidgets,
        reason: '回拉后列表应含新持仓');
  });

  // F14 #3 补充:页内空态引导按钮(_EmptyListHint → _openCreateForm 的
  // MaterialPageRoute push)提交 pop 后同样回拉 —— 该路径原本由
  // _openCreateForm 直接 reload,改造后统一走 didPopNext(同 branch 嵌套
  // Navigator),本测试钉住不回归。
  testWidgets('F14 #3b:空态引导创建交易提交 pop 后列表回拉', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final tagRepo = _MockTagRepo();
    when(() => tagRepo.list()).thenAnswer((_) async => const dartz.Right([]));
    getIt.registerSingleton<TagRepository>(tagRepo);
    final food = _account()
        .copyWith(id: 'food', name: '餐饮', accountType: AccountType.expense);
    when(() => getIt<AccountRepository>().list())
        .thenAnswer((_) async => dartz.Right([_account(), food]));
    when(() => getIt<TransactionRepository>().recordExpense(any())).thenAnswer(
        (_) async =>
            dartz.Right(_txn(id: 't-new2', description: '新咖啡2')));
    var listCalls = 0;
    when(() => getIt<TransactionRepository>().list(any())).thenAnswer((_) async {
      listCalls++;
      return dartz.Right(ListTransactionsResult(
          transactions: listCalls == 1
              ? <Transaction>[]
              : [_txn(id: 't-new2', description: '新咖啡2')],
          nextPageToken: ''));
    });

    final authBloc = _seededAuthBloc();
    final router = buildRouter(authBloc);
    router.go('/transactions');
    await tester.pumpWidget(app(router, authBloc));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // 空列表 → 空态引导按钮(顶栏创建按钮也在,取 .last = 空态引导)。
    expect(find.text('本月暂无交易'), findsOneWidget);

    await tester.tap(find.text('新增交易').last);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionFormPage), findsOneWidget);

    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    await _openDropdownAndPick(tester, '例如：招商银行、现金', '现金');
    await _openDropdownAndPick(tester, '例如：餐饮、交通', '餐饮');
    await tester.ensureVisible(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionFormPage), findsNothing);
    expect(find.text('新咖啡2'), findsOneWidget, reason: '空态路径 pop 后未回拉');
    // _openCreateForm 成功 toast(AppToast 3s 自动消失 timer)排空,避免
    // 测试收尾「Timer is still pending」断言。
    await tester.pump(const Duration(seconds: 4));
  });
}

/// Build an AuthBloc seeded Authenticated without driving any use case.
/// The router only reads `.state` for the redirect, so we seed the terminal
/// state directly. Use cases are mocks (never invoked).
AuthBloc _seededAuthBloc() => _SeededAuthedBloc();

class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
    emit(Authenticated(_user));
  }
}

/// AuthBloc explicitly Unauthenticated (a broken session): the login wall is
/// the recovery path for business routes, same as pre-R6 (FR-1 scenario 2).
AuthBloc _unauthBloc() => _SeededUnauthBloc();

class _SeededUnauthBloc extends AuthBloc {
  _SeededUnauthBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
    emit(Unauthenticated());
  }
}

/// Guest (no account, offline-first): same routing surface as Unauthenticated
/// for guard purposes.
AuthBloc _guestBloc() => _SeededGuestBloc();

class _SeededGuestBloc extends AuthBloc {
  _SeededGuestBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
    emit(Guest());
  }
}

/// Offline-kept session (tokens present, profile RPC failed on network):
/// treated as logged in by the guard.
AuthBloc _offlineBloc() => _SeededOfflineBloc();

class _SeededOfflineBloc extends AuthBloc {
  _SeededOfflineBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
    emit(OfflineAuthenticated());
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

Transaction _txn({String id = 't1', String description = 'stub'}) =>
    Transaction(
      id: id,
      transactionDate: DateTime(2026, 6, 19),
      description: description,
      entries: const [
        TransactionEntry(accountId: 'a1', debitCents: 100, creditCents: 0),
        TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: 100),
      ],
    );

/// Opens a DropdownButtonFormField by tapping its [hint] text, then taps the
/// [option] menu item(照 transaction_form_page_test 同款 idiom)。
Future<void> _openDropdownAndPick(
    WidgetTester tester, String hint, String option) async {
  await tester.tap(find.text(hint).first, warnIfMissed: false);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last, warnIfMissed: false);
  await tester.pumpAndSettle();
}

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
