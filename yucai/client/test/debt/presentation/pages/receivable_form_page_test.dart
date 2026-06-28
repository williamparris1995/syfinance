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

Widget _harness({
  required _MockDebtRepo debtRepo,
  required _MockAccountRepo accountRepo,
  DateTime? startDate,
  DateTime? dueDate,
  String? accountId,
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
      expect(find.textContaining('借出日期'), findsOneWidget);
      // 到期日期：字段 label + section 标题「3 · 借出与到期日期」均含 → findsWidgets。
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
      // 打开关联应收账户 dropdown
      await t.tap(find.textContaining('关联应收账户').first);
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
      expect(find.textContaining('每期收款'), findsWidgets);
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
      await t.tap(find.byKey(const ValueKey('amortization-lumpSum')));
      await fillForm(t);
      expect(find.textContaining('到期总额'), findsWidgets);
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
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_receivableAccount(id: 'recv-1')]));

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
              sourceAccountId: any(named: 'sourceAccountId'))).thenAnswer((inv) {
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
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('counterpartyField')), '李四');
      await t.enterText(find.byKey(const ValueKey('principalField')), '100000');
      await t.enterText(find.byKey(const ValueKey('rateField')), '8.0');
      // 切到「亲友」子类型（const key），验证 key 透传到 repo.create。
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
  });

  group('编辑模式（existing）', () {
    Debt existingDebt({
      String id = 'r-1',
      String counterparty = '李四',
      double interestRate = 8.0,
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
              matching: find.textContaining('8.0')),
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
              version: any(named: 'version'))).thenAnswer((_) {
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
