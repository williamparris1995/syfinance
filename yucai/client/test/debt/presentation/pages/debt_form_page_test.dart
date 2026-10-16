// Task 8 — TDD widget tests for DebtFormPage
// (表单字段 + 实时摊还预览 + 提交 CreateDebtRequested + 三端 desktop 分区 / mobile step wizard)。
//
// F62 迁移注记:场景卡替代 subtype 直选 / 载体户隐形 / 渐进披露三段 / 灰显
// 过滤 / 警示条编辑态收窄。既有断言迁移不删(提交链路/守卫/预填零弱化):
//  - debtType-credit_loan/card_loan/family/mortgage 直选卡 → scenarioCard-bank/
//    cc/family/mortgage(场景卡);cash/consumption/business/credit_card/other
//    仍走 debtType-* chips(「更多类型」面板,展开后可达)。
//  - 利率/摊还/每期手续费/占用开关/担保人/附件 → 段③高级(默认折叠,
//    Offstage 挂载);测试交互前先 openAdvanced。
//  - 关联账户字段(普通贷款)退役 → 载体自动创建断言(F62 ADR-3)。
//  - isConflict 警示条 → 新建态零出现 + 编辑态存量冲突仍显(数据修复)。
//
// 对齐 debts_page_test / debt_detail_page_test 的 harness：mocktail
// DebtRepository + AccountRepository → 真实 DebtBloc。表单页 initState 通过
// GetIt.instance<AccountRepository>().list() 拉关联 Loan 账户（与
// transactions_page _loadAccounts 同模式），故把 accountRepo 注册到 GetIt。
//
// 验证：
//   - 字段渲染：场景卡 / 债权方 / 本金 / 期数 / 到账卡 / 起始日 / 高级折叠
//   - 实时预览：等额本息(月供 + 前 5 期) / 等额本金(首月供) / 一次性(到期总额) / 空(本金 0)
//   - 提交：填全 → 点「创建债务」→ dispatch CreateDebtRequested(repo.create 被调用)
//   - 三端：desktop 双列(form + preview) / mobile step wizard(三步映射三段)
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/form_leave_gate.dart';
import 'package:yucai_client/core/shell_detail_title.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
// CreateDebtParams / UpdateDebtParams lives in debt_event.dart (re-exported implicitly via bloc).
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/pages/debt_form_page.dart';
import 'package:yucai_client/debt/presentation/widgets/product_scenario_picker.dart';

class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}

class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

Account _loanAccount({
  String id = 'loan-1',
  String name = '招商银行 · 个人住房贷款',
}) =>
    Account(
      id: id,
      name: name,
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 20000000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Account _cashAccount({String id = 'cash-1'}) =>
    Account(
      id: id,
      name: '招商银行储蓄卡',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 100000,
      currentBalanceCents: 100000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Account _creditCardAccount({
  String id = 'cc-1',
  String name = '招商银行信用卡',
  int creditLimitCents = 5000000,
  int? creditBillingDay = 5,
  int? creditRepaymentDay = 25,
  int? creditAnnualFeeCents = 100000,
  int version = 1,
}) =>
    Account(
      id: id,
      name: name,
      // creditCard category 派生 accountType = liability（见 value_objects）。
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      creditLimitCents: creditLimitCents,
      creditBillingDay: creditBillingDay,
      creditRepaymentDay: creditRepaymentDay,
      creditAnnualFeeCents: creditAnnualFeeCents,
      version: version,
    );

Account _otherLiabilityAccount({
  String id = 'ol-1',
  String name = '个人待还款',
}) =>
    Account(
      id: id,
      name: name,
      accountType: AccountType.liability,
      category: AccountCategory.otherLiability,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Widget _harness({
  required _MockDebtRepo debtRepo,
  required _MockAccountRepo accountRepo,
  DateTime? startDate,
  DateTime? dueDate,
  String? accountId,
  String? disbursementAccountId,
  Debt? existing,
}) {
  // 表单页 initState 走 GetIt<AccountRepository>().list()（对齐
  // transactions_page _loadAccounts）。注册到 GetIt 避免返回 null → 空下拉。
  // startDate/dueDate/accountId 走构造参数 seed，避免在 widget test 里
  // 驱动 showDatePicker（fragile）。
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
        BlocProvider<CurrencyBloc>.value(
          value: _FakeCurrencyBloc(const CurrencyState()),
        ),
      ],
      child: DebtFormPage(
        existing: existing,
        initialStartDate: startDate,
        initialDueDate: dueDate,
        initialAccountId: accountId,
        initialDisbursementAccountId: disbursementAccountId,
      ),
    ),
  );
}

void main() {
  GetIt.instance.registerLazySingleton<DataRefreshNotifier>(DataRefreshNotifier.new);

  setUpAll(() {
    registerFallbackValue(DebtType.borrowedIn);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  /// F62 迁移 helper:滚动目标到视口中部。页面用 SingleChildScrollView(非
  /// lazy:finder 恒命中 → scrollUntilVisible 零拖动;ensureVisible 动画在
  /// IntrinsicHeight 深层嵌套下偶发不生效)→ 直接位移 scroll position。
  Future<void> scrollTo(WidgetTester t, Finder f) async {
    // 先失焦:聚焦文本字段后出现的全屏选区/IME Listener(与下拉交互组合
    // 时)会吞掉后续 tap 的命中测试 —— 失焦后再滚动/点按。
    if (FocusManager.instance.primaryFocus != null) {
      FocusManager.instance.primaryFocus!.unfocus();
      await t.pumpAndSettle();
    }
    final render = t.renderObject<RenderBox>(f);
    final vp = t.view.physicalSize / t.view.devicePixelRatio;
    final top = render.localToGlobal(Offset.zero).dy;
    final bottom = top + render.size.height;
    if (top >= 0 && bottom <= vp.height) return; // 已在视口内。
    // 目标中心移到视口中部所需的附加滚动量。
    final delta = (top + bottom) / 2 - vp.height / 2;
    if (delta.abs() < 1) return;
    final state = t.state<ScrollableState>(find.byType(Scrollable).first);
    final pos = state.position;
    await pos.moveTo((pos.pixels + delta)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent));
    await t.pumpAndSettle();
  }

  /// F62 迁移 helper:展开段③高级(默认折叠;Offstage 挂载 → 交互前必须
  /// 展开)。幂等(已展开直过)。
  Future<void> openAdvanced(WidgetTester t) async {
    if (find
        .byKey(const ValueKey('advancedHintOpen'))
        .evaluate()
        .isNotEmpty) {
      return;
    }
    await scrollTo(t, find.byKey(const ValueKey('advancedFoldToggle')));
    await t.tap(find.byKey(const ValueKey('advancedFoldToggle')));
    await t.pumpAndSettle();
  }

  /// F62 迁移 helper:点场景卡(bank/cc/mortgage/family)。
  Future<void> tapScenario(WidgetTester t, String id) async {
    await scrollTo(t, find.byKey(ValueKey('scenarioCard-$id')));
    await t.tap(find.byKey(ValueKey('scenarioCard-$id')));
    await t.pumpAndSettle();
  }

  /// F62 迁移 helper:经「更多类型」面板选非映射类 subtype(幂等:面板已
  /// 展开直选,不重复切换)。
  Future<void> pickMore(WidgetTester t, String key) async {
    if (find.byKey(const ValueKey('scenarioMorePanel')).evaluate().isEmpty) {
      await scrollTo(t, find.byKey(const ValueKey('scenarioMoreToggle')));
      await t.tap(find.byKey(const ValueKey('scenarioMoreToggle')));
      await t.pumpAndSettle();
    }
    await scrollTo(t, find.byKey(ValueKey('debtType-$key')));
    await t.tap(find.byKey(ValueKey('debtType-$key')));
    await t.pumpAndSettle();
  }

  /// F62 迁移 helper:打开灰显过滤下拉(段②可能在折叠线下,先滚动可见)。
  Future<void> openDropdown(WidgetTester t, Key key) async {
    await scrollTo(t, find.byKey(key));
    await t.tap(find.byKey(key));
    await t.pumpAndSettle();
  }

  group('字段渲染', () {
    testWidgets('renders 场景卡 / 债权方 / 本金 / 到账卡 / 起始日 / 高级折叠',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 字段标签:①基本(首问场景卡+债权方+本金)/②到账与还款(到账卡+起始日)。
      expect(find.textContaining('这次借的是什么'), findsOneWidget);
      expect(find.textContaining('债权方'), findsWidgets);
      expect(find.textContaining('借款本金'), findsWidgets);
      expect(find.textContaining('钱到账到了哪张卡'), findsOneWidget);
      expect(find.textContaining('起始日期'), findsOneWidget);
      expect(find.textContaining('到期日期'), findsOneWidget);
      // 段③高级默认折叠:折叠头「已收起 N 项」,利率字段不在可视树。
      expect(find.byKey(const ValueKey('advancedFold')), findsOneWidget);
      expect(find.textContaining('已收起'), findsOneWidget);
      expect(find.byKey(const ValueKey('rateField')), findsNothing,
          reason: '高级默认折叠(渐进披露)');
    });

    testWidgets(
        'renders scenario cards + full subtype coverage(4 卡 + 更多类型 5 类 + 二级 2 类)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // 4 场景卡(FR-1)。
      for (final id in [
        DebtScenarioCard.bank,
        DebtScenarioCard.creditCardInstallment,
        DebtScenarioCard.mortgageAuto,
        DebtScenarioCard.family,
      ]) {
        expect(find.byKey(ValueKey('scenarioCard-$id')), findsOneWidget,
            reason: 'scenarioCard-$id 缺失');
      }
      // 「更多类型」保底枚举(5 类)展开后可达 —— 否定硬编码:选项必须来自
      // DebtScenarioCard.moreSubtypes。
      expect(DebtSubtypes.all.length, 10);
      await scrollTo(t, find.byKey(const ValueKey('scenarioMoreToggle')));
      await t.tap(find.byKey(const ValueKey('scenarioMoreToggle')));
      await t.pumpAndSettle();
      for (final key in DebtScenarioCard.moreSubtypes) {
        expect(find.byKey(ValueKey('debtType-$key')), findsOneWidget);
      }
      // 房贷·车贷二级选择(点卡展开)。
      await tapScenario(t, DebtScenarioCard.mortgageAuto);
      expect(find.byKey(const ValueKey('debtType-mortgage')), findsOneWidget);
      expect(find.byKey(const ValueKey('debtType-auto_loan')), findsOneWidget);
      // 10 类 subtype 标签全覆盖(卡标题/角标/chips)。
      for (final key in DebtSubtypes.all) {
        expect(find.text(DebtSubtypes.labels[key]!), findsWidgets,
            reason: '${DebtSubtypes.labels[key]} 未露出');
      }
    });

    testWidgets('renders 3 amortization radio cards (等额本息/等额本金/一次性)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // F62 迁移:摊还方法在段③高级 —— 展开后断言(断言不删)。
      await openAdvanced(t);
      expect(find.byKey(const ValueKey('amortization-equalPrincipalInterest')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('amortization-equalPrincipal')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('amortization-lumpSum')), findsOneWidget);
    });
  });

  group('实时摊还预览', () {
    Future<void> fillForm(WidgetTester t) async {
      // 债权方 / 本金(段①);利率(段③高级)。
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('counterpartyField')),
          '招商银行');
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '5.0');
      // 触发 recalc（日期已通过 harness seededDates 注入，避免驱动 date picker）
      await t.pump();
    }

    testWidgets('equalPrincipalInterest: 月供 + 前 5 期 rows', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo,
              startDate: DateTime(2026, 7, 1),
              dueDate: DateTime(2030, 7, 1)));
      await t.pumpAndSettle();
      await fillForm(t);
      // 预览标题 + 月供标签
      expect(find.byKey(const ValueKey('previewTitle')), findsOneWidget);
      expect(find.textContaining('月供'), findsWidgets);
      // 前 5 期 row（ValueKey 'previewRow-01'..'05'）
      for (var i = 1; i <= 5; i++) {
        final k = 'previewRow-${i.toString().padLeft(2, '0')}';
        expect(find.byKey(ValueKey(k), skipOffstage: false), findsOneWidget);
      }
    });

    testWidgets('equalPrincipal: 首月供 + 5 rows', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo,
              startDate: DateTime(2026, 7, 1),
              dueDate: DateTime(2030, 7, 1)));
      await t.pumpAndSettle();
      // 选「等额本金」(F62:摊还在段③高级;展开后滚动到可见再点)。
      await openAdvanced(t);
      await scrollTo(t, find.byKey(const ValueKey('amortization-equalPrincipal')));
      await t.tap(find.byKey(const ValueKey('amortization-equalPrincipal')));
      await fillForm(t);
      expect(find.textContaining('首月供'), findsWidgets);
      for (var i = 1; i <= 5; i++) {
        final k = 'previewRow-${i.toString().padLeft(2, '0')}';
        expect(find.byKey(ValueKey(k), skipOffstage: false), findsOneWidget);
      }
    });

    testWidgets('lumpSum: 到期总额 + single row', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo,
              startDate: DateTime(2026, 7, 1),
              dueDate: DateTime(2030, 7, 1)));
      await t.pumpAndSettle();
      await openAdvanced(t);
      await scrollTo(t, find.byKey(const ValueKey('amortization-lumpSum')));
      await t.tap(find.byKey(const ValueKey('amortization-lumpSum')));
      await fillForm(t);
      // 一次性：到期总额 标签
      expect(find.textContaining('到期总额'), findsWidgets);
      // 只有 1 行（到期）—— previewRow-02 不应存在
      expect(find.byKey(const ValueKey('previewRow-01'), skipOffstage: false),
          findsOneWidget);
      expect(find.byKey(const ValueKey('previewRow-02'), skipOffstage: false),
          findsNothing);
    });

    testWidgets('principal 0 → empty preview state', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // 不填任何东西 → 空态文案
      expect(find.byKey(const ValueKey('previewEmpty')), findsOneWidget);
    });
  });

  group('提交 CreateDebtRequested', () {
    testWidgets('fill form → tap 创建债务 → repo.create called', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      var created = false;
      // repo.create 没在 mock 注册命名参数；用 create({}) 模式拦截：用 list
      // success path 触发 LoadDebtsRequested。直接 stub create() 命名参数。
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods')))
          .thenAnswer((inv) {
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      when(() => accountRepo.list()).thenAnswer((_) async =>
          dartz.Right([_loanAccount(), _cashAccount()]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        // seed 起止日期 + 关联账户(seed 直达,不建载体),避免驱动 date picker / dropdown
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2030, 7, 1),
        accountId: 'loan-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 债权方 + 本金 + 利率(段③;日期 / 到账账户已 seed)
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('counterpartyField')),
          '招商银行');
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '5.0');
      // 提交（desktop 走 actions 卡 submitButton;mobile 走 wizard submitButton —— 二者其一）。
      final submitFinder = find
          .byKey(const ValueKey('submitButton'))
          .evaluate()
          .isNotEmpty
      ? find.byKey(const ValueKey('submitButton'))
      : find.text('确认创建');
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      // 让 bloc 异步链推进
      for (var i = 0; i < 10 && !created; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue);
      // 成功后可能弹 toast Timer，pump 推进
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  group('编辑模式（existing）', () {
    testWidgets('标题 = 编辑债务 + 预填 counterparty / 本金 / 利率',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(),
      ));
      await t.pumpAndSettle();

      // 页头标题 = 编辑债务（非「新建债务」）
      expect(find.text('编辑债务'), findsOneWidget);
      expect(find.text('新建债务'), findsNothing);
      // 字段预填(债权方/本金在段①;利率在段③ —— 展开后断言,预填断言不弱化)
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('counterpartyField')),
              matching: find.textContaining('招商银行')),
          findsWidgets);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('principalField')),
              matching: find.textContaining('150000')),
          findsWidgets);
      await openAdvanced(t);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('rateField')),
              matching: find.textContaining('4.25')),
          findsWidgets);
    });

    testWidgets('submit → dispatch UpdateDebtRequested (repo.update called)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const UpdateDebtParams(
        id: '',
        counterparty: '',
        interestRate: 0,
        version: 0,
      ));
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      var updated = false;
      when(() => debtRepo.update(
              id: any(named: 'id'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              version: any(named: 'version'),
              // F33-T5 后表单显式带 subtype → 必须 any() 通配(漏写会按
              // 接口默认值 '' 字面匹配,非 '' 即失配 → noSuchMethod 返回 null)。
              subtype: any(named: 'subtype'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              amortizationIndex: any(named: 'amortizationIndex'),
              dueDate: any(named: 'dueDate'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              interestWaivedCents: any(named: 'interestWaivedCents'),
              termPeriods: any(named: 'termPeriods'))).thenAnswer((_) {
        updated = true;
        return Future.value(dartz.Right(existingDebt(counterparty: '已改')));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(),
      ));
      await t.pumpAndSettle();

      // 改 counterparty，触发 dirty + 验证通过
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '建设银行');
      // 提交：desktop 走 actions 卡「保存」
      final submitFinder = find.byKey(const ValueKey('submitButton')).evaluate().isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('保存修改');
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && !updated; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(updated, isTrue);
      // 成功后 pop（编辑模式与创建模式同 BlocListener）
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets(
        'edit mode: scenario cards enabled → switch to 信用贷款 + submit sends new subtype',
        (t) async {
      // F33-T5 编辑解禁迁移:场景卡可改;UpdateDebtParams.subtype 显式携带
      // _subtypeKey(存量 subtype 修正走编辑自由改,FR-1)。
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const UpdateDebtParams(
        id: '',
        counterparty: '',
        interestRate: 0,
        version: 0,
      ));
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      String? capturedSubtype;
      var updated = false;
      when(() => debtRepo.update(
              id: any(named: 'id'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              version: any(named: 'version'),
              subtype: any(named: 'subtype'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              amortizationIndex: any(named: 'amortizationIndex'),
              dueDate: any(named: 'dueDate'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              interestWaivedCents: any(named: 'interestWaivedCents'),
              termPeriods: any(named: 'termPeriods'))).thenAnswer((inv) {
        capturedSubtype = inv.namedArguments[#subtype] as String?;
        updated = true;
        return Future.value(dartz.Right(existingDebt(counterparty: '已改')));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        // 存量 subtype=family → 编辑反选 family 卡;切「借钱到银行卡」→ credit_loan。
        existing: existingDebt(subtype: DebtSubtypes.family),
      ));
      await t.pumpAndSettle();

      // 切到「借钱到银行卡」场景卡(推导信用贷款)—— 编辑模式也可改(T5 解禁)。
      await tapScenario(t, DebtScenarioCard.bank);
      await t.pumpAndSettle();

      // 提交:desktop 走 actions 卡「保存」
      final submitFinder = find.byKey(const ValueKey('submitButton')).evaluate().isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('保存修改');
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && !updated; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(updated, isTrue);
      // 显式携带切换后的新值(而非空串「不修改」)
      expect(capturedSubtype, DebtSubtypes.creditLoan);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  // F33-T5 → F62 场景卡驱动(FR-1):subtype 状态机经场景卡/更多枚举推导;
  // 可观测出口 = 预览标题「未命名 · {subtypeLabel}」(previewTitle ValueKey)
  // + 提交显式携带。原「账户切换自动归位」行为随「关联账户」字段退役
  // (FR-3)—— 归位数据源 DebtSubtypeAffinity 保留为过滤器数据源(FR-2)。
  group('F62 场景卡推导(F33-T5 迁移)', () {
    // key 就挂在标题 Text 上 → 用 byWidgetPredicate 匹配 data。
    Finder previewTitleContaining(String s) => find.byWidgetPredicate((w) =>
        w is Text &&
        w.key == const ValueKey('previewTitle') &&
        (w.data?.contains(s) ?? false));

    testWidgets('create 默认 = 场景一(信用贷款,原型 .scn.on 智能默认)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      expect(previewTitleContaining('信用贷款'), findsOneWidget);
      expect(previewTitleContaining('房贷'), findsNothing);
    });

    testWidgets('场景卡切换驱动 subtype:family → bank(用户意图即所选)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      await tapScenario(t, DebtScenarioCard.family);
      expect(previewTitleContaining('亲友借款'), findsOneWidget);
      await tapScenario(t, DebtScenarioCard.bank);
      expect(previewTitleContaining('信用贷款'), findsOneWidget,
          reason: '场景卡切换 = subtype 重推导(FR-1)');
      expect(previewTitleContaining('亲友借款'), findsNothing);
    });

    testWidgets('edit 反选:存量 subtype 装载(family 卡选中,非默认卡)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'loan-1', name: '招行房贷'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(subtype: DebtSubtypes.family),
      ));
      await t.pumpAndSettle();

      // 装载已有 subtype = family(编辑态反选,零迁移)。
      expect(previewTitleContaining('亲友借款'), findsOneWidget);
      expect(previewTitleContaining('信用贷款'), findsNothing);
    });

    testWidgets('creditCard subtype(经「更多类型」)挂卡下拉收窄为信用卡(灰显)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'l1', name: '招行房贷'),
            _creditCardAccount(id: 'cc1', name: '招行信用卡'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 经「更多类型」切到信用卡 subtype → 段②出现挂卡选择器(灰显过滤)。
      await pickMore(t, DebtSubtypes.creditCard);
      expect(previewTitleContaining('信用卡'), findsOneWidget);
      await openDropdown(t, const ValueKey('accountDropdown'));
      // FR-2 迁移:不兼容项不再消失而是灰显+原因(更强断言:disabled item)。
      expect(find.textContaining('招行信用卡'), findsWidgets);
      final loanItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('招行房贷').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(loanItem.enabled, isFalse,
          reason: '贷款户在挂卡选择器灰显(FR-2)');
      expect(find.textContaining('仅信用卡账户可挂接'), findsOneWidget);
      final ccItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('招行信用卡').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(ccItem.enabled, isTrue);
    });
  });

  group('三端响应式', () {
    testWidgets('desktop: form + preview side-by-side (Row with 2 cols)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // desktop 不渲染 step wizard
      expect(find.byKey(const ValueKey('stepIndicator')), findsNothing);
      // 预览存在
      expect(find.byKey(const ValueKey('amortizationPreview')), findsOneWidget);
    });

    testWidgets('tablet: form + preview (still two-col)', (t) async {
      t.view.physicalSize = tablet;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('amortizationPreview')), findsOneWidget);
    });

    testWidgets('mobile: step wizard 三步映射三段(场景卡嵌第一步)',
        (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // step wizard 进度指示存在
      expect(find.byKey(const ValueKey('stepIndicator')), findsOneWidget);
      // 第一步 = 段①基本:场景卡 + 债权方 + 本金。
      expect(find.byKey(const ValueKey('scenarioPicker')), findsOneWidget);
      expect(find.textContaining('债权方'), findsWidgets);
      expect(find.textContaining('借款本金'), findsOneWidget);
      expect(find.byKey(const ValueKey('nextStepButton')), findsOneWidget);
      // 第二步 = 段②到账与还款:到账卡 + 起始日。
      await scrollTo(t, find.byKey(const ValueKey('nextStepButton')));
      await t.tap(find.byKey(const ValueKey('nextStepButton')));
      await t.pumpAndSettle();
      expect(find.textContaining('钱到账到了哪张卡'), findsOneWidget);
      expect(find.textContaining('起始日期'), findsOneWidget);
      expect(find.byKey(const ValueKey('prevStepButton')), findsOneWidget);
      // 第三步 = 段③高级(折叠)。
      await scrollTo(t, find.byKey(const ValueKey('nextStepButton')));
      await t.tap(find.byKey(const ValueKey('nextStepButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('advancedFold')), findsOneWidget);
    });
  });

  // Task 7 —— 子类型驱动 + 信用卡区(account 联动 updateAccount)。
  // F62 迁移:creditCard subtype 经「更多类型」可达;信用卡信息区随段③。
  group('子类型驱动 · 信用卡区', () {
    testWidgets('default subtype = creditLoan; selecting creditCard shows cc section',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_loanAccount(), _creditCardAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 默认 creditLoan(非信用卡)→ 信用卡区不出现
      expect(find.byKey(const ValueKey('creditCardSection')), findsNothing);
      expect(find.byKey(const ValueKey('ccBillingDayField')), findsNothing);

      // 经「更多类型」切「信用卡」subtype
      await pickMore(t, DebtSubtypes.creditCard);
      await t.pumpAndSettle();

      // 信用卡区(段③高级)+ 4 字段出现 —— 展开后断言(断言不删)。
      await openAdvanced(t);
      expect(find.byKey(const ValueKey('creditCardSection')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccBillingDayField')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccRepaymentDayField')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccLimitField')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccAnnualFeeField')), findsOneWidget);
    });

    testWidgets('negative: switching back hides cc section', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_loanAccount(), _creditCardAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 切到信用卡 → 出现(展开高级)
      await pickMore(t, DebtSubtypes.creditCard);
      await openAdvanced(t);
      expect(find.byKey(const ValueKey('creditCardSection')), findsOneWidget);

      // 切回场景一(信用贷款)→ 消失
      await tapScenario(t, DebtScenarioCard.bank);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('creditCardSection')), findsNothing);
    });

    testWidgets('cc fields prefilled from selected credit_card account', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_creditCardAccount(creditBillingDay: 9, creditRepaymentDay: 28, creditLimitCents: 8000000, creditAnnualFeeCents: 200000)]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        accountId: 'cc-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 切到信用卡 + 选中账户已 seed → 字段预填(段③展开后断言)
      await pickMore(t, DebtSubtypes.creditCard);
      await openAdvanced(t);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('ccBillingDayField')),
              matching: find.textContaining('9')),
          findsWidgets);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('ccRepaymentDayField')),
              matching: find.textContaining('28')),
          findsWidgets);
      // 额度 8000000 cents = 80000.00 元
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('ccLimitField')),
              matching: find.textContaining('80000')),
          findsWidgets);
    });

    testWidgets('no credit_card account + creditCard subtype → shows create hint',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      // 只有 loan，没有信用卡账户
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      await pickMore(t, DebtSubtypes.creditCard);
      expect(find.byKey(const ValueKey('createCreditCardHint')), findsOneWidget);
    });

    testWidgets('submit with creditCard subtype → repo.create called with subtype key + updateAccount called',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      // update(any()) 需要 UpdateAccountParams fallback（mocktail sound null-safety）。
      registerFallbackValue(
          const UpdateAccountParams(id: '', version: 0));
      // 捕获 create 收到的 subtype（应 == DebtSubtypes.creditCard const key）。
      String? capturedSubtype;
      when(() => accountRepo.list()).thenAnswer((_) async =>
          dartz.Right([_creditCardAccount(id: 'cc-1', version: 7), _cashAccount()]));
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'))).thenAnswer((inv) {
        capturedSubtype = inv.namedArguments[#subtype] as String?;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      // updateAccount(accountRepo.update) 拦截 —— 编辑信用卡字段后会触发。
      var accountUpdated = false;
      when(() => accountRepo.update(any())).thenAnswer((_) async {
        accountUpdated = true;
        return dartz.Right(_creditCardAccount(version: 8));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2030, 7, 1),
        accountId: 'cc-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 选信用卡子类型(经「更多类型」)
      await pickMore(t, DebtSubtypes.creditCard);
      await t.pumpAndSettle();
      // 填必填字段(利率/额度在段③)
      await openAdvanced(t);
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '招商银行');
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '5.0');
      // 编辑信用卡额度字段 → 触发 _ccDirty
      await t.enterText(find.byKey(const ValueKey('ccLimitField')), '99999.00');

      final submitFinder = find
              .byKey(const ValueKey('submitButton'))
              .evaluate()
              .isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('确认创建');
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && capturedSubtype == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      // subtype 用 const key（非中文 label / 非裸字符串）
      expect(capturedSubtype, DebtSubtypes.creditCard);
      // 信用卡字段编辑 → accountRepo.update 被调用（account 联动回写）
      expect(accountUpdated, isTrue);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('negative: hardcoded _debtTypes list is gone (options from DebtSubtypes.all)',
        (t) async {
      // 静态保证：DebtSubtypes.all 与 labels 覆盖 10 项（F33-T3 扩容 + F48 卡贷），且 key≠中文 label。
      expect(DebtSubtypes.all.toSet().length, 10);
      for (final key in DebtSubtypes.all) {
        expect(DebtSubtypes.labels.containsKey(key), isTrue);
        // key 是英文 snake_case，不是中文（防止把 label 当 key 存）。
        expect(DebtSubtypes.labels[key], isNot(equals(key)));
      }
    });
  });

    testWidgets('编辑态渲染周期入口与期数双模式', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: _emptyDetail().debt, // 等额本息(非 lumpSum)
      ));
      await t.pumpAndSettle();
      // F62:周期入口/期数双模式随段①(基本)—— 仍常驻可视区。
      expect(find.byKey(const ValueKey('debtRuleEntry')), findsOneWidget,
          reason: '编辑态应渲染周期规则入口(分期摊销)');
      expect(find.byKey(const ValueKey('termModeToggle')), findsOneWidget);
      await scrollTo(t, find.byKey(const ValueKey('debtRuleEntry')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('debtRuleEntry')));
      await t.pumpAndSettle();
      expect(find.text('重复规则'), findsOneWidget,
          reason: '点开入口应弹出共享规则编辑器');
    });

  // F33-T6 → F62:isConflict 警示条退役 —— 新建态灰显过滤从源头消除冲突
  // (零出现);编辑态存量冲突仍显(数据修复入口);非阻断语义保留(提交照常)。
  group('F62 警示条退役 + 编辑态数据修复(F33-T6 迁移)', () {
    testWidgets('新建态零出现:全场景切换(4 卡 + 更多类型)无警示条', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'l1'),
            _creditCardAccount(id: 'cc-1'),
            _otherLiabilityAccount(),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 默认 + 全部 4 卡 + 更多类型逐类切换:警示条恒不出现
      // (FR-2:「分类与关联账户不一致」不再可能出现)。
      for (final id in [
        DebtScenarioCard.bank,
        DebtScenarioCard.creditCardInstallment,
        DebtScenarioCard.mortgageAuto,
        DebtScenarioCard.family,
      ]) {
        await tapScenario(t, id);
        expect(find.byKey(const ValueKey('subtypeConflictCallout')),
            findsNothing,
            reason: '新建态冲突不可能(场景卡推导 + 灰显过滤)');
      }
      for (final k in [
        DebtSubtypes.cashInstallment,
        DebtSubtypes.consumptionLoan,
        DebtSubtypes.businessLoan,
        DebtSubtypes.creditCard,
        DebtSubtypes.other,
      ]) {
        await pickMore(t, k);
        expect(find.byKey(const ValueKey('subtypeConflictCallout')),
            findsNothing);
      }
      expect(find.textContaining('分类与关联账户'), findsNothing);
    });

    testWidgets('编辑态存量冲突(family × loan 载体)仍显 —— 数据修复入口', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        // 存量不一致数据:family 债挂在 loan 载体上(旧表单自由组合产物)。
        existing: existingDebt(subtype: DebtSubtypes.family, accountId: 'loan-1'),
      ));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('subtypeConflictCallout')), findsOneWidget,
          reason: '编辑态存量冲突仍显(数据修复入口)');
      expect(find.textContaining('分类与关联账户'), findsOneWidget);
      expect(find.text('可照常保存'), findsOneWidget);
      expect(find.textContaining('亲友借款」一般不挂在'), findsOneWidget);
    });

    testWidgets('编辑态兼容(creditLoan × loan 载体)不显', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(subtype: DebtSubtypes.creditLoan),
      ));
      await t.pumpAndSettle();
      expect(find.textContaining('分类与关联账户'), findsNothing);
    });

    // 评审 M-4:编辑态 other × otherLiability 载体不显警示 —— other 兜底类
    // 特判钉测(若非特判,otherLiability × other 按白名单本应冲突)。
    testWidgets('编辑态 other × otherLiability 载体不显警示(other 特判)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_otherLiabilityAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(
            subtype: DebtSubtypes.other, accountId: 'ol-1'),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('subtypeConflictCallout')), findsNothing,
          reason: 'other 兜底类编辑态恒不提示(isConflict 特判)');
      expect(find.textContaining('分类与关联账户'), findsNothing);
    });

    testWidgets(
        'non-blocking: 编辑冲突态照常提交(update called, subtype=family)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const UpdateDebtParams(
        id: '',
        counterparty: '',
        interestRate: 0,
        version: 0,
      ));
      String? capturedSubtype;
      var updated = false;
      when(() => debtRepo.update(
              id: any(named: 'id'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              version: any(named: 'version'),
              subtype: any(named: 'subtype'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              amortizationIndex: any(named: 'amortizationIndex'),
              dueDate: any(named: 'dueDate'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              interestWaivedCents: any(named: 'interestWaivedCents'),
              termPeriods: any(named: 'termPeriods'))).thenAnswer((inv) {
        capturedSubtype = inv.namedArguments[#subtype] as String?;
        updated = true;
        return Future.value(dartz.Right(existingDebt(counterparty: '已改')));
      });
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing:
            existingDebt(subtype: DebtSubtypes.family, accountId: 'loan-1'),
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('subtypeConflictCallout')), findsOneWidget);

      // 照常改字段提交 → 校验零阻断,update 携带 family subtype。
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '张三');
      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && !updated; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(updated, isTrue);
      expect(capturedSubtype, DebtSubtypes.family);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('subtype icon keys 渲染(二级 2 + 更多 5;迁移自 9 类图标测)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // 二级(房贷/车贷):点 mortgage 卡展开。
      await tapScenario(t, DebtScenarioCard.mortgageAuto);
      expect(find.byKey(const ValueKey('debtTypeIcon-mortgage')), findsOneWidget);
      expect(find.byKey(const ValueKey('debtTypeIcon-auto_loan')), findsOneWidget);
      // 更多枚举 5 类 icon(防漏项回归:icon switch 漏 case 落 default 兜底)。
      await scrollTo(t, find.byKey(const ValueKey('scenarioMoreToggle')));
      await t.tap(find.byKey(const ValueKey('scenarioMoreToggle')));
      await t.pumpAndSettle();
      for (final key in DebtScenarioCard.moreSubtypes) {
        expect(find.byKey(ValueKey('debtTypeIcon-$key')), findsOneWidget,
            reason: 'debtTypeIcon-$key 缺失');
      }
    });
  });

  // F62 渐进披露三段 + 期供预览(FR-4)。
  group('F62 渐进披露三段 + 期供预览', () {
    testWidgets('段③折叠展开:「已收起 N 项」→ 展开 → 字段可见 + 「已展开」',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 默认折叠:折叠头计数(普通贷款 = 年利率+摊还方法+利息减免+担保人合同 = 4 项)。
      expect(find.text('已收起 4 项'), findsOneWidget,
          reason: '折叠头显「已收起 N 项」(FR-4)');
      expect(find.byKey(const ValueKey('rateField')), findsNothing,
          reason: '折叠时字段不可视(Offstage)');
      // 展开:字段出现,折叠头翻「已展开」。
      await openAdvanced(t);
      expect(find.text('已展开'), findsOneWidget);
      expect(find.byKey(const ValueKey('rateField')), findsOneWidget);
      expect(find.textContaining('摊还方法'), findsWidgets);
      expect(find.textContaining('担保人'), findsWidgets);
      // 收起恢复。
      await t.tap(find.byKey(const ValueKey('advancedFoldToggle')));
      await t.pumpAndSettle();
      expect(find.text('已收起 4 项'), findsOneWidget);
      expect(find.byKey(const ValueKey('rateField')), findsNothing);
    });

    testWidgets('期供粗预览:8400 ÷ 12 → 约 ¥700/期 · 共 12 期 + 附注', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 按期数模式(段① termModeToggle)→ 粗预览即时可用(无需起始日)。
      await t.tap(find.text('按期数'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('principalField')), '8400');
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('roughPreviewRow')),
              matching: find.text('约 ¥700/期 · 共 12 期')),
          findsOneWidget,
          reason: 'FR-4 粗口径 = 本金 ÷ 期数(8400/12=700,与原型一致)');
      // 附注(「以保存后生成的期表为准」)。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('roughPreviewRow')),
              matching: find.textContaining('以保存后生成的期表为准')),
          findsOneWidget);
      // 联动:改期数 → 预览刷新(8400/24=350)。
      await t.enterText(find.byKey(const ValueKey('termPeriodsField')), '24');
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('roughPreviewRow')),
              matching: find.textContaining('¥350/期')),
          findsOneWidget);
    });

    testWidgets('卡贷路径高级计数含每期手续费/占用开关(动态 N)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 切卡贷并挂卡 → 高级 = 每期手续费+名义年化+利息减免+占用开关+担保人 = 5 项。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      await t.tap(find.text('招商银行信用卡').last);
      await t.pumpAndSettle();
      expect(find.text('已收起 5 项'), findsOneWidget,
          reason: '卡贷高级含每期手续费与占用开关(FR-4/FR-5)');
    });

    // 评审 I-3:折叠内必填校验无声死区 —— validate 失败 → 高级自动展开
    // 显露行内错误(R21 规范 E1:行内校验,不 toast 弹射)。
    testWidgets('I-3 折叠态空卡贷手续费提交 → 高级自动展开显露行内错误',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'loan-1'),
            _creditCardAccount(id: 'cc-1'),
            _cashAccount(id: 'cash-1'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 卡贷 + 挂卡 + 债权方/本金;每期手续费留空且高级保持折叠。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      await t.tap(find.text('招商银行信用卡').last);
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '招行备用金');
      await t.enterText(find.byKey(const ValueKey('principalField')), '60000');
      expect(find.byKey(const ValueKey('advancedHintClosed')), findsOneWidget,
          reason: '前置:高级默认折叠');

      // 提交 → validate 失败(每期手续费空)→ 高级自动展开 + 行内错误可见。
      await scrollTo(t, find.byKey(const ValueKey('submitButton')));
      await t.tap(find.byKey(const ValueKey('submitButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('advancedHintOpen')), findsOneWidget,
          reason: '折叠内必填校验失败 → 自动展开(I-3,无声死区消除)');
      expect(find.text('请输入每期手续费'), findsOneWidget,
          reason: '行内错误随展开显露');
      // 未提交:表单仍在(宿主页未回)。
      expect(find.byKey(const ValueKey('submitButton')), findsOneWidget);
    });
  });

  // F62 载体户隐形(FR-3/ADR-3)+ seed 直达(F52 预设兼容语义)+ 表单级
  // 灰显过滤接线(FR-2;组件级单测见 filtered_account_picker_test)。
  group('F62 载体隐形 + 灰显过滤接线(F49 FR-3 迁移)', () {
    testWidgets('普通贷款:无「关联账户」字段 + 载体说明(FR-3)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'l1', name: '招行房贷'),
            _cardLoanCarrierAccount(),
            _creditCardAccount(),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 「关联账户」字段整体消失(普通贷款);小字说明自动建管理账户。
      expect(find.byKey(const ValueKey('accountDropdown')), findsNothing,
          reason: 'FR-3:普通贷款表单不出现「关联账户/载体」字段');
      expect(find.byKey(const ValueKey('carrierAutoNote')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('carrierAutoNote')),
              matching: find.textContaining('系统将自动生成管理账户')),
          findsOneWidget);
      // 到账卡选择器在场(FilteredAccountPicker,替代旧到账下拉)。
      expect(find.byKey(const ValueKey('disbursementDropdown')), findsOneWidget);
    });

    testWidgets('保存 → 自动创建隐藏载体户(isSystem=true,债务落新载体)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      registerFallbackValue(const CreateAccountParams(
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.loan,
        currencyCode: '',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ));
      CreateAccountParams? capturedAccount;
      when(() => accountRepo.create(any())).thenAnswer((inv) {
        capturedAccount = inv.positionalArguments[0] as CreateAccountParams;
        return Future.value(dartz.Right(_loanAccount(id: 'auto-carrier-1')));
      });
      when(() => accountRepo.list()).thenAnswer((_) async =>
          dartz.Right([_loanAccount(), _cashAccount()]));
      String? capturedDebtAccountId;
      String? capturedSubtype;
      var created = false;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'))).thenAnswer((inv) {
        capturedDebtAccountId = inv.namedArguments[#accountId] as String?;
        capturedSubtype = inv.namedArguments[#subtype] as String?;
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2030, 7, 1),
        disbursementAccountId: 'cash-1',
        // 不 seed accountId → 触发载体自动创建(ADR-3)。
      ));
      await t.pumpAndSettle();

      // 默认场景一(信用贷款)填必填。
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '美团借钱');
      await t.enterText(find.byKey(const ValueKey('principalField')), '8400');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('rateField')), '7.2');

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && capturedAccount == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue, reason: '载体建户成功后继续 dispatch 创建');
      expect(capturedAccount, isNotNull);
      // FR-3:隐藏载体户(isSystem 既有机制)+ 自动创建标记。
      expect(capturedAccount!.isSystem, isTrue,
          reason: '普通贷款载体户隐藏(isSystem=true)');
      expect(capturedAccount!.notes, contains('自动创建'));
      expect(capturedAccount!.category, AccountCategory.loan);
      expect(capturedAccount!.name, contains('美团借钱'));
      // 接线:债务落在新载体上;subtype = 场景一推导 creditLoan。
      expect(capturedDebtAccountId, 'auto-carrier-1');
      expect(capturedSubtype, DebtSubtypes.creditLoan);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('亲友借款 → 载体类别 otherLiability(亲和白名单,不造冲突)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      registerFallbackValue(const CreateAccountParams(
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.loan,
        currencyCode: '',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ));
      CreateAccountParams? capturedAccount;
      when(() => accountRepo.create(any())).thenAnswer((inv) {
        capturedAccount = inv.positionalArguments[0] as CreateAccountParams;
        return Future.value(
            dartz.Right(_otherLiabilityAccount(id: 'auto-ol-1')));
      });
      when(() => accountRepo.list()).thenAnswer((_) async =>
          dartz.Right([_loanAccount(), _cashAccount()]));
      var created = false;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'))).thenAnswer((_) {
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2027, 7, 1),
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      await tapScenario(t, DebtScenarioCard.family);
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '表哥');
      await t.enterText(find.byKey(const ValueKey('principalField')), '5000');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('rateField')), '0');

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && capturedAccount == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue);
      expect(capturedAccount!.category, AccountCategory.otherLiability,
          reason: 'family 亲和 otherLiability(DebtSubtypeAffinity 白名单)');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('seed accountId 直达(零行为变化,不建载体)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      when(() => accountRepo.list()).thenAnswer((_) async =>
          dartz.Right([_loanAccount(id: 'loan-1'), _cashAccount()]));
      String? capturedDebtAccountId;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'))).thenAnswer((inv) {
        capturedDebtAccountId = inv.namedArguments[#accountId] as String?;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2030, 7, 1),
        accountId: 'loan-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '招商银行');
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('rateField')), '5.0');
      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && capturedDebtAccountId == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(capturedDebtAccountId, 'loan-1',
          reason: 'seed/深链 accountId 直达 —— 不触发载体自动创建');
      verifyNever(() => accountRepo.create(any()));
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('编辑 creditCard:挂卡选择器回显存量卡(value ⊆ items)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_creditCardAccount(id: 'cc-1', name: '平安信用卡'), _cashAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(
            subtype: DebtSubtypes.creditCard, accountId: 'cc-1'),
      ));
      await t.pumpAndSettle();

      // 编辑反选 creditCard → 挂卡选择器渲染且存量卡回显
      // (retention 缺失时 DropdownButtonFormField 会因 value ⊄ items 抛断言)。
      expect(find.byKey(const ValueKey('accountDropdown')), findsOneWidget);
      expect(find.text('平安信用卡'), findsWidgets,
          reason: '编辑态当前账户必须保留在选择器(value 命中 items)');
    });

    // 评审 I-1①:切入 credit_card 时仅保留信用卡类挂卡 —— 编辑存量挂的
    // loan 载体清空,不得作为灰显回显(镜像旧 debtType 直选语义)。
    testWidgets('I-1① 编辑 creditLoan(挂 loan 载体)→ 更多类型→信用卡 → 挂卡清空',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'loan-1', name: '招行房贷'),
            _creditCardAccount(id: 'cc-1', name: '招行信用卡'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(
            subtype: DebtSubtypes.creditLoan, accountId: 'loan-1'),
      ));
      await t.pumpAndSettle();

      await pickMore(t, DebtSubtypes.creditCard);
      await t.pumpAndSettle();
      // 不兼容 loan 载体被清空:闭合态不回显,退回 hint。
      expect(find.byKey(const ValueKey('accountDropdown')), findsOneWidget);
      expect(find.text('招行房贷'), findsNothing,
          reason: '切入信用卡后 loan 载体不得作为挂卡选中值回显');
      expect(find.textContaining('选择信用卡账户'), findsWidgets,
          reason: '挂卡清空 → hint 复现(待重选)');
      // 灰显上下文保留:下拉内贷款户灰显(不可选),信用卡可选。
      await openDropdown(t, const ValueKey('accountDropdown'));
      final loanItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('招行房贷').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(loanItem.enabled, isFalse,
          reason: 'loan 载体在挂卡选择器恒灰显(FR-2)');
      final ccItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('招行信用卡').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(ccItem.enabled, isTrue);
    });

    // 评审 I-1②:创建态 seed 资产户(initialAccountId)切信用卡同清空。
    testWidgets('I-1② 创建态 seed 资产户 → 更多类型→信用卡 → 挂卡清空', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _cashAccount(),
            _creditCardAccount(id: 'cc-1', name: '招行信用卡'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        accountId: 'cash-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      await pickMore(t, DebtSubtypes.creditCard);
      await t.pumpAndSettle();
      // seed 的资产户非信用卡 → 切入后挂卡清空(hint 复现);
      // 到账卡选择器不受影响(seed 值仍回显)。
      expect(find.textContaining('选择信用卡账户'), findsWidgets,
          reason: '资产户 seed 被清空 → 挂卡 hint 复现');
      final ccPicker = find.byKey(const ValueKey('accountDropdown'));
      expect(
          find.descendant(of: ccPicker, matching: find.text('招商银行储蓄卡')),
          findsNothing,
          reason: '资产户不得作为挂卡选中值回显');
      expect(find.text('招商银行储蓄卡'), findsWidgets,
          reason: '到账卡选择器仍回显 seed 的资产户(两选择器互不串扰)');
    });

    // 评审 I-2:载体户(isSystem)在三个灰显下拉(到账卡/挂卡/关联卡)
    // 的 items 中均不可见 —— F49 FR-3 消费点迁移钉测(池 = userVisible)。
    testWidgets('I-2 载体户(isSystem)不出现在到账卡/挂卡/关联卡下拉 items',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_cashAccount(), _cardLoanCarrierAccount(isSystem: true)]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // ① 到账卡:资产亮,载体户不出现在 items(灰显池滤 isSystem)。
      await openDropdown(t, const ValueKey('disbursementDropdown'));
      expect(find.text('招商银行储蓄卡'), findsWidgets);
      expect(find.text('平安银行 · 卡贷'), findsNothing,
          reason: '载体户对到账卡不可见不可选(FR-3,评审 I-2)');
      // 选资产并合上菜单(后续交互需要菜单关闭)。
      await t.tap(find.text('招商银行储蓄卡').last);
      await t.pumpAndSettle();

      // ② 卡贷挂卡:切场景卡后,载体户不出现在 items。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      expect(find.text('平安银行 · 卡贷'), findsNothing,
          reason: '载体户对挂卡选择器不可见(评审 I-2)');
      // 池内唯一项 = 资产户,灰显(仅信用卡可挂接)+ 原因句在场。
      expect(find.textContaining('仅信用卡账户可挂接'), findsOneWidget);
      await t.tapAt(const Offset(700, 60)); // 点外合上菜单
      await t.pumpAndSettle();

      // ③ 信用卡消费分期关联卡:同断言。
      await pickMore(t, DebtSubtypes.creditCard);
      await openDropdown(t, const ValueKey('accountDropdown'));
      expect(find.text('平安银行 · 卡贷'), findsNothing,
          reason: '载体户对关联卡选择器不可见(评审 I-2)');
    });

    testWidgets('到账卡灰显过滤(表单级接线):资产亮/信用卡灰+原因/贷款灰',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _cashAccount(),
            _creditCardAccount(id: 'cc-1', name: '平安信用卡'),
            _loanAccount(id: 'l1', name: '平安车主贷'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      await openDropdown(t, const ValueKey('disbursementDropdown'));
      // 原型口径原因句;灰显项 disabled。
      expect(find.text('信用卡不能作为到账卡'), findsOneWidget);
      expect(find.textContaining('负债账户不可作为到账账户'), findsOneWidget);
      final ccItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('平安信用卡').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(ccItem.enabled, isFalse);
      final savItem = t.widget<DropdownMenuItem<String>>(
        find.ancestor(
            of: find.text('招商银行储蓄卡').first,
            matching: find.byType(DropdownMenuItem<String>)),
      );
      expect(savItem.enabled, isTrue);
      // 点资产 → 选中;点灰显项 → 不动。
      await t.tap(find.text('平安信用卡').last);
      await t.pumpAndSettle();
      await openDropdown(t, const ValueKey('disbursementDropdown'));
      await t.tap(find.text('招商银行储蓄卡').last);
      await t.pumpAndSettle();
      // 选中值在闭合态回显(段②)。
      expect(find.text('招商银行储蓄卡'), findsWidgets);
    });
  });

  // F50 —— 债级开关「计入挂接卡额度占用」:仅 subtype==card_loan 且挂接了卡
  // (并账模式 + 已选卡 / 编辑态 collectionAccountId 非空)显示;默认开;
  // 随保存写入(countsTowardCardLimit 全链路透传)。F62:开关随段③高级。
  group('F50 计入挂接卡额度占用开关', () {
    /// 编辑态夹具:挂接卡贷(collectionAccountId 非空)。
    Debt cardLoanDebt({bool countsTowardCardLimit = true}) => Debt(
          id: 'd-cl',
          accountId: 'loan-1',
          counterparty: '招行e招贷',
          interestRate: 0.1,
          amortization: AmortizationMethod.equalPrincipalInterest,
          startDate: DateTime(2026, 7, 1),
          dueDate: DateTime(2027, 7, 1),
          totalPrincipalCents: 6000000,
          remainingPrincipalCents: 6000000,
          version: 3,
          subtype: DebtSubtypes.cardLoan,
          collectionAccountId: 'cc-1',
          countsTowardCardLimit: countsTowardCardLimit,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 8, 1),
        );

    Finder switchTile() =>
        find.byKey(const ValueKey('countsTowardCardLimitSwitch'));

    testWidgets('① 非卡贷(mortgage)不显示开关行', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // 默认 creditLoan → 卡贷区都不渲染,开关行更不该出现(含折叠挂载)。
      expect(find.byKey(const ValueKey('countsTowardCardLimitSwitch'),
          skipOffstage: false), findsNothing);
      expect(find.byKey(const ValueKey('countsTowardCardLimitRow')),
          findsNothing);
    });

    testWidgets('① 卡贷并账但未选挂接卡(非挂接)不显示开关行;选卡后显示且默认开',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 切到卡贷(并账默认)→ 未选挂接卡 → 开关行隐藏(含折叠挂载)。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('countsTowardCardLimitSwitch'),
          skipOffstage: false), findsNothing,
          reason: '卡贷未挂接卡(collectionAccountId 空)不显示开关');

      // 选挂接卡 → 开关行进入高级段,展开后可见且默认开。
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      await t.tap(find.text('招商银行信用卡').last);
      await t.pumpAndSettle();
      await openAdvanced(t);
      expect(switchTile(), findsOneWidget);
      expect(t.widget<SwitchListTile>(switchTile()).value, isTrue,
          reason: '新建默认开(计入占用)');
    });

    testWidgets('② 编辑挂接卡贷:开关默认开;既有 false 回填关', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));

      // 既有 true → 开(段③展开后断言)。
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: cardLoanDebt(countsTowardCardLimit: true),
      ));
      await t.pumpAndSettle();
      await openAdvanced(t);
      expect(switchTile(), findsOneWidget);
      expect(t.widget<SwitchListTile>(switchTile()).value, isTrue);
    });

    testWidgets('② 编辑挂接卡贷(既有 false)回填关;独立账单卡贷不显示开关',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));

      // 既有 false → 关(编辑保持,不重置为默认)。
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: cardLoanDebt(countsTowardCardLimit: false),
      ));
      await t.pumpAndSettle();
      await openAdvanced(t);
      expect(switchTile(), findsOneWidget);
      expect(t.widget<SwitchListTile>(switchTile()).value, isFalse);
    });

    testWidgets('① 编辑独立账单卡贷(collectionAccountId 空)不显示开关行',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      final indep = Debt(
        id: 'd-indep',
        accountId: 'loan-1',
        counterparty: 'e招贷独立',
        interestRate: 0.1,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2027, 7, 1),
        totalPrincipalCents: 6000000,
        remainingPrincipalCents: 6000000,
        version: 3,
        subtype: DebtSubtypes.cardLoan,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: indep,
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('countsTowardCardLimitSwitch'),
          skipOffstage: false), findsNothing,
          reason: '独立账单卡贷无挂接卡,不占卡额度语义不存在');
    });

    testWidgets('③ 创建卡贷切换开关后保存 → repo.create 收到 countsTowardCardLimit=false',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      registerFallbackValue(const CreateAccountParams(
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.loan,
        currencyCode: '',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ));
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'loan-1'),
            _creditCardAccount(id: 'cc-1'),
            _cashAccount(id: 'cash-1')
          ]));
      // 卡贷创建自动建贷款负债户 → stub accountRepo.create。
      when(() => accountRepo.create(any()))
          .thenAnswer((_) async => dartz.Right(_loanAccount(id: 'auto-loan-1')));
      bool? capturedFlag;
      var created = false;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'),
              // 卡贷创建 flatFeeCents 非默认(每期手续费)→ any() 通配。
              billingDay: any(named: 'billingDay'),
              flatFeeCents: any(named: 'flatFeeCents'),
              countsTowardCardLimit:
                  any(named: 'countsTowardCardLimit'))).thenAnswer((inv) {
        capturedFlag =
            inv.namedArguments[#countsTowardCardLimit] as bool?;
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2028, 7, 1),
        // _submit 创建路径先读 _accountId!(卡贷随后被自动建户替换)→ seed。
        accountId: 'loan-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 卡贷(并账默认)→ 选挂接卡。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await t.pumpAndSettle();
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      await t.tap(find.text('招商银行信用卡').last);
      await t.pumpAndSettle();
      // 填必填:债权方 / 本金 / 每期手续费(段③;卡贷年利率由费率推导不填)。
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '招行备用金');
      await t.enterText(find.byKey(const ValueKey('principalField')), '60000');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '50');
      // 切换开关 → 关(备用金独立额度不占卡额度)。
      await scrollTo(t, switchTile());
      await t.tap(switchTile());
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(switchTile()).value, isFalse);

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && !created; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue);
      expect(capturedFlag, isFalse,
          reason: '切换后保存 → create 链路须携带 countsTowardCardLimit=false');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('③ 编辑卡贷切换开关后保存 → repo.update 收到 countsTowardCardLimit=false',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const UpdateDebtParams(
        id: '',
        counterparty: '',
        interestRate: 0,
        version: 0,
      ));
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      bool? capturedFlag;
      var updated = false;
      when(() => debtRepo.update(
              id: any(named: 'id'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              version: any(named: 'version'),
              subtype: any(named: 'subtype'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              amortizationIndex: any(named: 'amortizationIndex'),
              dueDate: any(named: 'dueDate'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              interestWaivedCents: any(named: 'interestWaivedCents'),
              termPeriods: any(named: 'termPeriods'),
              countsTowardCardLimit:
                  any(named: 'countsTowardCardLimit'))).thenAnswer((inv) {
        capturedFlag =
            inv.namedArguments[#countsTowardCardLimit] as bool?;
        updated = true;
        return Future.value(dartz.Right(cardLoanDebt()));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: cardLoanDebt(countsTowardCardLimit: true),
      ));
      await t.pumpAndSettle();

      // 每期手续费编辑态必填(validator _required;段③)。
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '50');
      // 切换开关 → 关。
      await scrollTo(t, switchTile());
      await t.tap(switchTile());
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(switchTile()).value, isFalse);

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && !updated; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(updated, isTrue);
      expect(capturedFlag, isFalse,
          reason: '切换后保存 → update 链路须携带 countsTowardCardLimit=false');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  // F57 —— 首期锚点(并入模式卡贷常驻单选):放款次月(默认,现状)/
  // 放款当期(平安口径,首期 = 放款日当天)。副行实例化日期随起始日联动;
  // 独立账单模式不渲染本选项;提交经 CreateDebtParams.firstPeriodFromDisbursement
  // 透传(仅创建路径;编辑不重排,守卫既有)。F62:锚点随段②到账与还款。
  group('F57 首期锚点(并入模式常驻,独立不渲染)', () {
    Finder anchorRow() =>
        find.byKey(const ValueKey('firstPeriodAnchorRow'));
    Finder anchorNextMonth() =>
        find.byKey(const ValueKey('firstPeriodAnchor-nextMonth'));
    Finder anchorCurrent() =>
        find.byKey(const ValueKey('firstPeriodAnchor-current'));

    testWidgets('① 并入模式常驻:默认「放款次月」,副行/预览按起始日 8/2 实例化(次月 9/2)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'loan-1'),
            _creditCardAccount(id: 'cc-1'),
            _cashAccount(id: 'cash-1')
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 8, 2),
        dueDate: DateTime(2027, 8, 2),
        accountId: 'loan-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 切卡贷(并入模式默认)→ 锚点行常驻(段②,无需先选挂接卡)。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await t.pumpAndSettle();
      expect(anchorRow(), findsOneWidget,
          reason: '并入模式常驻渲染「首期锚点」(v15 形态 B)');
      // 副行实例化日期:8/2 起始 → 次月 2026-09-02 / 当期 2026-08-02。
      expect(
          find.descendant(
              of: anchorNextMonth(),
              matching: find.textContaining('2026-09-02')),
          findsOneWidget);
      expect(
          find.descendant(
              of: anchorCurrent(),
              matching: find.textContaining('2026-08-02')),
          findsOneWidget);
      // 预览联动(默认次月):第 1 期 = 2026-09-02。
      await t.enterText(find.byKey(const ValueKey('principalField')), '5000');
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('previewRow-01')),
              matching: find.text('2026-09-02')),
          findsOneWidget,
          reason: '默认次月 → 预览首期 = 放款日 + 1 月(FR-1)');
    });

    testWidgets('② 选当期:预览首期翻 2026-08-02,提交透传 firstPeriodFromDisbursement=true',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      registerFallbackValue(const CreateAccountParams(
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.loan,
        currencyCode: '',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ));
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'loan-1'),
            _creditCardAccount(id: 'cc-1'),
            _cashAccount(id: 'cash-1')
          ]));
      when(() => accountRepo.create(any()))
          .thenAnswer((_) async => dartz.Right(_loanAccount(id: 'auto-loan-1')));
      bool? capturedAnchor;
      var created = false;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'),
              billingDay: any(named: 'billingDay'),
              flatFeeCents: any(named: 'flatFeeCents'),
              countsTowardCardLimit: any(named: 'countsTowardCardLimit'),
              firstPeriodFromDisbursement:
                  any(named: 'firstPeriodFromDisbursement'))).thenAnswer((inv) {
        capturedAnchor =
            inv.namedArguments[#firstPeriodFromDisbursement] as bool?;
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 8, 2),
        dueDate: DateTime(2028, 8, 2),
        accountId: 'loan-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 卡贷(并账默认)→ 选挂接卡 → 填必填(债权方/本金/段③每期手续费)。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await t.pumpAndSettle();
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      await t.tap(find.text('招商银行信用卡').last);
      await t.pumpAndSettle();
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '平安现金分期');
      await t.enterText(find.byKey(const ValueKey('principalField')), '5000');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '9');

      // 预览联动:选「放款当期」→ 第 1 期翻为放款日当天 2026-08-02。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('previewRow-01')),
              matching: find.text('2026-09-02')),
          findsOneWidget,
          reason: '选择前默认次月 9/2');
      await scrollTo(t, anchorCurrent());
      await t.tap(anchorCurrent());
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('previewRow-01')),
              matching: find.text('2026-08-02')),
          findsOneWidget,
          reason: '选当期 → 预览首期 = 放款日当天(FR-1 预览随选项刷新)');

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && !created; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue);
      expect(capturedAnchor, isTrue,
          reason: '选当期保存 → create 链路须携带 firstPeriodFromDisbursement=true');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('③ 独立账单模式不渲染锚点;选过当期再切独立,提交仍 false(现状逐位)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      registerFallbackValue(const CreateAccountParams(
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.loan,
        currencyCode: '',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ));
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _loanAccount(id: 'loan-1'),
            _creditCardAccount(id: 'cc-1'),
            _cashAccount(id: 'cash-1')
          ]));
      when(() => accountRepo.create(any()))
          .thenAnswer((_) async => dartz.Right(_loanAccount(id: 'auto-loan-1')));
      bool? capturedAnchor;
      var created = false;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'),
              billingDay: any(named: 'billingDay'),
              flatFeeCents: any(named: 'flatFeeCents'),
              countsTowardCardLimit: any(named: 'countsTowardCardLimit'),
              firstPeriodFromDisbursement:
                  any(named: 'firstPeriodFromDisbursement'))).thenAnswer((inv) {
        capturedAnchor =
            inv.namedArguments[#firstPeriodFromDisbursement] as bool?;
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 8, 2),
        dueDate: DateTime(2028, 8, 2),
        accountId: 'loan-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 卡贷并账 → 锚点行在;先选「当期」再切「独立账单」→ 选项消失,
      // 且提交不得残留 true(独立模式生成行为与现状逐位一致)。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await t.pumpAndSettle();
      expect(anchorRow(), findsOneWidget);
      await scrollTo(t, anchorCurrent());
      await t.tap(anchorCurrent());
      await t.pumpAndSettle();
      final modeIndependent =
          find.byKey(const ValueKey('cardLoanMode-independent'));
      await scrollTo(t, modeIndependent);
      await t.tap(modeIndependent);
      await t.pumpAndSettle();
      expect(anchorRow(), findsNothing,
          reason: '独立账单模式(e招贷)无首期锚点分歧,不渲染(FR-1)');
      // 独立模式必填:账单日/还款日 + 债权方/本金/段③手续费。
      await t.enterText(find.byKey(const ValueKey('cardLoanBillDayField')), '5');
      await scrollTo(
          t, find.byKey(const ValueKey('cardLoanRepayDayField')));
      await t.enterText(
          find.byKey(const ValueKey('cardLoanRepayDayField')), '23');
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), 'e招贷');
      await t.enterText(find.byKey(const ValueKey('principalField')), '5000');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '9');

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && !created; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue);
      expect(capturedAnchor, isFalse,
          reason: '独立模式提交恒 false(生成行为与现状逐位一致)');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('④ 编辑态:锚点行不渲染(生成期参数不回填),预览走现状路径',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_loanAccount(id: 'loan-1'), _creditCardAccount(id: 'cc-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      final existing = Debt(
        id: 'd-f57-edit',
        accountId: 'loan-1',
        counterparty: '平安现金分期',
        interestRate: 0.072,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2026, 8, 2),
        dueDate: DateTime(2027, 8, 1),
        totalPrincipalCents: 6000000,
        remainingPrincipalCents: 6000000,
        version: 3,
        subtype: DebtSubtypes.cardLoan,
        collectionAccountId: 'cc-1',
        createdAt: DateTime(2026, 8, 2),
        updatedAt: DateTime(2026, 8, 3),
      );
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existing,
      ));
      await t.pumpAndSettle();

      // 生成期参数不持久化 → 编辑态无法真实回填 → 整行隐藏。
      expect(anchorRow(), findsNothing,
          reason: '编辑态不渲染首期锚点(选项仅创建时回答,编辑不重排守卫既有)');
      expect(anchorCurrent(), findsNothing);
      expect(anchorNextMonth(), findsNothing);
      // 锚点排除出 _effectiveDates(堵 dueDate 脱钩通道):预览首期仍走
      // 现状次月路径(8/2 起始 → 2026-09-02)。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('previewRow-01')),
              matching: find.text('2026-09-02')),
          findsOneWidget,
          reason: '编辑态预览/dueDate 推导不受锚点影响');
    });
  });

  // F49 T2 —— 建户置位(FR-1):并入模式自动载体户 isSystem=true(纯账务
  // 载体,展示层过滤);独立账单模式(e招贷)真实账户 isSystem=false 且
  // creditBillingDay/creditRepaymentDay 随建户写入。accountRepo.create 拦截
  // 捕获 CreateAccountParams(表单 → getIt<AccountRepository>().create)。
  group('F49 卡贷建户置位 (isSystem)', () {
    testWidgets(
        'merge mode (并入挂接卡) → accountRepo.create receives isSystem=true + auto-create notes',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      registerFallbackValue(const CreateAccountParams(
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.loan,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ));
      CreateAccountParams? capturedAccount;
      when(() => accountRepo.create(any())).thenAnswer((inv) {
        capturedAccount = inv.positionalArguments[0] as CreateAccountParams;
        return Future.value(dartz.Right(_cardLoanCarrierAccount()));
      });
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_creditCardAccount(id: 'cc-1', name: '平安信用卡'), _cashAccount()]));
      var created = false;
      // T2 评审补:接线断言 —— 债务必须落在刚建的载体户上(accountId 通道)。
      String? capturedDebtAccountId;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'),
              // 卡贷三参(bloc 显式携带;省略会被 noSuchMethod 前向器烘进
              // 字面默认 0,与真实 flatFeeCents≠0 失配 → stub 漏匹配)。
              interestWaivedCents: any(named: 'interestWaivedCents'),
              billingDay: any(named: 'billingDay'),
              flatFeeCents: any(named: 'flatFeeCents'))).thenAnswer((inv) {
        capturedDebtAccountId = inv.namedArguments[#accountId] as String?;
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 切「信用卡里的分期」(card_loan)—— 默认并入模式,挂接卡必选。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await t.pumpAndSettle();
      // 选挂接信用卡(并入 → collectionAccountId 语义)
      await scrollTo(t, find.byKey(const ValueKey('cardLoanCardDropdown')));
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      await t.tap(find.text('平安信用卡').last);
      await t.pumpAndSettle();
      // 债权方 / 本金 / 每期手续费(段③;日期=seed,期数=默认 12)
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '平安银行');
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '120');

      final submitFinder = find
              .byKey(const ValueKey('submitButton'))
              .evaluate()
              .isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('确认创建');
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && capturedAccount == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue, reason: '建户成功后应继续 dispatch CreateDebtRequested');
      expect(capturedAccount, isNotNull);
      // FR-1 场景1:并入模式 → 载体户 isSystem=true + notes 自动创建标记。
      expect(capturedAccount!.isSystem, isTrue,
          reason: '并入模式载体户应置 isSystem=true(F49 FR-1)');
      expect(capturedAccount!.notes, contains('自动创建'));
      // 并入模式不写账单日(账单挂在挂接卡上,非本户)。
      expect(capturedAccount!.creditBillingDay, isNull);
      // T2 评审补:建户 → CreateDebt 接线 —— accountId == 载体户 id。
      expect(capturedDebtAccountId, 'carrier-1',
          reason: '债务必须落在自动创建的载体户上(建户→CreateDebt 接线)');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets(
        'independent mode (独立账单) → isSystem=false + creditBillingDay/RepaymentDay written',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const CreateDebtParams(
        accountId: '',
        counterparty: '',
        interestRate: 0,
        amortizationIndex: 0,
        startDateOption: null,
        dueDateOption: null,
        totalPrincipalCents: 0,
      ));
      registerFallbackValue(const CreateAccountParams(
        name: '',
        accountType: AccountType.liability,
        category: AccountCategory.loan,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        ownership: Ownership.personal,
      ));
      CreateAccountParams? capturedAccount;
      when(() => accountRepo.create(any())).thenAnswer((inv) {
        capturedAccount = inv.positionalArguments[0] as CreateAccountParams;
        return Future.value(dartz.Right(_cardLoanCarrierAccount(isSystem: false)));
      });
      // T2 评审补:接线断言 —— 债务必须落在刚建的贷款账户上。
      String? capturedDebtAccountId;
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(
          [_creditCardAccount(id: 'cc-1', name: '平安信用卡'), _cashAccount()]));
      var created = false;
      when(() => debtRepo.create(
              accountId: any(named: 'accountId'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              amortizationIndex: any(named: 'amortizationIndex'),
              startDate: any(named: 'startDate'),
              dueDate: any(named: 'dueDate'),
              totalPrincipalCents: any(named: 'totalPrincipalCents'),
              type: any(named: 'type'),
              subtype: any(named: 'subtype'),
              sourceAccountId: any(named: 'sourceAccountId'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              guarantorName: any(named: 'guarantorName'),
              guarantorContact: any(named: 'guarantorContact'),
              collectionAccountId: any(named: 'collectionAccountId'),
              cycle: any(named: 'cycle'),
              interval: any(named: 'interval'),
              weekdayMask: any(named: 'weekdayMask'),
              monthlyMode: any(named: 'monthlyMode'),
              nth: any(named: 'nth'),
              termPeriods: any(named: 'termPeriods'),
              interestWaivedCents: any(named: 'interestWaivedCents'),
              billingDay: any(named: 'billingDay'),
              flatFeeCents: any(named: 'flatFeeCents'))).thenAnswer((inv) {
        capturedDebtAccountId = inv.namedArguments[#accountId] as String?;
        created = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 7, 1),
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 切「信用卡里的分期」→ 再切「独立账单」模式(如 e招贷)。
      await tapScenario(t, DebtScenarioCard.creditCardInstallment);
      await t.pumpAndSettle();
      await scrollTo(t, find.byKey(const ValueKey('cardLoanMode-independent')));
      await t.tap(find.byKey(const ValueKey('cardLoanMode-independent')));
      await t.pumpAndSettle();
      // 账单日 / 还款日(独立账单模式必填 1-31;段②)+ 段③手续费。
      await t.enterText(find.byKey(const ValueKey('cardLoanBillDayField')), '5');
      await t.enterText(
          find.byKey(const ValueKey('cardLoanRepayDayField')), '23');
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '招商银行');
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '120');

      final submitFinder = find
              .byKey(const ValueKey('submitButton'))
              .evaluate()
              .isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('确认创建');
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 20 && capturedAccount == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(created, isTrue, reason: '建户成功后应继续 dispatch CreateDebtRequested');
      expect(capturedAccount, isNotNull);
      // FR-1 场景2:独立账单模式 → 真实账户,不置位。
      expect(capturedAccount!.isSystem, isFalse,
          reason: '独立账单模式是真实账户,isSystem 必须 false(F49 FR-1)');
      expect(capturedAccount!.creditBillingDay, 5);
      expect(capturedAccount!.creditRepaymentDay, 23);
      // T2 评审补:建户 → CreateDebt 接线 —— accountId == 新建贷款账户 id。
      expect(capturedDebtAccountId, 'carrier-1',
          reason: '债务必须落在自动创建的贷款账户上(建户→CreateDebt 接线)');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  // F49 T10 —— 编辑切换同步(FR-1 评审补,闭合中间态):编辑卡贷切换出账
  // 方式时同步账户标记 —— 并入→独立:载体户 isSystem→false(转真实账户,
  // 账单日经账户编辑补);独立→并入:isSystem→true 且清空账单日/还款日
  // (转载体);无切换 = 零动作。accountRepo.update 拦截捕获 UpdateAccountParams。
  group('F49 编辑切换同步 (FR-1 评审补)', () {
    testWidgets('并入→独立:载体户 isSystem→false,不清账单日', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const UpdateAccountParams(id: '', version: 0));
      // 存量并入型:载体户 isSystem=true(建户置位产物),挂接卡供回填。
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _cardLoanCarrierAccount(isSystem: true),
            _creditCardAccount(id: 'cc-1', name: '平安信用卡'),
          ]));
      UpdateAccountParams? capturedUpdate;
      when(() => accountRepo.update(any())).thenAnswer((inv) {
        capturedUpdate = inv.positionalArguments[0] as UpdateAccountParams;
        return Future.value(
            dartz.Right(_cardLoanCarrierAccount(isSystem: false, version: 2)));
      });
      final isUpdated = _stubDebtUpdate(debtRepo);
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(
            subtype: DebtSubtypes.cardLoan,
            accountId: 'carrier-1',
            collectionAccountId: 'cc-1'),
      ));
      await t.pumpAndSettle();

      // 切「独立账单」(编辑态账单日字段禁用,空值不得阻断提交 —— 语义:
      // 存量账单日经「账户 → 编辑」补)。
      await scrollTo(t, find.byKey(const ValueKey('cardLoanMode-independent')));
      await t.tap(find.byKey(const ValueKey('cardLoanMode-independent')));
      await t.pumpAndSettle();
      // 每期手续费:卡贷必填校验(编辑态不回填,存量行为;段③)。
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '120');

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && !isUpdated(); i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(isUpdated(), isTrue, reason: '债务更新照常 dispatch(切换不阻断保存)');
      expect(capturedUpdate, isNotNull, reason: '切换出账方式必须同步载体户标记');
      expect(capturedUpdate!.id, 'carrier-1');
      expect(capturedUpdate!.version, 1, reason: '用存量账户 version(乐观锁)');
      expect(capturedUpdate!.isSystem, isFalse,
          reason: '并入→独立:载体转真实账户(可经账户编辑补账单日)');
      expect(capturedUpdate!.clearCreditScheduleDays, isFalse,
          reason: '并入→独立不清账单日(账户编辑补)');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('独立→并入:isSystem→true + 清空账单日/还款日(转载体)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const UpdateAccountParams(id: '', version: 0));
      // 存量独立型(e招贷):真实账户 isSystem=false + 自有账单日/还款日。
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _cardLoanCarrierAccount(
                isSystem: false, creditBillingDay: 5, creditRepaymentDay: 23),
            _creditCardAccount(id: 'cc-1', name: '平安信用卡'),
          ]));
      UpdateAccountParams? capturedUpdate;
      when(() => accountRepo.update(any())).thenAnswer((inv) {
        capturedUpdate = inv.positionalArguments[0] as UpdateAccountParams;
        return Future.value(
            dartz.Right(_cardLoanCarrierAccount(isSystem: true, version: 2)));
      });
      final isUpdated = _stubDebtUpdate(debtRepo);
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        // collectionAccountId 缺省 null = 独立账单模式。
        existing: existingDebt(
            subtype: DebtSubtypes.cardLoan, accountId: 'carrier-1'),
      ));
      await t.pumpAndSettle();

      // 切「并入信用卡账单」+ 选挂接卡。
      await scrollTo(t, find.byKey(const ValueKey('cardLoanMode-merge')));
      await t.tap(find.byKey(const ValueKey('cardLoanMode-merge')));
      await t.pumpAndSettle();
      await scrollTo(t, find.byKey(const ValueKey('cardLoanCardDropdown')));
      await openDropdown(t, const ValueKey('cardLoanCardDropdown'));
      await t.tap(find.text('平安信用卡').last);
      await t.pumpAndSettle();
      // 每期手续费:卡贷必填校验(编辑态不回填,存量行为;段③)。
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '120');

      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && !isUpdated(); i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(isUpdated(), isTrue);
      expect(capturedUpdate, isNotNull);
      expect(capturedUpdate!.id, 'carrier-1');
      expect(capturedUpdate!.isSystem, isTrue,
          reason: '独立→并入:真实账户转载体(展示层隐藏)');
      expect(capturedUpdate!.clearCreditScheduleDays, isTrue,
          reason: '独立→并入:清空账单日/还款日(账单语义随挂接卡走)');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('无切换(并入→并入):零动作(update 不被调)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const UpdateAccountParams(id: '', version: 0));
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _cardLoanCarrierAccount(isSystem: true),
            _creditCardAccount(id: 'cc-1', name: '平安信用卡'),
          ]));
      when(() => accountRepo.update(any())).thenAnswer((_) async =>
          dartz.Right(_cardLoanCarrierAccount(isSystem: true, version: 2)));
      final isUpdated = _stubDebtUpdate(debtRepo);
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(
            subtype: DebtSubtypes.cardLoan,
            accountId: 'carrier-1',
            collectionAccountId: 'cc-1'),
      ));
      await t.pumpAndSettle();

      // 不碰出账方式,只改债权方 → 提交(手续费为卡贷必填,补填放行;段③)。
      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '广发银行');
      await openAdvanced(t);
      await t.enterText(find.byKey(const ValueKey('cardLoanFeeField')), '120');
      final submitFinder = find.byKey(const ValueKey('submitButton'));
      await scrollTo(t, submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && !isUpdated(); i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(isUpdated(), isTrue, reason: '无切换照常保存债务');
      // 无切换 = 零动作,不得触发账户标记同步。
      verifyNever(() => accountRepo.update(any()));
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  // ── F59 FR-5(ADR-3):表单页接线 —— AppBar 退役 + 三级注入 + 离开守卫 ──
  group('F59 FR-5 表单页接线', () {
    /// 推入式 harness:form 页 push 于宿主页之上(系统返回断言的「回来」锚点,
    /// 照 form_leave_guard_test 先例)。两 port 注册(生产 injection 1k 同款;
    /// 同测试内多次 pumpPushed 复用注册,tearDown 统一 reset)。
    Future<void> pumpPushed(WidgetTester t, {Debt? existing}) async {
      if (!GetIt.instance.isRegistered<ShellDetailTitle>()) {
        GetIt.instance.registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
      }
      if (!GetIt.instance.isRegistered<FormLeaveGate>()) {
        GetIt.instance.registerLazySingleton<FormLeaveGate>(FormLeaveGate.new);
      }
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
          BlocProvider<CurrencyBloc>.value(
            value: _FakeCurrencyBloc(const CurrencyState()),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                    builder: (_) => DebtFormPage(existing: existing),
                  )),
                  child: const Text('__host__'),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('__host__'));
      await t.pumpAndSettle();
      await t.pump(const Duration(milliseconds: 50)); // DetailTitleSync 帧回调
    }

    testWidgets('AppBar 零残留(创建/编辑两态)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await pumpPushed(t);
      expect(find.byType(AppBar), findsNothing, reason: '自带 AppBar 导航退役');
      // 净态退栈后再推编辑态(Navigator element 复用,push 残留会挡宿主页)。
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      await pumpPushed(t, existing: existingDebt());
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('注入串两态:创建「新建债务」/ 编辑「编辑 · 债权方」', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await pumpPushed(t);
      expect(GetIt.instance<ShellDetailTitle>().value, '新建债务');
      // 净态退栈后再推编辑态;dispose 顺带清注入(下轮重新注入编辑串)。
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();

      await pumpPushed(t, existing: existingDebt(counterparty: '王五'));
      expect(GetIt.instance<ShellDetailTitle>().value, '编辑 · 王五');
    });

    testWidgets('净态:系统返回直放,零弹框', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await pumpPushed(t);

      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing, reason: '净态零摩擦');
      expect(find.text('__host__'), findsOneWidget, reason: '已回到宿主页');
    });

    testWidgets('脏态:系统返回弹确认 ——「继续编辑」留下,「放弃修改」放行', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await pumpPushed(t);
      // 首改即脏:改债权方。
      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '张三');
      await t.pumpAndSettle();

      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.text('未保存的修改'), findsOneWidget);
      await t.tap(find.text('继续编辑'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('counterpartyField')), findsOneWidget,
          reason: '「继续编辑」应留在表单');

      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.text('未保存的修改'), findsOneWidget);
      await t.tap(find.text('放弃修改'));
      await t.pumpAndSettle();
      expect(find.text('__host__'), findsOneWidget, reason: '「放弃修改」放行离开');
    });

    testWidgets('脏态:面包屑 page 级 veto 通道(gate.mayLeave)同弹确认', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await pumpPushed(t);
      // 净态问询:直 true 零弹框。
      expect(await GetIt.instance<FormLeaveGate>().mayLeave(), isTrue);
      expect(find.byType(AlertDialog), findsNothing);

      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '张三');
      await t.pumpAndSettle();
      final leave = GetIt.instance<FormLeaveGate>().mayLeave();
      await t.pump();
      expect(find.text('未保存的修改'), findsOneWidget, reason: '面包屑路径同守卫');
      await t.tap(find.text('放弃修改'));
      await t.pumpAndSettle();
      expect(await leave, isTrue);
      // mayLeave 只问询不导航:表单仍在树。
      expect(find.byKey(const ValueKey('counterpartyField')), findsOneWidget);
    });

    testWidgets('dispose 清理注入标题 + gate 无残留注册', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await pumpPushed(t);
      expect(GetIt.instance<ShellDetailTitle>().value, '新建债务');
      // 净态直走 → dispose。
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(GetIt.instance<ShellDetailTitle>().value, isNull,
          reason: '页面 dispose 清注入标题');
      expect(await GetIt.instance<FormLeaveGate>().mayLeave(), isTrue,
          reason: 'veto 随 dispose 注销');
    });
  });
}

/// 复用 _emptyDetail 的 Debt 结构,counterparty/version/subtype 可指定。
/// (F33-T5 从「编辑模式」group 提升到文件级,供 T5 归位 group 复用;
/// F49 T10 增 accountId/collectionAccountId 供卡贷编辑切换同步组复用。)
Debt existingDebt({
  String id = 'd-1',
  String counterparty = '招商银行',
  // 存储约定=小数(0.0425 即 4.25%;表单回显转百分数,提交 /100)。
  double interestRate = 0.0425,
  int totalPrincipalCents = 15000000,
  int version = 3,
  String subtype = '',
  String accountId = 'loan-1',
  // 非空 = 并入模式(挂接卡);null(缺省)= 独立账单(e招贷)。
  String? collectionAccountId,
}) =>
    Debt(
      id: id,
      accountId: accountId,
      counterparty: counterparty,
      interestRate: interestRate,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2025, 1, 1),
      dueDate: DateTime(2030, 1, 1),
      totalPrincipalCents: totalPrincipalCents,
      remainingPrincipalCents: totalPrincipalCents,
      version: version,
      subtype: subtype,
      collectionAccountId: collectionAccountId,
      createdAt: DateTime(2025, 1, 1),
      updatedAt: DateTime(2025, 6, 1),
    );

/// F49:卡贷自动建户返回的载体/贷款账户(accountRepo.create 拦截用);
/// T10 编辑切换同步组兼作 list() 里的存量账户(带账单日/版本)。
Account _cardLoanCarrierAccount({
  bool isSystem = true,
  int? creditBillingDay,
  int? creditRepaymentDay,
  int version = 1,
}) =>
    Account(
      id: 'carrier-1',
      name: '平安银行 · 卡贷',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      isSystem: isSystem,
      creditBillingDay: creditBillingDay,
      creditRepaymentDay: creditRepaymentDay,
      version: version,
    );

/// F49 T10 编辑切换同步组共通:debtRepo.update 全命名参数通配 stub
/// (照既有编辑测 —— F33-T5 后 subtype 等显式携带,漏 any() 即失配)。
/// 返回「已提交」轮询闭包。
bool Function() _stubDebtUpdate(_MockDebtRepo debtRepo) {
  var updated = false;
  when(() => debtRepo.update(
          id: any(named: 'id'),
          counterparty: any(named: 'counterparty'),
          interestRate: any(named: 'interestRate'),
          version: any(named: 'version'),
          subtype: any(named: 'subtype'),
          contact: any(named: 'contact'),
          contractRef: any(named: 'contractRef'),
          guarantorName: any(named: 'guarantorName'),
          guarantorContact: any(named: 'guarantorContact'),
          collectionAccountId: any(named: 'collectionAccountId'),
          amortizationIndex: any(named: 'amortizationIndex'),
          dueDate: any(named: 'dueDate'),
          cycle: any(named: 'cycle'),
          interval: any(named: 'interval'),
          weekdayMask: any(named: 'weekdayMask'),
          monthlyMode: any(named: 'monthlyMode'),
          nth: any(named: 'nth'),
          interestWaivedCents: any(named: 'interestWaivedCents'),
          termPeriods: any(named: 'termPeriods')))
      .thenAnswer((_) {
    updated = true;
    return Future.value(dartz.Right(existingDebt(counterparty: '已改')));
  });
  return () => updated;
}

DebtDetail _emptyDetail() => DebtDetail(
      debt: Debt(
        id: 'd-new',
        accountId: 'loan-1',
        counterparty: '招商银行',
        interestRate: 5.0,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2030, 7, 1),
        totalPrincipalCents: 20000000,
        remainingPrincipalCents: 20000000,
        version: 1,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
      ),
      schedule: const [],
    );
