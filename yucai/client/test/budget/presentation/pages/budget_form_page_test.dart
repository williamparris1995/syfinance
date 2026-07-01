// Task 10 — widget tests for BudgetFormPage
// (account picker 只列 expense 账户 + items 编辑器 + 提交 CreateBudgetRequested)。
//
// 对齐 debt_form_page_test 的 harness:mocktail BudgetRepository +
// AccountRepository → 真实 BudgetBloc。表单页 initState 走
// GetIt<AccountRepository>().list(),故把 accountRepo 注册到 GetIt。
//
// **KEY assertion**:account picker 只列 expense 账户(accountType == expense),
// 排除 asset / investment / wallet(对齐 spec 决策 ④/⑥:actuals 跟踪
// expense-category 支出,transfers/investments 自动排除)。
//
// 验证:
//   - account picker 只列 2 expense 账户(asset/investment 排除)—— load-bearing
//   - + 加项 / 删除项
//   - 提交 CreateBudgetRequested(repo.createBudget 被调用)
//   - 空 items 禁用提交(domain 要求 ≥1 item)
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/pages/budget_form_page.dart';

class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}

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

/// 默认 seed:2 expense + 1 asset + 1 investment(对齐 brief)。
List<Account> _seedAccounts() => [
      _account(id: 'exp-1', name: '餐饮', type: AccountType.expense),
      _account(id: 'exp-2', name: '交通', type: AccountType.expense),
      _account(id: 'ast-1', name: '招行储蓄', type: AccountType.asset),
      _account(
          id: 'inv-1',
          name: '股票投资',
          type: AccountType.asset,
          category: AccountCategory.investment),
    ];

Widget _harness({
  required _MockBudgetRepo budgetRepo,
  required _MockAccountRepo accountRepo,
  String? budgetId,
  String? initialMonth,
}) {
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  return MaterialApp(
    home: BlocProvider<BudgetBloc>(
      create: (_) => BudgetBloc(budgetRepo),
      child: BudgetFormPage(
        budgetId: budgetId,
        initialMonth: initialMonth,
      ),
    ),
  );
}

void main() {
  setUp(() {
    // mocktail:registerFallbackValue for createBudget items record.
    registerFallbackValue(
      <({String accountId, int plannedAmountCents, String? notes})>[]);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  const desktop = Size(1400, 900);

  group('account picker 过滤 expense (KEY)', () {
    testWidgets(
        'dropdown 只列 expense 账户(asset/investment 排除)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      await t.pumpWidget(
          _harness(budgetRepo: budgetRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 打开第 1 个 item 的 account dropdown。
      await t.tap(find.byKey(const ValueKey('itemAccount-0')));
      await t.pumpAndSettle();

      // 2 个 expense 账户出现。
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.text('交通'), findsOneWidget);
      // asset / investment 不出现 —— load-bearing assertion。
      expect(find.text('招行储蓄'), findsNothing);
      expect(find.text('股票投资'), findsNothing);
    });

    testWidgets(
        '无 expense 账户时 dropdown 为空(仍可加项,但提交被空 items/未选分类拦截)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_account(id: 'a', name: '储蓄', type: AccountType.asset)]));
      await t.pumpWidget(
          _harness(budgetRepo: budgetRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('itemAccount-0')));
      await t.pumpAndSettle();
      // 无 expense 项可选。
      expect(find.text('储蓄'), findsNothing);
    });
  });

  group('items 编辑器', () {
    testWidgets('+ 加项 添加新行 / 删除按钮 删行', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      await t.pumpWidget(
          _harness(budgetRepo: budgetRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 默认 1 行(itemRow-0)。
      expect(find.byKey(const ValueKey('itemRow-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('itemRow-1')), findsNothing);

      // + 加项 → 第 2 行。
      await t.tap(find.byKey(const ValueKey('addItemButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('itemRow-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('itemRemove-1')), findsOneWidget);

      // 删除第 2 行。
      await t.tap(find.byKey(const ValueKey('itemRemove-1')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('itemRow-1')), findsNothing);
    });

    testWidgets('删到 0 行后,加项仍可恢复;提交被空 items 拦截', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      when(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          )).thenAnswer((_) async =>
          dartz.Right(_emptyBudget())); // never expected to be called
      when(() => budgetRepo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(budgetRepo: budgetRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 删第 1 行 → 0 行。
      await t.tap(find.byKey(const ValueKey('itemRemove-0')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('itemRow-0')), findsNothing);

      // 填 name(满足 name 校验,但 items 空 → 提交应被拦截)。
      await t.enterText(find.byKey(const ValueKey('nameField')), '测试预算');
      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      await t.pumpAndSettle();

      // createBudget 不应被调用(空 items 拦截)。
      verifyNever(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          ));
      // 排空 AppToast 的 3s 自动消失 Timer(避免 timersPending 断言失败)。
      await t.pump(const Duration(seconds: 4));
    });
  });

  group('提交 CreateBudgetRequested', () {
    testWidgets('填全表 → 点确认创建 → createBudget called with items',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      // 捕获 createBudget 收到的 items。
      List<({String accountId, int plannedAmountCents, String? notes})>?
          capturedItems;
      when(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          )).thenAnswer((inv) {
        capturedItems = inv.namedArguments[#items]
            as List<({String accountId, int plannedAmountCents, String? notes})>?;
        return Future.value(dartz.Right(_emptyBudget()));
      });
      when(() => budgetRepo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        budgetRepo: budgetRepo,
        accountRepo: accountRepo,
        initialMonth: '2026-07',
      ));
      await t.pumpAndSettle();

      // 填名称。
      await t.enterText(find.byKey(const ValueKey('nameField')), '7 月预算');
      // 选第 1 个 item 的 account(expense) + 金额。
      await t.tap(find.byKey(const ValueKey('itemAccount-0')));
      await t.pumpAndSettle();
      await t.tap(find.text('餐饮').last);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('itemAmount-0')), '1000.00');

      // 提交。
      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      // 推进 bloc 异步链。
      for (var i = 0; i < 10 && capturedItems == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      expect(capturedItems, isNotNull);
      expect(capturedItems!.length, 1);
      expect(capturedItems!.first.accountId, 'exp-1');
      expect(capturedItems!.first.plannedAmountCents, 100000); // 1000.00 * 100
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
    });
  });

  group('空 items / 空 name 禁用提交', () {
    testWidgets('name 空 → createBudget 不被调用', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      when(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          )).thenAnswer((_) async => dartz.Right(_emptyBudget()));
      when(() => budgetRepo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(
          _harness(budgetRepo: budgetRepo, accountRepo: accountRepo));
      await t.pumpAndSettle();

      // 不填 name,直接提交。
      await t.ensureVisible(find.text('确认创建'));
      await t.tap(find.text('确认创建'));
      await t.pumpAndSettle();
      verifyNever(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          ));
      // 排空 AppToast 的 3s 自动消失 Timer。
      await t.pump(const Duration(seconds: 4));
    });
  });
}

// 空预算视图(用于 createBudget mock 返回,bloc 不解析其字段)。
BudgetView _emptyBudget() => const BudgetView(
      id: 'b-new',
      name: '',
      month: '',
      currencyCode: '',
      totalAmountCents: 0,
    );
