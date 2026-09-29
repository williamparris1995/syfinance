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
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

/// 页面主滚动(虚拟化 ListView 的 Scrollable;first 排除筛选输入框等
/// 内嵌 scrollable —— 树序在前)。
final _pageScrollable = find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

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
          // 与路由层同口径:首页 50 条(#2-B 无限滚动)。
          b.add(const LoadTransactionsRequested(
              pageSize: TransactionsPage.listPageSize));
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

    // 虚拟化列表(#2-B):tablet 头块较高(SummaryCard 双列),表头/首行在
    // 折叠线下 —— 滚动到首行(表头在其上方,仍在构建区)。
    await tester.scrollUntilVisible(
      find.text('交易 t1'),
      300,
      scrollable: _pageScrollable,
    );
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
    // 虚拟化:06-18 组在折叠线下,滚动到该组行(t3 唯一;『06-18』文本
    // 在组头与行日期列各一处,不能作 scrollUntilVisible 目标)。
    await tester.scrollUntilVisible(
      find.text('交易 t3'),
      200,
      scrollable: _pageScrollable,
    );
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

  testWidgets(
      '月份组头(#2-B):跨月分组渲染「YYYY年M月」组头 + 当月收入/支出小计',
      (tester) async {
    // 账户元数据供小计口径(a3 income / a2 expense / a1 asset)。
    final accountRepo = _FakeAccountRepo();
    const cash = Account(
      id: 'a1', name: '现金', accountType: AccountType.asset,
      category: AccountCategory.savings, currencyCode: 'CNY',
      initialBalanceCents: 0, currentBalanceCents: 0,
      ownership: Ownership.personal, status: AccountStatus.active);
    const food = Account(
      id: 'a2', name: '餐饮', accountType: AccountType.expense,
      category: AccountCategory.otherAsset, currencyCode: 'CNY',
      initialBalanceCents: 0, currentBalanceCents: 0,
      ownership: Ownership.personal, status: AccountStatus.active);
    const salary = Account(
      id: 'a3', name: '工资', accountType: AccountType.income,
      category: AccountCategory.otherAsset, currencyCode: 'CNY',
      initialBalanceCents: 0, currentBalanceCents: 0,
      ownership: Ownership.personal, status: AccountStatus.active);
    when(() => accountRepo.list())
        .thenAnswer((_) async => const dartz.Right([cash, food, salary]));
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
          // 6 月:收入 ¥100.00(credit income 账户)。
          Transaction(
            id: 'i1',
            transactionDate: DateTime(2026, 6, 19),
            description: '工资入账',
            entries: const [
              TransactionEntry(
                  accountId: 'a1', debitCents: 10000, creditCents: 0),
              TransactionEntry(
                  accountId: 'a3', debitCents: 0, creditCents: 10000),
            ],
          ),
          // 6 月:支出 ¥42.00。腿向照 server 口径(SimpleExpense = debit
          // expense + credit asset):expense 账户记借方。
          Transaction(
            id: 'e1',
            transactionDate: DateTime(2026, 6, 18),
            description: '午餐',
            entries: const [
              TransactionEntry(
                  accountId: 'a2', debitCents: 4200, creditCents: 0),
              TransactionEntry(
                  accountId: 'a1', debitCents: 0, creditCents: 4200),
            ],
          ),
          // 5 月:支出 ¥10.00。
          Transaction(
            id: 'e2',
            transactionDate: DateTime(2026, 5, 20),
            description: '五月打车',
            entries: const [
              TransactionEntry(
                  accountId: 'a2', debitCents: 1000, creditCents: 0),
              TransactionEntry(
                  accountId: 'a1', debitCents: 0, creditCents: 1000),
            ],
          ),
        ], nextPageToken: '')));

    await tester.pumpWidget(_harness(
      size: const Size(1440, 900),
      child: RepositoryProvider<AccountRepository>.value(
        value: accountRepo,
        child: BlocProvider<TransactionBloc>(
          create: (_) {
            final b = TransactionBloc(txnRepo);
            b.add(const LoadTransactionsRequested(
                pageSize: TransactionsPage.listPageSize));
            return b;
          },
          child: const TransactionsPage(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 两个月 → 两个月份组头(先 6 月后 5 月,输入序保持)。虚拟化:组头
    // 随滚动离场即销毁 —— 6 月组头(含小计)在滚动前断言,5 月组滚动到位
    // 后断言。
    expect(find.text('2026年6月'), findsOneWidget);
    // 组头小计(6 月):收入 ¥100.00 / 支出 ¥42.00。
    expect(find.textContaining('收入 ¥100.00'), findsOneWidget);
    expect(find.textContaining('支出 ¥42.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('2026年5月'),
      200,
      scrollable: _pageScrollable,
    );
    expect(find.text('2026年5月'), findsOneWidget);
    // 组头小计(5 月):支出 ¥10.00(无收入 → ¥0.00 不特判,小计恒展示)。
    expect(find.textContaining('支出 ¥10.00'), findsOneWidget);
  });

  testWidgets(
      '无限滚动(#2-B):滚到底(距底<400px)自动加载下一页 —— 追加不替换,'
      '加载中列表保留 + spinner,完成后页脚累计',
      (tester) async {
    // 记录式桩:收集每次 list 参数(首查 + 追加)。
    final calls = <ListTransactionsParams>[];
    final page2 =
        Completer<dartz.Either<Failure, ListTransactionsResult>>();
    when(() => txnRepo.list(any())).thenAnswer((invocation) async {
      final p = invocation.positionalArguments.single as ListTransactionsParams;
      calls.add(p);
      if ((p.pageToken ?? '').isEmpty) {
        // 首页 60 条(超 50/页阈值,撑出滚动距离),hasMore=true。
        return dartz.Right(ListTransactionsResult(
            transactions: [
              for (var i = 0; i < 60; i++)
                _txn('p1-$i', DateTime(2026, 6, 19))
            ],
            nextPageToken: 'c1'));
      }
      return page2.future; // 第 2 页挂起,便于断言 LoadingMore 中间态。
    });

    await pumpPage(tester, const Size(1440, 900));
    expect(calls.length, 1, reason: '初始只查首页');

    // 一大步滚到底(越过 400px 阈值)。拖动后的惯性收敛需要数帧,收尾
    // (ScrollEnd)通知在布局定形后才评估距底 —— 连续泵帧至收敛。
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(calls.length, 2, reason: '距底<400px 应自动请求下一页');
    expect(calls[1].pageToken, 'c1', reason: '追加携带上一页游标');
    expect(calls[1].pageSize, TransactionsPage.listPageSize,
        reason: '追加沿用首页 pageSize');

    // LoadingMore 中间态:首页尾部行仍在列(虚拟化:断言视口内的尾部行,
    // 首行 p1-0 已随滚动离场销毁),页脚 spinner。
    expect(find.text('交易 p1-59'), findsOneWidget,
        reason: '加载中不替换已加载列表');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 第 2 页返回(1 条 5 月数据,末页)→ 追加渲染 + 页脚累计 61 条。
    page2.complete(dartz.Right(ListTransactionsResult(
        transactions: [_txn('p2-0', DateTime(2026, 5, 3))],
        nextPageToken: '')));
    await tester.pumpAndSettle();
    // 内容在尾部增长后,惰性布局需要再一次滚动展开新增区(虚拟化列表
    // 特性;此时 hasMore=false,该滚动不会再发请求)。
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('交易 p2-0'), findsOneWidget, reason: '追加不替换');
    expect(find.text('交易 p1-59'), findsWidgets, reason: '旧页保留');
    expect(find.text('已全部加载 · 共 61 条'), findsOneWidget);
    expect(calls.length, 2, reason: '防抖:无重复请求');
  });

  testWidgets(
      '末页页脚(#2-B):hasMore=false 显示「已全部加载 · 共 N 条」,PagerBar 退出本页',
      (tester) async {
    // 默认桩:3 条、nextPageToken 空 → 末页。虚拟化:页脚在折叠线下,
    // scrollUntilVisible 滚到位(即断言其存在)。
    await pumpPage(tester, const Size(1440, 900));
    await tester.scrollUntilVisible(
      find.text('已全部加载 · 共 3 条'),
      200,
      scrollable: _pageScrollable,
    );
    expect(find.text('已全部加载 · 共 3 条'), findsOneWidget,
        reason: '末页页脚显示累计条数');
    // 页条分页(F7 FR-4)已被无限滚动取代:PagerBar 不再出现在本页。
    expect(find.text('第 1 页'), findsNothing);
    expect(find.byTooltip('上一页'), findsNothing);
    expect(find.byTooltip('下一页'), findsNothing);
  });

  testWidgets(
      '搜索(FR-2):逐键输入不触发重载,提交(回车)才携带完整词重查(fix round 1)',
      (tester) async {
    // 记录式桩:直接收集每次 list 参数(避免 mocktail 二次 verify 排除已
    // 校验调用的坑),便于断言「逐键零重查、提交一次」。
    final calls = <ListTransactionsParams>[];
    when(() => txnRepo.list(any())).thenAnswer((invocation) async {
      calls.add(invocation.positionalArguments.single as ListTransactionsParams);
      return dartz.Right(ListTransactionsResult(
          transactions: [_txn('t1', DateTime(2026, 6, 19))],
          nextPageToken: ''));
    });

    await pumpPage(tester, const Size(1440, 900));
    final field = find.byType(TextField);

    // 连续两次输入(未提交):列表不重查 —— 修复前逐键提交 → 整页 Loading
    // 替换卸载 filter_bar,输入焦点被打断。
    await tester.enterText(field, '午');
    await tester.pump();
    await tester.enterText(field, '午餐');
    await tester.pump();
    expect(calls.length, 1, reason: '逐键输入不应触发列表重查');

    // 提交动作(回车/完成):携带完整词重查第 1 页。
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(calls.length, 2);
    expect(calls.last.searchText, '午餐');
    expect(calls.last.pageToken, isNull, reason: '搜索变化重置第 1 页');

    // 提交重载后仍可继续输入并再次提交(修复:焦点/控制器不被打断)。
    await tester.enterText(field, '工资');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(calls.length, 3);
    expect(calls.last.searchText, '工资');
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

    // 分类 chip：显示账户名(餐饮)而非 category.label(其他资产)——对齐 OD
    // category name(account-as-category：expense 账户名即分类名)。
    expect(find.text('餐饮'), findsWidgets,
        reason: 'mobile 交易卡右侧应渲染分类 chip (账户名,对齐 OD category name)');
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
    // F7:sheet 新增搜索+排序后内容变长,先把「应用筛选」滚进可视区再 tap。
    final sheetScrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await t.scrollUntilVisible(
      find.text('应用筛选'),
      200,
      scrollable: sheetScrollable,
    );
    // 3. tap「应用筛选」关闭 sheet
    await t.tap(find.text('应用筛选'));
    await t.pumpAndSettle();
    expect(find.text('筛选交易'), findsNothing,
        reason: 'tap 应用筛选 应关闭 sheet');
  });

  // ─────────── 反馈1a(反馈⑥ 回归):页身选区 scope 的真实鼠标拖选 ───────────
  // 根因:全局/路由层 scope 与多滚动容器并存 = 拖选边沿更新被静默丢弃
  // (Flutter #153004 家族);修法 = TransactionsPage 页身自包
  // CurrentRouteSelectionArea。本测用真实按下-拖动-抬起序列(完整手势
  // 竞技场)断言行内描述可选 —— 真机链路由 integration e2e 双面钉死。
  testWidgets('反馈1a:desktop 行内描述真实鼠标拖选 → 选区非空', (tester) async {
    await pumpPage(tester, const Size(1440, 900));

    final row = find.text('交易 t1');
    expect(row.evaluate(), isNotEmpty, reason: '夹具行在列');
    // 行文本落在页身 scope 内(层级自查:SelectionArea 祖先)。
    expect(
      find.descendant(of: find.byType(SelectionArea), matching: row),
      findsOneWidget,
      reason: '行文本应在页身 CurrentRouteSelectionArea scope 内',
    );

    final region = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion).first);
    final center = tester.getCenter(row);
    final gesture = await tester.startGesture(center.translate(-6, 0),
        kind: PointerDeviceKind.mouse);
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      region.contextMenuButtonItems
          .any((i) => i.type == ContextMenuButtonType.copy),
      isTrue,
      reason: '反馈1a:拖选后选区非空(全局 scope 时代此处恒空)',
    );
    expect(region.selectionEndpoints.length, 2);
  });
}
