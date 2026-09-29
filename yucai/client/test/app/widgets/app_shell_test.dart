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
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/app/nav_settings.dart';
import 'package:yucai_client/app/widgets/command_palette.dart';
import 'package:yucai_client/core/theme/app_design.dart';
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
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

/// ⑨A 折叠记忆通道后端(NavSettings 注入缝,照 theme_settings_test 形态)。
class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

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

  // ── ⑨ 导航增强 A:侧栏分组折叠 / 活动组高亮 / 常用置顶 ─────────────────
  // 宽屏挂侧栏(默认 800x600 走底栏);置顶区新增同名钉位后,
  // 仪表盘/交易记录/报表分析 在侧栏两处(pin + 分组项)。

  Future<void> pumpWideShell(WidgetTester tester,
      {double logicalHeight = 900}) async {
    tester.view.physicalSize = Size(2400, logicalHeight * 2); // logical 1200xH
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpShell(tester);
  }

  testWidgets('⑨A 分组折叠:点组头收起分组,组内项离树;再点展开复原',
      (tester) async {
    await pumpWideShell(tester);

    // 默认全展开:资产组项可见。
    expect(find.text('账户管理'), findsOneWidget);

    // 组头可点(key 携带折叠态后缀,供测试/e2e 断言态)。
    await tester.tap(find.byKey(const ValueKey('navGroupHead-资产')));
    await tester.pumpAndSettle();

    // 折叠后:组内项离开树(不可见不可点),组头仍在;key 翻到折叠态。
    expect(find.byKey(const ValueKey('navGroupHead-资产')), findsNothing);
    expect(find.byKey(const ValueKey('navGroupHead-资产-collapsed')),
        findsOneWidget);
    expect(find.text('账户管理'), findsNothing);
    expect(find.text('投资组合'), findsNothing);

    // 再点折叠态组头:展开复原。
    await tester.tap(find.byKey(const ValueKey('navGroupHead-资产-collapsed')));
    await tester.pumpAndSettle();
    expect(find.text('账户管理'), findsOneWidget);
    expect(find.text('投资组合'), findsOneWidget);
  });

  testWidgets('⑨A 折叠记忆:收起分组经 NavSettings 落 secure storage', (tester) async {
    // 家法通道:NavSettings(ThemeSettings 同款)mock 后端注册进 getIt;
    // AppShell 折叠切换应写全量折叠组集合。
    final storage = _MockSecureStorage();
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    getIt.registerSingleton<NavSettings>(NavSettings(storage));

    await pumpWideShell(tester);

    await tester.tap(find.byKey(const ValueKey('navGroupHead-借贷')));
    await tester.pumpAndSettle();

    verify(() => storage.write(key: 'nav_collapsed_groups', value: '借贷'))
        .called(1);
    expect(find.text('债务管理'), findsNothing);
  });

  testWidgets('⑨A 活动组高亮:/home 下「概览」组头以强调色点亮', (tester) async {
    await pumpWideShell(tester);

    // 概览组含当前项(仪表盘,branch 0)→ 组头标签换强调色(裸 MaterialApp
    // harness 无 extension → context.yucai 回落亮色令牌,独立断言期望值)。
    final label = tester.widget<Text>(find.text('概览'));
    expect(
      label.style?.color,
      equals(YucaiTheme.light().sidebarActiveFg),
      reason: '活动组组头标签应以 sidebarActiveFg 点亮(原型 .has-active)',
    );
    // 非活动组(资产)保持 muted。
    final idle = tester.widget<Text>(find.text('资产'));
    expect(idle.style?.color, isNot(equals(YucaiTheme.light().sidebarActiveFg)));
  });

  testWidgets('⑨A 常用置顶区:三钉常显,钉位点击导航,钉位不显选中态', (tester) async {
    // 加高视口(1500 逻辑高):置顶区占高后「工具」组在 900 高视口下落入
    // 懒构建折叠线下 —— 加高使全侧栏入树,断言 pin+分组项两处同名。
    await pumpWideShell(tester, logicalHeight: 1500);

    // 置顶区标签 + 三钉(硬编码 v1:仪表盘/交易记录/报表分析;拖拽自定义=
    // backlog)。侧栏同名两处(pin + 分组项);/home 面包屑另含「仪表盘」
    // → 仪表盘全树三处。
    expect(find.text('常用'), findsOneWidget);
    expect(find.text('仪表盘'), findsNWidgets(3),
        reason: 'pin + 分组项 + 顶栏面包屑');
    expect(find.text('交易记录'), findsNWidgets(2));
    expect(find.text('报表分析'), findsNWidgets(2));

    // 当前页 = 仪表盘(/home):分组项高亮,钉位不显选中态(原型形态:
    // pin-block 无 active class)。树序 pin 先于分组项 → .first 即钉位。
    final pinTile = tester.widget<AnimatedContainer>(
      find
          .ancestor(
              of: find.text('仪表盘').first,
              matching: find.byType(AnimatedContainer))
          .first,
    );
    expect((pinTile.decoration as BoxDecoration).color,
        equals(Colors.transparent),
        reason: '钉位不承载选中态(选中态在分组项,原型 v10 pin-block)');

    // 钉位点击导航:报表分析钉(pin 在置顶区,恒可见)→ /reports。
    await tester.tap(find.text('报表分析').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final ctx = tester.element(find.byType(Navigator).first);
    expect(
        GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.toString(),
        '/reports');
  });

  // ── ⑨ 导航增强 B:Ctrl+K 全局命令面板(shell 级挂载) ────────────────────
  // 机制取舍(钉):Flutter 内建 Shortcuts/Actions 挂 AppShell 层(任务书
  // B1 选型,非 window_manager 键盘钩子)—— shell 内任意焦点(含文本框,
  // Ctrl+K 非文本默认键位,冒泡可达)触发;Focus(autofocus) 兜底启动
  // 零焦点期。面板组件级行为见 command_palette_test。

  testWidgets('⑨B Ctrl+K 唤起命令面板,Esc 关闭,再 Ctrl+K 切换(toggle)',
      (tester) async {
    await pumpShell(tester);
    expect(find.byType(CommandPalette), findsNothing);

    // Ctrl+K 唤起。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CommandPalette), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget, reason: '面板应显操作组条目');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    // Esc 关闭。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(CommandPalette), findsNothing);

    // 再 Ctrl+K = 重新唤起;开面板态 Ctrl+K = 关闭(toggle,原型语义)。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(CommandPalette), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.byType(CommandPalette), findsNothing);
  });

  testWidgets('⑨B 面板内 Enter 导航:↓ 选中报表分析后 ↵ 跳 /reports(shell 内)',
      (tester) async {
    await pumpShell(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    // ↓ → 第二项(报表分析),↵ 执行 → shell 内 branch 10。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final ctx = tester.element(find.byType(Navigator).first);
    expect(
        GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.toString(),
        '/reports');
    expect(find.byType(CommandPalette), findsNothing, reason: '执行后关闭');
  });

  // ── 反馈1a(反馈⑥ 回归):shell 层不再持选区 scope ─────────────────────
  // 根因:全局/内容区 scope 与多滚动容器并存 = 拖选边沿更新被静默丢弃
  // (Flutter #153004 家族);修法 = scope 下沉到页面体(CurrentRoute-
  // SelectionArea,见 core/widgets)。shell 层(chrome)不得再包
  // SelectionArea —— 一回来就复发。拖选正向契约见
  // transactions_page_test(页身 scope 真手势)与 integration e2e(真机)。
  testWidgets('反馈1a 回归锚:AppShell 内容区无 SelectionArea(scope 在页身)',
      (tester) async {
    await pumpShell(tester);
    expect(find.byType(SelectionArea), findsNothing,
        reason: 'scope 已下沉页面体(CurrentRouteSelectionArea);'
            'shell/路由层 scope = #153004 拖选失效复发点');
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
