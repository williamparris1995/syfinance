// F9-T2 — 账户详情「近期交易」标准查询套件 widget 测试(TDD 先红后绿)。
//
// 断言口径(F9 FR-2 / ADR-4 / NFR-2):
//   - 默认首屏 = 该账户近期交易(日期降序第 1 页,pageSize 100,无搜索);
//   - 搜索(提交制,复用 F7 TxnSearchField)透传 searchText,且任一筛选
//     变化重置第 1 页(F7 语义:Load 事件 → PageCursorStack 清栈);
//   - 排序四态(复用 F7 TxnSortControl)透传 sortKey/sortDir;
//   - 翻页走 pageToken 前进/回退(filter 不变,bloc 内共享 PageCursorStack);
//   - 单页(hasMore==false 且 pageIndex==0)整体隐藏共享 PagerBar。
//
// harness 照 account_detail_page_test.dart(与路由层 `/accounts/:id` 的
// MultiBlocProvider 同款初始化:bloc create 时发 account-scoped list+summary)。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/get_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/domain/usecases/update_account_usecase.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/pages/account_detail_page.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/widgets/pager_bar.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _MockTxnRepo extends Mock implements TransactionRepository {}

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

Account _account() => const Account(
      id: 'a1',
      name: '现金',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 100000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

/// 交易夹具:双 entry(a1 借 / a2 贷,资产对资产 → transfer 形态无关紧要,
/// 本套件只断言描述行与查询参数,不涉及 flavour 解析)。
Transaction _txn(String id, DateTime date, {String? desc}) => Transaction(
      id: id,
      transactionDate: date,
      description: desc ?? '交易 $id',
      entries: const [
        TransactionEntry(accountId: 'a1', debitCents: 5000, creditCents: 0),
        TransactionEntry(accountId: 'a2', debitCents: 0, creditCents: 5000),
      ],
    );

/// 默认「服务端」数据:7 条(t0..t6,日期降序),每页 5 条 → 两页。
/// pageToken 语义照真实 DS(offset 串):第 1 页 token 空 → 返回 0-4 + '5';
/// token '5' → 返回 5-6 + ''(末页)。pageSize 压小到 5 以便用 7 条数据
/// 验证翻页(客户端传 pageSize 100 由参数断言覆盖,与 stub 切片无关)。
List<Transaction> _allTxns() => List.generate(
    7, (i) => _txn('t$i', DateTime(2026, 6, 20).subtract(Duration(days: i))));

ListTransactionsResult _twoPageStub(ListTransactionsParams p) {
  // 搜索-aware:searchText='午餐' 命中 1 条(单页)—— 验证搜索经查询管道
  // 过滤后驱动 UI(而非客户端再过滤)。
  if (p.searchText == '午餐') {
    return ListTransactionsResult(
        transactions: [_txn('l1', DateTime(2026, 6, 20), desc: '午餐面')],
        nextPageToken: '');
  }
  final all = _allTxns();
  final offset = int.tryParse(p.pageToken ?? '') ?? 0;
  const pageSize = 5;
  final end = (offset + pageSize).clamp(0, all.length);
  return ListTransactionsResult(
    transactions: all.sublist(offset, end),
    nextPageToken: end < all.length ? '$end' : '',
  );
}

void main() {
  late _MockAccountRepo accountRepo;
  late _MockTxnRepo txnRepo;

  setUpAll(() {
    registerFallbackValue(const ListTransactionsParams());
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() {
    accountRepo = _MockAccountRepo();
    txnRepo = _MockTxnRepo();
    // 详情页 initState 的 _loadAccounts 经 getIt 解析 AccountRepository。
    GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
    GetIt.instance.registerSingleton<TransactionRepository>(txnRepo);
    // 本页 initState 订阅 DataRefreshNotifier(交易跨 branch 变更后重拉)。
    GetIt.instance.registerLazySingleton<DataRefreshNotifier>(
        DataRefreshNotifier.new);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  /// 泵页:与路由层 `/accounts/:id` 同款 bloc 初始化(账户详情页自身不发
  /// 初始 list —— 由 provide 方发,页面只读状态 + 驱动筛选/翻页事件)。
  Future<void> pumpSuite(
    WidgetTester tester, {
    ListTransactionsResult Function(ListTransactionsParams p)? onList,
  }) async {
    final a = _account();
    when(() => accountRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(a));
    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right([a]));
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
        .thenAnswer((_) async =>
            const dartz.Right(MonthlySummary(year: 2026, month: 6)));
    final respond = onList ?? _twoPageStub;
    when(() => txnRepo.list(any())).thenAnswer((inv) async =>
        dartz.Right(respond(inv.positionalArguments.first
            as ListTransactionsParams)));

    final listUc = _MockList();
    final createUc = _MockCreate();
    final deleteUc = _MockDelete();
    final getUc = _MockGet();
    final updateUc = _MockUpdate();
    when(() => getUc.call(any())).thenAnswer((_) async => dartz.Right(a));
    when(() => listUc.call()).thenAnswer((_) async => dartz.Right([a]));

    await tester.pumpWidget(MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AccountBloc>(
            create: (_) {
              final b =
                  AccountBloc(listUc, createUc, deleteUc, getUc, updateUc);
              b.add(const GetAccountRequested('a1'));
              return b;
            },
          ),
          BlocProvider<TransactionBloc>(
            create: (_) {
              final b = TransactionBloc(txnRepo);
              b.add(const LoadTransactionsRequested(
                  filter: TxnFilterState(accountId: 'a1')));
              b.add(LoadSummaryRequested(
                  year: DateTime.now().year,
                  month: DateTime.now().month,
                  accountId: 'a1'));
              return b;
            },
          ),
        ],
        child: const AccountDetailPage(id: 'a1'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// 滚动到「近期交易」panel(hero + stats 占满首屏,panel 在 ListView 下方,
  /// 懒构建需滚入视口)。
  Future<void> scrollToPanel(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  /// 取 tooltip 对应 IconButton 的当前实例(照 account_detail_page_test 的
  /// 既有 idiom:直接触发 onPressed,规避滚出视口的 tap 漂移)。
  IconButton pagerBtnOf(WidgetTester tester, String tooltip) =>
      tester.widget<IconButton>(find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ));

  List<ListTransactionsParams> listCalls() =>
      verify(() => txnRepo.list(captureAny()))
          .captured
          .cast<ListTransactionsParams>();

  testWidgets(
      '默认首屏:近期交易降序第 1 页(accountId 作用域 + pageSize 100 + 无搜索),'
      '单页隐藏分页条(NFR-2)', (tester) async {
    // 单页数据(空 nextToken)→ PagerBar 整体隐藏。
    await pumpSuite(tester, onList: (_) => ListTransactionsResult(
          transactions: [_allTxns()[0], _allTxns()[1]],
          nextPageToken: '',
        ));
    await scrollToPanel(tester);

    // 初始一次 list 调用:参数 = 默认标准套件口径。
    final calls = listCalls();
    expect(calls, hasLength(1));
    final p = calls.single;
    expect(p.accountId, 'a1', reason: '账户详情交易区固定 accountId 作用域');
    expect(p.searchText, isNull);
    expect(p.sortKey, TxnSortKey.date, reason: '默认日期降序(NFR-2 首屏语义)');
    expect(p.sortDir, TxnSortDir.desc);
    expect(p.pageSize, 100, reason: 'F9:标准 pageSize 100(替换 Task 6 的 5)');
    expect(p.pageToken, isNull);

    // 列表渲染(panel 行)。
    expect(find.text('交易 t0'), findsOneWidget);
    expect(find.text('交易 t1'), findsOneWidget);
    // 单页隐藏分页条。
    expect(find.byType(PagerBar), findsNothing);
    expect(find.text('第 1 页'), findsNothing);
    // 旧 Task 6 迷你分页页码(1/2)已删除。
    expect(find.text('1/2'), findsNothing);
  });

  testWidgets('搜索:提交搜索词 → searchText 透传 + UI 经管道过滤 + 重置第 1 页',
      (tester) async {
    await pumpSuite(tester);
    await scrollToPanel(tester);

    // 搜索框存在(F7 TxnSearchField 复用,提交制)。
    final field = find.descendant(
        of: find.byType(TxnSearchField), matching: find.byType(EditableText));
    expect(field, findsOneWidget);
    await tester.enterText(field, '午餐');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    // 过滤结果经查询管道返回( stub 只对 searchText='午餐' 返回午餐面)。
    expect(find.text('午餐面'), findsOneWidget);
    expect(find.text('交易 t0'), findsNothing);

    final calls = listCalls();
    expect(calls.last.searchText, '午餐');
    // 重置第 1 页:搜索提交走 Load 事件,不带 pageToken。
    expect(calls.last.pageToken, isNull,
        reason: '任一筛选变化重置第 1 页(F7 语义)');
  });

  testWidgets('排序:切「金额升序」→ sortKey=amount / sortDir=asc 透传 + 控件回显',
      (tester) async {
    await pumpSuite(tester);
    await scrollToPanel(tester);

    // 控件按钮显示当前态「日期降序」(默认)。
    expect(find.text('日期降序'), findsOneWidget);
    await tester.ensureVisible(find.text('日期降序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日期降序'));
    await tester.pumpAndSettle();

    // 四态菜单展开,点「金额升序」。
    expect(find.text('金额升序'), findsOneWidget);
    await tester.tap(find.text('金额升序').last);
    await tester.pumpAndSettle();

    final calls = listCalls();
    expect(calls.last.sortKey, TxnSortKey.amount);
    expect(calls.last.sortDir, TxnSortDir.asc);
    expect(calls.last.pageToken, isNull, reason: '排序变化重置第 1 页');
    // 控件按钮回显新态。
    expect(find.text('金额升序'), findsOneWidget);
  });

  testWidgets('翻页:token 前进/回退(下一页带 nextToken,上一页回空 token 第 1 页)',
      (tester) async {
    await pumpSuite(tester);
    await scrollToPanel(tester);

    // 第 1 页:pager 可见,显示 t0..t4(第 2 页内容不出现)。
    expect(find.text('第 1 页'), findsOneWidget);
    expect(find.text('交易 t4'), findsOneWidget);
    expect(find.text('交易 t5'), findsNothing);

    // 下一页:携带第 1 页返回的 nextToken('5',offset 串)重查。
    pagerBtnOf(tester, '下一页').onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.text('交易 t5'), findsOneWidget);
    expect(find.text('交易 t6'), findsOneWidget);
    // 翻页 = 切片替换(非追加):第 1 页内容不再显示。
    expect(find.text('交易 t0'), findsNothing);
    expect(listCalls().last.pageToken, '5');

    // 末页:下一页禁用。
    expect(pagerBtnOf(tester, '下一页').onPressed, isNull);

    // 上一页:回退到第 1 页起始 token(空 = 首查不带 token;共享
    // PageCursorStack 栈内复用,不重发探索性查询)。
    pagerBtnOf(tester, '上一页').onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('第 1 页'), findsOneWidget);
    expect(find.text('交易 t0'), findsOneWidget);
    expect(listCalls().last.pageToken, isNull,
        reason: '第 1 页 token 恒为空串 → 首查口径(不带 token)');
  });

  testWidgets('翻页透传筛选:第 2 页的 list 调用携带第 1 页提交的搜索词',
      (tester) async {
    // 让搜索结果也是两页:搜索词 '交易'(匹配全部 7 条描述「交易 t*」)。
    await pumpSuite(tester);
    await scrollToPanel(tester);

    final field = find.descendant(
        of: find.byType(TxnSearchField), matching: find.byType(EditableText));
    await tester.enterText(field, '交易');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    pagerBtnOf(tester, '下一页').onPressed!();
    await tester.pumpAndSettle();

    final last = listCalls().last;
    expect(last.searchText, '交易', reason: '翻页 filter 不变(仅换 token)');
    expect(last.pageToken, '5');
    expect(find.text('第 2 页'), findsOneWidget);
  });

  testWidgets('筛选变化重置第 1 页:翻到第 2 页后切排序 → pageToken 归空 + 页码回 1',
      (tester) async {
    await pumpSuite(tester);
    await scrollToPanel(tester);

    pagerBtnOf(tester, '下一页').onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('第 2 页'), findsOneWidget);

    // 切排序(日期降序 → 金额降序):应重置回第 1 页。
    await tester.ensureVisible(find.text('日期降序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('日期降序'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('金额降序').last);
    await tester.pumpAndSettle();

    final last = listCalls().last;
    expect(last.pageToken, isNull, reason: '筛选变化 = 重置第 1 页(F7 语义)');
    expect(last.sortKey, TxnSortKey.amount);
    expect(find.text('第 1 页'), findsOneWidget);
    expect(find.text('交易 t0'), findsOneWidget);
  });
}
