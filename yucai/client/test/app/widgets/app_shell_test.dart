// Widget test for AppShell's _TopBar frosted-glass treatment (Task 3:
// topbar 半透明米色 + 毛玻璃 blur(10)).
//
// _TopBar is private, so we pump the real router (buildRouter) — which mounts
// AppShell with a genuine StatefulNavigationShell — and assert BackdropFilter
// is present in the tree. This mirrors the harness in router_test.dart.
//
// No gRPC: the branch pages (HomePage / AccountsPage) read AccountBloc and
// TransactionBloc from getIt, so we register minimal mock-driven instances
// before pumping. AuthBloc is seeded Authenticated to clear the auth guard.
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/binding/presentation/bloc/sync_coordinator_bloc.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}
class _MockHasCredentials extends Mock implements HasStoredCredentialsUseCase {}

class _FakeCurrencySettings extends Fake implements CurrencySettings {
  final ValueNotifier<String> _notifier = ValueNotifier<String>('CNY');
  @override
  ValueListenable<String> get listenable => _notifier;
  @override
  String get value => 'CNY';
  @override
  Future<String> getBaseCurrency() async => 'CNY';
}

class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockGoalRepo extends Mock implements GoalRepository {}

/// F12 T2:SyncCoordinatorBloc 替身(照 backup_page_test 的 mock bloc 形态,
/// state/stream 桩)—— AppShell.build 首个生产 resolve 点的挂载验证用。
class _MockSyncBloc extends Mock implements SyncCoordinatorBloc {}

/// Fake NetWorthDataSource — HomePage _loadNetWorth reads getIt<NetWorthDataSource>
/// at initState (68508b2); register a fake so /home resolves. Mirrors router_test.
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
  });

  setUp(() {
    getIt.reset();
    final accountRepo = _MockAccountRepo();
    final txnRepo = _MockTxnRepo();
    final debtRepo = _MockDebtRepo();
    final holdingRepo = _MockHoldingRepo();
    final budgetRepo = _MockBudgetRepo();
    final goalRepo = _MockGoalRepo();
    getIt.registerSingleton<AccountRepository>(accountRepo);
    getIt.registerSingleton<TransactionRepository>(txnRepo);
    // HomePage reads CurrencySettings from getIt (cross-page refresh listener
    // in initState); register a fake so the home branch resolves.
    getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings());
    // HomePage 也订阅 DataRefreshNotifier(hotfix:存档导入后的全局重拉通知);
    // 注册真实例即可 —— 测试无需断言 bump,仅需 resolve 成功。
    getIt.registerSingleton<DataRefreshNotifier>(DataRefreshNotifier());
    // HomePage 依赖(占位修复 68508b2 + P0-1 摘要卡):注册 NetWorthDataSource +
    // Debt/Holding/Budget/Goal Repository,stub 返空/Left → 各卡隐藏或空态。
    getIt.registerSingleton<DebtRepository>(debtRepo);
    getIt.registerSingleton<HoldingRepository>(holdingRepo);
    getIt.registerSingleton<BudgetRepository>(budgetRepo);
    getIt.registerSingleton<GoalRepository>(goalRepo);
    getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs());

    // AccountBloc is constructed by the route via getIt<AccountBloc>() (factory
    // in production via injectable). Register a factory here that wires the
    // real bloc to mock use cases backed by the mocked AccountRepository.
    getIt.registerFactory<AccountBloc>(() => AccountBloc(
          ListAccountsUseCase(accountRepo),
          CreateAccountUseCase(accountRepo),
          DeleteAccountUseCase(accountRepo),
          GetAccountUseCase(accountRepo),
          UpdateAccountUseCase(accountRepo),
        ));

    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right([]));
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Right(
            ListTransactionsResult(transactions: [], nextPageToken: '')));
    // HomePage _loadSummaryCards(summary/budget/goal)+ _UpcomingPaymentsPanel
    // + _AssetAllocationPanel 读这些 repo;stub 返零值/空/Left → 卡隐藏或空态。
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async =>
            const dartz.Right(MonthlySummary(year: 2026, month: 1)));
    when(() => debtRepo.upcomingPayments(any()))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => holdingRepo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => budgetRepo.getBudgetByMonth(any()))
        .thenAnswer((_) async => const dartz.Left(ServerFailure('not found')));
    when(() => goalRepo.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) async => const dartz.Right([]));
  });

  testWidgets('AppShell topbar uses BackdropFilter for frosted glass',
      (tester) async {
    final authBloc = _SeededAuthedBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>()),
          child: child!,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // OD .topbar = backdrop-filter:blur(10px). AppShell mounts _TopBar for
    // every protected route; it must now render a BackdropFilter.
    expect(find.byType(BackdropFilter), findsWidgets);
  });

  // F12 T2:SyncStatusBadge 挂载(shell 顶层 BlocProvider.value 接线验证)。
  // 共用 setUp 的页面依赖桩;badge 额外需要 tracker + SyncCoordinatorBloc
  // (照 ThemeSettings fake 模式:getIt 注册替身)。

  /// 挂载 AppShell(与既有测试同 harness 形态:seeded AuthBloc + 真路由)。
  Future<void> pumpShell(WidgetTester tester) async {
    final authBloc = _SeededAuthedBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>()),
          child: child!,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('AppShell mounts SyncStatusBadge for bound sessions',
      (tester) async {
    getIt.registerSingleton<SessionModeTracker>(
        SessionModeTracker()..isGuest = false);
    final syncBloc = _MockSyncBloc();
    when(() => syncBloc.state).thenReturn(const SyncCoordinatorState(
        status: SyncStatus.clean, pendingCount: 2));
    when(() => syncBloc.stream).thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<SyncCoordinatorBloc>(syncBloc);

    final authBloc = _SeededAuthedBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>()),
          child: child!,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 绑定态:badge 经 AppShell 的 provider 读到 mock bloc → 渲染待同步 chip。
    expect(find.text('待同步 2'), findsOneWidget);
  });

  testWidgets('AppShell guest: SyncStatusBadge not rendered', (tester) async {
    getIt.registerSingleton<SessionModeTracker>(
        SessionModeTracker()..isGuest = true);
    final syncBloc = _MockSyncBloc();
    when(() => syncBloc.state).thenReturn(const SyncCoordinatorState(
        status: SyncStatus.clean, pendingCount: 2));
    when(() => syncBloc.stream).thenAnswer((_) => const Stream.empty());
    getIt.registerSingleton<SyncCoordinatorBloc>(syncBloc);

    final authBloc = _SeededAuthedBloc();
    final router = buildRouter(authBloc);
    router.go('/home');
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: BlocProvider<TransactionBloc>(
          create: (_) => TransactionBloc(getIt<TransactionRepository>()),
          child: child!,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // guest:tracker 守卫在 BlocBuilder 之前 → 无 badge 内容(guest 链路零扰动)。
    expect(find.text('待同步 2'), findsNothing);
  });

  // review 观察 B(根治):provider 条件注入 —— guest 会话不 resolve 不构造
  // bloc,恢复 T1「构造即 bound」前提;登录翻转后 shell 重建 → 注入 → 构造。
  // 断言用生产行为等价:lazySingleton 工厂体执行 = 首次 resolve(构造)发生。
  testWidgets('guest shell:不 resolve 不构造 SyncCoordinatorBloc(条件注入)',
      (tester) async {
    var resolved = false;
    final syncBloc = _MockSyncBloc();
    when(() => syncBloc.state).thenReturn(const SyncCoordinatorState(
        status: SyncStatus.clean, pendingCount: 2));
    when(() => syncBloc.stream).thenAnswer((_) => const Stream.empty());
    getIt.registerLazySingleton<SyncCoordinatorBloc>(() {
      resolved = true;
      return syncBloc;
    });
    getIt.registerSingleton<SessionModeTracker>(
        SessionModeTracker()..isGuest = true);

    await pumpShell(tester);

    expect(resolved, isFalse, reason: 'guest 会话不得构造 bloc');
    expect(find.text('待同步 2'), findsNothing);
  });

  testWidgets('guest→bound 翻转:shell 重建后注入并构造(补扫前提恢复)',
      (tester) async {
    var resolved = false;
    final syncBloc = _MockSyncBloc();
    when(() => syncBloc.state).thenReturn(const SyncCoordinatorState(
        status: SyncStatus.clean, pendingCount: 2));
    when(() => syncBloc.stream).thenAnswer((_) => const Stream.empty());
    getIt.registerLazySingleton<SyncCoordinatorBloc>(() {
      resolved = true;
      return syncBloc;
    });
    final tracker = SessionModeTracker()..isGuest = true;
    getIt.registerSingleton<SessionModeTracker>(tracker);

    await pumpShell(tester);
    expect(resolved, isFalse); // guest 期未构造。

    // 登录翻转:AuthBloc 发射驱动 shell 重建(此处直接重挂,等价时序 ——
    // tracker 旗标先置位,再进 shell.build 条件注入分支)。
    tracker.isGuest = false;
    await pumpShell(tester);

    expect(resolved, isTrue, reason: '绑定会话首帧 resolve(构造期补扫前提)');
    expect(find.text('待同步 2'), findsOneWidget);
  });

  // ── F41→F42 T2:应用内反馈入口(宽屏侧栏行 + 窄屏底栏 destination) ─────
  // Entries now open the FeedbackFormDialog (F42 dual-channel form) instead
  // of jumping straight to mailto; the F41 launcher seams still back the
  // dialog's mail channel. Note the DEFAULT test surface (800x600 logical)
  // is below the 1100px wide breakpoint — the wide case must enlarge the
  // view explicitly.

  testWidgets('F42 wide (≥1100): sidebar 意见反馈 row opens the form dialog',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 1800); // logical 1200x900
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpShell(tester);

    // fix-2 acceptance: the feedback row moved into the LIST TAIL, so the
    // fixed area grew zero pixels — the main nav (e.g. 债务管理) stays in
    // the viewport even on short windows (720p e2e regression).
    expect(find.text('债务管理').hitTestable(), findsOneWidget);

    // The row sits at the end of the scrollable nav list — at 1200x900 it
    // may be at/below the fold, so scroll like a real user (the sidebar's
    // ListView is the first Scrollable in the wide tree).
    await tester.scrollUntilVisible(
      find.text('意见反馈'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('意见反馈'), findsOneWidget);

    await tester.tap(find.text('意见反馈'));
    await tester.pump();
    // Pump past the 500ms package_info timeout guard (plugin-less test
    // env never answers; the entry degrades to an empty version).
    await tester.pump(const Duration(seconds: 1));

    // The form dialog replaced the direct mailto jump (find the 意见反馈
    // title INSIDE the AlertDialog — the sidebar row text also exists).
    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsOneWidget);
    expect(find.text('提交反馈'), findsOneWidget);
  });

  testWidgets(
      'F42 narrow (<1100): bottom nav 反馈 destination opens the form dialog',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600); // logical 800x1600
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpShell(tester);

    // 8th destination: after the 6 branch slots, before 退出.
    expect(find.text('反馈'), findsOneWidget);

    await tester.tap(find.text('反馈'));
    await tester.pump();
    // Same 500ms version-timeout guard as the wide case.
    await tester.pump(const Duration(seconds: 1));

    expect(find.widgetWithText(AlertDialog, '意见反馈'), findsOneWidget);
    expect(find.text('提交反馈'), findsOneWidget);
  });
}

class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
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
