// TDD three-size widget test for TransactionsPage.
//
// Asserts the御财 responsive breakpoints drive distinct layouts:
//   - 390   → mobile  → card-stack rows (TxnRow mobile branch), SummaryCard grid
//   - 1024  → tablet  → table rows (TxnRow table branch)
//   - 1440  → desktop → table rows, SummaryCard single row
//
// Plus:
//   - transactions are grouped by day, each group shows a date header
//   - the FilterBar is rendered and selecting a type dispatches a reload
//   - a "load more" control appears when the bloc signals hasMore
//   - the "新增交易" entry (FAB / button) is present
//
// The bloc is wired via BlocProvider with a fake repo; no DI / no gRPC.
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transactions_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _FakeTxnRepo extends Mock implements TransactionRepository {}
class _FakeAccountRepo extends Mock implements AccountRepository {}

Transaction _txn(String id, DateTime date, {int amount = 5000}) {
  return Transaction(
    id: id,
    transactionDate: date,
    description: '交易 $id',
    entries: [
      TransactionEntry(accountId: 'a1', debitCents: amount, creditCents: 0),
      TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: amount),
    ],
  );
}

Widget _harness({required Widget child, required Size size}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  late _FakeTxnRepo txnRepo;

  setUp(() {
    txnRepo = _FakeTxnRepo();
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          _txn('t1', DateTime(2026, 6, 19)),
          _txn('t2', DateTime(2026, 6, 19)),
          _txn('t3', DateTime(2026, 6, 18)),
        ], nextPageToken: '')));
    // Task 5.2: the page triggers LoadSummaryRequested on init / filter
    // change / after-create. Default to a non-zero summary so tests that assert
    // on the card values have something to render; override per-test as needed.
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 123456,
              expenseCents: 78900,
              netCents: 44556,
              dailyAvgCents: 1481,
            )));
  });

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    await tester.pumpWidget(_harness(
      size: size,
      child: BlocProvider<TransactionBloc>(
        create: (_) {
          final b = TransactionBloc(txnRepo);
          b.add(const LoadTransactionsRequested());
          return b;
        },
        child: const TransactionsPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mobile (390): renders card-stack rows (no table header), SummaryCard grid',
      (tester) async {
    await pumpPage(tester, const Size(390, 844));

    // No table header column labels on mobile.
    expect(find.text('日期'), findsNothing);
    // Card-stack rows render each txn description.
    expect(find.text('交易 t1'), findsOneWidget);
    expect(find.text('交易 t2'), findsOneWidget);
    // Summary placeholder cells present (four of them).
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
  });

  testWidgets(
      'tablet (1024): renders table header + table rows',
      (tester) async {
    await pumpPage(tester, const Size(1024, 768));

    expect(find.text('日期'), findsOneWidget);
    expect(find.text('交易 t1'), findsOneWidget);
  });

  testWidgets(
      'desktop (1440): renders table header + table rows + SummaryCard row',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    expect(find.text('日期'), findsOneWidget);
    expect(find.text('交易 t1'), findsOneWidget);
  });

  testWidgets('transactions are grouped by day with date headers',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Two distinct day groups: 06-19 (t1, t2) and 06-18 (t3).
    expect(find.text('06-19'), findsWidgets);
    expect(find.text('06-18'), findsWidgets);
  });

  testWidgets('FilterBar type segment "支出" dispatches a reload',
      (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Tap the 支出 segment in the filter bar.
    await tester.tap(find.text('支出').first);
    await tester.pumpAndSettle();

    // repo.list called at least twice (initial + reload).
    verify(() => txnRepo.list(any())).called(greaterThanOrEqualTo(2));
  });

  testWidgets('"加载更多" appears when the bloc has a next page token',
      (tester) async {
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(
            transactions: [_txn('t1', DateTime(2026, 6, 19))],
            nextPageToken: 'cursor1')));

    await pumpPage(tester, const Size(1440, 900));
    expect(find.text('加载更多'), findsOneWidget);

    // Tapping it triggers a second list call with the cursor.
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(
            transactions: [_txn('t2', DateTime(2026, 6, 19))],
            nextPageToken: '')));
    await tester.tap(find.text('加载更多'));
    await tester.pumpAndSettle();
    verify(() => txnRepo.list(any())).called(greaterThanOrEqualTo(2));
  });

  testWidgets('error state surfaces the message and a retry control',
      (tester) async {
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Left(ServerFailure('加载失败')));

    await pumpPage(tester, const Size(1440, 900));

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('empty state shows a "新增交易" entry', (tester) async {
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Right(ListTransactionsResult(transactions: [])));

    await pumpPage(tester, const Size(1440, 900));
    expect(find.textContaining('新增交易'), findsWidgets);
  });

  // ───────────────────────── Task 5.2: SummaryCard 接真实 ─────────────────────────

  testWidgets('SummaryCard renders the real MonthlySummary values', (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    // Default stub: income 123456 → ¥1,234.56 ; expense 78900 → ¥789.00.
    expect(find.text('¥1,234.56'), findsOneWidget);
    expect(find.text('¥789.00'), findsOneWidget);
    // net 44556 → ¥445.56 (positive → green / income-coloured).
    expect(find.text('¥445.56'), findsOneWidget);
    // dailyAvg 1481 → ¥14.81.
    expect(find.text('¥14.81'), findsOneWidget);
  });

  testWidgets('SummaryCard falls back to ¥0.00 before summary resolves',
      (tester) async {
    // summary never resolves (pending) → card shows zeros, list still renders.
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) => Completer<dartz.Either<Failure, MonthlySummary>>()
            .future);
    await pumpPage(tester, const Size(1440, 900));
    expect(find.text('¥0.00'), findsWidgets);
  });

  testWidgets('a failed summary leaves the card at ¥0.00 (does not crash)',
      (tester) async {
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async => const dartz.Left(ServerFailure('summary err')));
    await pumpPage(tester, const Size(1440, 900));
    expect(find.text('¥0.00'), findsWidgets);
    // The list still renders normally — a summary blip doesn't blank it.
    expect(find.text('交易 t1'), findsOneWidget);
  });

  // ─────────── Task 1: _MobileTxnCard 副行(账户首字母方块 + HH:MM) + 右侧分类 chip ───────────

  testWidgets(
      'mobile txn card: 分类 chip + HH:MM + 账户首字母方块 (text assertions)',
      (tester) async {
    // 注入账户仓库:一个 expense(餐饮)账户 + 一个 asset(现金)账户,
    // 让 _CategoryChip / _AccountTag 有真实 account 可渲染。
    final accountRepo = _FakeAccountRepo();
    const expenseAcct = Account(
      id: 'a2',
      name: '餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
    const assetAcct = Account(
      id: 'a1',
      name: '现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
    when(() => accountRepo.list())
        .thenAnswer((_) async => const dartz.Right([expenseAcct, assetAcct]));

    // 交易带 transactionTime(HH:MM 来源)。
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          Transaction(
            id: 'm1',
            transactionDate: DateTime(2026, 6, 19),
            transactionTime: DateTime(2026, 6, 19, 9, 5),
            description: '早餐',
            entries: const [
              TransactionEntry(
                  accountId: 'a1', debitCents: 1200, creditCents: 0),
              TransactionEntry(
                  accountId: 'a2', debitCents: 0, creditCents: 1200),
            ],
          ),
        ], nextPageToken: '')));

    // mobile viewport 375×900 触发 mobile 分支。
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 包一层 RepositoryProvider<AccountRepository> 让页面 _loadAccounts 可解析。
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(375, 900)),
        child: Scaffold(
          body: RepositoryProvider<AccountRepository>.value(
            value: accountRepo,
            child: BlocProvider<TransactionBloc>(
              create: (_) {
                final b = TransactionBloc(txnRepo);
                b.add(const LoadTransactionsRequested());
                return b;
              },
              child: const TransactionsPage(),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 分类 chip:expense 账户 category.label
    expect(find.text('其他资产'), findsWidgets,
        reason: 'mobile 交易卡右侧应渲染分类 chip (账户 category label)');
    // HH:MM 时间(transactionTime 09:05,副行显示「· 09:05」)
    expect(find.textContaining(RegExp(r'\d{2}:\d{2}')), findsWidgets,
        reason: 'mobile 副行应显示 HH:MM');
    // 账户首字母方块:_AccountTag 渲染 asset 账户名「现金」
    expect(find.text('现金'), findsWidgets,
        reason: 'mobile 副行应含账户首字母方块 + 账户名');
  });

  // ─────────── C1 fix regression: 非转账无 asset 账户不崩溃 ───────────
  //
  // _MobileTxnCard 非转账副行曾用 firstWhere(无 orElse)找 asset 账户;若交易
  // 全是 expense/income(无 asset)或 accountOf 全 null → StateError 崩溃。
  // 现加 orElse: () => txn.entries.first,本测试断言该场景渲染不崩溃。

  testWidgets(
      'mobile txn card: 非转账 entries 无 asset 账户渲染不崩溃 (C1 fix)',
      (tester) async {
    final accountRepo = _FakeAccountRepo();
    // 注入两个 expense 账户(非 asset),让 firstWhere(asset) 找不到匹配。
    const expenseAcct1 = Account(
      id: 'a1',
      name: '餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
    const expenseAcct2 = Account(
      id: 'a2',
      name: '交通',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );
    when(() => accountRepo.list()).thenAnswer(
        (_) async => const dartz.Right([expenseAcct1, expenseAcct2]));

    // 非转账 compound:两条 entries 都是 expense 账户(无 asset)。
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          Transaction(
            id: 'c1',
            transactionDate: DateTime(2026, 6, 19),
            transactionTime: DateTime(2026, 6, 19, 9, 5),
            description: '复合支出',
            entries: const [
              TransactionEntry(
                  accountId: 'a1', debitCents: 1200, creditCents: 0),
              TransactionEntry(
                  accountId: 'a2', debitCents: 0, creditCents: 1200),
            ],
          ),
        ], nextPageToken: '')));

    // mobile viewport 375×900 触发 mobile 分支。
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(375, 900)),
        child: Scaffold(
          body: RepositoryProvider<AccountRepository>.value(
            value: accountRepo,
            child: BlocProvider<TransactionBloc>(
              create: (_) {
                final b = TransactionBloc(txnRepo);
                b.add(const LoadTransactionsRequested());
                return b;
              },
              child: const TransactionsPage(),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 修复前:firstWhere 无 orElse → StateError: No element 崩溃,pumpAndSettle 抛错。
    // 修复后:回落到 entries.first,正常渲染描述文本。
    expect(find.text('复合支出'), findsOneWidget,
        reason: '无 asset 账户的非转账交易应正常渲染,不崩溃 (C1 fix)');
  });

  // ─────────── Task 2: _MobileFilterSheet 单元渲染 + 应用回调 ───────────
  //
  // sheet 在 Task 4 才组装进 _Content;此处直接 pump 单元 widget,
  // 验证渲染(标题/应用按钮) + 点击「应用筛选」回调 onApply。

  testWidgets('_MobileFilterSheet 渲染 + 应用回调', (tester) async {
    TxnFilterState? applied;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MobileFilterSheet(
          initial: const TxnFilterState(),
          accountOptions: const [FilterOption('a1', '招商银行')],
          categoryOptions: const [FilterOption('food', '餐饮')],
          monthOptions: const [FilterOption('2026-06', '2026年6月')],
          onApply: (s) => applied = s,
        ),
      ),
    ));

    expect(find.text('筛选交易'), findsOneWidget);
    expect(find.text('应用筛选'), findsOneWidget);

    await tester.tap(find.text('应用筛选'));
    await tester.pumpAndSettle();

    expect(applied, isNotNull);
  });

  // ─────────── Task 3: MobileHeader month-bar + 可展开 sum-card ───────────
  //
  // 单元 pump MobileHeader(公开 + @visibleForTesting),不依赖 _Content 组装(组装在 Task 4)。
  // 验证:month-bar 文本(YYYY年M月) + sum-card 三列(收入/支出/净额) + 展开切换 + 日均支出。

  testWidgets('MobileHeader: month-bar 文本 + sum-card 三列 + 展开日均', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MobileHeader(
          filter: const TxnFilterState(month: '2026-06'),
          count: 12,
          summary: const MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 2480000,
              expenseCents: 1835000,
              netCents: 645000,
              dailyAvgCents: 61167),
          onFilterChanged: (_) {},
        ),
      ),
    ));
    // month-bar 文本(2026年6月)
    expect(find.textContaining('2026年6月'), findsOneWidget);
    // sum-card 三列(收入/支出/净额)
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.textContaining('本月净'), findsOneWidget);
    // 展开 toggle
    expect(find.text('查看月度明细'), findsOneWidget);
    await t.tap(find.text('查看月度明细'));
    await t.pumpAndSettle();
    // 展开后:日均支出
    expect(find.textContaining('日均'), findsWidgets);
  });

  testWidgets('MobileHeader: prev/next 切月 onFilterChanged', (t) async {
    TxnFilterState? next;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MobileHeader(
          filter: const TxnFilterState(month: '2026-06'),
          count: 12,
          summary: null,
          onFilterChanged: (s) => next = s,
        ),
      ),
    ));
    await t.tap(find.byTooltip('上一月'));
    await t.pumpAndSettle();
    expect(next?.month, '2026-05', reason: 'prev → 上一月');
  });

  // ─────────── Task 4: _Content mobile 分支组装(_MobileAppBar + MobileHeader + _MobileList) ───────────
  //
  // mobile 分支显示 _MobileAppBar(标题「交易管理」) + MobileHeader(month-bar YYYY年M月),
  // 隐藏 desktop _Header(标题「交易记录」) / SummaryCard / TxnFilterBar。
  //
  // 注:既有 mobile (390) test 用 _harness(MediaQuery size) 注入宽度,本 task 同样用
  // MediaQuery 包一层注入 mobile 宽度,与既有 mobile test 同源(Breakpoints 基于
  // MediaQuery.size.width),无需 tester.view.physicalSize。

  testWidgets(
      'mobile: _Content 显示 _MobileAppBar/_MobileHeader,隐藏 desktop _Header/TxnFilterBar',
      (t) async {
    // mobile viewport 375×900 触发 mobile 分支(Breakpoints mobileUpper=600)。
    await pumpPage(t, const Size(375, 900));

    // mobile appbar 标题「交易管理」(_MobileAppBar)
    expect(find.text('交易管理'), findsOneWidget,
        reason: 'mobile 分支应渲染 _MobileAppBar (标题「交易管理」)');
    // mobile header month-bar 文本(YYYY年M月,MobileHeader)
    expect(find.textContaining(RegExp(r'\d{4}年\d+月')), findsWidgets,
        reason: 'mobile 分支应渲染 MobileHeader (month-bar YYYY年M月)');
    // desktop _Header 标题「交易记录」隐藏(mobile 分支不渲染 _Header)
    expect(find.text('交易记录'), findsNothing,
        reason: 'mobile 分支应隐藏 desktop _Header (标题「交易记录」)');
  });

  // ─────────── Task 2 推迟的端到端 test: filterBtn tap → 筛选 sheet 弹 → 应用筛选 → 关 ───────────
  //
  // Task 2 reviewer 提醒:Task 2 仅单元 pump MobileFilterSheet;_MobileAppBar.filterBtn →
  // _showMobileFilterSheet → MobileFilterSheet 的端到端链路需在 Task 4 组装后验证。

  testWidgets(
      'mobile: filterBtn tap 弹出筛选 sheet,「应用筛选」关闭 sheet (端到端)',
      (t) async {
    await pumpPage(t, const Size(375, 900));

    // 1. _MobileAppBar 的筛选 IconButton(tooltip='筛选')
    final filterBtn = find.byTooltip('筛选');
    expect(filterBtn, findsOneWidget, reason: 'mobile appbar 应有筛选 btn');
    // 2. tap 弹出 MobileFilterSheet(标题「筛选交易」)
    await t.tap(filterBtn);
    await t.pumpAndSettle();
    expect(find.text('筛选交易'), findsOneWidget,
        reason: 'tap 筛选 btn 应弹出 MobileFilterSheet (标题「筛选交易」)');
    // 3. tap「应用筛选」关闭 sheet
    await t.tap(find.text('应用筛选'));
    await t.pumpAndSettle();
    expect(find.text('筛选交易'), findsNothing,
        reason: 'tap 应用筛选 应关闭 sheet');
  });
}
