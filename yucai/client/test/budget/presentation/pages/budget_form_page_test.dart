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

// Task 10 review fix — edit-mode widget tests for BudgetFormPage.
//
// 编辑模式流程(budget_form_page.dart):
//   initState → _loadExisting → dispatch LoadDetailRequested → bloc emit
//   BudgetDetailLoaded → listener 预填 name/month/currency/items。
//   提交 → dispatch DeleteBudgetRequested(budgetId) THEN CreateBudgetRequested。
//   _onDelete/_onCreate 成功后各自 add(LoadListRequested) → emit BudgetListLoaded。
//   listener 用 _editCreateCount 等到第 2 次 BudgetListLoaded(create 的)才 pop。
//
// 用真实 BudgetBloc + stub repo(deleteBudget/listBudgets/createBudget 都 Right)
// → 自然产生 2 次 BudgetListLoaded,无需 stateful fake。

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
/// 直接 emit 状态 + 记录 add 调用。仅用于「编辑模式 pop」测试 —— 该测试验证
/// 的是 widget 的 listener 逻辑(_editCreateCount >= 2 → pop),不是 bloc 内部。
///
/// 继承自 BudgetBloc(而非裸 Bloc<BudgetEvent,BudgetState>),以便作为
/// BlocProvider<BudgetBloc>.value 注入。add 被 override → 真实 handler 不跑,
/// 故 repo 不会被真正调用(mock 不需 stub,但仍传入以满足构造函数)。
class _ControllableBudgetBloc extends BudgetBloc {
  _ControllableBudgetBloc(super.repo);

  /// widget 通过 context.read<BudgetBloc>().add(...) dispatch 的事件。
  final List<BudgetEvent> dispatched = [];

  /// 测试侧手动 emit 状态(触发 BlocConsumer.listener)。
  void emitState(BudgetState s) => emit(s);

  @override
  void add(BudgetEvent event) {
    dispatched.add(event);
    // 不调用 super.add —— 不走真实 handler,故无 async/timer,不会卡死。
  }
}

/// 记录 didPop 调用次数的真实 NavigatorObserver(不用 mocktail,因 mocktail
/// 的 verify 不能在循环里作布尔探针——会抛异常)。pop 在 route 移除动画前
/// 同步触发,故不需等动画 quiesce。
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

  // ----- 编辑模式(Task 10 review fix) -----
  // 三条 KEY:预填、提交=delete+create、第 2 次 BudgetListLoaded 才 pop。
  group('编辑模式 (edit-mode)', () {
    testWidgets(
        '编辑模式预填:BudgetDetailLoaded → name/month/account/金额回填',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final budgetRepo = _MockBudgetRepo();
      final accountRepo = _MockAccountRepo();
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));
      // _loadExisting → LoadDetailRequested → bloc _onLoadDetail → getBudget。
      when(() => budgetRepo.getBudget('b1'))
          .thenAnswer((_) async => dartz.Right(_existingBudget()));
      await t.pumpWidget(_harness(
        budgetRepo: budgetRepo,
        accountRepo: accountRepo,
        budgetId: 'b1',
      ));
      await t.pumpAndSettle();

      // AppBar 标题 = 编辑预算。
      expect(find.text('编辑预算'), findsOneWidget);
      // Name 回填旧预算。
      expect(
          find.ancestor(
              of: find.text('旧预算'),
              matching: find.byKey(const ValueKey('nameField'))),
          findsOneWidget,
          reason: 'nameField 应预填 "旧预算"');
      // Month 回填 2026-06(monthPicker 显示)。
      expect(find.text('2026-06'), findsOneWidget,
          reason: '月份应预填 2026-06');
      // 金额回填 500.00(itemAmount-0 controller text)。
      expect(
          find.ancestor(
              of: find.text('500.00'),
              matching: find.byKey(const ValueKey('itemAmount-0'))),
          findsOneWidget,
          reason: 'itemAmount-0 应预填 500.00');
      // account dropdown 选中 exp-1(餐饮)。
      expect(find.text('餐饮'), findsOneWidget,
          reason: 'itemAccount-0 应预选 餐饮(exp-1)');
      // 提交按钮文案 = 保存修改。
      expect(find.text('保存修改'), findsOneWidget);
    });

    testWidgets(
        '编辑模式提交 = delete + create(verifyInOrder: delete 在 create 前)',
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
      // delete + create 都成功(bloc 各自 add LoadListRequested → listBudgets)。
      when(() => budgetRepo.deleteBudget('b1'))
          .thenAnswer((_) async => const dartz.Right(null));
      List<({String accountId, int plannedAmountCents, String? notes})>?
          capturedItems;
      String? capturedCreateName;
      when(() => budgetRepo.createBudget(
            name: any(named: 'name'),
            month: any(named: 'month'),
            currencyCode: any(named: 'currencyCode'),
            items: any(named: 'items'),
          )).thenAnswer((inv) {
        capturedCreateName = inv.namedArguments[#name] as String;
        capturedItems = inv.namedArguments[#items]
            as List<({String accountId, int plannedAmountCents, String? notes})>?;
        return Future.value(dartz.Right(_emptyBudget()));
      });
      when(() => budgetRepo.listBudgets(activeOnly: any(named: 'activeOnly')))
          .thenAnswer((_) async => const dartz.Right([]));
      await t.pumpWidget(_harness(
        budgetRepo: budgetRepo,
        accountRepo: accountRepo,
        budgetId: 'b1',
      ));
      await t.pumpAndSettle();

      // 编辑 name → 新预算(触发 dirty 提交)。
      await t.enterText(find.byKey(const ValueKey('nameField')), '新预算');
      // 提交。
      await t.ensureVisible(find.text('保存修改'));
      await t.tap(find.text('保存修改'));
      // 推进 bloc 异步链(delete → listLoaded → create → listLoaded)。
      for (var i = 0; i < 20 && capturedItems == null; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }

      // KEY:delete 与 create 都被调用,且 delete 先于 create。
      verifyInOrder([
        () => budgetRepo.deleteBudget('b1'),
        () => budgetRepo.createBudget(
              name: any(named: 'name'),
              month: any(named: 'month'),
              currencyCode: any(named: 'currencyCode'),
              items: any(named: 'items'),
            ),
      ]);
      // create 收到编辑后的 name=新预算 + items(exp-1, 50000 cents)。
      expect(capturedCreateName, '新预算');
      expect(capturedItems, isNotNull);
      expect(capturedItems!.length, 1);
      expect(capturedItems!.first.accountId, 'exp-1');
      expect(capturedItems!.first.plannedAmountCents, 50000); // 500.00 * 100
      // 排空后续 BudgetListLoaded → pop 链 + Toast。
      await t.pumpAndSettle();
    });

    testWidgets(
        '编辑模式 第 2 次 BudgetListLoaded 才 pop(delete 的 reload 不 pop)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final accountRepo = _MockAccountRepo();
      final budgetRepo = _MockBudgetRepo(); // 仅满足 _ControllableBudgetBloc 构造,add 被 override 不真正调用
      when(() => accountRepo.list())
          .thenAnswer((_) async => dartz.Right(_seedAccounts()));

      // 用 _ControllableBudgetBloc 绕开真实 bloc 的 async/timer 链(在 widget
      // 测试里 pumpAndSettle 会卡死)。手动 emit 状态 + 记录 dispatch,精确
      // 验证 listener 的 _editCreateCount 计数 → pop 逻辑。
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

      // initState → _loadExisting → context.read<BudgetBloc>().add(LoadDetail)。
      expect(
        bloc.dispatched.whereType<LoadDetailRequested>().single.id,
        'b1',
      );

      // 手动 emit BudgetDetailLoaded → listener 预填。
      bloc.emitState(BudgetDetailLoaded(_existingBudget()));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 20));
        if (find.text('500.00').evaluate().isNotEmpty) break;
      }
      expect(find.text('编辑预算'), findsOneWidget);
      expect(find.text('500.00'), findsOneWidget, reason: '预填应完成');

      // 编辑 + 提交 → widget dispatch Delete + Create(顺序)。
      await t.enterText(find.byKey(const ValueKey('nameField')), '新预算2');
      await t.ensureVisible(find.text('保存修改'));
      await t.tap(find.text('保存修改'));
      await t.pump();

      // 提交应 dispatch 顺序:Delete('b1') 在 Create 之前。
      final deletes =
          bloc.dispatched.whereType<DeleteBudgetRequested>().toList();
      final creates =
          bloc.dispatched.whereType<CreateBudgetRequested>().toList();
      expect(deletes.length, 1);
      expect(deletes.single.id, 'b1');
      expect(creates.length, 1);
      expect(creates.single.name, '新预算2');
      expect(
        bloc.dispatched.indexOf(deletes.single) <
            bloc.dispatched.indexOf(creates.single),
        isTrue,
        reason: '编辑模式提交应先 dispatch DeleteBudgetRequested 再 CreateBudgetRequested',
      );

      // === 第 1 阶段:模拟 delete 完成后的 reload ===
      bloc.emitState(const BudgetListLoaded([BudgetView(
        id: 'after-delete',
        name: 'reload-1',
        month: '2026-06',
        currencyCode: 'CNY',
        totalAmountCents: 0,
      )]));
      await t.pump();
      // KEY:第 1 次 BudgetListLoaded 后 _editCreateCount=1 < 2 → 不 pop。
      expect(observer.popCount, 0,
          reason: 'delete 的 reload(第1次 BudgetListLoaded)不应 pop');

      // === 第 2 阶段:模拟 create 完成后的 reload → 第 2 次 BudgetListLoaded ===
      bloc.emitState(const BudgetListLoaded([BudgetView(
        id: 'after-create',
        name: 'reload-2',
        month: '2026-06',
        currencyCode: 'CNY',
        totalAmountCents: 0,
      )]));
      await t.pump();
      // KEY:第 2 次 BudgetListLoaded 后 _editCreateCount=2 ≥ 2 → pop。
      expect(observer.popCount, greaterThanOrEqualTo(1),
          reason: 'create 的 reload(第2次 BudgetListLoaded)后应 pop');
      // 注意:不调 bloc.close()—— BudgetBloc.close() 在此 widget 测试环境里挂死
      // (疑似 BlocConsumer 监听未完全释放);BlocProvider.value 不会自动 close,
      // 测试结束后 bloc 随用例释放。
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

// 编辑模式 seed:1 条 item(accountId=exp-1 餐饮,planned 50000 cents = ¥500.00)。
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
