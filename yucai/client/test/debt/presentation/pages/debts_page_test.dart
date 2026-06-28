// Task 6 — TDD widget tests for DebtsPage (列表 + 三端响应式 + progress bar)。
//
// _OverviewCard + _DebtCard 私有，故测试通过公开 DebtsPage 驱动：用 mocktail
// 的 DebtRepository 构造真实 DebtBloc，注入 DebtsLoaded 状态。验证：
//   - 总债务概览：总负债 / 总剩余本金 / 整体还清进度 progress bar
//   - 债务卡：counterparty / 类型 badge / 剩余本金 / progress bar / 利率 / 到期
//   - 三端 viewport：mobile 单列 Column / tablet 2 列 / desktop ≥3 列 GridView
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/pages/debts_page.dart';

class _MockRepo extends Mock implements DebtRepository {}

/// Fake CurrencyBloc (与 accounts_page_test 同模式)。
class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

Debt _debt({
  required String id,
  required String counterparty,
  required double interestRate,
  required AmortizationMethod amortization,
  required DateTime dueDate,
  required int totalPrincipalCents,
  required int remainingPrincipalCents,
}) =>
    Debt(
      id: id,
      accountId: 'a-$id',
      counterparty: counterparty,
      interestRate: interestRate,
      amortization: amortization,
      startDate: DateTime(2026, 1, 1),
      dueDate: dueDate,
      totalPrincipalCents: totalPrincipalCents,
      remainingPrincipalCents: remainingPrincipalCents,
      version: 1,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Widget _harness(List<Debt> debts) {
  final repo = _MockRepo();
  registerFallbackValue(const CreateDebtParams(
    accountId: '',
    counterparty: '',
    interestRate: 0,
    amortizationIndex: 0,
    startDateOption: null,
    dueDateOption: null,
    totalPrincipalCents: 0,
  ));
  when(() => repo.list(typeFilter: any(named: 'typeFilter')))
      .thenAnswer((_) async => dartz.Right(debts));
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<DebtBloc>(create: (_) => DebtBloc(repo)),
        BlocProvider<CurrencyBloc>.value(
            value: _FakeCurrencyBloc(const CurrencyState())),
      ],
      child: const DebtsPage(),
    ),
  );
}

void main() {
  // desktop 宽视口，确保完整布局（概览三栏 + 卡片 dc-mid）。
  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  final debts = [
    _debt(
      id: 'd1',
      counterparty: '招商银行',
      interestRate: 4.10,
      amortization: AmortizationMethod.equalPrincipalInterest,
      dueDate: DateTime(2051, 6, 1),
      totalPrincipalCents: 280000000, // 280 万
      remainingPrincipalCents: 210000000, // 剩 210 万 → 已还 25%
    ),
    _debt(
      id: 'd2',
      counterparty: '建设银行',
      interestRate: 5.20,
      amortization: AmortizationMethod.equalPrincipal,
      dueDate: DateTime(2027, 3, 1),
      totalPrincipalCents: 15000000,
      remainingPrincipalCents: 8000000,
    ),
  ];

  testWidgets('overview: 总负债 + 总剩余本金 + progress bar', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(debts));
    await t.pumpAndSettle();
    // 概览标签
    expect(find.textContaining('总负债'), findsWidgets);
    expect(find.textContaining('总剩余本金'), findsWidgets);
    // 概览的 LinearProgressIndicator（整体还清进度）存在。
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    // 总负债 = sum(remaining) = 2.1 亿 + 800 万 = ¥2,180,000.00
    expect(find.textContaining('¥2,180,000.00'), findsWidgets);
  });

  testWidgets('overview: progress ratio = sum(progress*total)/sum(total)',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(debts));
    await t.pumpAndSettle();
    // d1: 0.25 * 280000000 = 70000000；d2: (15-8)/15 * 15000000 = 7000000
    // sum = 77000000；total sum = 295000000 → 77000000/295000000 = 0.261016...
    // → 26.1%
    expect(find.textContaining('26.1%'), findsWidgets);
  });

  testWidgets('debt card: counterparty + 剩余本金 + 利率 + 到期', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(debts));
    await t.pumpAndSettle();
    expect(find.text('招商银行'), findsOneWidget);
    expect(find.text('建设银行'), findsOneWidget);
    // 剩余本金标签 + 值（d1 = ¥2,100,000.00）
    expect(find.textContaining('¥2,100,000.00'), findsOneWidget);
    expect(find.textContaining('剩余本金'), findsWidgets);
    // 利率
    expect(find.textContaining('4.10%'), findsOneWidget);
    expect(find.textContaining('5.20%'), findsOneWidget);
    // 到期（yyyy-MM-dd）—— 卡片 meta 行
    expect(find.textContaining('2051-06-01'), findsOneWidget);
    // 2027-03-01 出现两次：overview「下次还款」+ d2 卡「到期」
    expect(find.textContaining('2027-03-01'), findsNWidgets(2));
    // 下次还款 = min(dueDate) = 2027-03-01（d2 最早到期）—— overview 行
    expect(find.textContaining('下次还款'), findsWidgets);
  });

  testWidgets('debt card: progress bar uses gold accent + progressRatio',
      (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([debts.first]));
    await t.pumpAndSettle();
    // 找到债务卡的进度条（概览也有一个，但 d1 卡片进度 = 0.25）。
    final bars = t.widgetList<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator));
    final cardBar = bars.firstWhere(
      (b) => (b.value ?? 0) > 0.24 && (b.value ?? 0) < 0.26,
    );
    // 金色已还
    expect((cardBar.valueColor as AlwaysStoppedAnimation<Color?>?)?.value,
        AppColors.accent);
  });

  testWidgets('mobile: single-column Column (no GridView)', (t) async {
    t.view.physicalSize = mobile;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(debts));
    await t.pumpAndSettle();
    expect(find.byType(GridView), findsNothing);
    expect(find.text('招商银行'), findsOneWidget);
    expect(find.text('建设银行'), findsOneWidget);
  });

  testWidgets('tablet: 2-column GridView', (t) async {
    t.view.physicalSize = tablet;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(debts));
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });

  testWidgets('desktop: GridView with >=3 columns', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness([
      ...debts,
      _debt(
        id: 'd3',
        counterparty: '招行信用卡',
        interestRate: 18.0,
        amortization: AmortizationMethod.lumpSum,
        dueDate: DateTime(2027, 5, 1),
        totalPrincipalCents: 2000000,
        remainingPrincipalCents: 1500000,
      ),
    ]));
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byType(GridView).first);
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(3));
  });

  testWidgets('FAB present (创建债务)', (t) async {
    t.view.physicalSize = mobile;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(debts));
    await t.pumpAndSettle();
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('empty state when no debts', (t) async {
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(_harness(const []));
    await t.pumpAndSettle();
    // 概览不渲染（0 笔）→ 空态文案。
    expect(find.textContaining('还没有债务'), findsOneWidget);
  });

  // 回归测试(Finding 1):debts_page 必须以 borrowedIn 过滤拉取,
  // 确保 borrowedOut(债权/应收)不会泄漏进债务列表 + 总债务概览。
  testWidgets(
      'regression: dispatches LoadDebtsRequested(typeFilter: borrowedIn)',
      (t) async {
    final repo = _MockRepo();
    registerFallbackValue(const CreateDebtParams(
      accountId: '',
      counterparty: '',
      interestRate: 0,
      amortizationIndex: 0,
      startDateOption: null,
      dueDateOption: null,
      totalPrincipalCents: 0,
    ));
    final calls = <DebtType?>[];
    when(() => repo.list(typeFilter: any(named: 'typeFilter')))
        .thenAnswer((inv) async {
      calls.add(inv.namedArguments[#typeFilter] as DebtType?);
      return const dartz.Right([]);
    });
    await t.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<DebtBloc>(create: (_) => DebtBloc(repo)),
          BlocProvider<CurrencyBloc>.value(
              value: _FakeCurrencyBloc(const CurrencyState())),
        ],
        child: const DebtsPage(),
      ),
    ));
    await t.pumpAndSettle();
    expect(calls, isNotEmpty);
    expect(calls.last, DebtType.borrowedIn);
  });

  // 回归测试(Finding 1,负向断言):即便 repo 返回 borrowedOut(债权)的债务,
  // debts_page 也不应将其当作债务渲染。锁定制表单的负向测试模式:
  // mock 仅对 borrowedIn 返回空 → borrowedOut 的「张三」绝不出现在债务页。
  testWidgets(
      'regression: borrowedOut receivable does NOT appear in debts page',
      (t) async {
    final repo = _MockRepo();
    registerFallbackValue(const CreateDebtParams(
      accountId: '',
      counterparty: '',
      interestRate: 0,
      amortizationIndex: 0,
      startDateOption: null,
      dueDateOption: null,
      totalPrincipalCents: 0,
    ));
    // borrowedIn(债务)返回空;其他方向(债权)即便有数据也不入此页。
    when(() => repo.list(typeFilter: DebtType.borrowedIn))
        .thenAnswer((_) async => const dartz.Right([]));
    when(() => repo.list(typeFilter: any(
            named: 'typeFilter', that: isNot(equals(DebtType.borrowedIn)))))
        .thenAnswer((_) async => dartz.Right([
              _debt(
                id: 'recv-leak',
                counterparty: '张三-不应泄漏',
                interestRate: 0.0,
                amortization: AmortizationMethod.equalPrincipal,
                dueDate: DateTime(2026, 8, 15),
                totalPrincipalCents: 5000000,
                remainingPrincipalCents: 3000000,
              ),
            ]));
    t.view.physicalSize = desktop;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<DebtBloc>(create: (_) => DebtBloc(repo)),
          BlocProvider<CurrencyBloc>.value(
              value: _FakeCurrencyBloc(const CurrencyState())),
        ],
        child: const DebtsPage(),
      ),
    ));
    await t.pumpAndSettle();
    // 债权方向数据绝不在债务页渲染。
    expect(find.text('张三-不应泄漏'), findsNothing);
    // 空态(borrowedIn 无数据)。
    expect(find.textContaining('还没有债务'), findsOneWidget);
  });

  // Task 9 — 列表 badge 用持久化 subtype const label(替代 _inferBadge 推断)。
  group('badge subtype label (Task 9)', () {
    Debt debtWith({
      required String id,
      required String subtype,
      String counterparty = '某机构',
    }) =>
        Debt(
          id: id,
          accountId: 'a-$id',
          counterparty: counterparty,
          interestRate: 5.0,
          amortization: AmortizationMethod.equalPrincipal,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2027, 6, 1),
          totalPrincipalCents: 1000000,
          remainingPrincipalCents: 800000,
          version: 1,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          type: DebtType.borrowedIn,
          subtype: subtype,
        );

    testWidgets('subtype=creditCard shows const label "信用卡"', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      // counterparty 不含「信用卡/crAgent」关键字 —— 老 _inferBadge 会猜「借款」,
      // 但持久化 subtype 应胜出,显示 const label「信用卡」。
      final cc = debtWith(
          id: 'cc', subtype: DebtSubtypes.creditCard, counterparty: '某机构');
      await t.pumpWidget(_harness([cc]));
      await t.pumpAndSettle();
      expect(find.text('信用卡'), findsWidgets);
      // 不出现 fallback 推断的「借款」badge。
      expect(find.text('借款'), findsNothing);
    });

    testWidgets('subtype=mortgage shows const label "房贷"', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final mg = debtWith(
          id: 'mg', subtype: DebtSubtypes.mortgage, counterparty: '某机构');
      await t.pumpWidget(_harness([mg]));
      await t.pumpAndSettle();
      expect(find.text('房贷'), findsWidgets);
    });

    testWidgets('subtype empty(legacy) falls back to _inferBadge', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      // subtype 空 + counterparty 含「房」→ fallback 推断「房贷」。
      final legacy = debtWith(
          id: 'lg', subtype: '', counterparty: '某房贷机构');
      await t.pumpWidget(_harness([legacy]));
      await t.pumpAndSettle();
      expect(find.text('房贷'), findsWidgets);
    });
  });
}
