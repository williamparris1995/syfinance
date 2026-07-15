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
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
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

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    // mocktail any() 需要非原始类型的 fallback 值。
    registerFallbackValue(const ListTransactionsParams());
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
    final observer = _MockNavigatorObserver();
    await t.pumpWidget(_routerHarness(observer));
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
    final observer = _MockNavigatorObserver();
    await t.pumpWidget(_routerHarness(observer));
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('记一笔'));
    await t.tap(find.text('记一笔'));
    await t.pumpAndSettle();

    expect(find.text('txn_new'), findsOneWidget);
  });

  testWidgets('快捷操作:点「买入投资」→ 导航 /holdings/new', (t) async {
    final observer = _MockNavigatorObserver();
    await t.pumpWidget(_routerHarness(observer));
    await t.pumpAndSettle();

    await t.ensureVisible(find.text('买入投资'));
    await t.tap(find.text('买入投资'));
    await t.pumpAndSettle();

    expect(find.text('holdings_new'), findsOneWidget);
  });
}
