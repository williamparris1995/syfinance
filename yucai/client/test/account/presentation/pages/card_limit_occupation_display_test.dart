// F50 Task C — TDD RED:卡贷额度占用「显示注入」两页 widget 测试。
//
// 口径(spec FR-1/FR-3,design ADR-3/U4):信用卡的「已用」= abs(欠款) +
// cardLoanOccupationCents(仅剩余本金,开关过滤;TA 纯函数保证),「可用」=
// limit − 已用。**display-only 铁律**:占用只进已用/可用/利用率,任何
// 余额/负债聚合/净资产路径逐分不变(测试三:同一数据切换某债开关,
// 总负债/净资产逐分一致,仅已用/利用率变化)。
//
// 平安校准 fixture(与 test/debt/domain/card_loan_occupation_test.dart 同源,
// 单位 cents):卡欠 31,963 + 占用 1,095,207(215,368+454,032+425,807 开;
// 2,968,344 关)+ limit 5,000,000
//   → 页面级已用 1,127,170(¥11,271.70)/ 可用 3,872,830(¥38,728.30)。
//
// 锚点选择:
//  - 账户页卡片:bar-meta 文本「已用 X / 额度」+ LinearProgressIndicator.value
//    (widget 层最深可锚的显示断言);
//  - 详情页四卡:stat 卡值文本(_fmtSigned 千分位形态);
//  - 净资产/总负债:accounts_page 汇总头(页面级负债聚合纯管道,与
//    dashboard net worth 同口径:负债 = 非债务欠款 + Σ 债务本息剩余)。
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

/// Fake CurrencyBloc(恒定 state;账户页 _GroupBlock watch 需要)。
class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

// ───────────────────────── fixtures(平安真值校准数) ─────────────────────────

/// 平安信用卡:欠款 31,963c(credit-正不变式),额度 5,000,000c。
Account _pinganCard() => const Account(
      id: 'pingan-card',
      name: '平安信用卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      institution: '平安银行',
      initialBalanceCents: 0,
      currentBalanceCents: 31963,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      creditLimitCents: 5000000,
    );

/// 招行信用卡:欠款 12,400c,额度 800,000c(e招贷未挂接对照卡)。
Account _cmbCard() => const Account(
      id: 'cmb-card',
      name: '招行信用卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      institution: '招商银行',
      initialBalanceCents: 0,
      currentBalanceCents: 12400,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      creditLimitCents: 800000,
    );

/// 卡贷 fixture(subtype=card_loan,挂接 [cardId];accountId 指向载体贷款户,
/// 不与展示账户碰撞 —— 与 F48 生产形态一致)。
Debt _cardLoan(
  String id,
  int remainingCents, {
  String? cardId,
  bool countsTowardCardLimit = true,
}) =>
    Debt(
      id: id,
      accountId: 'loan-$id',
      counterparty: '银行$id',
      interestRate: 3,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2027, 1, 1),
      totalPrincipalCents: remainingCents,
      remainingPrincipalCents: remainingCents,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      subtype: DebtSubtypes.cardLoan,
      collectionAccountId: cardId,
      countsTowardCardLimit: countsTowardCardLimit,
    );

/// 平安四债:三笔挂接开(215,368/454,032/425,807)+ 备用金关(2,968,344,
/// 独立额度不占卡)。[caiZhiTongOn] 控制财智通开关(display-only 对照用)。
List<Debt> _pinganDebts({bool caiZhiTongOn = true}) => [
      _cardLoan('e-zhi', 215368, cardId: 'pingan-card'),
      _cardLoan('wan-yong-jin', 454032, cardId: 'pingan-card'),
      _cardLoan('cai-zhi-tong', 425807,
          cardId: 'pingan-card', countsTowardCardLimit: caiZhiTongOn),
      _cardLoan('bei-yong-jin', 2968344,
          cardId: 'pingan-card', countsTowardCardLimit: false),
    ];

// ───────────────────────── harness:共享 GetIt 注册 ─────────────────────────
//
// 注册纪律(库内先例:accounts_page_test/account_detail_page_test):仓库
// mock 在 setUp 注册一次、tearDown 统一 reset(get_it 7.7 的 reset() 是
// async,清空落在本测试的微任务里 —— 测试体内 reset+重注册会被这次延迟
// 清空抹掉,故**禁止**在测试体内 reset)。display-only 双 pump 靠 mocktail
// 对同一 mock 重打 stub 切换数据,不动 GetIt。

late _MockDebtRepo _debtRepo;
late _MockAccountRepo _accountRepo;
late _MockTxnRepo _txnRepo;

// ───────────────────────── harness:accounts_page ─────────────────────────

/// 挂 AccountsPage(自带 AccountBloc);每次调用对共享 debtRepo 重打 stub
/// 返回 [debts](双 pump 切换数据靠重打 stub,不 reset GetIt)。
/// 单卡夹具:一张 creditCard 一条 LinearProgressIndicator,bar 可唯一定位。
Future<void> pumpAccountsPage(
  WidgetTester t,
  List<Debt> debts, {
  List<Account> accounts = const [],
}) async {
  when(() => _debtRepo.list()).thenAnswer((_) async => dartz.Right(debts));

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

  // UniqueKey:每次 pump 都整树重挂 —— initState/_loadDebts 重跑,读到的
  // 是本次重打的 debts stub(display-only 双 pump 的数据切换靠这个,不靠
  // in-place update 保留旧 State)。
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

// ───────────────────────── harness:account_detail_page ─────────────────────────

/// 挂 AccountDetailPage(账户 [account] + 卡贷 [debts],无账单日 → 四卡走
/// 额度回退路径;无 AppDatabase → breakdown 恒 null,断言不受周期面板干扰)。
/// 每次调用对共享 mocks 重打 stub(双 pump 切换数据,不 reset GetIt)。
Future<void> pumpDetailPage(
  WidgetTester t, {
  required Account account,
  List<Debt> debts = const [],
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
  // (_loadRepaymentPlans,卡贷经 collectionAccountId 挂卡并入 plans)。
  when(() => _debtRepo.list()).thenAnswer((_) async => dartz.Right(debts));
  when(() => _debtRepo.list(typeFilter: any(named: 'typeFilter')))
      .thenAnswer((_) async => dartz.Right(debts));
  for (final d in debts) {
    when(() => _debtRepo.get(d.id)).thenAnswer(
        (_) async => dartz.Right(DebtDetail(debt: d, schedule: const [])));
  }

  final listUc = _MockList();
  final createUc = _MockCreate();
  final deleteUc = _MockDelete();
  final getUc = _MockGet();
  final updateUc = _MockUpdate();
  when(() => getUc.call(any())).thenAnswer((_) async => dartz.Right(account));
  when(() => listUc.call())
      .thenAnswer((_) async => dartz.Right(<Account>[account]));

  // UniqueKey:每次 pump 都整树重挂(display-only 双 pump 数据切换,同
  // pumpAccountsPage 注),ListView 滚动位也随重挂复位。
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
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
    registerFallbackValue(DebtType.borrowedIn);
    // 本页 initState 订阅 DataRefreshNotifier;详情页/列表页直取三仓库。
    GetIt.instance
        .registerLazySingleton<DataRefreshNotifier>(DataRefreshNotifier.new);
    GetIt.instance.registerSingleton<DebtRepository>(_debtRepo);
    GetIt.instance.registerSingleton<AccountRepository>(_accountRepo);
    GetIt.instance.registerSingleton<TransactionRepository>(_txnRepo);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  // ───────────── 账户页卡片(bar-meta 已用 + 利用率条) ─────────────

  group('F50 accounts_page 卡片:已用/利用率计入卡贷占用', () {
    // desktop 视口:_fullCard 分支渲染 bar-meta「已用 X / 额度」。
    Future<void> pinDesktop(WidgetTester t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
    }

    testWidgets('平安校准:已用 = 欠款 31,963 + 占用 1,095,207 → ¥11,271.70',
        (t) async {
      await pinDesktop(t);
      await pumpAccountsPage(t, _pinganDebts(), accounts: [_pinganCard()]);
      // bar-meta:已用 ¥11,271.70 / 额度 ¥50,000.00(1,127,170 / 5,000,000)。
      expect(find.text('已用 ¥11,271.70 / ¥50,000.00'), findsOneWidget);
      // 利用率条分子同式:1,127,170/5,000,000 ≈ 0.2254(单卡 → 唯一 bar)。
      final bar = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(0.225434, 0.001));
    });

    testWidgets('e招贷未挂接(collectionAccountId 空)→ 招行卡已用不变',
        (t) async {
      await pinDesktop(t);
      await pumpAccountsPage(t, [
        _cardLoan('e-dai', 2606286, cardId: null), // e招贷,独立账单不挂卡
      ], accounts: [_cmbCard()]);
      // 招行卡:已用仍 = 欠款 ¥124.00(e招贷 2,606,286c 不计入)。
      expect(find.text('已用 ¥124.00 / ¥8,000.00'), findsOneWidget);
      final bar = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(12400 / 800000, 0.001));
    });

    // display-only 铁律:同一数据切换财智通开关,总负债/净资产逐分不变
    // (负债聚合 = 非债务欠款 31,963 + Σ四债本息剩余 4,063,551 = 4,095,514c,
    // 与开关无关);仅已用/利用率变化(占用 1,095,207 ↔ 669,400)。
    testWidgets('display-only:债开关切换 → 总负债/净资产逐分不变,仅已用/利用率变',
        (t) async {
      await pinDesktop(t);

      // 变体 A(财智通开):已用 1,127,170 / 占用全额。
      await pumpAccountsPage(t, _pinganDebts(caiZhiTongOn: true),
          accounts: [_pinganCard()]);
      expect(find.text('已用 ¥11,271.70 / ¥50,000.00'), findsOneWidget);
      expect(find.text('¥40,955.14'), findsOneWidget,
          reason: '总负债 = 卡欠 319.63 + 四债剩余 40,635.51');
      expect(find.text('-¥40,955.14'), findsOneWidget,
          reason: '净资产 = 0 资产 − 总负债 4,095,514c');
      final barOn = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));

      // 变体 B(财智通关):同一批债仅 countsTowardCardLimit 翻转。
      await pumpAccountsPage(t, _pinganDebts(caiZhiTongOn: false),
          accounts: [_pinganCard()]);
      expect(find.text('已用 ¥7,013.63 / ¥50,000.00'), findsOneWidget,
          reason: '已用 = 31,963 + 占用 669,400 = 701,363c');
      // 聚合/净资产逐分一致(display-only 铁律)。
      expect(find.text('¥40,955.14'), findsOneWidget,
          reason: 'display-only:总负债不得随占用开关变化');
      expect(find.text('-¥40,955.14'), findsOneWidget,
          reason: 'display-only:净资产不得随占用开关变化');
      final barOff = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));

      // 利用率变化:0.2254 → 0.1403(仅显示层口径变化)。
      expect(barOn.value, closeTo(0.225434, 0.001));
      expect(barOff.value, closeTo(0.140273, 0.001));
      expect(barOn.value, isNot(closeTo(barOff.value!, 0.001)));
    });
  });

  // ───────────── 详情页四卡(已用/可用额度) ─────────────

  group('F50 account_detail_page 四卡:已用/可用计入卡贷占用', () {
    /// 滚到四卡区(额度回退路径:信用额度/已用额度/可用额度/账单日)。
    Future<void> scrollToStats(WidgetTester t) async {
      await t.scrollUntilVisible(
        find.text('信用额度'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }

    testWidgets('平安校准:已用 ¥11,271.70 / 可用 ¥38,728.30(limit − 已用)',
        (t) async {
      await pumpDetailPage(t, account: _pinganCard(), debts: _pinganDebts());
      await scrollToStats(t);
      expect(find.text('已用额度'), findsOneWidget);
      expect(find.text('可用额度'), findsOneWidget);
      // 四卡值:_fmtSigned 千分位形态。
      expect(find.text('¥50,000.00'), findsOneWidget, reason: '信用额度不变');
      expect(find.text('¥11,271.70'), findsOneWidget,
          reason: '已用 = 欠款 31,963 + 占用 1,095,207');
      expect(find.text('¥38,728.30'), findsOneWidget,
          reason: '可用 = 5,000,000 − 1,127,170(spec FR 真值)');
    });

    testWidgets('e招贷未挂接(collectionAccountId 空)→ 招行卡已用/可用不变',
        (t) async {
      await pumpDetailPage(t, account: _cmbCard(), debts: [
        _cardLoan('e-dai', 2606286, cardId: null),
      ]);
      await scrollToStats(t);
      expect(find.text('¥124.00'), findsOneWidget,
          reason: '已用额度仍 = 欠款 12,400c');
      expect(find.text('¥7,876.00'), findsOneWidget,
          reason: '可用 = 800,000 − 12,400 = 787,600c');
    });

    // display-only 铁律(详情页侧):开关切换 → hero 欠款大字/信用额度卡
    // 逐分不变(余额路径零改动),仅已用/可用变化。
    testWidgets('display-only:债开关切换 → hero 欠款/信用额度不变,仅已用/可用变',
        (t) async {
      // hero 欠款大字锚点(ValueKey('heroBalance') 直接落在 Text 上;信用卡
      // credit-正 → _fmt 正数形态 '¥ 319.63')。
      String heroBalanceText() =>
          t.widget<Text>(find.byKey(const ValueKey('heroBalance'))).data!;

      // 变体 A(财智通开)。
      await pumpDetailPage(t, account: _pinganCard(), debts: _pinganDebts());
      expect(heroBalanceText(), '¥ 319.63',
          reason: 'hero 欠款大字 = 账户余额,不含占用');
      await scrollToStats(t);
      expect(find.text('¥11,271.70'), findsOneWidget);
      expect(find.text('¥38,728.30'), findsOneWidget);

      // 变体 B(财智通关):仅 countsTowardCardLimit 翻转。
      await pumpDetailPage(
          t, account: _pinganCard(), debts: _pinganDebts(caiZhiTongOn: false));
      expect(heroBalanceText(), '¥ 319.63',
          reason: 'display-only:余额显示不得随占用开关变化');
      await scrollToStats(t);
      expect(find.text('¥50,000.00'), findsOneWidget,
          reason: 'display-only:信用额度静态卡不变');
      expect(find.text('¥7,013.63'), findsOneWidget,
          reason: '已用随占用变化:31,963 + 669,400');
      expect(find.text('¥42,986.37'), findsOneWidget,
          reason: '可用随已用变化:5,000,000 − 701,363');
      // 变体 A 的已用/可用值不再出现(确证变化)。
      expect(find.text('¥11,271.70'), findsNothing);
      expect(find.text('¥38,728.30'), findsNothing);
    });
  });
}
