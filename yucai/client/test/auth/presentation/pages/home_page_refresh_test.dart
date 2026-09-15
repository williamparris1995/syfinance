// Hotfix(导入存档后 dashboard 全零)— HomePage 跨页刷新 widget 测试。
//
// 根因:home 在 StatefulShellRoute.indexedStack 分支内长期驻留,initState
// 一次性加载(AccountBloc Load + 净资产 + 3 摘要卡);设置页导入存档成功后
// 仅 toast,零通知 —— 首页空态永续(切回分支不重建不 didPopNext)。
//
// 修复契约:HomePage 订阅 getIt<DataRefreshNotifier>(ValueNotifier<int>),
// notifier.bump()(导入存档成功后由设置页触发)→ 重跑 initState 同组加载。
//
// 断言手段(mock 计数,不依赖 UI 文案;计数在 when 桩内自增 —— mocktail 的
// verify 会移除已验记录,同一 mock 上二次计数不可靠):
// - AccountBloc LoadAccountsRequested 再次发出 → accountRepo.list() 第二次调用;
// - _loadNetWorth 重跑 → NetWorthDataSource.getNetWorth 第二次调用;
// - _loadSummaryCards 重跑 → txnRepo.summary / budgetRepo.getBudgetByMonth /
//   goalRepo.listGoals 各第二次调用。
//
// harness 形态照 home_page_test._harness(getIt 注册假件 + MultiBlocProvider),
// 额外注册 DataRefreshNotifier 并把各 mock/计数器返回给测试断言。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/auth/presentation/pages/home_page.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
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
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}
class _MockHasCredentials extends Mock implements HasStoredCredentialsUseCase {}

/// 计数式假 NetWorthDataSource:getNetWorth 计数供断言(返回固定视图)。
class _CountingNetWorthDs extends Fake implements NetWorthDataSource {
  int calls = 0;

  @override
  Future<NetWorthView> getNetWorth({required String baseCurrency}) async {
    calls++;
    return NetWorthView(
      totalAssetsCents: 1200000,
      totalLiabilitiesCents: 300000,
      netWorthCents: 900000,
      currency: baseCurrency,
    );
  }
}

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
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockGoalRepo extends Mock implements GoalRepository {}

/// AuthBloc seeded Authenticated(home watch 显示名;照 home_page_test)。
class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
    emit(Authenticated(User(
      id: 'u1',
      tenantId: 't1',
      email: 't@example.com',
      displayName: '测试用户',
      avatarUrl: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    )));
  }
}

/// 刷新测试 harness:注册全量假件(空数据)并返回各计数器,测试对调用
/// 计数断言「bump 后 initState 同组加载重跑」。
({Widget app, DataRefreshNotifier notifier, _CountingNetWorthDs netWorthDs,
      int Function() accountListCalls, int Function() summaryCalls,
      int Function() budgetCalls, int Function() goalCalls})
    _refreshHarness() {
  final getIt = GetIt.instance;
  final netWorthDs = _CountingNetWorthDs();
  getIt.registerSingleton<NetWorthDataSource>(netWorthDs);
  getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings('CNY'));

  // 各 mock 的调用计数(when 桩内闭包自增,不受 verify 移除已验记录影响)。
  var accountListCalls = 0;
  var summaryCalls = 0;
  var budgetCalls = 0;
  var goalCalls = 0;

  final accountRepo = _MockAccountRepo();
  when(() => accountRepo.list()).thenAnswer((_) async {
    accountListCalls++;
    return const dartz.Right(<Account>[]);
  });

  final accountBloc = AccountBloc(
    ListAccountsUseCase(accountRepo),
    CreateAccountUseCase(accountRepo),
    DeleteAccountUseCase(accountRepo),
    GetAccountUseCase(accountRepo),
    UpdateAccountUseCase(accountRepo),
  );

  final txnRepo = _MockTxnRepo();
  when(() => txnRepo.list(any())).thenAnswer((_) async =>
      const dartz.Right(ListTransactionsResult(transactions: [])));
  when(() => txnRepo.summary(any(), any(),
          accountId: any(named: 'accountId'),
          scope: any(named: 'scope'),
          day: any(named: 'day')))
      .thenAnswer((_) async {
    summaryCalls++;
    return const dartz.Right(MonthlySummary(year: 2026, month: 7));
  });
  getIt.registerSingleton<TransactionRepository>(txnRepo);

  final debtRepo = _MockDebtRepo();
  when(() => debtRepo.upcomingPayments(any()))
      .thenAnswer((_) async => const dartz.Right(<Debt>[]));
  getIt.registerSingleton<DebtRepository>(debtRepo);

  final holdingRepo = _MockHoldingRepo();
  when(() => holdingRepo.listHoldings())
      .thenAnswer((_) async => const dartz.Right(<Holding>[]));
  getIt.registerSingleton<HoldingRepository>(holdingRepo);

  final budgetRepo = _MockBudgetRepo();
  when(() => budgetRepo.getBudgetByMonth(any())).thenAnswer((_) async {
    budgetCalls++;
    return const dartz.Left(ServerFailure('not found'));
  });
  getIt.registerSingleton<BudgetRepository>(budgetRepo);

  final goalRepo = _MockGoalRepo();
  when(() => goalRepo.listGoals(
          type: any(named: 'type'), completed: any(named: 'completed')))
      .thenAnswer((_) async {
    goalCalls++;
    return const dartz.Right(<GoalView>[]);
  });
  getIt.registerSingleton<GoalRepository>(goalRepo);

  // 被测通知器:HomePage 应订阅它,设置页导入存档成功后 bump。
  final notifier = DataRefreshNotifier();
  getIt.registerSingleton<DataRefreshNotifier>(notifier);

  return (
    app: MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: _SeededAuthedBloc()),
          BlocProvider<AccountBloc>.value(value: accountBloc),
        ],
        child: const HomePage(),
      ),
    ),
    notifier: notifier,
    netWorthDs: netWorthDs,
    accountListCalls: () => accountListCalls,
    summaryCalls: () => summaryCalls,
    budgetCalls: () => budgetCalls,
    goalCalls: () => goalCalls,
  );
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() {
    getIt.reset();
  });

  tearDown(() {
    getIt.reset();
  });

  testWidgets('导入存档通知(bump)→ 重跑 initState 同组加载(账户/净资产/摘要)',
      (t) async {
    final h = _refreshHarness();
    await t.pumpWidget(h.app);
    await t.pumpAndSettle();

    // 初始一次性加载:各 1 次。
    expect(h.netWorthDs.calls, 1);
    expect(h.accountListCalls(), 1);
    expect(h.summaryCalls(), 1);
    expect(h.budgetCalls(), 1);
    expect(h.goalCalls(), 1);

    // 模拟设置页导入存档成功后的通知。
    h.notifier.bump();
    await t.pumpAndSettle();

    // 同组加载全部重跑:各 2 次(AccountBloc LoadAccountsRequested 再次
    // 发出 → repo.list 第二次;_loadNetWorth + _loadSummaryCards 同理)。
    expect(h.netWorthDs.calls, 2);
    expect(h.accountListCalls(), 2);
    expect(h.summaryCalls(), 2);
    expect(h.budgetCalls(), 2);
    expect(h.goalCalls(), 2);
  });

  testWidgets('HomePage dispose 后 bump 不再重拉(监听已移除,无泄漏重载)', (t) async {
    final h = _refreshHarness();
    await t.pumpWidget(h.app);
    await t.pumpAndSettle();

    // 换走页面( HomePage 卸载,dispose 应移除监听)。
    await t.pumpWidget(const MaterialApp(home: Scaffold()));
    await t.pumpAndSettle();

    h.notifier.bump();
    await t.pumpAndSettle();

    // 卸载后 bump:零新增调用(仍只有初始的 1 次)。
    expect(h.netWorthDs.calls, 1);
    expect(h.accountListCalls(), 1);
  });
}
