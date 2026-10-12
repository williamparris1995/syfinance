// Task 1 (UI-align P0-1) — TDD widget tests for _AccountCard type-specific
// subline + progress bar by AccountCategory.
//
// The _AccountCard widget is private inside accounts_page.dart, so tests drive
// the public AccountsPage via a mocked AccountBloc that emits AccountsLoaded.
// Each test seeds one account per category, asserts the type-specific 副信息
// text and the progress bar presence/absence/color:
//   - savings: 利率（interestRate 有值时），无进度条
//   - creditCard: 额度 · 账单/还款日，已用额度红 bar
//   - investment: +X% 今年收益（正绿/负红），无 bar
//   - fixedDeposit: 到期日 · 利率，无 bar
//   - goldFx: 买入 · 涨幅，无 bar
//   - realEstate: 现估值 · 增值，无 bar
//   - loan: 原始 · 月供 · 下次还款，已还比例绿 bar
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/account_presets.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/account/presentation/pages/accounts_page.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    show AppDatabase;
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart'
    show AmortizationMethod;

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}
class _MockDebtRepo extends Mock implements DebtRepository {}

/// 挂借入债夹具(credit-正:remaining/unpaidInterest 均正数)。
Debt _debt(String id, String accountId,
        {int remaining = 50000000, int unpaidInterest = 3000000}) =>
    Debt(
      id: id,
      accountId: accountId,
      counterparty: '工商银行',
      interestRate: 3.9,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2024, 1, 1),
      dueDate: DateTime(2054, 12, 1),
      totalPrincipalCents: 100000000,
      remainingPrincipalCents: remaining,
      unpaidInterestCents: unpaidInterest,
      version: 1,
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

/// 到期候选可变 fake 源(照 due_candidate_provider_test 范式)。
class _FakeDueSource implements DueScheduleSource {
  _FakeDueSource(this.entries);
  List<DueScheduleEntry> entries;

  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async => entries;
}

/// 挂失存储 fake:恒无挂失(覆写查询,不触 drift —— testWidgets 的
/// FakeAsync 内 drift isolate 查询会挂起;库内先例:drift 仅用于纯 test())。
/// 传入的内存库永不打开(惰性连接),close 为无害 no-op。
class _NoDismissals extends ReminderDismissalStore {
  _NoDismissals() : super(AppDatabase(NativeDatabase.memory()));

  @override
  Future<Set<String>> dismissedEntryIds() async => const {};
}

/// Fake CurrencyBloc that holds a fixed state (no async event dispatch needed).
class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

Account _savings() => const Account(
      id: 's1',
      name: '招行储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      institution: '招商银行',
      initialBalanceCents: 0,
      currentBalanceCents: 1200000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      interestRate: 1.5,
    );

Account _credit() => const Account(
      id: 'c1',
      name: '招行信用卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      institution: '招商银行',
      initialBalanceCents: 0,
      currentBalanceCents: 300000, // 欠款 3000
      ownership: Ownership.personal,
      status: AccountStatus.active,
      creditLimitCents: 500000, // 额度 5000
      creditBillingDay: 5,
      creditRepaymentDay: 25,
    );

Account _investment() => const Account(
      id: 'i1',
      name: '证券账户',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      institution: '华泰',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      investReturnYtd: 8.25,
    );

Account _fixed() => Account(
      id: 'f1',
      name: '大额存单',
      accountType: AccountType.asset,
      category: AccountCategory.fixedDeposit,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      fixedMaturityDate: DateTime(2027, 6, 15),
      interestRate: 2.75,
    );

Account _gold() => const Account(
      id: 'g1',
      name: '实物黄金',
      accountType: AccountType.asset,
      category: AccountCategory.goldFx,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      goldProductType: 'Au9999',
      goldQuantity: 10.0,
      goldBuyPriceCents: 50000, // 买入 500/克
      goldCurrentPriceCents: 60000, // 现价 600/克
    );

Account _estate() => const Account(
      id: 'e1',
      name: '自住房',
      accountType: AccountType.asset,
      category: AccountCategory.realEstate,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      estatePurchasePriceCents: 300000000, // 300 万
      estateCurrentValueCents: 360000000, // 360 万
    );

Account _loan() => Account(
      id: 'l1',
      name: '房贷',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      loanOriginalCents: 100000000, // 100 万
      loanRemainingCents: 40000000, // 剩 40 万 → 已还 60%
      loanMonthlyCents: 500000, // 月供 5000
      loanNextPaymentDate: DateTime(2026, 7, 1),
    );

Account _account(
  String id,
  String name, {
  AccountCategory cat = AccountCategory.savings,
  int bal = 0,
  AccountType type = AccountType.asset,
}) =>
    Account(
      id: id,
      name: name,
      accountType: type,
      category: cat,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: bal,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Widget _harness(List<Account> accounts) =>
    _harnessWithCurrency(accounts, const CurrencyState());

/// Multi-currency variant: provides a CurrencyBloc pre-seeded with `cstate`
/// (rates/preferred) so the page's `context.watch<CurrencyBloc>()` resolves.
Widget _harnessWithCurrency(List<Account> accounts, CurrencyState cstate) {
  final listUc = _MockList();
  final createUc = _MockCreate();
  final deleteUc = _MockDelete();
  final getUc = _MockGet();
  final updateUc = _MockUpdate();
  when(() => listUc.call())
      .thenAnswer((_) async => dartz.Right(accounts));
  registerFallbackValue(const CreateAccountParams(
    name: '',
    accountType: AccountType.asset,
    category: AccountCategory.savings,
    currencyCode: 'CNY',
    initialBalanceCents: 0,
    ownership: Ownership.personal,
  ));
  registerFallbackValue(const UpdateAccountParams(id: '', version: 0));
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AccountBloc>(
          create: (_) =>
              AccountBloc(listUc, createUc, deleteUc, getUc, updateUc),
        ),
        BlocProvider<CurrencyBloc>.value(value: _FakeCurrencyBloc(cstate)),
      ],
      child: const AccountsPage(),
    ),
  );
}

void main() {
  // 真实布局单卡最小 280px；副信息为单行，窄视口会触发省略号。
  // 用宽视口确保单行完整渲染，匹配实际桌面网格。
  const size = Size(1400, 900);

  setUp(() {
    // 本页 initState 订阅 DataRefreshNotifier(交易跨 branch 变更后重拉)。
    GetIt.instance.registerLazySingleton<DataRefreshNotifier>(
        DataRefreshNotifier.new);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('savings card shows 利率 and no progress bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_savings()]));
    await t.pumpAndSettle();
    expect(find.textContaining('利率 1.50%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('credit card shows 额度 + 账单/还款日 + red usage bar',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_credit()]));
    await t.pumpAndSettle();
    expect(find.textContaining('额度'), findsWidgets);
    expect(find.textContaining('账单5日'), findsOneWidget);
    expect(find.textContaining('还款25日'), findsOneWidget);
    final bar = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.6, 0.001)); // 3000/5000
    expect(bar.backgroundColor ?? AppColors.fg, isNot(AppColors.negative));
    expect((bar.valueColor as AlwaysStoppedAnimation<Color?>?)?.value,
        AppColors.negative);
  });

  testWidgets('investment card shows +return% (green) and no bar',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_investment()]));
    await t.pumpAndSettle();
    expect(find.textContaining('今年收益'), findsOneWidget);
    expect(find.textContaining('+8.25%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('fixed deposit card shows 到期 + 利率 and no bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_fixed()]));
    await t.pumpAndSettle();
    expect(find.textContaining('到期'), findsOneWidget);
    expect(find.textContaining('2027-06-15'), findsOneWidget);
    expect(find.textContaining('利率 2.75%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('gold card shows 买入 + 涨幅 and no bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_gold()]));
    await t.pumpAndSettle();
    expect(find.textContaining('买入'), findsOneWidget);
    expect(find.textContaining('+20.00%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('real estate card shows 现估值 + 增值 and no bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_estate()]));
    await t.pumpAndSettle();
    // Task 2: compact 行新增 label「现估值」，与 _sublineWidget「现估值 ¥ ...」并存；
    // 用完整 subline 文本断言类型副信息（唯一），避免与紧凑 label 冲突。
    expect(find.textContaining('现估值'), findsWidgets);
    expect(find.textContaining('+20.00%'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('loan card shows 原始/月供/下次 + green repaid bar', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_loan()]));
    await t.pumpAndSettle();
    expect(find.textContaining('原始'), findsOneWidget);
    expect(find.textContaining('月供'), findsOneWidget);
    expect(find.textContaining('下次'), findsOneWidget);
    final bar = t.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(0.6, 0.001)); // (100-40)/100
    expect((bar.valueColor as AlwaysStoppedAnimation<Color?>?)?.value,
        AppColors.positive);
  });

  // Task 1 — card 副标题 = institution · 卡号尾号（ac-sub，非类型专属 _sublineWidget）
  testWidgets('card subtitle: institution · 尾号 when both present', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      const Account(
        id: 'a1',
        name: '招行储蓄',
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 100000,
        ownership: Ownership.personal,
        status: AccountStatus.active,
        institution: '招商银行',
        cardNumberTail: '2840',
      ),
    ]));
    await t.pumpAndSettle();
    expect(find.text('招商银行 · 尾号 2840'), findsOneWidget);
  });

  testWidgets('card subtitle: institution only when no cardNumberTail',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      const Account(
        id: 'a2',
        name: '现金',
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 50000,
        ownership: Ownership.personal,
        status: AccountStatus.active,
        institution: '微信',
        cardNumberTail: '',
      ),
    ]));
    await t.pumpAndSettle();
    expect(find.text('微信'), findsOneWidget);
  });

  testWidgets(
      'card subtitle: category · currency fallback when no institution',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      const Account(
        id: 'a3',
        name: '现金钱包',
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 50000,
        ownership: Ownership.personal,
        status: AccountStatus.active,
        institution: '',
        cardNumberTail: '',
      ),
    ]));
    await t.pumpAndSettle();
    expect(find.text('储蓄 · CNY'), findsOneWidget);
  });

  // Task 1 — _AccountsHeader 响应式（desktop sumcard / mobile 紧凑汇总卡）
  testWidgets('desktop header: sumcard with 净资产 + 总资产 + 总负债', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      _account('a1', '储蓄', cat: AccountCategory.savings, bal: 100000),
      _account('a2', '信用卡',
          cat: AccountCategory.creditCard,
          type: AccountType.liability,
          bal: -30000),
    ]));
    await t.pumpAndSettle();
    expect(find.text('净资产合计'), findsOneWidget);
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('总负债'), findsOneWidget);
  });

  testWidgets(
    'desktop header: 总负债=卡欠款+债务本息剩余(credit-正),净资产=资产−总负债 (dev 反馈:总计不正确)',
    (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      when(() => debtRepo.list())
          .thenAnswer((_) async => dartz.Right([_debt('d1', 'l1')]));
      GetIt.instance.registerSingleton<DebtRepository>(debtRepo);

      await t.pumpWidget(_harness([
        // 资产 ¥10,000。
        _account('a1', '储蓄', cat: AccountCategory.savings, bal: 1000000),
        // 信用卡欠款 ¥300(credit-正)。
        _account('c1', '信用卡',
            cat: AccountCategory.creditCard,
            type: AccountType.liability,
            bal: 30000),
        // 挂债贷款账户:余额不参与总负债,由债务本息剩余(¥500,000+¥30,000)
        // 计入。
        _account('l1', '融e借',
            cat: AccountCategory.loan,
            type: AccountType.liability,
            bal: 400000),
      ]));
      await t.pumpAndSettle();

      // 总资产 ¥10,000.00;总负债 ¥530,300.00;净资产 −¥520,300.00(注意
      // _fmtSymbol 的负号在货币符号之前,'-520,300.00' 不是子串)。
      expect(find.textContaining('10,000.00'), findsWidgets);
      expect(find.textContaining('530,300.00'), findsOneWidget,
          reason: '总负债 = 卡欠款300 + 债务本息剩余530,000');
      expect(find.text('-¥520,300.00'), findsOneWidget,
          reason: '净资产 = 资产10,000 − 总负债530,300');
    },
  );

  testWidgets('mobile header: compact 净资产 + 资产·负债 meta, no count', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      _account('a1', '储蓄', cat: AccountCategory.savings, bal: 100000),
      _account('a2', '信用卡',
          cat: AccountCategory.creditCard,
          type: AccountType.liability,
          bal: -30000),
    ]));
    await t.pumpAndSettle();
    expect(find.text('全部账户余额合计'), findsOneWidget);
    expect(find.text('净资产合计'), findsNothing); // mobile 用 label 非「净资产合计」
    expect(find.textContaining('资产'), findsWidgets);
    expect(find.textContaining('共'), findsNothing); // count 行去掉
  });

  // Task 2 — _AccountCard mobile 紧凑行（< 600）：右侧 label+val；下方副信息+bar。
  testWidgets('mobile card: compact row (label+val right, sub+bar below)',
      (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      Account(
        id: 'c1',
        name: '招行信用卡',
        accountType: AccountType.liability,
        category: AccountCategory.creditCard,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: -12400, // 欠款 124
        ownership: Ownership.personal,
        status: AccountStatus.active,
        creditLimitCents: 800000, // 额度 8000
        creditBillingDay: 12,
        creditRepaymentDay: 1,
      ),
    ]));
    await t.pumpAndSettle();
    // 紧凑行：右侧 label「当前欠款」+ 余额
    expect(find.text('当前欠款'), findsOneWidget);
    expect(find.text('招行信用卡'), findsOneWidget);
    // 进度条存在（信用卡）
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  // 断点基于页面宽度（MediaQuery）后，desktop 视口（1400×900 → page width ≥ 600）
  // 下 _AccountCard 走 _fullCard 分支。_fullCard 重写后对齐 tablet.html .card：
  // cicon + cv(右) + csub + bar + bar-meta，无 PopupMenuButton（操作移至详情页）。
  // 此测试用 _fullCard 专属的 bar-meta「已用 ...」作判别 witness（_compactCard 无 bar-meta）。
  testWidgets(
      'desktop card: _fullCard branch (bar-meta present, card has no action popup)',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      Account(
        id: 'c1',
        name: '招行信用卡',
        accountType: AccountType.liability,
        category: AccountCategory.creditCard,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: -12400, // 欠款 124
        ownership: Ownership.personal,
        status: AccountStatus.active,
        creditLimitCents: 800000, // 额度 8000（_usageSpec 非 null → bar+meta）
      ),
    ]));
    await t.pumpAndSettle();
    expect(find.text('招行信用卡'), findsOneWidget);
    // _fullCard 专属：bar-meta「已用 ... / ...」（_compactCard 只有 bar 无 meta）。
    expect(find.textContaining('已用'), findsOneWidget);
    // 卡片操作菜单已移除（迁至详情页 AppBar）。F52(FR-2)后页头「新建账户」
    // 合法持有一个 PopupMenuButton(六项平权菜单)→ 判据收窄为「全页唯一
    // popup = 新建入口(按钮文案『新建账户』)」,卡片仍零操作 popup。
    // byWidgetPredicate 而非 byType:泛型实例化(记录型选中值)下
    // byType(PopupMenuButton) 匹配不到(byType 是 runtimeType 全等)。
    final popup = find.byWidgetPredicate((w) => w is PopupMenuButton);
    expect(popup, findsOneWidget);
    expect(
      find.descendant(of: popup, matching: find.text('新建账户')),
      findsOneWidget,
    );
  });

  // Task 3 — _GroupBlock 三断点列数（mobile 1-col Column / tablet 2 / desktop auto-fill）。
  // mobile 改用 Column（卡片 intrinsic 高度，避免固定 aspect 裁剪），故此处断言
  // mobile 视口下无 GridView（_GroupBlock 走 Column 分支）+ 两卡纵向排列。
  testWidgets('mobile: Column layout (no GridView), cards stack vertically',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness([
      _account('a1', '储蓄1', cat: AccountCategory.savings, bal: 10000),
      _account('a2', '储蓄2', cat: AccountCategory.savings, bal: 20000),
    ]));
    await tester.pumpAndSettle();
    // mobile 分支用 Column，不再有 GridView。
    expect(find.byType(GridView), findsNothing);
    // 两卡名都在树中（纵向堆叠）。
    expect(find.text('储蓄1'), findsOneWidget);
    expect(find.text('储蓄2'), findsOneWidget);
  });

  testWidgets('tablet: 2 columns', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness([
      _account('a1', '储蓄1', cat: AccountCategory.savings, bal: 10000),
      _account('a2', '储蓄2', cat: AccountCategory.savings, bal: 20000),
    ]));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('desktop: auto-fill (>=3 cols at 1280)', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness([
      _account('a1', '储蓄1', cat: AccountCategory.savings, bal: 10000),
      _account('a2', '储蓄2', cat: AccountCategory.savings, bal: 20000),
      _account('a3', '储蓄3', cat: AccountCategory.savings, bal: 30000),
    ]));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(3));
  });

  // Discriminating witness：旧 auto-fill 公式 floor((maxWidth+14)/(280+14))
  // 在 1050px 视口算出 3 列，新断点（600-1099 → 2 列）给出 2 列。
  // 此测试在旧代码会 FAIL（期望 2 实得 3），故为有效回归守卫，而非 smoke test。
  // 旧：floor((1050-32+14)/(280+14)) = floor(1032/294) = 3
  // 新：1050-32=1018 ∈ tablet(600-1099) → 2
  testWidgets('tablet 1050px: 2 cols (discriminating — old auto-fill gave 3)',
      (tester) async {
    tester.view.physicalSize = const Size(1050, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness([
      _account('a1', '储蓄1', cat: AccountCategory.savings, bal: 10000),
      _account('a2', '储蓄2', cat: AccountCategory.savings, bal: 20000),
      _account('a3', '储蓄3', cat: AccountCategory.savings, bal: 30000),
    ]));
    await tester.pumpAndSettle();
    final grid = tester.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  // Issue 2 回归守卫：长按卡片应弹出快捷菜单（含「删除账户」条目），而非直接删除。
  // 旧实现 onLongPress=onDelete 直接走确认弹窗；新实现先弹菜单。
  testWidgets(
      'long-press opens quick menu with 删除账户 item (not direct delete)',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_harness([_savings()]));
    await tester.pumpAndSettle();
    // 长按前无菜单条目。
    expect(find.text('删除账户'), findsNothing);
    // 长按卡片（_compactCard 的 GestureDetector）。
    await tester.longPress(find.text('招行储蓄'));
    await tester.pumpAndSettle();
    // 菜单弹出，包含「删除账户」「编辑」「记一笔」等条目。
    expect(find.text('删除账户'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget);
  });

  // Issue 1 回归守卫：desktop _fullCard 底部有 5 个快捷操作按钮（详情/编辑/记账/转账/更多）。
  // 按钮始终渲染（opacity 0 时不可见但占位），保证卡片高度稳定。
  testWidgets('desktop card: hover action bar has 5 quick actions', (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([_savings()]));
    await t.pumpAndSettle();
    // 5 个快捷按钮 label 都在树中（即使 opacity 0 也渲染）。
    expect(find.text('详情'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('记账'), findsOneWidget);
    expect(find.text('转账'), findsOneWidget);
    expect(find.text('更多'), findsOneWidget);
  });

  // ─── Task 9 — multi-currency conversion ───
  // Card 余额：原货币符号 + 原金额（不换算）。
  // 总计/小计：toPreferredCents 换算到 preferred(CNY) 后累加，显示 preferred 符号。
  //
  // 数据：USD 1000 cents（= $10.00）+ CNY 10000 cents（= ¥100.00），preferred=CNY，
  //       rates {USD:1.08, CNY:7.81, EUR:1.0}。
  // 换算：USD→CNY = 7.81/1.08 × 1000 = 7231.5 → round 7231；+CNY 10000 = 17231 cents
  //       = ¥172.31。
  testWidgets(
      'multi-currency: sumcard 总资产 in preferred (¥) + USD card keeps \$ original',
      (t) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final usd = Account(
      id: 'u1',
      name: '美元储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'USD',
      initialBalanceCents: 0,
      currentBalanceCents: 1000, // $10.00
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
    final cny = Account(
      id: 'c2',
      name: '人民币储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 10000, // ¥100.00
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
    const cstate = CurrencyState(
      preferred: 'CNY',
      rates: {'USD': 1.08, 'CNY': 7.81, 'EUR': 1.0},
      status: CurrencyStatus.loaded,
    );
    await t.pumpWidget(_harnessWithCurrency([usd, cny], cstate));
    await t.pumpAndSettle();
    // 总资产 sumcard：preferred(CNY) 符号 ¥ + 换算后 17231 cents = ¥172.31。
    expect(find.textContaining('¥172.31'), findsWidgets);
    // USD card 余额：原货币符号 $ + 原金额（不换算）= $10.00。
    expect(find.textContaining(r'$10.00'), findsOneWidget);
  });

  // ─────────────── F9-T3:账户搜索(FR-5:name contains,无排序无分页) ───────────────

  group('F9-T3 搜索(accounts_page,页面层过滤)', () {
    testWidgets('搜索提交 → 分组列表收窄到名称命中;清除 → 恢复', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      // 两支储蓄(同组,名称可区分)+ 一支信用卡。
      await t.pumpWidget(_harness([
        _account('s1', '招行储蓄'),
        _account('s2', '建行储蓄'),
        _credit(),
      ]));
      await t.pumpAndSettle();
      expect(find.text('招行储蓄'), findsOneWidget);
      expect(find.text('建行储蓄'), findsOneWidget);
      expect(find.text('招行信用卡'), findsOneWidget);

      // 提交「招行」→ 命中 招行储蓄 + 招行信用卡。
      await t.enterText(find.byType(TextField), '招行');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('招行储蓄'), findsOneWidget);
      expect(find.text('招行信用卡'), findsOneWidget);
      expect(find.text('建行储蓄'), findsNothing);

      // 清除 → 恢复全部。
      await t.tap(find.byTooltip('清除搜索'));
      await t.pumpAndSettle();
      expect(find.text('招行储蓄'), findsOneWidget);
      expect(find.text('建行储蓄'), findsOneWidget);
      expect(find.text('招行信用卡'), findsOneWidget);
    });

    testWidgets('搜索忽略大小写;未命中 → 该筛选下暂无账户', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([
        _account('s1', 'CMB Savings'),
        _account('s2', '建行储蓄'),
      ]));
      await t.pumpAndSettle();

      // 小写查询命中大写名称。
      await t.enterText(find.byType(TextField), 'cmb');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('CMB Savings'), findsOneWidget);
      expect(find.text('建行储蓄'), findsNothing);

      // 未命中 → 沿用既有分组空态文案。
      await t.enterText(find.byType(TextField), 'zzz');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('该筛选下暂无账户'), findsOneWidget);
    });
  });

  // ─────────────── 2026-09 到期聚合条接线(FR-1/2/3/7) ───────────────
  // 候选 = 共享 DueCandidateProvider 广播流(真 provider + fake 源 + 无挂失
  // fake 存储,零 drift 查询 —— FakeAsync 内 drift 会挂起);页面只订阅,
  // 启动/销毁归装配方(本组测试自己 start/dispose)。
  group('到期聚合条接线(provider 订阅 + stream 驱动刷新)', () {
    // 固定时钟 2026-09-23;窗口 advanceDays=3 → 9/26 到期 = 3 天后。
    final today = DateTime(2026, 9, 23);

    DueScheduleEntry ccEntry() => DueScheduleEntry(
        id: 'cc:a1:2026-09',
        debtName: '招行卡',
        totalCents: 5000,
        paymentDate: DateTime(2026, 9, 26),
        target: const AccountTarget('a1'));

    /// 注册真 provider(可变源 + 触发流)并启动;返回三元组供测试驱动刷新。
    (DueCandidateProvider, _FakeDueSource, StreamController<void>)
        registerProvider(List<DueScheduleEntry> entries) {
      final sc = StreamController<void>.broadcast();
      final source = _FakeDueSource(entries);
      final provider = DueCandidateProvider(
        changeTriggers: [sc.stream],
        source: source,
        dismissalStore: _NoDismissals(),
        configProvider: () => const DueReminderConfig(),
        clock: () => today,
      );
      GetIt.instance.registerSingleton<DueCandidateProvider>(provider);
      unawaited(provider.start());
      addTearDown(() async {
        await provider.dispose();
        await sc.close();
      });
      return (provider, source, sc);
    }

    testWidgets('候选非空 → 净资产 hero 上方显示聚合条(FR-1 位置)', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      registerProvider([ccEntry()]);
      // provider 初始刷新(microtask 链)落地 latest 后再挂页面(首帧有数;
      // 生产同构:bootstrap start 先于页面挂载)。
      await t.pump();
      await t.pump();
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('dueBanner')), findsOneWidget);
      expect(find.text('⏰ 1 笔待还 · 最近 3 天后'), findsOneWidget);
      // 位置:聚合条在净资产 hero(_AccountsHeader)上方。
      expect(
        t.getTopLeft(find.byKey(const ValueKey('dueBanner'))).dy,
        lessThan(t.getTopLeft(find.text('净资产合计')).dy),
      );
    });

    testWidgets('流刷新到空列表 → 聚合条消失(还款后候选自动消失的机制面)',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final (provider, source, sc) = registerProvider([ccEntry()]);
      await t.pump();
      await t.pump();
      expect(provider.latest, isNotEmpty);
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('dueBanner')), findsOneWidget);

      // 模拟还款落账:源候选清空 + watch 触发 → 防抖 500ms → 刷新广播空列表。
      source.entries = [];
      sc.add(null);
      await t.pump(const Duration(milliseconds: 600));
      await t.pumpAndSettle();
      expect(provider.latest, isEmpty);
      expect(find.byKey(const ValueKey('dueBanner')), findsNothing);
      // hero 回到页面顶部原位(空态不占位,FR-1)。
      expect(find.text('净资产合计'), findsOneWidget);
    });

    testWidgets('未注册 provider(装配前/裸挂载)→ 无聚合条、不报错(fail-safe)',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('dueBanner')), findsNothing);
      expect(find.text('净资产合计'), findsOneWidget);
    });
  });

  // ─────────────── F52-T3:新建入口六项平权菜单(FR-2) ───────────────
  // 「新建账户」按钮改锚定菜单:信用卡(普通)/花呗/京东白条/美团月付/微信
  // 分付/分隔/全部自定义…。前五项经构造参数直传进表单(design LLD「对象直传」
  // 照 _openEditForm 的 existing 先例);「全部自定义」= 现状无参路径逐位
  // 一致(FR-2 回归钉死)。菜单文案/结构基准 = v14 原型形态 ii。
  group('F52-T3 新建入口六项菜单(FR-2)', () {
    // 泛型菜单件(byType 是 runtimeType 全等,匹配不到带类型实参的实例,
    // 库内先例 credit_card_repay_dialog_test 的 SegmentedButton 判据)。
    final popupBtn = find.byWidgetPredicate((w) => w is PopupMenuButton);
    final popupItem = find.byWidgetPredicate((w) => w is PopupMenuItem);

    /// 菜单内文本 finder(限定 PopupMenuItem 子树 —— 页面背后还有
    /// 分类 chips「信用卡」等同名文本,避免误命中)。
    Finder inMenu(String text) =>
        find.descendant(of: popupItem, matching: find.text(text));

    testWidgets('点击新建账户 → 菜单恰六项 + 分隔(六项平权,副行文案齐)',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      // 唯一 popup = 页头新建入口(卡片/其他位置零 popup)。
      expect(popupBtn, findsOneWidget);

      await t.tap(find.text('新建账户'));
      await t.pumpAndSettle();

      // FR-2「菜单恰六项(含分隔)」:六项 + 一条分隔,无「自定义账户」吞掉
      // 普通信用卡的形态(普通信用卡与预设同层平权)。
      expect(popupItem, findsNWidgets(6));
      expect(find.byWidgetPredicate((w) => w is PopupMenuDivider),
          findsOneWidget);

      expect(inMenu('信用卡'), findsOneWidget);
      expect(inMenu('普通'), findsOneWidget); // dn-chip「普通」
      expect(inMenu('花呗'), findsOneWidget);
      expect(inMenu('京东白条'), findsOneWidget);
      expect(inMenu('美团月付'), findsOneWidget);
      expect(inMenu('微信分付'), findsOneWidget);
      expect(inMenu('全部自定义…'), findsOneWidget);

      // 副行文案(v14 形态 ii):花呗固定日期;白条类激活日 hint(目录同源)。
      expect(inMenu('账单 1 日 · 还款 9 日'), findsOneWidget);
      expect(inMenu('账单日按激活日,建后可改'), findsNWidgets(3));
      expect(inMenu('银行信用卡,参数自填 · 填额度/账单日/还款日'), findsOneWidget);
      expect(inMenu('储蓄/投资/贷款等其余类型'), findsOneWidget);
    });

    testWidgets('花呗 → 表单 preset 对象直传(目录第 1 条,预填指令经参数面)',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      await t.tap(find.text('新建账户'));
      await t.pumpAndSettle();
      await t.tap(inMenu('花呗'));
      await t.pumpAndSettle();

      final form = t.widget<AccountFormPage>(find.byType(AccountFormPage));
      expect(form.preset, same(accountPresets.first));
      expect(form.preselectCreditCard, isFalse);
      expect(form.existing, isNull);
    });

    testWidgets('信用卡(普通) → 仅 preselectCreditCard(零预设,零 existing)',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      await t.tap(find.text('新建账户'));
      await t.pumpAndSettle();
      await t.tap(inMenu('信用卡'));
      await t.pumpAndSettle();

      final form = t.widget<AccountFormPage>(find.byType(AccountFormPage));
      expect(form.preselectCreditCard, isTrue);
      expect(form.preset, isNull);
      expect(form.existing, isNull);
    });

    testWidgets('全部自定义… → 现状无参路径回归(preset/preselect 均空)',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      await t.tap(find.text('新建账户'));
      await t.pumpAndSettle();
      await t.tap(inMenu('全部自定义…'));
      await t.pumpAndSettle();

      // 与旧行为 const AccountFormPage() 逐位等价(FR-2 回归:零类别预选)。
      final form = t.widget<AccountFormPage>(find.byType(AccountFormPage));
      expect(form.preset, isNull);
      expect(form.preselectCreditCard, isFalse);
      expect(form.existing, isNull);
    });

    testWidgets('空态「新建账户」按钮展开同一六项菜单(第三触发位)', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([]));
      await t.pumpAndSettle();
      expect(find.text('还没有账户'), findsOneWidget);
      await t.tap(find.text('新建账户'));
      await t.pumpAndSettle();
      expect(popupItem, findsNWidgets(6));
      expect(find.byWidgetPredicate((w) => w is PopupMenuDivider),
          findsOneWidget);
    });

    testWidgets('mobile:汇总卡右上「+」圆钮展开同一六项菜单', (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness([_savings()]));
      await t.pumpAndSettle();
      // mobile 汇总卡唯一的 plus 图标 = 右上圆钮(desktop 药丸钮不渲染)。
      await t.tap(find.byIcon(LucideIcons.plus));
      await t.pumpAndSettle();
      expect(popupItem, findsNWidgets(6));
      expect(find.byWidgetPredicate((w) => w is PopupMenuDivider),
          findsOneWidget);
    });
  });
}
