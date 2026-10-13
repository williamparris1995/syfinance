// F58 T3(FR-1/FR-2/FR-6)— AppShell 顶栏面包屑三段化 + 标题 port 消费 +
// 债权 detail 特例收敛的 widget 测试。
//
// harness 照 app_shell_test.dart 先例(seeded AuthBloc + buildRouter 真路由,
// mock repo 桩),导航至 /debts/:id、/receivables/:id 等 detail 路由断言:
//  - 三段渲染(section 纯文本 / page 链接 / current 加粗);
//  - detail 加载态占位「…」与非 detail 形态不显第三段;
//  - page 段 tap 经 FormLeaveGate 问询后 go 列表 root(veto=false 拦下);
//  - ShellDetailTitle 清零/保留语义(M2 精确清零:detail 实体 key 变才清,
//    非 detail 停留保留值 → 跨分支 push/pop 往返标题自动恢复);
//  - 债权 detail 回归全局 _TopBar(_isReceivableDetail 特例移除)。
//
// 断言范围用 BackdropFilter 收窄到 shell _TopBar(未迁移页仍可能带同名
// 面包屑文本/占位,该收窄在 F59 扫页退役全部 detail AppBar 前继续成立)。
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/app/widgets/app_shell.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/form_leave_gate.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/core/shell_detail_title.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/template/presentation/bloc/template_bloc.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';

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
class _MockSummaryRepo extends Mock implements ReceivablesSummaryRepository {}
class _MockTemplateRepo extends Mock implements TemplateRepository {}

/// 路由层 /debts、/debts/:id、/receivables/:id builder 均经 getIt 取
/// CurrencyBloc(照 router_test 的 fake:state/stream 桩,add 无操作)。
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

class _FakeNetWorthDs extends Fake implements NetWorthDataSource {
  @override
  Future<NetWorthView> getNetWorth({required String baseCurrency}) async =>
      const NetWorthView(
        totalAssetsCents: 0,
        totalLiabilitiesCents: 0,
        netWorthCents: 0,
        currency: 'CNY',
      );
}

DebtDetail _debtDetail({String counterparty = '招商银行'}) => DebtDetail(
      debt: Debt(
        id: 'd1',
        accountId: 'a1',
        counterparty: counterparty,
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

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(const ListTransactionsParams());
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
    // /debts、/receivables branch root 的共享单例(点面包屑回列表时构建)。
    getIt.registerLazySingleton<DebtBloc>(() => DebtBloc(debtRepo));
    getIt.registerSingleton<ReceivablesSummaryRepository>(summaryRepo);
    getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings());
    getIt.registerSingleton<DataRefreshNotifier>(DataRefreshNotifier());
    getIt.registerSingleton<NetWorthDataSource>(_FakeNetWorthDs());
    getIt.registerSingleton<HoldingRepository>(holdingRepo);
    getIt.registerSingleton<BudgetRepository>(budgetRepo);
    getIt.registerSingleton<GoalRepository>(goalRepo);
    getIt.registerFactory<CurrencyBloc>(() => _FakeCurrencyBloc());
    getIt.registerFactory<AccountBloc>(() => AccountBloc(
          ListAccountsUseCase(accountRepo),
          CreateAccountUseCase(accountRepo),
          DeleteAccountUseCase(accountRepo),
          GetAccountUseCase(accountRepo),
          UpdateAccountUseCase(accountRepo),
        ));
    // F58 T3 两 port(生产 injection.dart 1k 同款注册;真实例即测真行为)。
    getIt.registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
    getIt.registerLazySingleton<FormLeaveGate>(FormLeaveGate.new);

    when(() => accountRepo.list())
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Right(
            ListTransactionsResult(transactions: [], nextPageToken: '')));
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async =>
            const dartz.Right(MonthlySummary(year: 2026, month: 1)));
    when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => debtRepo.upcomingPayments(any()))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => debtRepo.get(any()))
        .thenAnswer((_) async => dartz.Right(_debtDetail()));
    when(() => holdingRepo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => budgetRepo.getBudgetByMonth(any()))
        .thenAnswer((_) async => const dartz.Left(ServerFailure('nf')));
    when(() => goalRepo.listGoals(
            type: any(named: 'type'), completed: any(named: 'completed')))
        .thenAnswer((_) async => const dartz.Right([]));
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
  });

  /// 挂 shell 到指定路由(宽屏逻辑 1400x900 默认;detail 页双列布局需
  /// 桌面宽视口避免溢出,照 router_test 先例)。返回 router 供 location 断言。
  Future<GoRouter> pumpAt(WidgetTester tester, String startLocation,
      {Size logical = const Size(1400, 900)}) async {
    tester.view.physicalSize = logical;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authBloc = _SeededAuthedBloc();
    final router = buildRouter(authBloc);
    router.go(startLocation);
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
    // 不 pumpAndSettle:detail 页在 stripped harness 持续 schedule post-frame
    // (照 router_test 先例,两次 pump 足够路由解析)。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return router;
  }

  /// location 断言口径(照 router_test 先例)。
  String locationOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// shell 侧 location 口径:AppShell 读 `GoRouterState.of(context)` —— 与
  /// [locationOf] 的 currentConfiguration **不同源**(go_router 14.6.2:branch
  /// 内 push 改前者、不改后者),push 类断言必须与 shell 同源才见真相。
  String shellLocationOf(WidgetTester tester) => GoRouterState.of(
          tester.element(find.byType(AppShell).first))
      .uri
      .toString();

  /// 收窄到 shell _TopBar 的文本 finder(未迁移页仍可能带同名面包屑/
  /// 占位;F59 扫页退役全部 detail AppBar 后可放宽)。
  Finder crumbOf(String text) => find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.text(text),
      );

  testWidgets('FR-1 detail 三段渲染:section 纯文本 / page 链接 / current 加粗',
      (tester) async {
    await pumpAt(tester, '/debts/d-42');

    // 标题注入(T4 起 detail 页加载完成 set;此处直推 port 验证 shell 消费)。
    getIt<ShellDetailTitle>().set('平安现金分期');
    await tester.pump();

    expect(crumbOf('财务'), findsOneWidget);
    expect(crumbOf('债务管理'), findsOneWidget);
    expect(crumbOf('平安现金分期'), findsOneWidget);

    // page 段:InkWell 可点 + link 色(主题无 link 令牌 → accent;裸
    // MaterialApp harness 无 extension → 回落亮色令牌,独立断言期望值)。
    expect(
      find.ancestor(of: crumbOf('债务管理'), matching: find.byType(InkWell)),
      findsOneWidget,
    );
    final pageText = tester.widget<Text>(crumbOf('债务管理'));
    expect(pageText.style?.color, equals(YucaiTheme.light().accent));

    // section 段:纯文本 —— 无可点包裹、muted 色。
    expect(
      find.ancestor(of: crumbOf('财务'), matching: find.byType(InkWell)),
      findsNothing,
    );
    final sectionText = tester.widget<Text>(crumbOf('财务'));
    expect(sectionText.style?.color, equals(YucaiTheme.light().muted));

    // current 段:加粗不可点。
    final currentText = tester.widget<Text>(crumbOf('平安现金分期'));
    expect(currentText.style?.fontWeight, greaterThanOrEqualTo(FontWeight.w700));
    expect(
      find.ancestor(
          of: crumbOf('平安现金分期'), matching: find.byType(InkWell)),
      findsNothing,
    );
  });

  testWidgets('FR-2 加载中占位:detail 形态且标题 null 时当前级显「…」,page 级可回退',
      (tester) async {
    // T4 起 detail 页加载完成即注入标题;要钉「加载中」占位,get 桩悬置
    // (永不完成,无 timer)—— 页面停在 DebtLoading,标题 port 保持 null。
    when(() => getIt<DebtRepository>().get(any())).thenAnswer(
        (_) => Completer<dartz.Either<Failure, DebtDetail>>().future);
    await pumpAt(tester, '/debts/d-42');

    expect(crumbOf('…'), findsOneWidget, reason: '标题未注入 = 加载中占位');
    // page 级链接来自 branch 元数据静态数据,不依赖标题 → 可点回退。
    expect(
      find.ancestor(of: crumbOf('债务管理'), matching: find.byType(InkWell)),
      findsOneWidget,
    );
  });

  testWidgets('FR-1 非 detail 形态:两段(列表页)与单级(仪表盘),无第三段',
      (tester) async {
    await pumpAt(tester, '/debts');
    expect(crumbOf('财务'), findsOneWidget);
    expect(crumbOf('债务管理'), findsOneWidget);
    expect(crumbOf('…'), findsNothing, reason: '列表页非 detail 形态,不显第三段');

    final router = await pumpAt(tester, '/home');
    expect(locationOf(router), '/home');
    expect(crumbOf('仪表盘'), findsOneWidget);
    expect(crumbOf('财务'), findsNothing, reason: 'section 空 → 单级面包屑');
  });

  testWidgets('FR-1 page 段 tap → go 列表 root(详情栈清理)', (tester) async {
    final router = await pumpAt(tester, '/debts/d-42');
    expect(locationOf(router), '/debts/d-42');

    await tester.tap(crumbOf('债务管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(locationOf(router), '/debts', reason: '面包屑 page 级回退到列表 root');
  });

  testWidgets('FR-7/ADR-3 FormLeaveGate veto=false:page 段 tap 不导航',
      (tester) async {
    final router = await pumpAt(tester, '/debts/d-42');

    final gate = getIt<FormLeaveGate>();
    var asked = 0;
    gate.register(() async {
      asked++;
      return false; // 脏表单:拦下离开。
    });

    await tester.tap(crumbOf('债务管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(asked, 1, reason: 'onTap 必须经 gate.mayLeave 问询');
    expect(locationOf(router), '/debts/d-42', reason: 'veto=false 中止导航');
  });

  testWidgets('FR-2 离开 detail(go 跨分支):显示层零残留 + port 保留,返回自动恢复',
      (tester) async {
    final router = await pumpAt(tester, '/debts/d-42');
    // T4 接线:detail 页加载完成注入 counterparty(此处不手动 set,走页面真实路径)。
    await tester.pump(const Duration(milliseconds: 100));
    expect(crumbOf('招商银行'), findsOneWidget);

    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // 显示层:/home 非 detail 形态,第三段不渲染(占位与旧标题均不显)。
    expect(crumbOf('…'), findsNothing, reason: '非 detail 形态不显第三段');
    expect(crumbOf('招商银行'), findsNothing, reason: '顶栏不残留上一实体标题');
    // M2 核心断言:非 detail 目的地不清值。IndexedShell 下 branch 3 的
    // detail 页保留挂载(不 dispose → 页面侧 clear 不触发),旧「location
    // 一变即清」语义在此清值 → 返回时页面无加载事件重发,标题永停「…」;
    // M2 保留值 → 返回即恢复。此断言在旧语义下转红(M2 的价值证明)。
    expect(getIt<ShellDetailTitle>().value, '招商银行',
        reason: '非 detail 目的地不清值(供返回原 detail 恢复)');

    // 返回原 detail:实体 key 未变 → 不清,保留值直接恢复显示。
    router.go('/debts/d-42');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(crumbOf('招商银行'), findsOneWidget, reason: '返回 detail:保留值自动恢复');
  });

  testWidgets('FR-2 push 离开再 pop 回:port 保留值,标题自动恢复(评审场景)',
      (tester) async {
    final router = await pumpAt(tester, '/debts/d-42');
    await tester.pump(const Duration(milliseconds: 100));
    expect(crumbOf('招商银行'), findsOneWidget);

    // push(非 go):detail 页保留在栈内 —— 不 dispose(页面侧 clear 不触发)、
    // 亦无加载事件重发。shell 的 GoRouterState 反映 push(与
    // currentConfiguration 不同源),故 scrubber 会看到「离开 detail 到非
    // detail」—— 旧「location 一变即清」语义下 pop 回来标题永停「…」,
    // M2 保留值则自动恢复。注:push 目标取同分支兄弟叶子 '/debts/new'
    // (go_router 14.6.2:push 不切 shell branch、push 祖先路由是 no-op,
    // 均经 scratch 诊断确认;跨分支 push 本版本不可达)。
    unawaited(router.push('/debts/new'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(shellLocationOf(tester), '/debts/new');
    expect(locationOf(router), '/debts/d-42',
        reason: 'currentConfiguration 不反映 push(14.6.2 契约,防升级回归锚)');

    // 非 detail 停留:显示层零泄漏 + port 值保留(M2 精确清零:不清)。
    expect(crumbOf('…'), findsNothing);
    expect(crumbOf('招商银行'), findsNothing);
    expect(getIt<ShellDetailTitle>().value, '招商银行',
        reason: '非 detail 目的地不清值(供 pop 回原 detail 恢复)');

    // pop 回原 detail:实体 key 未变 → 不清,保留值直接恢复显示,
    // 无需任何页面侧重发事件。
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(shellLocationOf(tester), '/debts/d-42');
    expect(crumbOf('招商银行'), findsOneWidget,
        reason: 'pop 回原 detail:key 同不清,保留值自动恢复');
  });

  testWidgets('FR-6 债权 detail 回归全局 _TopBar(特例移除)', (tester) async {
    await pumpAt(tester, '/receivables/r-42');

    // 此前 _isReceivableDetail 隐藏全局顶栏;移除后 _TopBar 恒在(毛玻璃)。
    expect(find.byType(BackdropFilter), findsWidgets);
    expect(crumbOf('财务'), findsOneWidget);
    expect(crumbOf('债权管理'), findsOneWidget);
    // T4 起债权详情加载完成即注入 counterparty(FR-2+FR-6 完整闭环:
    // 全局顶栏呈现「财务 › 债权管理 › <counterparty>」)。
    expect(crumbOf('招商银行'), findsOneWidget, reason: 'detail 页注入的当前级');
  });

  testWidgets('FR-1 compact 顶栏(<1100)面包屑同样可点回退', (tester) async {
    final router =
        await pumpAt(tester, '/debts/d-42', logical: const Size(1000, 900));
    expect(locationOf(router), '/debts/d-42');

    await tester.tap(crumbOf('债务管理'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(locationOf(router), '/debts', reason: '窄屏同构,无断点特判');
  });

  testWidgets('FR-2 负向:静态子路由与深层路由非 detail 形态,不显第三段占位',
      (tester) async {
    // /accounts/templates 路由 create getIt<TemplateBloc>()(照 router_test
    // 先例:mock repo + 工厂注册,空模板表)。
    final templateRepo = _MockTemplateRepo();
    when(() => templateRepo.list(paused: any(named: 'paused')))
        .thenAnswer((_) async => const dartz.Right(<Template>[]));
    getIt.registerFactory<TemplateBloc>(() => TemplateBloc(templateRepo));

    await pumpAt(tester, '/accounts/templates');
    // 顺带钉 location 覆盖 branch 元数据的面包屑口径(F14 既有行为)。
    expect(crumbOf('交易'), findsOneWidget,
        reason: '面包屑按 location 覆盖(accounts branch 下显「交易 › 订阅管理」)');
    expect(crumbOf('订阅管理'), findsOneWidget);
    expect(crumbOf('…'), findsNothing,
        reason: 'templates 段不含数字(静态子路由)→ 非 detail 形态');

    // 深层路由 /debts/:id/edit(4 段)→ 非 detail(编辑表单维持两段口径)。
    await pumpAt(tester, '/debts/d-42/edit');
    expect(crumbOf('财务'), findsOneWidget);
    expect(crumbOf('债务管理'), findsOneWidget);
    expect(crumbOf('…'), findsNothing, reason: ':id/edit 段数不符 → 非 detail 形态');
  });

  testWidgets('FR-2 detail→detail 切换同样清零,占位「…」重现(scrubber 核心场景)',
      (tester) async {
    // T4 起 detail 页加载完成即注入标题;本测试钉 scrubber 在「新页面 set
    // 前」的清零语义,get 桩悬置让新详情停在加载态(否则新页面会注入自身
    // counterparty,清零窗口不可观测)。
    when(() => getIt<DebtRepository>().get(any())).thenAnswer(
        (_) => Completer<dartz.Either<Failure, DebtDetail>>().future);
    final router = await pumpAt(tester, '/debts/d-42');
    getIt<ShellDetailTitle>().set('平安现金分期');
    await tester.pump();
    expect(crumbOf('平安现金分期'), findsOneWidget);

    router.go('/debts/d-43');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(getIt<ShellDetailTitle>().value, isNull,
        reason: 'location-diff 清零对 detail→detail 同样触发(新页面 set 前不残留)');
    expect(crumbOf('平安现金分期'), findsNothing);
    expect(crumbOf('…'), findsOneWidget, reason: '新详情加载中 → 占位「…」重现');
  });

  testWidgets('I-1 跨分支回退:debt → receivable → go 回 debt,标题重注入',
      (tester) async {
    // 桩按 id 分流:两侧 counterparty 不同,才能证明回退后是「重注入的本页
    // 值」而非残留(分支冻结不重拉;若实现改为重建分支,分流桩对冻结/重建
    // 两语义均成立)。
    when(() => getIt<DebtRepository>().get(any())).thenAnswer((inv) async {
      final id = inv.positionalArguments.single as String;
      return dartz.Right(id == 'r-42'
          ? _debtDetail(counterparty: '王五 · 应收')
          : _debtDetail(counterparty: '招商银行'));
    });
    final router = await pumpAt(tester, '/debts/d-42');
    expect(crumbOf('招商银行'), findsOneWidget);

    // 跨分支去债权详情:其页加载完成注入自身 counterparty。
    router.go('/receivables/r-42');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(crumbOf('王五 · 应收'), findsOneWidget);

    // go 回债务详情:分支回退 —— router builder 重跑,但冻结 bloc 无新
    // emission(listener-only 注入永不重放 → 标题永停「…」/残留他页值,
    // 即 I-1);DetailTitleSync 随 loaded 分支重建 → 帧回调重注入。
    router.go('/debts/d-42');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(crumbOf('招商银行'), findsOneWidget, reason: '分支回退后重注入本页标题');
    expect(crumbOf('王五 · 应收'), findsNothing);
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
