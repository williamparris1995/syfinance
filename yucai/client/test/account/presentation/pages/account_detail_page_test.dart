// Task 6.1 — TDD widget test for AccountDetailPage 占位 → 真实.
//
// Asserts the placeholder surfaces are replaced by real transaction-module
// wiring:
//   - 「记一笔」/「转账」 AppBar buttons are ENABLED (tappable) and push the
//     TransactionFormPage (no more 🔒 disabled).
//   - 「近期交易」 panel renders the account-scoped transaction list from
//     TransactionBloc.loadByAccount (no more "待 Transaction 模块接入").
//   - 「收支统计」 4 cards render the MonthlySummary(accountId) values
//     (本月收入 / 本月支出 / 净值变动 / 交易数) — no more "—/待交易模块".
//   - AppBar 记一笔 / 转账 activated (Task 8: content 内 _quickActions card
//     已移除，操作集中在 AppBar)。
//
// Both blocs are wired via BlocProvider with a fake repo; no DI / no gRPC.
// Mirrors transactions_page_test.dart harness shape.
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
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

class _MockAccountRepo extends Mock implements AccountRepository {}
class _FakeTxnRepo extends Mock implements TransactionRepository {}

class _MockList extends Mock implements ListAccountsUseCase {}
class _MockCreate extends Mock implements CreateAccountUseCase {}
class _MockDelete extends Mock implements DeleteAccountUseCase {}
class _MockGet extends Mock implements GetAccountUseCase {}
class _MockUpdate extends Mock implements UpdateAccountUseCase {}

Account _account({
  AccountStatus status = AccountStatus.active,
  AccountCategory category = AccountCategory.savings,
  AccountType accountType = AccountType.asset,
  int currentBalanceCents = 100000,
  String name = '现金',
}) =>
    Account(
      id: 'a1',
      name: name,
      accountType: accountType,
      category: category,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: currentBalanceCents,
      ownership: Ownership.personal,
      status: status,
    );

/// 信用卡账户（覆盖 hero-fields creditCard 分支）。
Account _creditCardAccount() => _account(
      name: '招行信用卡',
      category: AccountCategory.creditCard,
      accountType: AccountType.liability,
      currentBalanceCents: -320000,
    ).copyWith(
      creditLimitCents: 500000,
      creditBillingDay: 9,
      creditRepaymentDay: 27,
      creditAnnualFeeCents: 10000,
    );

/// 贷款账户（覆盖 hero-fields loan 分支）。
Account _loanAccount() => _account(
      name: '房贷',
      category: AccountCategory.loan,
      accountType: AccountType.liability,
      currentBalanceCents: -180000000,
    ).copyWith(
      loanOriginalCents: 200000000,
      loanRemainingCents: 180000000,
      loanMonthlyCents: 900000,
      loanNextPaymentDate: DateTime(2026, 7, 1),
    );

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

Widget _harness({required Widget child}) {
  return MaterialApp(home: child);
}

void main() {
  late _MockAccountRepo accountRepo;
  late _FakeTxnRepo txnRepo;

  tearDown(() {
    GetIt.instance.reset();
  });

  setUp(() {
    accountRepo = _MockAccountRepo();
    txnRepo = _FakeTxnRepo();
    registerFallbackValue(ListTransactionsParams());
    registerFallbackValue(
      const UpdateAccountParams(id: 'a1', version: 1),
    );
    // Register both repos in getIt so TransactionFormPage (pushed by
    // _recordTxn) can resolve them when building its own bloc.
    GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
    GetIt.instance.registerSingleton<TransactionRepository>(txnRepo);

    // Account detail page emits GetAccountRequested on initState.
    when(() => accountRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(_account()));
    // list is invoked by AccountFormPage if a navigation opens it; stub anyway.
    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right([_account()]));

    // Transaction list scoped to this account.
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
              _txn('t1', DateTime(2026, 6, 19)),
              _txn('t2', DateTime(2026, 6, 18)),
            ], nextPageToken: '')));
    // MonthlySummary scoped to this account (Task 5.1 accountId scope).
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId')))
        .thenAnswer((_) async => const dartz.Right(MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 123456,
              expenseCents: 78900,
              netCents: 44556,
              dailyAvgCents: 1481,
            )));
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    Account? account,
    int? netCents,
    List<Transaction>? transactions,
    MonthlySummary? summary,
  }) async {
    final a = account ?? _account();
    final net = netCents ?? 44556;
    // 近期交易分页测试（Task 6）：注入自定义交易列表。默认沿用 setUp 的
    // 2 条 stub；若显式传入则覆盖 list 返回。
    if (transactions != null) {
      when(() => txnRepo.list(any())).thenAnswer((_) async =>
          dartz.Right(ListTransactionsResult(
              transactions: transactions, nextPageToken: '')));
    }
    // Override the setUp default stubs for this pump (account + summary).
    // 保留 setUp 默认 income/expense（123456/78900）以不破坏既有「收支统计」
    // 4 卡断言；仅 net 由参数控制（hero 本月收支副信息用 net）。
    // Task 8：传入 summary 时直接用（含 byDay 供饼图聚合）。
    when(() => accountRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(a));
    when(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId')))
        .thenAnswer((_) async => dartz.Right(summary ??
            MonthlySummary(
              year: 2026,
              month: 6,
              incomeCents: 123456,
              expenseCents: 78900,
              netCents: net,
              dailyAvgCents: 1481,
            )));

    final listUc = _MockList();
    final createUc = _MockCreate();
    final deleteUc = _MockDelete();
    final getUc = _MockGet();
    final updateUc = _MockUpdate();
    when(() => getUc.call(any())).thenAnswer((_) async => dartz.Right(a));

    await tester.pumpWidget(_harness(
      child: MultiBlocProvider(
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
              // account-scoped list + summary (Task 6.1 wiring the page does
              // on initState — emitted here so the harness mirrors it).
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

  testWidgets('「记一笔」按钮 enabled (placeholder 🔒 removed)',
      (tester) async {
    await pumpPage(tester);

    // Active account → button label has no 🔒.
    expect(find.text('记一笔🔒'), findsNothing);
    // AppBar 「记一笔」 TextButton is enabled (its onPressed != null).
    final btn = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('记一笔').first,
        matching: find.byType(TextButton),
      ),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('「转账」按钮 enabled (placeholder 🔒 removed)',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('转账🔒'), findsNothing);
    final btn = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('转账').first,
        matching: find.byType(TextButton),
      ),
    );
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('「近期交易」 panel renders the account-scoped transactions',
      (tester) async {
    await pumpPage(tester);

    // Placeholder text replaced.
    expect(find.text('待 Transaction 模块接入'), findsNothing);
    // hero 加了 hero-name + hero-org + hero-bal-label 后整体更高，近期交易
    // panel 被推到默认 800x600 视口之下；ListView 懒构建，需滚入视口才渲染。
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Both stubbed transactions render.
    expect(find.text('交易 t1'), findsOneWidget);
    expect(find.text('交易 t2'), findsOneWidget);
  });

  testWidgets('「收支统计」 4 cards render the account-scoped MonthlySummary',
      (tester) async {
    await pumpPage(tester);

    // Placeholder replaced.
    expect(find.text('待交易模块'), findsNothing);
    // incomeCents 123456 → ¥1,234.56 ; expenseCents 78900 → ¥789.00 ;
    // netCents 44556 → ¥445.56. Card count of transactions = 2.
    expect(find.text('¥1,234.56'), findsOneWidget);
    expect(find.text('¥789.00'), findsOneWidget);
    expect(find.text('¥445.56'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('AppBar 记一笔 / 转账 activated (no 待交易模块 placeholder)',
      (tester) async {
    // Task 8: 原 content 内 _quickActions card 已移除（操作集中在 AppBar）。
    // 此测试改为断言 AppBar 上的记一笔/转账已激活（无 🔒/待交易模块 占位）。
    await pumpPage(tester);

    // AppBar buttons no longer carry the 「（待交易模块）」 placeholder.
    expect(find.textContaining('记一笔（待交易模块）'), findsNothing);
    expect(find.textContaining('转账（待交易模块）'), findsNothing);
    // Activated labels render in AppBar.
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('记一笔'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('转账'),
      ),
      findsOneWidget,
    );
    // Content 内 _quickActions card 标题不应出现。
    expect(find.text('快捷操作'), findsNothing);
  });

  testWidgets('tapping 记一笔 (AppBar) pushes TransactionFormPage',
      (tester) async {
    await pumpPage(tester);

    // Task 8: content 内 _quickActions card 已移除，记一笔只在 AppBar。
    final btn = find.descendant(
      of: find.byType(AppBar),
      matching: find.ancestor(
        of: find.text('记一笔'),
        matching: find.byType(TextButton),
      ),
    );
    expect(btn, findsOneWidget);
    await tester.ensureVisible(btn);
    await tester.tap(btn, warnIfMissed: false);
    await tester.pumpAndSettle();

    // A new route was pushed: the form page is on screen.
    expect(find.byType(TransactionFormPage), findsOneWidget);
  });

  testWidgets('archived account keeps 记一笔 / 转账 disabled (no write ops)',
      (tester) async {
    when(() => txnRepo.list(any())).thenAnswer(
        (_) async => const dartz.Right(ListTransactionsResult(transactions: [])));
    when(() => accountRepo.getById(any())).thenAnswer(
        (_) async => dartz.Right(_account(status: AccountStatus.archived)));

    final getUc = _MockGet();
    when(() => getUc.call(any()))
        .thenAnswer((_) async => dartz.Right(_account(status: AccountStatus.archived)));
    final listUc = _MockList();
    final createUc = _MockCreate();
    final deleteUc = _MockDelete();
    final updateUc = _MockUpdate();

    await tester.pumpWidget(_harness(
      child: MultiBlocProvider(
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

    // Archived → AppBar record/transfer buttons are removed entirely.
    expect(find.text('记一笔'), findsNothing);
    expect(find.text('转账'), findsNothing);
  });

  // ───── Task 2: 账户详情 Hero 升级（深色金色渐变 + badge + 本月净额 + 字段网格）─────

  testWidgets('hero: 深色金色渐变 Container + 径向金色光晕', (tester) async {
    await pumpPage(tester);

    // Hero 是带 LinearGradient 的 Container（#1C1E21 → #2A2D33）。
    final containers = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).gradient is LinearGradient)
        .toList();
    expect(containers, isNotEmpty,
        reason: 'hero 应有 LinearGradient 的 Container');

    final grad =
        (containers.first.decoration as BoxDecoration).gradient as LinearGradient;
    expect(grad.colors.first, const Color(0xFF1C1E21));
    expect(grad.colors.last, const Color(0xFF2A2D33));

    // 径向金色光晕（RadialGradient + accent #B08D57 alpha 0.18）。
    final radial = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).gradient is RadialGradient)
        .toList();
    expect(radial, isNotEmpty, reason: 'hero 应有径向金色光晕');
    final rg = (radial.first.decoration as BoxDecoration).gradient
        as RadialGradient;
    expect(rg.colors.first.withValues(alpha: 1.0), AppColors.accent);
  });

  testWidgets('hero: 40px serif 白字余额', (tester) async {
    await pumpPage(tester);

    // currentBalanceCents 100000 → _fmt "¥ 1,000.00"（hero 用 _fmt）。
    // 找到 40px 的 Text。
    final bal = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.style?.fontSize == 40,
      orElse: () => throw StateError('未找到 40px 余额文本'),
    );
    expect(bal.style?.color, Colors.white);
    expect(bal.style?.fontFamily, AppTypography.displayFamily);
  });

  testWidgets('hero: hero-badge 类型 + 资产·负债类（2 badges，对齐 OD）',
      (tester) async {
    await pumpPage(tester);

    // 储蓄账户 → '储蓄' / '资产类'。OD hero 只保留 2 个 ghost badge
    //（类型 + 资产/负债类）；原「活期/定期」badge 已合并进语义，不再独立显示。
    expect(find.text('储蓄'), findsWidgets);
    expect(find.text('资产类'), findsOneWidget);
    expect(find.text('活期'), findsNothing,
        reason: 'OD 对齐后 hero 只保留 2 badge，活期/定期不再独立显示');
    expect(find.text('定期'), findsNothing);
  });

  // ───── Task 4: hero 加 hero-name + hero-org + hero-bal-label（对齐 OD）─────

  testWidgets('hero: hero-name 显示账户名（28px serif，从 AppBar 移入）',
      (tester) async {
    // 账户名现在渲染在 hero-name，不再在 AppBar title。
    await pumpPage(tester, account: _account(name: '招商银行储蓄卡'));

    expect(find.text('招商银行储蓄卡'), findsOneWidget);
    // AppBar title 保持「账户详情」（决策：不改面包屑）。
    expect(find.text('账户详情'), findsOneWidget);
  });

  testWidgets('hero: hero-org 机构 · 币种 · 尾号', (tester) async {
    await pumpPage(
      tester,
      account: _account(name: '招商银行储蓄卡').copyWith(
        institution: '招商银行',
        cardNumberTail: '2840',
      ),
    );

    // hero-org: 机构 · 币种 · 尾号（对齐 OD .hero-org）。
    expect(find.text('招商银行 · CNY · 尾号 2840'), findsOneWidget);
  });

  testWidgets('hero: hero-bal-label "可用余额"', (tester) async {
    await pumpPage(tester);

    expect(find.text('可用余额'), findsOneWidget);
  });

  testWidgets('hero: hero-org 机构/尾号缺失时回退到 类别 · 币种', (tester) async {
    // 默认 _account() 无 institution / cardNumberTail → 回退分支。
    await pumpPage(tester);

    // 储蓄 category label = '储蓄'。
    expect(find.text('储蓄 · CNY'), findsOneWidget);
  });

  testWidgets('hero: hero-bal-sub 本月收支（正数绿色）', (tester) async {
    // 默认 netCents 44556 → "本月收支 +¥445.56"（绿）。
    await pumpPage(tester);

    expect(find.text('本月收支 +¥445.56'), findsOneWidget);
    final net = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.data == '本月收支 +¥445.56',
    );
    expect(net.style?.color, const Color(0xFF6FCF9A));
  });

  testWidgets('hero: hero-bal-sub 本月收支（负数红色）', (tester) async {
    await pumpPage(tester, netCents: -30000);

    // -30000 → "-¥300.00"（红）。
    expect(find.text('本月收支 -¥300.00'), findsOneWidget);
    final net = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.data == '本月收支 -¥300.00',
    );
    expect(net.style?.color, const Color(0xFFE57373));
  });

  testWidgets('hero: 字段网格（储蓄 → 利率/开户日期/币种）', (tester) async {
    await pumpPage(
      tester,
      account: _account().copyWith(
        interestRate: 3.5,
        openingDate: DateTime(2024, 1, 15),
      ),
    );

    // 储蓄默认分支字段。
    expect(find.text('利率'), findsOneWidget);
    expect(find.text('开户日期'), findsOneWidget);
    expect(find.text('币种'), findsOneWidget);
    // _specificChips 的扁平 Chip 已被结构化字段网格取代。
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('hero: 字段网格（信用卡 → 额度/账单日/还款日/年费）',
      (tester) async {
    await pumpPage(tester, account: _creditCardAccount());

    // Task 5 quick-stats 卡也渲染「账单日」（共 2 处），故 hero 字段断言
    // 收紧为 hero-scoped find.descendant，仍证明 hero 字段网格渲染该 label。
    final hero = find.byKey(const ValueKey('heroFields'));
    expect(find.text('额度'), findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('账单日')),
        findsOneWidget);
    expect(find.text('还款日'), findsOneWidget);
    expect(find.text('年费'), findsOneWidget);
    // 负债类 badge。
    expect(find.text('负债类'), findsOneWidget);
  });

  testWidgets('hero: 字段网格（贷款 → 原始本金/剩余本金/月供/下次还款）',
      (tester) async {
    await pumpPage(tester, account: _loanAccount());

    // Task 5 quick-stats 卡也渲染 原始本金/剩余本金/月供（共 2 处），故 hero
    // 字段断言收紧为 hero-scoped find.descendant。
    final hero = find.byKey(const ValueKey('heroFields'));
    expect(find.descendant(of: hero, matching: find.text('原始本金')),
        findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('剩余本金')),
        findsOneWidget);
    expect(find.descendant(of: hero, matching: find.text('月供')),
        findsOneWidget);
    expect(find.text('下次还款'), findsOneWidget);
    expect(find.text('负债类'), findsOneWidget);
  });

  // ───── Task 5: quick-stats 类型专属 4 卡（按 category 分支）─────

  testWidgets('credit card stats: 额度/已用/可用/账单日', (tester) async {
    await pumpPage(tester, account: _creditCardAccount());

    // hero field grid (Task 4) also renders 「账单日」 for creditCard, so
    // assert the stats-card-exclusive labels strictly and 账单日 loosely.
    expect(find.text('信用额度'), findsOneWidget);
    expect(find.text('已用额度'), findsOneWidget);
    expect(find.text('可用额度'), findsOneWidget);
    expect(find.text('账单日'), findsWidgets);
  });

  testWidgets('loan stats: 原始/剩余/月供/已还比例', (tester) async {
    // currentBalance -180w, original 200w, remaining 180w → 已还 (200w-180w)/200w = 10.0%.
    await pumpPage(tester, account: _loanAccount());

    expect(find.text('已还比例'), findsOneWidget);
    expect(find.text('10.0%'), findsOneWidget);
  });

  testWidgets('savings stats: 本月收入/本月支出/本月净流入/交易数（默认）',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('本月净流入'), findsOneWidget);
    expect(find.text('交易数'), findsOneWidget);
  });

  // ───── Task 6: 详情近期交易页码分页（5/页）─────

  testWidgets('recent txn pagination: page 2 shows remaining + page indicator',
      (tester) async {
    // 造 7 条交易 → ceil(7/5)=2 页。第 1 页显示 0-4，第 2 页显示 5-6。
    final txns = List.generate(
        7, (i) => _txn('t$i', DateTime(2026, 6, 19).subtract(Duration(days: i))));
    await pumpPage(tester, transactions: txns);

    // 近期交易 panel 在 ListView 之下，需滚入视口才渲染。
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 第 1 页：显示 t0..t4（描述格式「交易 t0」…）。
    expect(find.text('交易 t0'), findsOneWidget);
    expect(find.text('交易 t4'), findsOneWidget);
    // 页码指示：2/2（page+1=1 但总页数 ceil(7/5)=2，当前 page=0 → "1/2"）。
    expect(find.text('1/2'), findsOneWidget);

    // 点「下一页」→ 第 2 页（page=1），显示 t5/t6。
    // find.byTooltip 命中的是 RawTooltip，取其 IconButton 祖先再触发 onPressed。
    final nextIconBtn = tester.widget<IconButton>(find.ancestor(
      of: find.byTooltip('下一页'),
      matching: find.byType(IconButton),
    ));
    expect(nextIconBtn.onPressed, isNotNull,
        reason: '下一页 在 page=0 / pageCount=2 时应可点击');
    nextIconBtn.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('交易 t5'), findsOneWidget);
    expect(find.text('交易 t6'), findsOneWidget);
    // 第 1 页的 t0 不应再显示。
    expect(find.text('交易 t0'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);
  });

  // ───── Task 7: 详情 info-card 独立字段表（对齐 OD .info-card / .info-grid）─────

  testWidgets('info-card shows institution + card tail + initial balance',
      (tester) async {
    final account = Account(
      id: 'a1',
      name: '招行储蓄',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 120000000,
      currentBalanceCents: 128540000,
      ownership: Ownership.personal,
      status: AccountStatus.active,
      institution: '招商银行',
      cardNumberTail: '2840',
      interestRate: 1.9,
      openingDate: DateTime(2022, 3, 15),
    );
    await pumpPage(tester, account: account);

    // info-card 在 ListView 之下，需滚入视口才渲染。
    await tester.scrollUntilVisible(
      find.textContaining('账户信息'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('账户信息'), findsOneWidget);
    expect(find.text('开户机构'), findsOneWidget);
    expect(find.text('招商银行'), findsOneWidget);
    expect(find.text('卡号尾号'), findsOneWidget);
    expect(find.text('尾号 2840'), findsOneWidget);
  });

  // ───── Task 8: 收支统计饼图（_summaryPanel 重写为 pie + legend）+ 移除 content 内 _quickActions ─────

  testWidgets('summary panel renders pie + legend; no quick actions card',
      (tester) async {
    // summary.byDay 含 expense 分类（餐饮/交通）→ 月度聚合后饼图应渲染 + legend
    // 显示分类名。_quickActions 已移除（操作集中在 AppBar）。
    final summary = MonthlySummary(
      year: 2026,
      month: 6,
      expenseCents: 18000,
      incomeCents: 24000,
      netCents: 6000,
      byDay: [
        DailySummary(
          date: '2026-06-01',
          totalIncomeCents: 0,
          byCategory: [
            CategoryTotal(
                categoryId: 'food',
                name: '餐饮',
                accountType: 'expense',
                amountCents: 12000),
            CategoryTotal(
                categoryId: 'tran',
                name: '交通',
                accountType: 'expense',
                amountCents: 6000),
          ],
        ),
      ],
    );
    // 通过 pumpPage 的 summary 参数注入（避免 helper 内部覆盖 stub）。
    await pumpPage(tester, summary: summary);

    // 收支统计 panel 在 ListView 之下（hero + stats 占满首屏），需滚入视口。
    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 饼图用 CustomPaint 绘制（findsWidgets ≥1 即可）。
    expect(find.byType(CustomPaint), findsWidgets);
    // legend 显示分类名。
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
    // _quickActions 已移除，「快捷操作」标题不应出现。
    expect(find.text('快捷操作'), findsNothing);
  });
}
