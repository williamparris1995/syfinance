// F51 Task C — TDD RED:两页读侧统一派生(widget 测试,spec FR-3/FR-4,
// design ADR-2/U4)。
//
// 口径:
//  - 挂接 loan 账户 → 估值 = Σ债剩余本金(derivedLoanFields().remainingPrincipalCents);
//  - 挂接 investment 账户 → 估值 = Σ持仓市值(derivedInvestFields().totalMarketValueCents);
//  - 账户列仅未挂接时生效(FR-4:闭包返回 null → 原列读逻辑逐分不变);
//  - 负债聚合边界(ADR-2 grill):总负债/净资产维持既有「债源本息」口径
//    (remaining + unpaidInterest),本票不改 —— 测试④用利息>0 fixture 同帧
//    钉死(卡面估值 Σ本金 vs 汇总头总负债 Σ本息,两套口径各自稳定不串)。
//
// fixture 数字(spec FR-1 Scenario,单位 cents):两笔挂接债
//   d1: 总额 3,500,000 / 剩余本金 2,968,344
//   d2: 总额   910,000 / 剩余本金   454,032
//   Σ剩余本金 = 3,422,376(¥34,223.76)—— spec FR-3 Scenario 的「派生」数。
//
// harness 注册纪律(照 card_limit_occupation_display_test 先例):仓库 mock
// 在 setUp 注册一次、tearDown 统一 reset,测试体内禁止 reset(重打 stub 切数据)。
import 'package:dartz/dartz.dart' as dartz;
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
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/account/presentation/pages/accounts_page.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}
class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockHoldingRepo extends Mock implements HoldingRepository {}

/// Fake CurrencyBloc(恒定 state;账户页/分组块 watch 需要)。
class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

// ───────────────────────── fixtures(spec FR-1/FR-3 校准数) ─────────────────────────

/// 挂接借入债 fixture(单位 cents;subtype 缺省 = 普通挂账户债)。
Debt _specDebt(
  String id,
  String accountId, {
  required int total,
  required int remaining,
  int unpaidInterest = 0,
}) =>
    Debt(
      id: id,
      accountId: accountId,
      counterparty: '工商银行',
      interestRate: 3.9,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2024, 1, 1),
      dueDate: DateTime(2054, 12, 1),
      totalPrincipalCents: total,
      remainingPrincipalCents: remaining,
      unpaidInterestCents: unpaidInterest,
      version: 1,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

/// spec FR-1 Scenario 两笔挂接债:Σ剩余本金 = 2,968,344 + 454,032
/// = 3,422,376 cents(¥34,223.76)。
List<Debt> _specDebts(String accountId, {int unpaidInterest = 0}) => [
      _specDebt('d1', accountId,
          total: 3500000, remaining: 2968344, unpaidInterest: unpaidInterest),
      _specDebt('d2', accountId,
          total: 910000, remaining: 454032, unpaidInterest: unpaidInterest),
    ];

/// 挂债贷款账户:loan 组列全部陈旧(剩余列 = 0)—— spec FR-3 Scenario 前提。
Account _staleLoan() => const Account(
      id: 'l1',
      name: '房贷',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      loanOriginalCents: 0,
      loanRemainingCents: 0, // 列陈旧为 0(不得污染估值)
    );

/// 挂持仓投资账户:invest 组列 stale(全空)。
Account _staleInvest() => const Account(
      id: 'i1',
      name: '证券账户',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// 持仓 fixture:marketValueCents 已是 DS 投影口径(live price 优先、缺价退
/// avgCost),本票消费该投影不另算价。
Holding _holding(String id, String accountId, {required int mv}) => Holding(
      id: id,
      accountId: accountId,
      securityId: 'sec-$id',
      securityName: '基金$id',
      securitySymbol: 'F$id',
      quantity: 100,
      avgCostCents: 1000,
      marketValueCents: mv,
      unrealizedPnlCents: mv - 100000,
      version: 1,
    );

/// i1 名下两持仓:Σ市值 = 1,234,567 + 2,345,678 = 3,580,245 cents(¥35,802.45);
/// 外加一笔他户持仓(不得计入 i1)。
List<Holding> _investHoldings() => [
      _holding('h1', 'i1', mv: 1234567),
      _holding('h2', 'i1', mv: 2345678),
      _holding('h9', 'elsewhere', mv: 999999),
    ];

// ───────────────────────── harness(共享 GetIt 注册) ─────────────────────────

late _MockDebtRepo _debtRepo;
late _MockAccountRepo _accountRepo;
late _MockTxnRepo _txnRepo;
late _MockHoldingRepo _holdingRepo;

/// 钉视口(desktop 卡片分支 + 宽卡单行;[tall] 供多分组/长页全量构建)。
Future<void> _pin(WidgetTester t, {bool tall = false}) async {
  t.view.physicalSize = tall ? const Size(1400, 3400) : const Size(1400, 900);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

/// 挂 AccountsPage(自带 AccountBloc);每次调用对共享 debt/holding mock 重打
/// stub(双 pump 切数据,不 reset GetIt)。
Future<void> pumpAccountsPage(
  WidgetTester t, {
  required List<Account> accounts,
  List<Debt> debts = const [],
  List<Holding> holdings = const [],
}) async {
  when(() => _debtRepo.list()).thenAnswer((_) async => dartz.Right(debts));
  when(() => _holdingRepo.listHoldings())
      .thenAnswer((_) async => dartz.Right(holdings));

  final listUc = _MockList();
  final createUc = _MockCreate();
  final deleteUc = _MockDelete();
  final getUc = _MockGet();
  final updateUc = _MockUpdate();
  when(() => listUc.call())
      .thenAnswer((_) async => dartz.Right(<Account>[...accounts]));
  registerFallbackValue(const CreateAccountParams(
    name: '',
    accountType: AccountType.asset,
    category: AccountCategory.savings,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));
  registerFallbackValue(const UpdateAccountParams(id: '', version: 0));

  // UniqueKey:每次 pump 都整树重挂 —— initState/_loadDebts/_loadHoldings 重跑,
  // 读到的是本次重打的 stub。
  await t.pumpWidget(MaterialApp(
    key: UniqueKey(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AccountBloc>(
          create: (_) =>
              AccountBloc(listUc, createUc, deleteUc, getUc, updateUc),
        ),
        BlocProvider<CurrencyBloc>.value(
            value: _FakeCurrencyBloc(const CurrencyState())),
      ],
      child: const AccountsPage(),
    ),
  ));
  await t.pumpAndSettle();
}

/// 挂 AccountDetailPage(account + 挂接债/持仓;无 AppDatabase → 信用卡
/// breakdown 恒 null,断言不受周期面板干扰)。
Future<void> pumpDetailPage(
  WidgetTester t, {
  required Account account,
  List<Debt> debts = const [],
  List<Holding> holdings = const [],
}) async {
  when(() => _accountRepo.getById(any()))
      .thenAnswer((_) async => dartz.Right(account));
  when(() => _accountRepo.list())
      .thenAnswer((_) async => dartz.Right(<Account>[account]));
  when(() => _txnRepo.list(any())).thenAnswer((_) async =>
      const dartz.Right(
          ListTransactionsResult(transactions: [], nextPageToken: '')));
  when(() => _txnRepo.recentDescriptions())
      .thenAnswer((_) async => const dartz.Right(<String>[]));
  when(() => _txnRepo.summary(any(), any(),
          accountId: any(named: 'accountId'),
          scope: any(named: 'scope'),
          day: any(named: 'day')))
      .thenAnswer((_) async => const dartz.Right(MonthlySummary(
          year: 2026, month: 6, incomeCents: 0, expenseCents: 0, netCents: 0)));
  // 详情页两条债务管道:裸 list()(_loadLinkedDebt)与 typeFilter 版
  // (_loadRepaymentPlans)。
  when(() => _debtRepo.list()).thenAnswer((_) async => dartz.Right(debts));
  when(() => _debtRepo.list(typeFilter: any(named: 'typeFilter')))
      .thenAnswer((_) async => dartz.Right(debts));
  for (final d in debts) {
    when(() => _debtRepo.get(d.id)).thenAnswer(
        (_) async => dartz.Right(DebtDetail(debt: d, schedule: const [])));
  }
  // 持仓管道:listHoldings(accountId:) 按 accountId 过滤(忠实 repo 语义)。
  when(() => _holdingRepo.listHoldings())
      .thenAnswer((_) async => dartz.Right(holdings));
  when(() => _holdingRepo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((inv) async {
    final id = inv.namedArguments[#accountId] as String?;
    return dartz.Right(holdings.where((h) => h.accountId == id).toList());
  });

  final listUc = _MockList();
  final createUc = _MockCreate();
  final deleteUc = _MockDelete();
  final getUc = _MockGet();
  final updateUc = _MockUpdate();
  when(() => getUc.call(any())).thenAnswer((_) async => dartz.Right(account));
  when(() => listUc.call())
      .thenAnswer((_) async => dartz.Right(<Account>[account]));

  await t.pumpWidget(MaterialApp(
    key: UniqueKey(),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AccountBloc>(
          create: (_) {
            final b =
                AccountBloc(listUc, createUc, deleteUc, getUc, updateUc);
            b.add(GetAccountRequested(account.id));
            return b;
          },
        ),
        BlocProvider<TransactionBloc>(
          create: (_) {
            final b = TransactionBloc(_txnRepo);
            b.add(LoadTransactionsRequested(
                filter: TxnFilterState(accountId: account.id)));
            b.add(LoadSummaryRequested(
                year: DateTime.now().year,
                month: DateTime.now().month,
                accountId: account.id));
            return b;
          },
        ),
      ],
      child: AccountDetailPage(id: account.id),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  setUp(() {
    _debtRepo = _MockDebtRepo();
    _accountRepo = _MockAccountRepo();
    _txnRepo = _MockTxnRepo();
    _holdingRepo = _MockHoldingRepo();
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
    registerFallbackValue(DebtType.borrowedIn);
    // 本页 initState 订阅 DataRefreshNotifier;两页直取 debt/holding/account
    // 仓库(照 _loadDebts/_loadLinkedDebt 既有管道)。
    GetIt.instance
        .registerLazySingleton<DataRefreshNotifier>(DataRefreshNotifier.new);
    GetIt.instance.registerSingleton<DebtRepository>(_debtRepo);
    GetIt.instance.registerSingleton<AccountRepository>(_accountRepo);
    GetIt.instance.registerSingleton<TransactionRepository>(_txnRepo);
    GetIt.instance.registerSingleton<HoldingRepository>(_holdingRepo);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  // ───────── ① spec FR-3 Scenario:loan 列 stale=0 → 估值/汇总头显 Σ债剩余 ─────────

  group('① FR-3 loan:挂债 + loanRemainingCents 列 stale=0 → 派生估值', () {
    testWidgets(
        '账户页卡面估值与汇总头显示 Σ债剩余 ¥34,223.76(不显示 0)',
        (t) async {
      await _pin(t);
      await pumpAccountsPage(t,
          accounts: [_staleLoan()], debts: _specDebts('l1'));

      // 卡面主数字(「剩余本金」位)= Σ债剩余本金(派生);同帧汇总头总负债
      // 同数(本 fixture 无未还利息 → 债源本息 == Σ本金)。
      expect(find.text('¥34,223.76'), findsNWidgets(2),
          reason: '卡面估值 + 汇总头总负债均为 3,422,376c');
      // 分组小计与卡面同口径(小计是 Text.rich,须开 findRichText)。
      expect(find.textContaining('小计 ¥34,223.76', findRichText: true),
          findsOneWidget);
      expect(find.text('-¥34,223.76'), findsOneWidget,
          reason: '净资产 = 0 资产 − 3,422,376');
      // 陈旧列不污染:页面上唯一 ¥0.00 是空总资产位(loan 是负债),
      // 估值位不吃 stale 列的 0 回退。
      expect(find.text('¥0.00'), findsOneWidget);
    });
  });

  // ───────── ② FR-3 invest:列 stale → 卡面/总资产显 Σ持仓市值 ─────────

  group('② FR-3 invest:挂持仓 + invest 组列 stale → 派生估值', () {
    testWidgets('账户页卡面估值与汇总头总资产显示 Σ持仓市值 ¥35,802.45', (t) async {
      await _pin(t);
      await pumpAccountsPage(t,
          accounts: [_staleInvest()], holdings: _investHoldings());

      // 卡面「当前市值」+ 汇总头总资产 + 净资产(正值同串)= Σ持仓市值
      // 3,580,245c;他户持仓(h9 → elsewhere)不计入。
      expect(find.text('¥35,802.45'), findsNWidgets(3),
          reason: '卡面 + 总资产 + 净资产 = 1,234,567 + 2,345,678');
      expect(find.textContaining('小计 ¥35,802.45', findRichText: true),
          findsOneWidget);
      // 列 stale(空)不再回退 currentBalance(¥0.00)驱动估值位;
      // 页面上唯一 ¥0.00 是空负债的总负债位。
      expect(find.text('¥0.00'), findsOneWidget);
    });
  });

  // ───────── ③ FR-4:未挂接账户 numValue 输出逐分不变(对照断言) ─────────

  group('③ FR-4:未挂接账户估值读列逐分不变', () {
    /// 九账户矩阵(每 category 一户,loan 两形态:列有值/列 stale 回退)。
    /// 期望值 = F51 前旧 numValue 逻辑的手工对照值(钉死逐分不变)。
    List<Account> matrix() => [
          const Account(
              id: 's1',
              name: '招行储蓄',
              accountType: AccountType.asset,
              category: AccountCategory.savings,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 1200000,
              ownership: Ownership.personal,
              status: AccountStatus.active),
          const Account(
              id: 'i1',
              name: '华泰证券',
              accountType: AccountType.asset,
              category: AccountCategory.investment,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 0,
              ownership: Ownership.personal,
              status: AccountStatus.active,
              investMarketValueCents: 5000000,
              investCostCents: 4000000,
              investReturnYtd: 8.25),
          const Account(
              id: 'i2',
              name: '未估值投资',
              accountType: AccountType.asset,
              category: AccountCategory.investment,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 800000,
              ownership: Ownership.personal,
              status: AccountStatus.active),
          const Account(
              id: 'g1',
              name: '实物黄金',
              accountType: AccountType.asset,
              category: AccountCategory.goldFx,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 0,
              ownership: Ownership.personal,
              status: AccountStatus.active,
              goldQuantity: 10.0,
              goldCurrentPriceCents: 60000),
          const Account(
              id: 'e1',
              name: '自住房',
              accountType: AccountType.asset,
              category: AccountCategory.realEstate,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 0,
              ownership: Ownership.personal,
              status: AccountStatus.active,
              estateCurrentValueCents: 36000000),
          const Account(
              id: 'f1',
              name: '大额存单',
              accountType: AccountType.asset,
              category: AccountCategory.fixedDeposit,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 0,
              ownership: Ownership.personal,
              status: AccountStatus.active,
              fixedPrincipalCents: 2000000),
          Account(
              id: 'l1',
              name: '房贷',
              accountType: AccountType.liability,
              category: AccountCategory.loan,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 0,
              ownership: Ownership.personal,
              status: AccountStatus.active,
              loanOriginalCents: 10000000,
              loanRemainingCents: 4000000,
              loanMonthlyCents: 500000,
              loanNextPaymentDate: DateTime(2026, 7, 1)),
          const Account(
              id: 'l2',
              name: '旧贷款',
              accountType: AccountType.liability,
              category: AccountCategory.loan,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 15000,
              ownership: Ownership.personal,
              status: AccountStatus.active,
              loanRemainingCents: 0 // 列 0 → 旧逻辑回退 currentBalance
              ),
          const Account(
              id: 'c1',
              name: '招行信用卡',
              accountType: AccountType.liability,
              category: AccountCategory.creditCard,
              currencyCode: 'CNY',
              initialBalanceCents: 0,
              currentBalanceCents: 300000,
              ownership: Ownership.personal,
              status: AccountStatus.active,
              creditLimitCents: 5000000),
        ];

    /// 断言矩阵([aggregates] = 是否连汇总头一起钉;variant b 的 foreign 债
    /// 会按债源口径合法计入总负债,负债侧两数跳过)。
    Future<void> expectMatrix(WidgetTester t, {bool aggregates = true}) async {
      // 各 category 卡面主数字 = 旧 numValue 逐分对照值。
      expect(find.text('¥12,000.00'), findsOneWidget, reason: 'savings→余额');
      expect(find.text('¥50,000.00'), findsOneWidget,
          reason: 'invest→investMarketValueCents 列');
      expect(find.text('¥8,000.00'), findsOneWidget,
          reason: 'invest 列空→回退 currentBalance');
      expect(find.text('¥6,000.00'), findsOneWidget,
          reason: 'gold→现价×数量(60000×10)');
      expect(find.text('¥360,000.00'), findsOneWidget,
          reason: 'realEstate→estateCurrentValueCents');
      expect(find.text('¥20,000.00'), findsOneWidget,
          reason: 'fixedDeposit→fixedPrincipalCents');
      expect(find.text('¥40,000.00'), findsOneWidget,
          reason: 'loan→loanRemainingCents 列');
      expect(find.text('¥150.00'), findsOneWidget,
          reason: 'loan 列 0→回退 currentBalance');
      expect(find.text('¥3,000.00'), findsOneWidget,
          reason: 'creditCard→currentBalance');
      // 汇总头(资产全走旧列读口径):
      // 总资产 = 1,200,000+5,000,000+800,000+600,000+36,000,000+2,000,000
      //        = 45,600,000;总负债 = 非债负债余额 15,000+300,000 = 315,000;
      // 净资产 = 45,285,000。
      expect(find.text('¥456,000.00'), findsOneWidget);
      if (aggregates) {
        expect(find.text('¥3,150.00'), findsOneWidget);
        expect(find.text('¥452,850.00'), findsOneWidget);
      }
    }

    testWidgets('仓库无数据(裸挂载)→ 全 category 卡面/汇总头逐分不变', (t) async {
      await _pin(t, tall: true); // 九账户七分组,长视口全量构建
      await pumpAccountsPage(t, accounts: matrix());
      await expectMatrix(t);
    });

    testWidgets('仓库有数据但未挂接本账户 → 输出同样逐分不变', (t) async {
      await _pin(t, tall: true);
      await pumpAccountsPage(t, accounts: matrix(), debts: [
        // 债挂在他处(elsewhere):本矩阵 loan 户不挂接;卡面读列不变。
        _specDebt('dx', 'elsewhere', total: 9999999, remaining: 999999),
      ], holdings: [
        _holding('h9', 'elsewhere', mv: 999999),
      ]);
      // foreign 债按债源口径合法计入总负债(999,999c),负债侧两数跳过;
      // 估值位(卡面/总资产)不变。
      await expectMatrix(t, aggregates: false);
    });
  });

  // ───────── ④ 跨页一致:同账户 accounts_page 卡面 == 详情 hero(逐分) ─────────

  group('④ 跨页一致(accounts_page 卡面 == account_detail hero)', () {
    testWidgets(
        'loan 挂债(有未还利息):两页均为 Σ剩余本金 ¥34,223.76;'
        '总负债保持债源本息 ¥35,223.76(ADR-2 口径边界)', (t) async {
      await _pin(t);
      // accounts 页:卡面估值 = 派生 Σ剩余本金;**不是** F50 期本息聚合
      // (3,522,376c)—— 估值口径与表单(TB)/详情 hero 逐分一致。
      await pumpAccountsPage(t,
          accounts: [_staleLoan()],
          debts: _specDebts('l1', unpaidInterest: 50000));
      expect(find.text('¥34,223.76'), findsOneWidget,
          reason: 'accounts 卡面 = Σ剩余本金 3,422,376c(派生,非本息 3,522,376c)');
      // 口径边界(ADR-2 grill):总负债/净资产维持债源本息口径,本票不改。
      expect(find.text('¥35,223.76'), findsOneWidget,
          reason: '总负债 = Σ本息 3,422,376 + 2×50,000(债源口径)');
      expect(find.text('-¥35,223.76'), findsOneWidget);

      // 详情页 hero:同 fixture 逐分一致(3,422,376c;_fmt 无千分位、
      // 符号后带空格)。
      await pumpDetailPage(t,
          account: _staleLoan(),
          debts: _specDebts('l1', unpaidInterest: 50000));
      expect(
          t.widget<Text>(find.byKey(const ValueKey('heroBalance'))).data,
          '¥ 34223.76',
          reason: '详情 hero 与 accounts 卡面同数(Σ剩余本金,逐分一致)');
    });

    testWidgets('invest 挂持仓:两页均为 Σ持仓市值 ¥35,802.45;详情 hero 字段/四卡/信息卡同源',
        (t) async {
      await _pin(t, tall: true); // 详情页长内容(四卡/信息卡/占位面板)全量构建
      // accounts 页:卡面「当前市值」= Σ持仓市值。
      await pumpAccountsPage(t,
          accounts: [_staleInvest()], holdings: _investHoldings());
      expect(find.text('¥35,802.45'), findsNWidgets(3),
          reason: 'accounts 卡面 + 总资产 + 净资产 = 3,580,245c');

      // 详情页:hero 大数字/标签 + hero-fields 市值 + 四卡当前市值 + 信息卡市值
      // 全部走派生(与 accounts 卡面同源)。
      await pumpDetailPage(t,
          account: _staleInvest(), holdings: _investHoldings());
      expect(find.text('当前市值'), findsNWidgets(2),
          reason: 'hero 标签(挂接 → 当前市值)+ stats 四卡标签');
      expect(t.widget<Text>(find.byKey(const ValueKey('heroBalance'))).data,
          '¥ 35802.45',
          reason: '详情 hero 与 accounts 卡面同数(Σ持仓市值,逐分一致)');
      // hero-fields 市值(_fmt 口径,与 hero 大数字同串)。
      expect(find.text('¥ 35802.45'), findsNWidgets(2),
          reason: 'hero 大数字 + hero-fields「市值」');
      // stats 四卡「当前市值」+ 信息卡「市值」(_fmtSigned 千分位)。
      expect(find.text('¥35,802.45'), findsNWidgets(2),
          reason: 'stats 当前市值 + 信息卡 市值 = 派生 3,580,245c');
    });
  });

  // ───────── ⑤ 「持仓列表」占位面板不动(design NonGoals 显式排除) ─────────

  group('⑤ 占位面板:挂持仓态仍渲染「待 Holding 模块接入」', () {
    testWidgets('investment 详情页占位面板文本仍在(本票严禁触碰)', (t) async {
      await _pin(t, tall: true);
      await pumpDetailPage(t,
          account: _staleInvest(), holdings: _investHoldings());
      expect(find.text('持仓列表'), findsOneWidget);
      expect(find.text('待 Holding 模块接入'), findsOneWidget);
    });
  });
}
