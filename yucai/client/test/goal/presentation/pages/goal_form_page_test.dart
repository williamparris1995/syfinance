// Task 13 — widget tests for GoalFormPage
// (type picker 切动态字段 + account/debt picker filter by type + 提交 dispatch
//  CreateGoalRequested/UpdateGoalRequested + 校验禁用)。
//
// 对齐 budget_form_page_test harness:mocktail GoalRepository +
// AccountRepository + DebtRepository → 真实 GoalBloc。表单页 initState 走
// GetIt<AccountRepository>().list() + GetIt<DebtRepository>().list()。
//
// **KEY assertions**(load-bearing):
//   - investment type picker 只列 investment 类别账户(排除 expense/savings/asset)
//   - savings type picker 只列 asset 类(排除 investment 类别),排除 expense
//   - debtPayoff type picker 列 debts + 选债务自动填 target = 剩余本金
//   - 提交 CreateGoalRequested(name/type/target/deadline/linkedAccountIds=[单选])
//   - name 空 / target ≤0 / 关联未选 → 提交禁用(_canSubmit 兜底 + dispatch 拦截)
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_state.dart';
import 'package:yucai_client/goal/presentation/pages/goal_form_page.dart';

/// createGoal mock 返回的 stub GoalView(bloc 不解析字段,success → re-load list)。
GoalView _stubCreated() => const GoalView(
      id: 'g-new',
      name: 'stub',
      type: GoalType.savings,
      targetAmountCents: 0,
    );

class _MockGoalRepo extends Mock implements GoalRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockDebtRepo extends Mock implements DebtRepository {}

/// 可控 Bloc:绕过真实事件处理器 async/timer 链(在 widget 测试里易卡死),
/// 直接 emit 状态 + 记录 add 调用。仅用于「编辑模式 pop」测试 —— 该测试验证
/// 的是 widget 的 listener 逻辑,不是 bloc 内部。继承自 GoalBloc 以便作为
/// BlocProvider<GoalBloc>.value 注入。
class _ControllableGoalBloc extends GoalBloc {
  _ControllableGoalBloc(super.repo);

  final List<GoalEvent> dispatched = [];
  void emitState(GoalState s) => emit(s);

  @override
  void add(GoalEvent event) {
    dispatched.add(event);
    // 不调 super.add —— 不走真实 handler。
  }
}

/// 记录 pop 次数的真实 NavigatorObserver。
class _PopCounter extends NavigatorObserver {
  int popCount = 0;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
  }
}

Account _account({
  required String id,
  required String name,
  required AccountType type,
  AccountCategory category = AccountCategory.savings,
}) =>
    Account(
      id: id,
      name: name,
      accountType: type,
      category: category,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// seed:1 expense + 1 savings(asset,savings 类别)+ 1 investment(asset,investment 类别)。
List<Account> _seedAccounts() => [
      _account(id: 'exp-1', name: '餐饮', type: AccountType.expense),
      _account(
          id: 'sav-1', name: '招行储蓄', type: AccountType.asset, category: AccountCategory.savings),
      _account(
          id: 'inv-1',
          name: '股票账户',
          type: AccountType.asset,
          category: AccountCategory.investment),
    ];

Debt _debt({
  required String id,
  String counterparty = '花呗',
  int remaining = 500000, // ¥5000.00
  int total = 1000000,
}) =>
    Debt(
      id: id,
      accountId: 'loan-1',
      counterparty: counterparty,
      interestRate: 12.0,
      amortization: AmortizationMethod.equalPrincipalInterest,
      startDate: DateTime(2026, 1, 1),
      dueDate: DateTime(2027, 1, 1),
      totalPrincipalCents: total,
      remainingPrincipalCents: remaining,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

List<Debt> _seedDebts() => [
      _debt(id: 'debt-1', counterparty: '花呗', remaining: 500000),
      _debt(id: 'debt-2', counterparty: '房贷', remaining: 80000000),
    ];

Widget _harness({
  required _MockGoalRepo goalRepo,
  required _MockAccountRepo accountRepo,
  required _MockDebtRepo debtRepo,
  String? goalId,
  DateTime? initialDeadline,
  GoalBloc? bloc,
}) {
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  GetIt.instance.registerSingleton<DebtRepository>(debtRepo);
  return MaterialApp(
    home: bloc == null
        ? BlocProvider<GoalBloc>(
            create: (_) => GoalBloc(goalRepo),
            child: GoalFormPage(goalId: goalId, initialDeadline: initialDeadline),
          )
        : BlocProvider<GoalBloc>.value(
            value: bloc,
            child: GoalFormPage(goalId: goalId, initialDeadline: initialDeadline),
          ),
  );
}

void main() {
  setUp(() {
    registerFallbackValue(GoalType.savings);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  const desktop = Size(1400, 900);

  void stubPickers(
    _MockAccountRepo accountRepo,
    _MockDebtRepo debtRepo, {
    List<Account>? accounts,
    List<Debt>? debts,
  }) {
    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right(accounts ?? _seedAccounts()));
    when(() => debtRepo.list())
        .thenAnswer((_) async => dartz.Right(debts ?? _seedDebts()));
  }

  // ───────────── group: type picker 切动态字段 ─────────────

  group('type picker 切动态字段', () {
    testWidgets('初始创建模式:detail 区显占位「请先选择目标类型」', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      expect(find.text('新建目标'), findsOneWidget);
      expect(find.text('请先选择目标类型'), findsOneWidget);
      // accountPicker 不存在(未选 type)。
      expect(find.byKey(const ValueKey('accountPicker')), findsNothing);
      expect(find.byKey(const ValueKey('debtPicker')), findsNothing);
    });

    testWidgets('选 savings type → 出现 accountPicker + targetField(可编辑)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      // 点 savings type option。
      await t.tap(find.byKey(const ValueKey('typeOption_savings')));
      await t.pumpAndSettle();

      // accountPicker + targetField 出现;debtPicker 不出现。
      expect(find.byKey(const ValueKey('accountPicker')), findsOneWidget);
      expect(find.byKey(const ValueKey('targetField')), findsOneWidget);
      expect(find.byKey(const ValueKey('debtPicker')), findsNothing);
      // 占位消失。
      expect(find.text('请先选择目标类型'), findsNothing);
    });

    testWidgets('切 type savings → debtPayoff:accountPicker 换 debtPicker',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('typeOption_savings')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('accountPicker')), findsOneWidget);

      // 切到 debtPayoff。
      await t.tap(find.byKey(const ValueKey('typeOption_debtPayoff')));
      await t.pumpAndSettle();
      // 现在 debtPicker 出现,accountPicker 消失。
      expect(find.byKey(const ValueKey('debtPicker')), findsOneWidget);
      expect(find.byKey(const ValueKey('accountPicker')), findsNothing);
    });
  });

  // ───────────── group: account/debt picker filter by type(KEY) ─────────────

  group('account picker filter by type (KEY)', () {
    testWidgets(
        'investment type:accountPicker 只列 investment 类别账户(排除 expense/savings)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('typeOption_investment')));
      await t.pumpAndSettle();

      // 打开 accountPicker dropdown。
      await t.tap(find.byKey(const ValueKey('accountPicker')));
      await t.pumpAndSettle();

      // 只出现 investment 账户(股票账户)。load-bearing。
      expect(find.text('股票账户'), findsOneWidget);
      expect(find.text('招行储蓄'), findsNothing, reason: 'savings 类别不应出现');
      expect(find.text('餐饮'), findsNothing, reason: 'expense 账户不应出现');
    });

    testWidgets(
        'savings type:accountPicker 列 asset 类排除 investment(招行储蓄出现,股票账户排除)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('typeOption_savings')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('accountPicker')));
      await t.pumpAndSettle();

      // savings 账户出现,investment 排除,expense 排除。load-bearing。
      expect(find.text('招行储蓄'), findsOneWidget);
      expect(find.text('股票账户'), findsNothing, reason: 'investment 类别应排除');
      expect(find.text('餐饮'), findsNothing, reason: 'expense 账户应排除');
    });

    testWidgets('debtPayoff type:debtPicker 列 debts', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('typeOption_debtPayoff')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('debtPicker')));
      await t.pumpAndSettle();

      expect(find.text('花呗'), findsOneWidget);
      expect(find.text('房贷'), findsOneWidget);
    });

    testWidgets('debtPayoff:选债务 → targetField 自动 = 剩余本金(只读)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('typeOption_debtPayoff')));
      await t.pumpAndSettle();

      // 选花呗(remaining 500000 cents = ¥5000.00)。
      await t.tap(find.byKey(const ValueKey('debtPicker')));
      await t.pumpAndSettle();
      await t.tap(find.text('花呗').last);
      await t.pumpAndSettle();

      // targetField 自动填 5000.00。
      expect(
        find.ancestor(
          of: find.text('5000.00'),
          matching: find.byKey(const ValueKey('targetField')),
        ),
        findsOneWidget,
        reason: 'DebtPayoff target 应自动 = 债务剩余本金 ¥5000.00',
      );
    });
  });

  // ───────────── group: 提交 CreateGoalRequested ─────────────

  group('提交 CreateGoalRequested', () {
    testWidgets(
        'savings:填全表 → 点确认创建 → createGoal called with linkedAccountIds=[sav-1]',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);

      // 捕获 createGoal 参数。
      List<String>? capturedAccountIds;
      int? capturedTarget;
      String? capturedName;
      GoalType? capturedType;
      when(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((inv) {
        capturedName = inv.namedArguments[#name] as String;
        capturedType = inv.namedArguments[#type] as GoalType;
        capturedTarget = inv.namedArguments[#targetAmountCents] as int;
        capturedAccountIds =
            inv.namedArguments[#linkedAccountIds] as List<String>;
        return Future.value(dartz.Right(_stubCreated()));
      });
      when(() => goalRepo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const dartz.Right([]));

      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      // 选 savings type。
      await t.tap(find.byKey(const ValueKey('typeOption_savings')));
      await t.pumpAndSettle();
      // 填 name。
      await t.enterText(find.byKey(const ValueKey('nameField')), '紧急备用金');
      // 填 target。
      await t.enterText(find.byKey(const ValueKey('targetField')), '60000');
      // 选 sav-1。
      await t.tap(find.byKey(const ValueKey('accountPicker')));
      await t.pumpAndSettle();
      await t.tap(find.text('招行储蓄').last);
      await t.pumpAndSettle();

      // 提交。
      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      // 推进 bloc 异步链。
      for (var i = 0; i < 10 && capturedAccountIds == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      expect(capturedName, '紧急备用金');
      expect(capturedType, GoalType.savings);
      expect(capturedTarget, 6000000); // 60000 * 100
      // Phase 1 单选:list = [单选]。
      expect(capturedAccountIds, ['sav-1']);
      // 排空 pop 链。
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
    });

    testWidgets(
        'debtPayoff:提交 → linkedDebtIds=[debt-1] + target=剩余本金(500000)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);

      List<String>? capturedDebtIds;
      int? capturedTarget;
      when(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((inv) {
        capturedTarget = inv.namedArguments[#targetAmountCents] as int;
        capturedDebtIds = inv.namedArguments[#linkedDebtIds] as List<String>;
        return Future.value(dartz.Right(_stubCreated()));
      });
      when(() => goalRepo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const dartz.Right([]));

      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('typeOption_debtPayoff')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('nameField')), '清花呗');
      // 选 debt-1(花呗)→ target 自动 5000.00。
      await t.tap(find.byKey(const ValueKey('debtPicker')));
      await t.pumpAndSettle();
      await t.tap(find.text('花呗').last);
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      for (var i = 0; i < 10 && capturedDebtIds == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      // target = 剩余本金(500000 cents),linkedDebtIds = [debt-1]。
      expect(capturedTarget, 500000);
      expect(capturedDebtIds, ['debt-1']);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
    });
  });

  // ───────────── group: 空校验禁用 ─────────────

  group('空校验禁用提交', () {
    testWidgets('name 空 → createGoal 不被调用', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      when(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => dartz.Right(_stubCreated()));
      when(() => goalRepo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const dartz.Right([]));

      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      // 选 type + target + account,但 name 留空。
      await t.tap(find.byKey(const ValueKey('typeOption_investment')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('targetField')), '200000');
      await t.tap(find.byKey(const ValueKey('accountPicker')));
      await t.pumpAndSettle();
      await t.tap(find.text('股票账户').last);
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      await t.pumpAndSettle();

      verifyNever(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          ));
      // 排空 AppToast Timer。
      await t.pump(const Duration(seconds: 4));
    });

    testWidgets('target ≤0 → createGoal 不被调用', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      when(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => dartz.Right(_stubCreated()));
      when(() => goalRepo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const dartz.Right([]));

      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('typeOption_savings')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('nameField')), '备用金');
      // target 留 0(或非法值)。
      await t.enterText(find.byKey(const ValueKey('targetField')), '0');
      await t.tap(find.byKey(const ValueKey('accountPicker')));
      await t.pumpAndSettle();
      await t.tap(find.text('招行储蓄').last);
      await t.pumpAndSettle();

      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      await t.pumpAndSettle();

      verifyNever(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          ));
      await t.pump(const Duration(seconds: 4));
    });

    testWidgets('关联未选 → createGoal 不被调用', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      when(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((_) async => dartz.Right(_stubCreated()));
      when(() => goalRepo.listGoals(type: any(named: 'type')))
          .thenAnswer((_) async => const dartz.Right([]));

      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        initialDeadline: DateTime(2027, 1, 1),
      ));
      await t.pumpAndSettle();

      // 选 type + name + target,但不选关联账户。
      await t.tap(find.byKey(const ValueKey('typeOption_savings')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('nameField')), '备用金');
      await t.enterText(find.byKey(const ValueKey('targetField')), '60000');

      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      await t.pumpAndSettle();

      verifyNever(() => goalRepo.createGoal(
            name: any(named: 'name'),
            type: any(named: 'type'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          ));
      await t.pump(const Duration(seconds: 4));
    });
  });

  // ───────────── group: 编辑模式 ─────────────

  group('编辑模式 (edit-mode)', () {
    testWidgets('编辑模式预填:GoalDetailLoaded → name/type/target/account 回填',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      // _loadExisting → LoadDetailRequested → _onLoadDetail → getGoal。
      when(() => goalRepo.getGoal('g1')).thenAnswer((_) async => const dartz.Right(
                GoalView(
              id: 'g1',
              name: '旧目标',
              type: GoalType.savings,
              targetAmountCents: 6000000, // ¥60000.00
              deadline: null, // 测试用 deadline=null 避免 DateTime 比较
              linkedAccountIds: ['sav-1'],
            ),
          ));

      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        goalId: 'g1',
      ));
      await t.pumpAndSettle();

      // AppBar 标题 = 编辑目标。
      expect(find.text('编辑目标'), findsOneWidget);
      // name 回填。
      expect(
        find.ancestor(
          of: find.text('旧目标'),
          matching: find.byKey(const ValueKey('nameField')),
        ),
        findsOneWidget,
      );
      // target 回填 60000.00。
      expect(
        find.ancestor(
          of: find.text('60000.00'),
          matching: find.byKey(const ValueKey('targetField')),
        ),
        findsOneWidget,
      );
      // savings type 被选中(accountPicker 出现,且 sav-1 在 dropdown 选中)。
      expect(find.byKey(const ValueKey('accountPicker')), findsOneWidget);
      // 提交按钮文案 = 保存修改。
      expect(find.text('保存修改'), findsOneWidget);
    });

    testWidgets('编辑模式提交 → dispatch UpdateGoalRequested(id + 新值)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);
      when(() => goalRepo.getGoal('g1')).thenAnswer((_) async => const dartz.Right(
                GoalView(
              id: 'g1',
              name: '旧目标',
              type: GoalType.savings,
              targetAmountCents: 6000000,
              linkedAccountIds: ['sav-1'],
            ),
          ));
      // updateGoal 成功 → bloc emit GoalDetailLoaded(新)。
      GoalView? updatedView;
      when(() => goalRepo.updateGoal(
            id: any(named: 'id'),
            name: any(named: 'name'),
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).thenAnswer((inv) {
        updatedView = const GoalView(
          id: 'g1',
          name: '新目标',
          type: GoalType.savings,
          targetAmountCents: 8000000,
        );
        return Future.value(dartz.Right(updatedView!));
      });

      await t.pumpWidget(_harness(
        goalRepo: goalRepo,
        accountRepo: accountRepo,
        debtRepo: debtRepo,
        goalId: 'g1',
      ));
      await t.pumpAndSettle();

      // 编辑 name → 新目标。
      await t.enterText(find.byKey(const ValueKey('nameField')), '新目标');
      await t.ensureVisible(find.text('保存修改'));
      await t.tap(find.text('保存修改'));
      // 推进 bloc async(updateGoal → GoalDetailLoaded)。
      await t.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 10 && updatedView == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      // KEY:updateGoal 被调用,id=g1,新 name。
      verify(() => goalRepo.updateGoal(
            id: 'g1',
            name: '新目标',
            targetAmountCents: any(named: 'targetAmountCents'),
            deadline: any(named: 'deadline'),
            linkedAccountIds: any(named: 'linkedAccountIds'),
            linkedDebtIds: any(named: 'linkedDebtIds'),
          )).called(1);
      await t.pumpAndSettle();
    });

    testWidgets('编辑模式提交成功(GoalDetailLoaded)→ pop', (t) async {
      // 用 _ControllableGoalBloc 绕开真实 bloc async/timer(pumpAndSettle 易卡死)。
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final goalRepo = _MockGoalRepo();
      final accountRepo = _MockAccountRepo();
      final debtRepo = _MockDebtRepo();
      stubPickers(accountRepo, debtRepo);

      final bloc = _ControllableGoalBloc(goalRepo);
      final observer = _PopCounter();
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
      GetIt.instance.registerSingleton<DebtRepository>(debtRepo);
      await t.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: BlocProvider<GoalBloc>.value(
          value: bloc,
          child: GoalFormPage(
            goalId: 'g1',
            initialDeadline: DateTime(2027, 1, 1),
          ),
        ),
      ));
      await t.pump();

      // initState → _loadExisting → dispatch LoadDetailRequested。
      expect(
        bloc.dispatched.whereType<LoadDetailRequested>().single.id,
        'g1',
      );

      // 手动 emit GoalDetailLoaded → listener 预填。
      bloc.emitState(const GoalDetailLoaded(GoalView(
        id: 'g1',
        name: '旧目标',
        type: GoalType.savings,
        targetAmountCents: 6000000,
        linkedAccountIds: ['sav-1'],
      )));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 20));
        if (find.text('编辑目标').evaluate().isNotEmpty &&
            find.text('60000.00').evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.text('编辑目标'), findsOneWidget);
      expect(find.text('60000.00'), findsOneWidget, reason: '预填应完成');

      // 编辑 + 提交 → dispatch UpdateGoalRequested。
      await t.enterText(find.byKey(const ValueKey('nameField')), '新目标2');
      await t.ensureVisible(find.text('保存修改'));
      await t.tap(find.text('保存修改'));
      await t.pump();

      final updates =
          bloc.dispatched.whereType<UpdateGoalRequested>().toList();
      expect(updates.length, 1);
      expect(updates.single.id, 'g1');
      expect(updates.single.name, '新目标2');

      // 模拟 updateGoal 成功 → bloc emit GoalDetailLoaded(新)→ listener pop。
      expect(observer.popCount, 0, reason: '提交后未收到成功 state,不应 pop');
      bloc.emitState(const GoalDetailLoaded(GoalView(
        id: 'g1',
        name: '新目标2',
        type: GoalType.savings,
        targetAmountCents: 6000000,
      )));
      await t.pump();
      expect(observer.popCount, greaterThanOrEqualTo(1),
          reason: 'UpdateGoalRequested 成功(GoalDetailLoaded)后应 pop');
    });
  });
}
