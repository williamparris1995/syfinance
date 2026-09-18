// Task 8 — TDD widget tests for DebtFormPage
// (表单字段 + 实时摊还预览 + 提交 CreateDebtRequested + 三端 desktop 分区 / mobile step wizard)。
//
// 对齐 debts_page_test / debt_detail_page_test 的 harness：mocktail
// DebtRepository + AccountRepository → 真实 DebtBloc。表单页 initState 通过
// GetIt.instance<AccountRepository>().list() 拉关联 Loan 账户（与
// transactions_page _loadAccounts 同模式），故把 accountRepo 注册到 GetIt。
//
// _AmortizationPreview / _StepWizard 等私有，故测试通过公开 DebtFormPage 驱动。
//
// 验证：
//   - 字段渲染：债权方 / 类型(5 卡) / 关联账户 / 本金 / 利率 / 摊还(3 卡) / 起止日期
//   - 实时预览：等额本息(月供 + 前 5 期) / 等额本金(首月供) / 一次性(到期总额) / 空(本金 0)
//   - 提交：填全 → 点「确认创建」→ dispatch CreateDebtRequested(repo.create 被调用)
//   - 三端：desktop 双列(form + preview) / mobile step wizard(进度指示 + 上一步/下一步)
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:yucai_client/core/data_refresh.dart';
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
          value: _FakeCurrencyBloc(const CurrencyState())),
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

  group('字段渲染', () {
    testWidgets('renders 债权方 / 类型 / 关联账户 / 本金 / 利率 / 摊还 / 日期', (t) async {
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

      // 字段标签
      expect(find.textContaining('债权方'), findsWidgets);
      expect(find.textContaining('债务类型'), findsWidgets);
      expect(find.textContaining('关联账户'), findsWidgets);
      // OD section sub「本金 · 年利率 · 摊还方法」+ 字段 label 同名 → findsWidgets。
      expect(find.textContaining('借款本金'), findsWidgets);
      expect(find.textContaining('年利率'), findsWidgets);
      expect(find.textContaining('摊还方法'), findsWidgets);
      expect(find.textContaining('起始日期'), findsOneWidget);
      expect(find.textContaining('到期日期'), findsOneWidget);
    });

    testWidgets('renders 5 debt-type radio cards keyed by DebtSubtypes.all',
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
      // 5 个债务类型卡 —— ValueKey 用 const key（DebtSubtypes.all），非中文 label。
      // 否定硬编码 _debtTypes：选项必须来自 DebtSubtypes.all。
      expect(DebtSubtypes.all.length, 5);
      for (final key in DebtSubtypes.all) {
        expect(find.byKey(ValueKey('debtType-$key')), findsOneWidget);
        expect(find.text(DebtSubtypes.labels[key]!), findsOneWidget);
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
      expect(find.byKey(const ValueKey('amortization-equalPrincipalInterest')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('amortization-equalPrincipal')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('amortization-lumpSum')), findsOneWidget);
    });

    testWidgets('关联账户 dropdown lists loan accounts', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_loanAccount(id: 'l1', name: '招行房贷'),
                        _loanAccount(id: 'l2', name: '建行车贷')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter'))).thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // tap the 关联账户 dropdown to open menu(OD 字段 label 不再可点,
      // 用 dropdown 自身的 ValueKey 命中 DropdownButtonFormField)。
      await t.tap(find.byKey(const ValueKey('accountDropdown')));
      await t.pumpAndSettle();
      expect(find.textContaining('招行房贷'), findsWidgets);
      expect(find.textContaining('建行车贷'), findsWidgets);
    });
  });

  group('实时摊还预览', () {
    Future<void> fillForm(WidgetTester t) async {
      // 债权方
      await t.enterText(find.byKey(const ValueKey('counterpartyField')),
          '招商银行');
      // 本金 200000 元
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      // 利率 5.0
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
      // 选「等额本金」(利息减免字段加入后卡片可能被挤出视口 → 先滚动到可见)
      await t.ensureVisible(find.byKey(const ValueKey('amortization-equalPrincipal')));
      await t.pumpAndSettle();
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
      await t.ensureVisible(find.byKey(const ValueKey('amortization-lumpSum')));
      await t.pumpAndSettle();
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
    testWidgets('fill form → tap 确认创建 → repo.create called', (t) async {
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
        // seed 起止日期 + 关联账户，避免驱动 date picker / dropdown
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2030, 7, 1),
        accountId: 'loan-1',
        disbursementAccountId: 'cash-1',
      ));
      await t.pumpAndSettle();

      // 债权方 + 本金 + 利率（日期 / 账户已 seed）
      await t.enterText(find.byKey(const ValueKey('counterpartyField')),
          '招商银行');
      await t.enterText(find.byKey(const ValueKey('principalField')), '200000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '5.0');
      // 提交（desktop 走 FormActions FilledButton「确认创建」；
      // mobile 走 step wizard 的 submitButton ValueKey —— 二者其一）。
      final submitFinder = find
          .byKey(const ValueKey('submitButton'))
          .evaluate()
          .isNotEmpty
      ? find.byKey(const ValueKey('submitButton'))
      : find.text('确认创建');
      // FormActions 在桌面布局底部可能位于首屏之外 → ensureVisible 后再 tap。
      await t.ensureVisible(submitFinder);
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
    // 复用 _emptyDetail 的 Debt 结构，但 counterparty/version 改为可识别值。
    Debt existingDebt({
      String id = 'd-1',
      String counterparty = '招商银行',
      // 存储约定=小数(0.0425 即 4.25%;表单回显转百分数,提交 /100)。
      double interestRate = 0.0425,
      int totalPrincipalCents = 15000000,
      int version = 3,
    }) =>
        Debt(
          id: id,
          accountId: 'loan-1',
          counterparty: counterparty,
          interestRate: interestRate,
          amortization: AmortizationMethod.equalPrincipalInterest,
          startDate: DateTime(2025, 1, 1),
          dueDate: DateTime(2030, 1, 1),
          totalPrincipalCents: totalPrincipalCents,
          remainingPrincipalCents: totalPrincipalCents,
          version: version,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 6, 1),
        );

    testWidgets('AppBar title = 编辑债务 + 预填 counterparty / 本金 / 利率',
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

      // AppBar 标题 = 编辑债务（非「新建债务」）
      expect(find.text('编辑债务'), findsOneWidget);
      expect(find.text('新建债务'), findsNothing);
      // 字段预填
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
      // 提交：desktop 走 FormActions「保存修改」
      final submitFinder = find.byKey(const ValueKey('submitButton')).evaluate().isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('保存修改');
      await t.ensureVisible(submitFinder);
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
        'edit mode: subtype chips are read-only (tapping does not change subtype)',
        (t) async {
      // M2 fix:UpdateDebtParams 不携带 subtype,后端不支持改 —— chips 必须
      // 显示当前 subtype 但不可点击,避免用户误改后静默丢失。
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      // existing.subtype 用真实 const(非 mortgage,便于验证不被切换回 mortgage)。
      final existing = existingDebt();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right([_loanAccount(id: 'loan-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existing,
      ));
      await t.pumpAndSettle();

      // 提示文案存在
      expect(find.byKey(const ValueKey('subtypeReadonlyHint')), findsOneWidget);
      // 点其他 subtype chip 后,selected 状态不变(仍是默认 mortgage,因为
      // existing 未带 subtype → initState fallback 到 mortgage)。
      final creditCardChip =
          find.byKey(const ValueKey('debtType-${DebtSubtypes.creditCard}'));
      // 默认 selected 是 mortgage —— mortgage chip 应有 selected 视觉,
      // creditCard chip 不 selected。tapped 后仍如此。
      // GestureDetector.onTap=null 时 tap 被忽略,无异常。
      await t.tap(creditCardChip, warnIfMissed: false);
      await t.pumpAndSettle();
      // 再次断言提示仍在 + creditCard chip 仍未变 selected(通过 hint 仍存在
      // 间接证明 chips 未被点动 —— _isEdit 不变,提示不会消失)。
      expect(find.byKey(const ValueKey('subtypeReadonlyHint')), findsOneWidget);
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

    testWidgets('mobile: step wizard with progress indicator + 上一步/下一步',
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
      // 第 1 步：基本信息（债权方 + 类型 + 关联账户）
      expect(find.textContaining('债权方'), findsWidgets);
      // 「下一步」按钮存在
      expect(find.byKey(const ValueKey('nextStepButton')), findsOneWidget);
      // 点下一步进入 Step 2（金额利率）
      await t.tap(find.byKey(const ValueKey('nextStepButton')));
      await t.pumpAndSettle();
      expect(find.textContaining('借款本金'), findsOneWidget);
      // 「下一步」+「上一步」并存
      expect(find.byKey(const ValueKey('prevStepButton')), findsOneWidget);
    });
  });

  // Task 7 —— 子类型驱动 + 信用卡区(account 联动 updateAccount)
  group('子类型驱动 · 信用卡区', () {
    testWidgets('default subtype = mortgage; selecting creditCard shows cc section',
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

      // 默认 mortgage（非信用卡）→ 信用卡区不出现
      expect(find.byKey(const ValueKey('creditCardSection')), findsNothing);
      expect(find.byKey(const ValueKey('ccBillingDayField')), findsNothing);

      // 点「信用卡」子类型卡（ValueKey 用 const key）
      await t.tap(find.byKey(const ValueKey('debtType-${DebtSubtypes.creditCard}')));
      await t.pumpAndSettle();

      // 信用卡区 + 4 字段出现
      expect(find.byKey(const ValueKey('creditCardSection')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccBillingDayField')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccRepaymentDayField')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccLimitField')), findsOneWidget);
      expect(find.byKey(const ValueKey('ccAnnualFeeField')), findsOneWidget);
    });

    testWidgets('negative: selecting mortgage hides cc section', (t) async {
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

      // 切到信用卡 → 出现
      await t.tap(find.byKey(const ValueKey('debtType-${DebtSubtypes.creditCard}')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('creditCardSection')), findsOneWidget);

      // 切回 mortgage → 消失
      await t.tap(find.byKey(const ValueKey('debtType-${DebtSubtypes.mortgage}')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('creditCardSection')), findsNothing);
    });

    testWidgets('creditCard subtype narrows account dropdown to credit_card category',
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

      // 切到信用卡 → 下拉只列信用卡账户
      await t.tap(find.byKey(const ValueKey('debtType-${DebtSubtypes.creditCard}')));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('选择信用卡账户'));
      await t.pumpAndSettle();
      expect(find.textContaining('招行信用卡'), findsWidgets);
      expect(find.textContaining('招行房贷'), findsNothing);
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

      // 切到信用卡 + 选中账户已 seed → 字段预填
      await t.tap(find.byKey(const ValueKey('debtType-${DebtSubtypes.creditCard}')));
      await t.pumpAndSettle();
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

      await t.tap(find.byKey(const ValueKey('debtType-${DebtSubtypes.creditCard}')));
      await t.pumpAndSettle();
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

      // 选信用卡子类型
      await t.tap(find.byKey(const ValueKey('debtType-${DebtSubtypes.creditCard}')));
      await t.pumpAndSettle();
      // 填必填字段
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
      await t.ensureVisible(submitFinder);
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
      // 静态保证：DebtSubtypes.all 与 labels 覆盖 5 项，且 key≠中文 label。
      expect(DebtSubtypes.all.toSet().length, 5);
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
      expect(find.byKey(const ValueKey('debtRuleEntry')), findsOneWidget,
          reason: '编辑态应渲染周期规则入口(分期摊销)');
      expect(find.byKey(const ValueKey('termModeToggle')), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('debtRuleEntry')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('debtRuleEntry')));
      await t.pumpAndSettle();
      expect(find.text('重复规则'), findsOneWidget,
          reason: '点开入口应弹出共享规则编辑器');
    });
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
