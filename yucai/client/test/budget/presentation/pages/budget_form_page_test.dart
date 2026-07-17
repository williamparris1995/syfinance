// Widget tests for BudgetFormPage(对齐 OD 原型版:topbar + month picker +
// account chips + btn-gold 提交)。
//
// 对齐 debt_form_page_test 的 harness:mocktail BudgetRepository +
// AccountRepository → 真实 BudgetBloc。表单页 initState 走
// GetIt<AccountRepository>().list(),故把 accountRepo 注册到 GetIt。
//
// **KEY assertion**:account picker(chips 化)只列 expense 账户
// (accountType == expense),排除 asset / investment / wallet。
//
// 验证:
//   - account chips 只列 2 expense 账户(asset/investment 排除)—— load-bearing
//   - + 添加条目 / 删除按钮
//   - 提交 CreateBudgetRequested(repo.createBudget 被调用)
//   - 空 items / 空 name / 未选分类 / planned ≤0 禁用 btn-gold 提交
//   - 编辑模式:预填 + 提交 = UpdateBudgetRequested(非 delete+recreate)+
//     update 后 BudgetDetailLoaded → pop + month picker disabled(AbsorbPointer)
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
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';
import 'package:yucai_client/budget/presentation/pages/budget_form_page.dart';

class _MockBudgetRepo extends Mock implements BudgetRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}

/// 可控 Bloc:绕过真实事件处理器的 async/timer 链(在 widget 测试里易卡死),
/// 直接 emit 状态 + 记录 add 调用。仅用于「编辑模式 pop」测试。
class _ControllableBudgetBloc extends BudgetBloc {
  _ControllableBudgetBloc(super.repo);

  final List<BudgetEvent> dispatched = [];

  void emitState(BudgetState s) => emit(s);

  @override
  void add(BudgetEvent event) {
    dispatched.add(event);
  }
}

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
    registerFallbackValue(
      <({String accountId, int plannedAmountCents, String? notes})>[]);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  const desktop = Size(1400, 900);

  group('account picker chips 过滤 expense (KEY)', () {
    testWidgets('chips 只列 expense 账户(asset/investment 排除)', (t) async {
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

      // 第 1 个 item 的 account chips 区(itemAccount-0 Wrap)。
      expect(find.byKey(const ValueKey('itemAccount-0')), findsOneWidget);

      // 2 个 expense 账户 chip 出现。
      expect(find.byKey(const ValueKey('itemAccountChip_exp-1')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('itemAccountChip_exp-2')),
          findsOneWidget);
      // asset / investment 不出现 —— load-bearing assertion。
      expect(find.text('招行储蓄'), findsNothing);
      expect(find.text('股票投资'), findsNothing);
    });

    testWidgets('无 expense 账户时 chips 为空(提示文案)', (t) async {
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

      expect(find.byKey(const ValueKey('itemAccountChip_a')), findsNothing);
      expect(find.text('暂无支出分类账户(需先创建 expense 账户)'), findsOneWidget);
    });
  });

  group('items 编辑器', () {
    testWidgets('+ 添加条目 添加新行 / 删除按钮 删行', (t) async {
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

      expect(find.byKey(const ValueKey('itemRow-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('itemRow-1')), findsNothing);

      await t.tap(find.byKey(const ValueKey('addItemButton')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('itemRow-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('itemRemove-1')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('itemRemove-1')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('itemRow-1')), findsNothing);
    });

    testWidgets('删到 0 行后,加项仍可恢复;提交被空 items 禁用', (t) async {
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

      await t.tap(find.byKey(const ValueKey('itemRemove-0')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('itemRow-0')), findsNothing);

      await t.enterText(find.byKey(const ValueKey('nameField')), '测试预算');
      // btn-gold disabled(canSubmit=false 因 items 空)。
      final ElevatedButton btn =
          t.widget<ElevatedButton>(find.descendant(of: find.byKey(const ValueKey('budgetFormSubmit')), matching: find.byType(ElevatedButton)));
      expect(btn.onPressed, isNull, reason: '空 items 应禁用 btn-gold 提交');

      verifyNever(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          ));
      await t.pump(const Duration(seconds: 4));
    });
  });

  group('提交 CreateBudgetRequested', () {
    testWidgets('填全表 → 点保存预算 → createBudget called with items',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
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

      await t.enterText(find.byKey(const ValueKey('nameField')), '7 月预算');
      await t.tap(find.byKey(const ValueKey('itemAccountChip_exp-1')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('itemAmount-0')), '1000.00');
      await t.pumpAndSettle(); // 触发 amount onChanged setState 重建。

      // 点 topbar 的 btn-gold 提交(byKey + descendant ElevatedButton 避免与
      // bottom 重复 label 冲突)。
      final submitBtn = find.descendant(
          of: find.byKey(const ValueKey('budgetFormSubmit')),
          matching: find.byType(ElevatedButton));
      await t.ensureVisible(submitBtn);
      await t.tap(submitBtn);
      for (var i = 0; i < 30 && capturedItems == null; i++) {
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

  group('空校验禁用 btn-gold 提交', () {
    testWidgets('name 空 → btn-gold disabled', (t) async {
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

      final ElevatedButton btn =
          t.widget<ElevatedButton>(find.descendant(of: find.byKey(const ValueKey('budgetFormSubmit')), matching: find.byType(ElevatedButton)));
      expect(btn.onPressed, isNull, reason: 'name 空 应禁用 btn-gold');
      verifyNever(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          ));
    });

    testWidgets('planned ≤0 → btn-gold disabled', (t) async {
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

      await t.enterText(find.byKey(const ValueKey('nameField')), '测试');
      await t.tap(find.byKey(const ValueKey('itemAccountChip_exp-1')));
      await t.enterText(find.byKey(const ValueKey('itemAmount-0')), '0');
      await t.pumpAndSettle();

      final ElevatedButton btn =
          t.widget<ElevatedButton>(find.descendant(of: find.byKey(const ValueKey('budgetFormSubmit')), matching: find.byType(ElevatedButton)));
      expect(btn.onPressed, isNull, reason: 'planned ≤0 应禁用 btn-gold');
    });
  });

  // ----- 编辑模式 -----
  group('编辑模式 (edit-mode)', () {
    testWidgets('编辑模式预填:BudgetDetailLoaded → name/month/account/金额回填',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      when(() => budgetRepo.getBudget('b1'))
          .thenAnswer((_) async => dartz.Right(_existingBudget()));
      await t.pumpWidget(_harness(
        budgetRepo: budgetRepo,
        accountRepo: accountRepo,
        budgetId: 'b1',
      ));
      await t.pumpAndSettle();

      expect(find.text('编辑预算'), findsOneWidget);
      expect(
          find.ancestor(
              of: find.text('旧预算'),
              matching: find.byKey(const ValueKey('nameField'))),
          findsOneWidget,
          reason: 'nameField 应预填 "旧预算"');
      expect(find.text('2026-06'), findsOneWidget,
          reason: '月份应预填 2026-06');
      expect(
          find.ancestor(
              of: find.text('500.00'),
              matching: find.byKey(const ValueKey('itemAmount-0'))),
          findsOneWidget,
          reason: 'itemAmount-0 应预填 500.00');
      final chip = t.widget<ChoiceChip>(
          find.byKey(const ValueKey('itemAccountChip_exp-1')));
      expect(chip.selected, isTrue, reason: 'exp-1 chip 应预选');
      expect(find.text('保存修改'), findsWidgets);
    });

    testWidgets('编辑模式提交 = UpdateBudgetRequested(非 delete+recreate)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      when(() => budgetRepo.getBudget('b1'))
          .thenAnswer((_) async => dartz.Right(_existingBudget()));
      List<({String accountId, int plannedAmountCents, String? notes})>?
          capturedItems;
      String? capturedName;
      String? capturedCurrency;
      when(() => budgetRepo.updateBudget(
            id: any(named: 'id'),
            name: any(named: 'name'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          )).thenAnswer((inv) {
        capturedName = inv.namedArguments[#name] as String;
        capturedCurrency = inv.namedArguments[#currencyCode] as String;
        capturedItems = inv.namedArguments[#items]
            as List<({String accountId, int plannedAmountCents, String? notes})>?;
        return Future.value(dartz.Right(_emptyBudget()));
      });
      await t.pumpWidget(_harness(
        budgetRepo: budgetRepo,
        accountRepo: accountRepo,
        budgetId: 'b1',
      ));
      await t.pumpAndSettle();

      await t.enterText(find.byKey(const ValueKey('nameField')), '新预算');
      await t.ensureVisible(find.text('保存修改').first);
      await t.tap(find.text('保存修改').first);
      for (var i = 0; i < 20 && capturedItems == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      // 关键:edit 提交 dispatch UpdateBudgetRequested(非 delete+create)。
      verifyNever(() => budgetRepo.deleteBudget(any()));
      verifyNever(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          ));
      verify(() => budgetRepo.updateBudget(
            id: 'b1',
            name: '新预算',
            currencyCode: 'CNY',
            items: any(named: 'items'),
          )).called(1);
      expect(capturedName, '新预算');
      expect(capturedCurrency, 'CNY');
      expect(capturedItems, isNotNull);
      expect(capturedItems!.length, 1);
      expect(capturedItems!.first.accountId, 'exp-1');
      expect(capturedItems!.first.plannedAmountCents, 50000); // 500.00 * 100
    });

    testWidgets('编辑模式 BudgetDetailLoaded(update 后)后 pop', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final accountRepo = _MockAccountRepo();
      final budgetRepo = _MockBudgetRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));

      final bloc = _ControllableBudgetBloc(budgetRepo);
      final observer = _PopCounter();
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
      await t.pumpWidget(MaterialApp(
        navigatorObservers: [observer],
        home: BlocProvider<BudgetBloc>.value(
          value: bloc,
          child: const BudgetFormPage(budgetId: 'b1'),
        ),
      ));
      await t.pump();

      expect(
        bloc.dispatched.whereType<LoadDetailRequested>().single.id,
        'b1',
      );

      bloc.emitState(BudgetDetailLoaded(_existingBudget()));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 20));
        if (find.text('500.00').evaluate().isNotEmpty) break;
      }
      expect(find.text('编辑预算'), findsOneWidget);
      expect(find.text('500.00'), findsOneWidget, reason: '预填应完成');
      expect(observer.popCount, 0, reason: '加载预填不应 pop');

      await t.enterText(find.byKey(const ValueKey('nameField')), '新预算2');
      await t.ensureVisible(find.text('保存修改').first);
      await t.tap(find.text('保存修改').first);
      await t.pump();

      // 关键:edit 提交只 dispatch UpdateBudgetRequested(无 Delete / Create)。
      final updates =
          bloc.dispatched.whereType<UpdateBudgetRequested>().toList();
      expect(updates.length, 1);
      expect(updates.single.budgetId, 'b1');
      expect(updates.single.name, '新预算2');
      expect(bloc.dispatched.whereType<DeleteBudgetRequested>(), isEmpty);
      expect(bloc.dispatched.whereType<CreateBudgetRequested>(), isEmpty);

      // update 后 bloc 重拉 detail → BudgetDetailLoaded → form pop。
      // 注:不再有「第 1 次 BudgetListLoaded 不 pop」的竞态。
      // BudgetLoading 先打破 Equatable 去重(照真实 _onUpdate 流)。
      bloc.emitState(BudgetLoading());
      await t.pump();
      bloc.emitState(BudgetDetailLoaded(_updatedBudget()));
      await t.pump();
      expect(observer.popCount, greaterThanOrEqualTo(1),
          reason: 'BudgetDetailLoaded(update 后)应立即 pop');
    });

    testWidgets('编辑模式 month picker 不可点(AbsorbPointer)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      when(() => budgetRepo.getBudget('b1'))
          .thenAnswer((_) async => dartz.Right(_existingBudget()));
      await t.pumpWidget(_harness(
        budgetRepo: budgetRepo,
        accountRepo: accountRepo,
        budgetId: 'b1',
      ));
      await t.pumpAndSettle();

      // month picker 有 2 层 AbsorbPointer 祖先:global(submitting,不吸收)+
      // month(_isEdit,吸收)。验证至少一个 absorbing。
      final absorbers = find.ancestor(
          of: find.byKey(const ValueKey('monthPicker')),
          matching: find.byType(AbsorbPointer));
      final absorbing = t
          .widgetList<AbsorbPointer>(absorbers)
          .any((a) => a.absorbing);
      expect(absorbing, isTrue,
          reason: 'edit 模式 month picker 应被内层 AbsorbPointer 吸收点击');

      // 视觉灰显:Opacity 0.5(month picker 旁)。
      final opacity = t.widget<Opacity>(
          find.ancestor(
              of: find.byKey(const ValueKey('monthPicker')),
              matching: find.byType(Opacity)));
      expect(opacity.opacity, 0.5);
    });
  });
}

BudgetView _emptyBudget() => const BudgetView(
      id: 'b-new',
      name: '',
      month: '',
      currencyCode: '',
      totalAmountCents: 0,
    );

BudgetView _existingBudget() => const BudgetView(
      id: 'b1',
      name: '旧预算',
      month: '2026-06',
      currencyCode: 'CNY',
      totalAmountCents: 50000,
      items: [
        BudgetItemView(
          id: 'bi-1',
          accountId: 'exp-1',
          accountName: '餐饮',
          plannedAmountCents: 50000,
          actualAmountCents: 0,
        ),
      ],
    );

/// update 成功后 bloc 重拉的 detail(名字更新,反映 UpdateBudget 生效)。
BudgetView _updatedBudget() => const BudgetView(
      id: 'b1',
      name: '新预算2',
      month: '2026-06',
      currencyCode: 'CNY',
      totalAmountCents: 50000,
      items: [
        BudgetItemView(
          id: 'bi-1',
          accountId: 'exp-1',
          accountName: '餐饮',
          plannedAmountCents: 50000,
          actualAmountCents: 0,
        ),
      ],
    );
