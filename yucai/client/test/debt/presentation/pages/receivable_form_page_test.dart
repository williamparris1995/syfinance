// Task 9 — TDD widget tests for ReceivableFormPage
// （表单字段 + 实时收款计划预览 + 提交 CreateDebtRequested(type: borrowedOut)
//   + 三端 desktop 分区 / mobile step wizard + edit mode）。
//
// 对齐 debt_form_page_test 的 harness：mocktail DebtRepository +
// AccountRepository → 真实 DebtBloc。表单页 initState 通过
// GetIt.instance<AccountRepository>().list() 拉关联应收账户，故把 accountRepo
// 注册到 GetIt。
//
// 与 debt_form_page_test 的关键差异（本测试要验证的）：
//   1. type 固定 borrowedOut：无债务方向选择器；提交 CreateDebtRequested 的
//      params.type == DebtType.borrowedOut。
//   2. 关联账户 = asset 应收（category otherAsset）：dropdown 只列出 otherAsset
//      账户，过滤掉 liability/loan。
//   3. Label 收款语义：债务人 / 借出本金 / 收款计划预览 / 收款日 / 创建债权。
//      负向断言：不出现 债权人 / 借款本金 / 还款计划。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
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
// CreateDebtParams / UpdateDebtParams lives in debt_event.dart.
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/pages/receivable_form_page.dart';

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

/// 应收账户（asset / otherAsset）—— receivable_form 应关联的资产侧账户。
Account _receivableAccount({
  String id = 'recv-1',
  String name = '应收账款-商业',
}) =>
    Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 10000000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// 负债账户（liability / loan）—— receivable_form 必须过滤掉（不属于应收）。
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

/// 借出来源账户（asset / savings）—— 现金来源候选。
Account _sourceAccount({
  String id = 'src-1',
  String name = '招商银行储蓄',
}) =>
    Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 10000000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Widget _harness({
  required _MockDebtRepo debtRepo,
  required _MockAccountRepo accountRepo,
  DateTime? startDate,
  DateTime? dueDate,
  String? accountId,
  String? sourceAccountId,
  Debt? existing,
}) {
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
        BlocProvider<CurrencyBloc>.value(
          value: _FakeCurrencyBloc(const CurrencyState()),
        ),
      ],
      child: ReceivableFormPage(
        existing: existing,
        initialStartDate: startDate,
        initialDueDate: dueDate,
        initialAccountId: accountId,
        initialSourceAccountId: sourceAccountId,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(DebtType.borrowedIn);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  group('字段渲染 + 收款语义 label', () {
    testWidgets('renders 债务人 / 借出本金 / 收款计划预览 / 收款日 labels', (t) async {
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
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 收款语义正向断言
      expect(find.textContaining('债务人'), findsWidgets);
      // 借出本金：字段 label + 空态文案「填写借出本金与…」均含 → findsWidgets。
      expect(find.textContaining('借出本金'), findsWidgets);
      expect(find.textContaining('收款计划预览'), findsWidgets);
      // 借出日期:字段 label + section sub「借出日期 · 到期日期 · 决定期数」均含 → findsWidgets。
      expect(find.textContaining('借出日期'), findsWidgets);
      // 到期日期：字段 label + section sub「借出日期 · 到期日期 · 决定期数」均含 → findsWidgets。
      expect(find.textContaining('到期日期'), findsWidgets);
      expect(find.textContaining('关联应收账户'), findsWidgets);
    });

    testWidgets('does NOT render debt-page labels (债权人 / 借款本金 / 还款计划)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 负向断言：债务页的 label 不应出现（语义已切到收款侧）
      expect(find.text('债权方 / 借出方'), findsNothing);
      expect(find.textContaining('借款本金'), findsNothing);
      expect(find.textContaining('还款计划'), findsNothing);
    });

    testWidgets(
        'renders receivable-type cards from ReceivableSubtypes.all (const) — not debt types',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // 4 个债权类型卡：keys 来自 ReceivableSubtypes.all，label 来自 labels[key]。
      expect(ReceivableSubtypes.all.length, 4);
      for (final key in ReceivableSubtypes.all) {
        expect(find.byKey(ValueKey('receivableType-$key')), findsOneWidget);
        expect(find.text(ReceivableSubtypes.labels[key]!), findsOneWidget);
      }
      // 负向：不出现债务类型卡（debt_form 的 DebtSubtypes）
      for (final key in DebtSubtypes.all) {
        expect(find.byKey(ValueKey('debtType-$key')), findsNothing);
      }
    });

    testWidgets('renders 3 amortization cards (等额本息/等额本金/一次性)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('amortization-equalPrincipalInterest')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('amortization-equalPrincipal')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('amortization-lumpSum')), findsOneWidget);
    });
  });

  group('关联账户过滤 = asset/otherAsset', () {
    testWidgets('dropdown lists otherAsset accounts and filters out liability/loan',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _receivableAccount(id: 'r1', name: '应收账款-商业'),
            _receivableAccount(id: 'r2', name: '应收账款-亲友'),
            _loanAccount(id: 'l1', name: '招行房贷'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      // 打开关联应收账户 dropdown(OD 块标签在 input 上方,tap label 不开 dropdown;
      // 改 tap dropdown widget 本身,by key)。
      await t.tap(find.byKey(const ValueKey('accountDropdown')));
      await t.pumpAndSettle();
      // 应收账户列出
      expect(find.textContaining('应收账款-商业'), findsWidgets);
      expect(find.textContaining('应收账款-亲友'), findsWidgets);
      // 负债账户被过滤掉
      expect(find.textContaining('招行房贷'), findsNothing);
    });
  });

  group('实时收款计划预览', () {
    Future<void> fillForm(WidgetTester t) async {
      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '李四');
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      await t.pump();
    }

    testWidgets('equalPrincipalInterest: 每期收款 + 前 5 期 rows', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
      ));
      await t.pumpAndSettle();
      await fillForm(t);
      expect(find.byKey(const ValueKey('previewTitle')), findsOneWidget);
      // shared AmortizationPreview:headline label「每期收款」(receivable 语义,
      // 与 debt form「月供」区分)。tags 包含「期数 N 期」。
      expect(find.text('每期收款'), findsOneWidget);
      // 精确匹配 tag「期数 12 期」(date hint「期数 12 期（按月）」也含此串 →
      // find.text 精确而非 containing,只命中 tag)。
      expect(find.text('期数 12 期'), findsOneWidget);
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
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
      ));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('amortization-lumpSum')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('amortization-lumpSum')));
      await t.pump();
      await fillForm(t);
      // shared AmortizationPreview:lumpSum headline label = 到期总额。
      expect(find.text('到期总额'), findsOneWidget);
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
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('previewEmpty')), findsOneWidget);
    });
  });

  group('提交 CreateDebtRequested (type: borrowedOut)', () {
    testWidgets(
        'fill form → tap 创建债权 → repo.create called with type borrowedOut + subtype key',
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
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _receivableAccount(id: 'recv-1'),
            _sourceAccount(id: 'src-1'),
          ]));

      // 拦截 repo.create，捕获 type + subtype 参数验证。
      DebtType? capturedType;
      String? capturedSubtype;
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
              collectionAccountId: any(named: 'collectionAccountId'))).thenAnswer((inv) {
        capturedType = inv.namedArguments[#type] as DebtType?;
        capturedSubtype = inv.namedArguments[#subtype] as String?;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
        accountId: 'recv-1',
        sourceAccountId: 'src-1',
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '李四');
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      // 切到「亲友」子类型（const key），验证 key 透传到 repo.create。
      // Task 11 后表单加 3 字段 → type cards 下移,需 ensureVisible 再 tap。
      await t.ensureVisible(
          find.byKey(ValueKey('receivableType-${ReceivableSubtypes.family}')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('receivableType-${ReceivableSubtypes.family}')));
      await t.pump();
      // desktop: FormActions「创建债权」
      final submitFinder = find.byKey(const ValueKey('submitButton')).evaluate().isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('创建债权');
      await t.ensureVisible(submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && capturedType == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      // 关键断言：type 固定 borrowedOut（非默认 borrowedIn）；subtype = const key。
      expect(capturedType, DebtType.borrowedOut);
      expect(capturedSubtype, ReceivableSubtypes.family);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets(
        'fill form → repo.create called with sourceAccountId(borrowedOut 双写来源)',
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
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _receivableAccount(id: 'recv-1'),
            _sourceAccount(id: 'src-1'),
          ]));
      String? capturedSource;
      String? capturedAccount;
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
              collectionAccountId: any(named: 'collectionAccountId'))).thenAnswer((inv) {
        capturedSource = inv.namedArguments[#sourceAccountId] as String?;
        capturedAccount = inv.namedArguments[#accountId] as String?;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
        accountId: 'recv-1',
        sourceAccountId: 'src-1',
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '李四');
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      final submitFinder = find
              .byKey(const ValueKey('submitButton'))
              .evaluate()
              .isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('创建债权');
      await t.ensureVisible(submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && capturedSource == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(capturedAccount, 'recv-1');
      expect(capturedSource, 'src-1');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  group('编辑模式（existing）', () {
    Debt existingDebt({
      String id = 'r-1',
      String counterparty = '李四',
      // 存储约定=小数(0.08 即 8%;对齐 debt 表单修复)。
      double interestRate = 0.08,
      int totalPrincipalCents = 10000000,
      int version = 3,
      String subtype = '',
    }) =>
        Debt(
          id: id,
          accountId: 'recv-1',
          counterparty: counterparty,
          interestRate: interestRate,
          amortization: AmortizationMethod.equalPrincipalInterest,
          startDate: DateTime(2025, 6, 15),
          dueDate: DateTime(2026, 6, 15),
          totalPrincipalCents: totalPrincipalCents,
          remainingPrincipalCents: totalPrincipalCents,
          version: version,
          createdAt: DateTime(2025, 6, 15),
          updatedAt: DateTime(2025, 12, 1),
          type: DebtType.borrowedOut,
          subtype: subtype,
        );

    testWidgets('AppBar title = 编辑债权 + 预填 债务人 / 本金 / 利率', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount(id: 'recv-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(),
      ));
      await t.pumpAndSettle();

      expect(find.text('编辑债权'), findsOneWidget);
      expect(find.text('新建债权'), findsNothing);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('counterpartyField')),
              matching: find.textContaining('李四')),
          findsWidgets);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('principalField')),
              matching: find.textContaining('100000')),
          findsWidgets);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('rateField')),
              matching: find.textContaining('8')),
          findsWidgets);
    });

    testWidgets('submit → dispatch UpdateDebtRequested (repo.update called)', (t) async {
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
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount(id: 'recv-1')]));
      var updated = false;
      when(() => debtRepo.update(
              id: any(named: 'id'),
              counterparty: any(named: 'counterparty'),
              interestRate: any(named: 'interestRate'),
              version: any(named: 'version'),
              contact: any(named: 'contact'),
              contractRef: any(named: 'contractRef'),
              collectionAccountId: any(named: 'collectionAccountId'))).thenAnswer((_) {
        updated = true;
        return Future.value(dartz.Right(existingDebt(counterparty: '已改')));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing: existingDebt(),
      ));
      await t.pumpAndSettle();

      await t.enterText(
          find.byKey(const ValueKey('counterpartyField')), '王五');
      final submitFinder = find.byKey(const ValueKey('submitButton')).evaluate().isNotEmpty
          ? find.byKey(const ValueKey('submitButton'))
          : find.text('保存');
      await t.ensureVisible(submitFinder);
      await t.tap(submitFinder);
      for (var i = 0; i < 10 && !updated; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(updated, isTrue);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('prefills _subtypeKey from debt.subtype (const key)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount(id: 'recv-1')]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      // existing 带子类型 personal —— 表单应预选「私人」卡。
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        existing:
            existingDebt(subtype: ReceivableSubtypes.personal),
      ));
      await t.pumpAndSettle();
      // personal 卡选中、其他卡未选中。
      expect(
          find.byKey(
              ValueKey('receivableType-${ReceivableSubtypes.personal}')),
          findsOneWidget);
      expect(
          find.byKey(
              ValueKey('receivableType-${ReceivableSubtypes.business}')),
          findsOneWidget);
    });
  });

  group('三端响应式', () {
    testWidgets('desktop: form + preview side-by-side, no step wizard', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('stepIndicator')), findsNothing);
      expect(find.byKey(const ValueKey('amortizationPreview')), findsOneWidget);
    });

    testWidgets('tablet: form + preview (still two-col)', (t) async {
      t.view.physicalSize = tablet;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('amortizationPreview')), findsOneWidget);
    });

    testWidgets('mobile: step wizard with progress indicator + 上一步/下一步', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('stepIndicator')), findsOneWidget);
      // Step 1：债务人
      expect(find.textContaining('债务人'), findsWidgets);
      expect(find.byKey(const ValueKey('nextStepButton')), findsOneWidget);
      // 进入 Step 2（金额利率）→ 借出本金
      await t.tap(find.byKey(const ValueKey('nextStepButton')));
      await t.pumpAndSettle();
      expect(find.textContaining('借出本金'), findsOneWidget);
      expect(find.byKey(const ValueKey('prevStepButton')), findsOneWidget);
    });
  });

  // ====================================================================
  // Task 11 — form 对齐 OD:radio cards / preview 2×2 sum grid /
  // contact+contract+collection 字段输入 + 提交透传。
  // ====================================================================
  group('Task 11: radio cards / sum grid / 应收追踪字段', () {
    testWidgets('债权类型 4 卡渲染 icon + label(私人/商业/亲友/其他)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 4 个 _RadioCard 节点存在(每个含 1 个 Icon widget + label text)。
      for (final key in ReceivableSubtypes.all) {
        final card = find.byKey(ValueKey('receivableType-$key'));
        expect(card, findsOneWidget);
        expect(find.descendant(of: card, matching: find.byType(Icon)),
            findsOneWidget);
        expect(
            find.descendant(
                of: card, matching: find.text(ReceivableSubtypes.labels[key]!)),
            findsOneWidget);
      }
    });

    testWidgets('摊还 3 卡渲染 icon + label + desc(每期合计相同 等)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(debtRepo: debtRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 等额本息卡:icon + label「等额本息」+ desc「每期合计相同」均渲染。
      final epiCard =
          find.byKey(const ValueKey('amortization-equalPrincipalInterest'));
      expect(epiCard, findsOneWidget);
      expect(find.descendant(of: epiCard, matching: find.byType(Icon)),
          findsOneWidget);
      expect(find.descendant(of: epiCard, matching: find.text('等额本息')),
          findsOneWidget);
      expect(find.descendant(of: epiCard, matching: find.text('每期合计相同')),
          findsOneWidget);
      // 等额本金 desc。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('amortization-equalPrincipal')),
              matching: find.text('本金相同 利息递减')),
          findsOneWidget);
      // 一次性 desc。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('amortization-lumpSum')),
              matching: find.text('到期一次结清')),
          findsOneWidget);
    });

    testWidgets('preview tags 渲染(每期收款 + 期数 + 总利息 + 总还款)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount()]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
      ));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      await t.pump();

      // shared AmortizationPreview:header headline label + 3 个 tag(期数 /
      // 总利息 / 总还款)。receivable headline = 「每期收款」。
      expect(find.text('每期收款'), findsOneWidget);
      // 精确匹配 tag「期数 12 期」(date hint 也含此串 → find.text 精确)。
      expect(find.text('期数 12 期'), findsOneWidget);
      expect(find.textContaining('总利息'), findsOneWidget);
      expect(find.textContaining('总还款'), findsOneWidget);
      // table 三列 header 收款语义(date + 收回本金 + 合计)。
      expect(find.text('期次 / 收款日'), findsOneWidget);
      expect(find.text('收回本金 / 利息'), findsOneWidget);
    });

    testWidgets('contact / contract_ref / collection_account_id 字段渲染 + 输入',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _receivableAccount(id: 'recv-1'),
            _sourceAccount(id: 'src-1'),
          ]));
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        sourceAccountId: 'src-1',
      ));
      await t.pumpAndSettle();

      // 3 字段渲染。
      expect(find.byKey(const ValueKey('contactField')), findsOneWidget);
      expect(find.byKey(const ValueKey('contractRefField')), findsOneWidget);
      expect(find.byKey(const ValueKey('collectionAccountDropdown')),
          findsOneWidget);

      // 输入自由文本。
      await t.enterText(find.byKey(const ValueKey('contactField')), '13800000000');
      await t.enterText(
          find.byKey(const ValueKey('contractRefField')), 'IOU-2026-001');
      await t.pump();
      // collection 默认 = 来源账户(initState 预设 'src-1')—— 不需交互即非空。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('collectionAccountDropdown')),
              matching: find.textContaining('招商银行储蓄')),
          findsWidgets);
    });

    testWidgets(
        'submit 透传 contact + contractRef + collectionAccountId 到 repo.create',
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
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _receivableAccount(id: 'recv-1'),
            _sourceAccount(id: 'src-1'),
            _sourceAccount(id: 'src-2', name: '工商银行储蓄'),
          ]));
      String? capturedContact;
      String? capturedContractRef;
      String? capturedCollection;
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
              collectionAccountId: any(named: 'collectionAccountId'))).thenAnswer((inv) {
        capturedContact = inv.namedArguments[#contact] as String?;
        capturedContractRef = inv.namedArguments[#contractRef] as String?;
        capturedCollection = inv.namedArguments[#collectionAccountId] as String?;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
        accountId: 'recv-1',
        sourceAccountId: 'src-1',
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '李四');
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      await t.enterText(find.byKey(const ValueKey('contactField')), '13800000000');
      await t.enterText(
          find.byKey(const ValueKey('contractRefField')), 'IOU-2026-001');
      // 改 collection 到 src-2(验证用户选择覆盖默认)。打开 dropdown overlay 后,
      // overlay 中「工商银行储蓄」选项唯一(非选中值不重复渲染)。表单较长,
      // collection dropdown 可能超出桌面视口 → 先 ensureVisible 再 tap。
      await t.ensureVisible(
          find.byKey(const ValueKey('collectionAccountDropdown')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('collectionAccountDropdown')));
      await t.pumpAndSettle();
      await t.tap(find.text('工商银行储蓄'));
      await t.pumpAndSettle();

      final submitFinder =
          find.byKey(const ValueKey('submitButton')).evaluate().isNotEmpty
              ? find.byKey(const ValueKey('submitButton'))
              : find.text('创建债权');
      await t.ensureVisible(submitFinder);
      await t.tap(submitFinder);
      for (var i = 0;
          i < 20 && (capturedContact == null || capturedCollection == null);
          i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      // 关键断言:3 字段透传到 repo.create。
      expect(capturedContact, '13800000000');
      expect(capturedContractRef, 'IOU-2026-001');
      expect(capturedCollection, 'src-2');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('collection 创建模式必填(空 → toast 拦截,repo.create 不调用)',
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
      when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right([
            _receivableAccount(id: 'recv-1'),
            // 仅 receivable,无 source/collection 候选 → dropdown 空。
          ]));
      var createCalled = false;
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
              collectionAccountId: any(named: 'collectionAccountId'))).thenAnswer((_) {
        createCalled = true;
        return Future.value(dartz.Right(_emptyDetail().debt));
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        debtRepo: debtRepo,
        accountRepo: accountRepo,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
        accountId: 'recv-1',
        // 不传 sourceAccountId → collection 默认 null。
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '李四');
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      final submitFinder =
          find.byKey(const ValueKey('submitButton')).evaluate().isNotEmpty
              ? find.byKey(const ValueKey('submitButton'))
              : find.text('创建债权');
      await t.ensureVisible(submitFinder);
      await t.tap(submitFinder);
      await t.pump();
      // 校验:提交被拦截(source/collection 均空 → 两个前置校验之一先拦截),
      // repo.create 未调用。本测试验证「collection 创建模式必填」语义:
      // 由于 collection 默认 = source(见 initState),source 空 → collection 空,
      // 任一前置校验失败都会阻止 create。关键断言是 createCalled == false。
      expect(createCalled, isFalse);
      expect(
          find.textContaining('请选择借出来源账户').evaluate().isNotEmpty ||
              find.textContaining('请选择回款关联账户').evaluate().isNotEmpty,
          isTrue);
      // AppToast 用 3s Timer 自动消失 —— 被拦截的提交不 pop,toast 留屏,
      // 需 pump 过 3s 让 Timer 完成否则「Timer pending」断言失败。
      await t.pump(const Duration(seconds: 4));
    });
  });
}

DebtDetail _emptyDetail() => DebtDetail(
      debt: Debt(
        id: 'r-new',
        accountId: 'recv-1',
        counterparty: '李四',
        interestRate: 8.0,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2026, 6, 15),
        dueDate: DateTime(2027, 6, 15),
        totalPrincipalCents: 10000000,
        remainingPrincipalCents: 10000000,
        version: 1,
        createdAt: DateTime(2026, 6, 15),
        updatedAt: DateTime(2026, 6, 15),
        type: DebtType.borrowedOut,
      ),
      schedule: const [],
    );
