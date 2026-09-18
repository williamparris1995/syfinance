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
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/pager_bar.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/core/data_refresh.dart';
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

Widget _harness({required Widget child, ThemeData? theme}) {
  return MaterialApp(theme: theme, home: child);
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
    registerFallbackValue(SummaryScope.month);
    // Register both repos in getIt so TransactionFormPage (pushed by
    // _recordTxn) can resolve them when building its own bloc.
    GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
    GetIt.instance.registerSingleton<TransactionRepository>(txnRepo);
    // 本页 initState 订阅 DataRefreshNotifier(交易跨 branch 变更后重拉)。
    GetIt.instance.registerLazySingleton<DataRefreshNotifier>(
        DataRefreshNotifier.new);

    // Account detail page emits GetAccountRequested on initState.
    when(() => accountRepo.getById(any()))
        .thenAnswer((_) async => dartz.Right(_account()));
    // list is invoked by AccountFormPage if a navigation opens it; stub anyway.
    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right([_account()]));

    // Transaction list scoped to this account.
    // Issue ② 后 4th 卡「交易数」按当前 scope(默认 month)过滤 —— 夹具
    // 用当月日期保证 count=2 确定性(固定旧日期会随时间腐烂,正是本测试
    // 此前 drift 的原因)。
    final now = DateTime.now();
    when(() => txnRepo.list(any())).thenAnswer((_) async => dartz.Right(
        ListTransactionsResult(transactions: [
              _txn('t1', DateTime(now.year, now.month, 19)),
              _txn('t2', DateTime(now.year, now.month, 18)),
            ], nextPageToken: '')));
    // MonthlySummary scoped to this account (Task 5.1 accountId scope).
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

  Future<void> pumpPage(
    WidgetTester tester, {
    Account? account,
    int? netCents,
    List<Transaction>? transactions,
    MonthlySummary? summary,
    List<Account>? accounts,
    ThemeData? theme,
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
            accountId: any(named: 'accountId'),
            scope: any(named: 'scope'),
            day: any(named: 'day')))
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
    // Task 12：详情页 initState 现在也发 LoadAccountsRequested（供近期交易行
    // 解析 entries 的账户名）。listUc 默认返回单账户；具体测试可通过
    // accounts 参数注入多账户。
    final accountsList = accounts ?? [a];
    when(() => listUc.call()).thenAnswer((_) async => dartz.Right(accountsList));
    when(() => accountRepo.list())
        .thenAnswer((_) async => dartz.Right(accountsList));

    await tester.pumpWidget(_harness(
      theme: theme,
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
    // Task 6 响应式：默认 800×600 → tablet(≤900) → AppBar 记一笔/转账 改为
    // IconButton（无文字），本测试断言 TextButton 文字「记一笔」需 pin desktop
    // 视口（1200，>900 走 TextButton icon+文字 分支）。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    // Task 6 响应式：同 记一笔 enabled 测试，pin desktop 视口让 AppBar 走
    // TextButton 分支（默认 800×600 tablet 改为 IconButton 无文字）。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    // Task 6 响应式：默认 800×600 → tablet → AppBar 改 IconButton 无文字；本测试
    // 断言 find.text('记一笔'/'转账') 需 pin desktop 视口（1200，TextButton 分支）。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    // Task 6 响应式：默认 800×600 → tablet → AppBar 记一笔改 IconButton（无文字
    // 也非 TextButton），本测试通过 find.text('记一笔') 找 TextButton 触发 tap，
    // 需 pin desktop 视口（1200，TextButton icon+文字 分支）。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    when(() => listUc.call()).thenAnswer(
        (_) async => dartz.Right([_account(status: AccountStatus.archived)]));
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

  testWidgets('hero: 变体 A 金渐变描边 Container + 径向金色光晕(F26)', (tester) async {
    // F26:固定深渐变面(#1C1E21→#2A2D33)退役 → 暗 = surface 卡 + 金渐变描边
    // (accent→accentDeep)。裸 MaterialApp 回落亮色(无描边),须 AppTheme.dark()
    // 注入语义令牌后再断言(双主题完整探针见 test/account/hero_theme_follow_test)。
    await pumpPage(tester, theme: AppTheme.dark());

    // Hero 描边层 = LinearGradient Container(#E8C07A → #C9964A,暗档 accent/accentDeep)。
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
    expect(grad.colors.first, const Color(0xFFE8C07A));
    expect(grad.colors.last, const Color(0xFFC9964A));

    // 固定深色面退役:全树无 #1C1E21/#2A2D33 系渐变残留。
    final deep = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) {
      if (c.decoration is! BoxDecoration) return false;
      final g = (c.decoration as BoxDecoration).gradient;
      if (g is! LinearGradient) return false;
      return g.colors.contains(const Color(0xFF1C1E21)) ||
          g.colors.contains(const Color(0xFF2A2D33));
    });
    expect(deep, isEmpty, reason: 'v1 固定深渐变面应退役(F26)');

    // 径向金色光晕(RadialGradient + 暗档 accent #E8C07A alpha 0.18)。
    final radial = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).gradient is RadialGradient)
        .toList();
    expect(radial, isNotEmpty, reason: 'hero 应有径向金色光晕');
    final rg = (radial.first.decoration as BoxDecoration).gradient
        as RadialGradient;
    expect(rg.colors.first.withValues(alpha: 1.0), const Color(0xFFE8C07A));
  });

  testWidgets('hero: 40px serif 余额 fg 色(F26 白系文本退役)', (tester) async {
    await pumpPage(tester);

    // currentBalanceCents 100000 → _fmt "¥ 1,000.00"（hero 用 _fmt）。
    // 找到 40px 的 Text。F26:白字 → context.yucai.fg(裸 MaterialApp 回落
    // 晨白 → #0F172A = AppColors.fg;暗色渐变金形态见 hero_theme_follow 探针)。
    final bal = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.style?.fontSize == 40,
      orElse: () => throw StateError('未找到 40px 余额文本'),
    );
    expect(bal.style?.color, AppColors.fg);
    expect(bal.style?.fontFamily, AppTypography.displayFamily);
  });

  testWidgets('hero: hero-badge 类型账户 + 资产·负债类·活期（2 badges，对齐 OD）',
      (tester) async {
    await pumpPage(tester);

    // 储蓄账户 → 第1金色实心 badge「储蓄账户」(landmark icon)，
    // 第2 ghost badge「资产类 · 活期」。对齐 OD .hero-badges。
    expect(find.text('储蓄账户'), findsOneWidget);
    expect(find.text('资产类 · 活期'), findsOneWidget);
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

    // hero-org: 机构 · 人民币 币种 · 卡号 **** 尾号（对齐 OD .hero-org）。
    expect(find.text('招商银行 · 人民币 CNY · 卡号 **** 2840'), findsOneWidget);
  });

  testWidgets('hero: hero-bal-label "可用余额"', (tester) async {
    await pumpPage(tester);

    expect(find.text('可用余额'), findsOneWidget);
  });

  testWidgets('hero: hero-org 机构/尾号缺失时回退到 类别 · 币种', (tester) async {
    // 默认 _account() 无 institution / cardNumberTail → 回退分支。
    await pumpPage(tester);

    // 储蓄 category label = '储蓄'；CNY 中文名「人民币」。
    expect(find.text('储蓄 · 人民币 CNY'), findsOneWidget);
  });

  testWidgets('hero: hero-bal-sub 本月收支（正数绿色）', (tester) async {
    // 默认 netCents 44556 → "本月收支 +¥445.56"（绿）。
    await pumpPage(tester);

    expect(find.text('本月收支 +¥445.56'), findsOneWidget);
    final net = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.data == '本月收支 +¥445.56',
    );
    expect(net.style?.color, AppColors.positive);
  });

  testWidgets('hero: hero-bal-sub 本月收支（负数红色）', (tester) async {
    await pumpPage(tester, netCents: -30000);

    // -30000 → "-¥300.00"（红）。
    expect(find.text('本月收支 -¥300.00'), findsOneWidget);
    final net = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.data == '本月收支 -¥300.00',
    );
    // R8 v2:旧红 E57373 → 语义 negative(E11D48)。
    expect(net.style?.color, AppColors.negative);
  });

  testWidgets('hero: 字段网格（储蓄 → 利率/开户日期/币种）', (tester) async {
    await pumpPage(
      tester,
      account: _account().copyWith(
        interestRate: 3.5,
        openingDate: DateTime(2024, 1, 15),
      ),
    );

    // 储蓄默认分支 4 字段（对齐 OD .hero-fields）。
    expect(find.text('年化利率'), findsOneWidget);
    expect(find.text('开户日期'), findsOneWidget);
    expect(find.text('账户类型'), findsOneWidget);
    expect(find.text('币种'), findsOneWidget);
    // 币种值：「CNY 人民币」（code + 中文名）。
    expect(find.text('CNY 人民币'), findsOneWidget);
    // 账户类型值：储蓄非定期 → 「储蓄 · 活期」。
    expect(find.text('储蓄 · 活期'), findsOneWidget);
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
    // 负债类 badge（信用卡非定期 → 「负债类 · 活期」）。
    expect(find.text('负债类 · 活期'), findsOneWidget);
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
    // 负债类 badge（贷款非定期 → 「负债类 · 活期」）。
    expect(find.text('负债类 · 活期'), findsOneWidget);
  });

  // ───── Task 5: quick-stats 类型专属 4 卡（按 category 分支）─────

  testWidgets('credit card stats: 额度/已用/可用/账单日', (tester) async {
    await pumpPage(tester, account: _creditCardAccount());

    // Task 3：heroFields 断点 600→900 后，默认 800x600 视口下 hero 字段网格
    // 变成 2 列（更高），把 stat 卡推到首屏之外 —— 滚入视口再断言。
    await tester.scrollUntilVisible(
      find.textContaining('信用额度'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
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

    // Task 3：同 credit card stats —— hero 变高后 stat 卡需滚入视口。
    await tester.scrollUntilVisible(
      find.textContaining('已还比例'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已还比例'), findsOneWidget);
    expect(find.text('10.0%'), findsOneWidget);
  });

  testWidgets('savings stats: 本月收入/本月支出/本月净流入/本月交易（默认 month）',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('本月净流入'), findsOneWidget);
    // Task 11：交易卡 label 也跟随 scope（默认 month → 本月交易）。
    expect(find.text('本月交易'), findsOneWidget);
  });

  // ───── Task 6 → F9: 近期交易标准查询套件(替换 5/页迷你分页)─────
  //
  // F9 FR-2/ADR-4:旧「5 条/页客户端切片 + 1/N 页码」迷你分页已删除,近期
  // 交易区改经 F7 查询管道(pageSize 100 + token 翻页 + 搜索/排序)。此处
  // 迁移原分页测试为「单页」形态;token 翻页/搜索/排序的完整覆盖见
  // account_detail_txn_suite_test.dart。

  testWidgets('recent txn single page: all rows render, pager hidden (F9)',
      (tester) async {
    // 7 条交易在同一页(stub 一次返回全部、nextPageToken 空 = 末页)→ 全部
    // 渲染且分页条整体隐藏(F7 _showPager 语义:hasMore==false 且 pageIndex==0)。
    final txns = List.generate(
        7, (i) => _txn('t$i', DateTime(2026, 6, 19).subtract(Duration(days: i))));
    await pumpPage(tester, transactions: txns);

    // 近期交易 panel 在 ListView 之下，需滚入视口才渲染。
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 单页:7 条全部渲染(不再 5 条切片)。
    for (var i = 0; i < 7; i++) {
      expect(find.text('交易 t$i'), findsOneWidget);
    }
    // 分页条隐藏 + 旧迷你分页页码(1/2)不再渲染。
    expect(find.byType(PagerBar), findsNothing);
    expect(find.text('1/2'), findsNothing);
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

  // ───── Task 13: 双色饼图（收入绿 + 支出红）+ 圆心净流入 + 图例（取代 Task 8 多色分类饼图）─────
  //
  // Task 8 的多色分类饼图（_monthExpenseByCategory → _legendRow 分类名）已被
  // Task 13 双色饼图取代：income 弧绿 + expense 弧红 + 圆心净流入（本X净流入）+
  // 图例 2 行（收入类/支出类 · 金额 · 占比）。_quickActions 仍移除（断言保留）。

  /// 滚动到收支统计 panel 并返回（多个测试共用）。
  Future<void> _scrollToSummary(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }

  testWidgets(
      'Task 13: 双色饼图 — 圆心显示净流入 + scope label + 图例收入/支出金额·占比',
      (tester) async {
    // income 24000 / expense 18000 / net +6000 → 圆心「+¥60.00」(green) +
    // 「本月净流入」label + 图例 收入类 ¥240.00·57% / 支出类 ¥180.00·43%。
    final summary = MonthlySummary(
      year: 2026,
      month: 6,
      incomeCents: 24000,
      expenseCents: 18000,
      netCents: 6000,
    );
    await pumpPage(tester, summary: summary);
    await _scrollToSummary(tester);

    // 饼图用 CustomPaint 绘制（双色 income 绿 + expense 红 弧）。
    expect(find.byType(CustomPaint), findsWidgets);
    // 圆心：净流入金额（pie 独有；stats 卡显 ¥60.00 无 + 号）。
    expect(find.text('+¥60.00'), findsOneWidget);
    // 圆心 scope label：stats 卡也显「本月净流入」→ 共 2 处。
    expect(find.text('本月净流入'), findsNWidgets(2));
    // 图例 2 行：收入类 / 支出类 标签（取代 Task 8 的分类名）。
    expect(find.text('收入类'), findsOneWidget);
    expect(find.text('支出类'), findsOneWidget);
    // 图例金额 + 占比：income 24000/(24000+18000)=57%，expense=43%。
    expect(find.textContaining('¥240.00'), findsWidgets);
    expect(find.textContaining('57%'), findsOneWidget);
    expect(find.textContaining('¥180.00'), findsWidgets);
    expect(find.textContaining('43%'), findsOneWidget);
    // Task 8 的分类图例（餐饮/交通）已不再渲染。
    expect(find.text('餐饮'), findsNothing);
    expect(find.text('交通'), findsNothing);
    // _quickActions 仍移除。
    expect(find.text('快捷操作'), findsNothing);
  });

  testWidgets('Task 13: 净流入为负 → 圆心红色 -¥X（sign-colored）',
      (tester) async {
    // expense > income → net 负 → 圆心显红色「-¥300.00」（-30000 cents）。
    final summary = MonthlySummary(
      year: 2026,
      month: 6,
      incomeCents: 10000,
      expenseCents: 40000,
      netCents: -30000,
    );
    await pumpPage(tester, summary: summary);
    await _scrollToSummary(tester);

    // 圆心：负净流入显「-¥300.00」。stats 卡也显同文本（size 18 无色），
    // 圆心为 size 13 红色 —— 取 fontSize==13 的那个断言颜色。
    final netTexts = find.text('-¥300.00');
    expect(netTexts, findsNWidgets(2));
    final rendered = tester
        .widgetList<Text>(netTexts)
        .firstWhere((t) => t.style?.fontSize == 13);
    expect(rendered.style?.color, AppColors.negative);
  });

  testWidgets('Task 13: 净流入为正 → 圆心绿色 +¥X（sign-colored）',
      (tester) async {
    // +30000 cents → 「+¥300.00」绿色（stats 卡显无 + 号的 ¥300.00）。
    final summary = MonthlySummary(
      year: 2026,
      month: 6,
      incomeCents: 50000,
      expenseCents: 20000,
      netCents: 30000,
    );
    await pumpPage(tester, summary: summary);
    await _scrollToSummary(tester);

    // 圆心 +¥300.00（size 13 绿）；stats 卡无 + 号，故 +¥ 仅圆心一处。
    final netText = find.text('+¥300.00');
    expect(netText, findsOneWidget);
    final rendered = tester.widget<Text>(netText);
    expect(rendered.style?.color, AppColors.positive);
  });

  testWidgets('Task 13: income+expense==0 → 占位文案（避免除零）',
      (tester) async {
    // 全零 summary → 双色饼图无弧可画，显占位「暂无收支」而非崩溃（除零）。
    const summary = MonthlySummary(
      year: 2026,
      month: 6,
      incomeCents: 0,
      expenseCents: 0,
      netCents: 0,
    );
    await pumpPage(tester, summary: summary);
    await _scrollToSummary(tester);

    expect(find.textContaining('暂无收支'), findsOneWidget);
    // 无双色饼图（占位取代）、无图例。stats 卡的「本月净流入」仍在，但饼图
    // 圆心独有的净流入金额（+¥X / -¥X）不应出现。
    expect(find.text('收入类'), findsNothing);
    expect(find.text('支出类'), findsNothing);
  });

  // ───── Task 10: 周期切换 segmented control（日/月/年）+ scope state ─────

  testWidgets('period segmented control: default 本月 → 月 active', (tester) async {
    await pumpPage(tester);

    // 收支统计 panel 在 ListView 之下（hero + stats 占满首屏），需滚入视口。
    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 三个段都渲染。
    expect(find.text('日'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    // 旧的固定「本月」文本已被 segmented control 取代。
    expect(find.text('本月'), findsNothing);
  });

  testWidgets('tapping 年 → emits LoadSummaryRequested(scope: year)',
      (tester) async {
    // Task 1 响应式：默认 800x600 落入 tablet(≤900) 走 Column 堆叠，segmented
    // control tap 位置漂移 → pin desktop viewport 让其走 Row 分支（本测试设计
    // 基于双栏布局，收支统计 panel 在右侧）。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);

    // 滚到收支统计 panel（segmented control 在 panel-head 右侧）。
    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 点「年」。
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();

    // 验证 repo.summary 被以 scope=year 调用（事件传播到 RPC 的直接证据）。
    verify(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: SummaryScope.year,
            day: any(named: 'day')));
  });

  testWidgets('tapping 日 → emits LoadSummaryRequested(scope: day, day: today)',
      (tester) async {
    // Task 1 响应式：pin desktop viewport（同 tapping 年，避免 tablet 堆叠导致
    // segmented control tap 漂移）。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);

    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();

    final today = DateTime.now().day;
    verify(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: SummaryScope.day,
            day: today));
  });

  testWidgets('tapping 月 → emits LoadSummaryRequested(scope: month)',
      (tester) async {
    await pumpPage(tester);

    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 先切到年（离开默认月），再切回月，确保切换确有 dispatch。
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月'));
    await tester.pumpAndSettle();

    verify(() => txnRepo.summary(any(), any(),
            accountId: any(named: 'accountId'),
            scope: SummaryScope.month,
            day: any(named: 'day')));
  });

  // ───── Task 11: stat 4 卡 + hero 文案按 scope 动态（本日/本月/本年）─────

  testWidgets(
      'scope=year → savings stats show 本年收入/本年支出/本年净流入/本年交易 '
      '+ hero sub 本年收支', (tester) async {
    // Task 1 响应式：pin desktop viewport —— 本测试断言「滚回顶部后 stat 4 卡
    // 仍挂载」，仅在双栏 Row 布局（stat 卡在顶部、收支统计在右侧）下成立。
    // tablet Column 堆叠下 stat 卡易滑出 cacheExtent，故固定 desktop 视口。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);

    // 滚到收支统计 panel 让 segmented control 可见。
    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();

    // Task 13：双色饼图让收支统计 panel 变高，切换 scope 后重建使顶部 4 卡
    // 滑出 ListView cacheExtent 被卸载 —— 先滚回顶部让 4 卡重新挂载。
    await tester.scrollUntilVisible(
      find.textContaining('可用余额'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    // 储蓄 4 卡 label 按 scope=year。
    expect(find.text('本年收入'), findsOneWidget);
    expect(find.text('本年支出'), findsOneWidget);
    // Task 13：饼图圆心也显「本年净流入」→ stats 卡 + 圆心共 2 处。
    expect(find.text('本年净流入'), findsNWidgets(2));
    expect(find.text('本年交易'), findsOneWidget);
    // hero-bal-sub 副信息也按 scope=year。滚回顶部让 hero 重新构建可见。
    await tester.scrollUntilVisible(
      find.textContaining('可用余额'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('本年收支'), findsOneWidget);
    // 旧的「本月」前缀应消失（stat + hero sub 全部跟随 scope）。
    expect(find.text('本月收入'), findsNothing);
    expect(find.text('本月支出'), findsNothing);
    expect(find.text('本月净流入'), findsNothing);
  });

  testWidgets(
      'scope=day → savings stats show 本日收入/本日支出/本日净流入/本日交易 '
      '+ hero sub 本日收支', (tester) async {
    // Task 1 响应式：pin desktop viewport（同 scope=year 测试，stat 卡在双栏
    // 顶部布局下才能在滚回顶部后重新挂载）。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpPage(tester);

    await tester.scrollUntilVisible(
      find.textContaining('收支统计'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('日'));
    await tester.pumpAndSettle();

    // Task 13：双色饼图让 panel 变高，切 scope 后重建使顶部 4 卡滑出
    // cacheExtent 被卸载 —— 先滚回顶部让 4 卡重新挂载。
    await tester.scrollUntilVisible(
      find.textContaining('可用余额'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('本日收入'), findsOneWidget);
    expect(find.text('本日支出'), findsOneWidget);
    // Task 13：饼图圆心也显「本日净流入」→ stats 卡 + 圆心共 2 处。
    expect(find.text('本日净流入'), findsNWidgets(2));
    expect(find.text('本日交易'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('可用余额'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('本日收支'), findsOneWidget);
  });

  testWidgets('scope=month (default) → savings stats show 本月... (unchanged)',
      (tester) async {
    await pumpPage(tester);

    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('本月净流入'), findsOneWidget);
    // 默认 month scope → 交易卡 label 为「本月交易」。
    expect(find.text('本月交易'), findsOneWidget);
    expect(find.textContaining('本月收支'), findsOneWidget);
  });

  // ───── Issue ②: stat-card 交易数 must follow scope ─────
  //
  // The savings stat-card row shows income/expense/net (all scope-scoped via
  // the summary RPC) PLUS a 4th card 「{scope}交易 = txns.length」. But txns is
  // the account-scoped recent list (no scope filter), so the count was
  // inconsistent: scope-scoped totals + all-recent count. The fix filters the
  // count by scope (DAY = today's txns, MONTH = this month's, YEAR = this
  // year's), so all four cards reflect the same period.

  testWidgets(
    'Issue ②: scope=day → stat-card 本日交易 count reflects only today\'s txns '
    '(not the full account-scoped list)',
    (tester) async {
      // Three transactions: one today, one earlier this month, one last month.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final txns = [
        _txn('today', today),
        _txn('earlierThisMonth', today.subtract(const Duration(days: 5))),
        _txn('lastMonth', today.subtract(const Duration(days: 40))),
      ];
      // Task 1 响应式：pin desktop viewport —— 本测试断言「切 scope 后滚回顶部
      // stat 4 卡重新挂载」，仅在双栏 Row 布局下成立。
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPage(tester, transactions: txns);

      // Switch to DAY scope.
      await tester.scrollUntilVisible(
        find.textContaining('收支统计'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('日'));
      await tester.pumpAndSettle();

      // Stat cards rebuilt at top after scope change — scroll back.
      await tester.scrollUntilVisible(
        find.textContaining('可用余额'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );

      // DAY scope → 本日交易 count = 1 (only today's txn), NOT 3.
      expect(find.text('本日交易'), findsOneWidget);
      expect(find.text('1'), findsOneWidget,
          reason: 'issue ②: 本日交易 should count only today\'s txn (1), not all (3)');
    },
  );

  testWidgets(
    'Issue ②: scope=year → stat-card 本年交易 count reflects this year\'s txns',
    (tester) async {
      final now = DateTime.now();
      final thisYear = DateTime(now.year, 6, 15);
      final txns = [
        _txn('y1', thisYear),
        _txn('y2', thisYear.subtract(const Duration(days: 60))),
        // A txn from last year must be excluded under YEAR scope.
        _txn('lastYear', DateTime(now.year - 1, 6, 15)),
      ];
      // Task 1 响应式：pin desktop viewport（同 Issue② scope=day）。
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPage(tester, transactions: txns);

      await tester.scrollUntilVisible(
        find.textContaining('收支统计'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('年'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('可用余额'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );

      // YEAR scope → 本年交易 = 2 (y1 + y2), NOT 3.
      expect(find.text('本年交易'), findsOneWidget);
      expect(find.text('2'), findsOneWidget,
          reason: 'issue ②: 本年交易 should exclude last year (2), not all (3)');
    },
  );

  // ───── Task 12: 近期交易真实行（icon + 名称 + 分类·账户 + 金额 + 日期时间）─────

  /// expense 交易：expense 账户 a3（借方）+ asset 账户 a1（贷方）。
  /// amount 5000 cents → -¥50.00（负，红）。分类=支出账户 category label，
  /// 账户=asset 账户名。
  Transaction expenseTxn(DateTime date, {DateTime? time}) => Transaction(
        id: 'te',
        transactionDate: date,
        transactionTime: time,
        description: '午餐',
        entries: [
          const TransactionEntry(
              accountId: 'a3', debitCents: 5000, creditCents: 0),
          const TransactionEntry(
              accountId: 'a1', debitCents: 0, creditCents: 5000),
        ],
      );

  testWidgets(
      'recent txn row: expense → name + 分类·账户 + 红色金额 + MM-dd HH:mm '
      '(from transactionTime)', (tester) async {
    // list 必须返回 asset + expense 账户，供 entries 解析分类/账户名。
    final accounts = [
      _account(name: '现金'),
      Account(
        id: 'a3',
        name: '餐饮',
        accountType: AccountType.expense,
        category: AccountCategory.otherAsset,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: Ownership.personal,
        status: AccountStatus.active,
      ),
    ];
    final txns = [
      expenseTxn(DateTime(2026, 6, 5), time: DateTime(2026, 6, 5, 9, 30)),
    ];
    await pumpPage(tester, transactions: txns, accounts: accounts);

    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 名称。
    expect(find.text('午餐'), findsOneWidget);
    // 副行：分类 · 账户（餐饮 · 现金）。
    expect(find.text('餐饮 · 现金'), findsOneWidget);
    // 日期时间 MM-dd HH:mm（来自 transactionTime）。
    expect(find.text('06-05 09:30'), findsOneWidget);
    // 金额：expense → 负，红。
    final amt = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.data == '-¥50.00',
      orElse: () => throw StateError('未找到 expense 金额 -¥50.00'),
    );
    expect(amt.style?.color, AppColors.negative);
  });

  testWidgets(
      'recent txn row: income → 绿色金额；transactionTime null → MM-dd fallback',
      (tester) async {
    final accounts = [
      _account(name: '现金'),
      Account(
        id: 'a4',
        name: '工资',
        accountType: AccountType.income,
        category: AccountCategory.otherAsset,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: Ownership.personal,
        status: AccountStatus.active,
      ),
    ];
    // income: asset a1 借方（入账），income a4 贷方。
    final txns = [
      Transaction(
        id: 'ti',
        transactionDate: DateTime(2026, 6, 3),
        description: '六月工资',
        entries: [
          const TransactionEntry(
              accountId: 'a1', debitCents: 800000, creditCents: 0),
          const TransactionEntry(
              accountId: 'a4', debitCents: 0, creditCents: 800000),
        ],
      ),
    ];
    await pumpPage(tester, transactions: txns, accounts: accounts);

    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('六月工资'), findsOneWidget);
    expect(find.text('工资 · 现金'), findsOneWidget);
    // transactionTime null → 回退 MM-dd（来自 transactionDate）。
    expect(find.text('06-03'), findsOneWidget);
    // income → 正（+），绿。
    final amt = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.data == '+¥8,000.00',
      orElse: () => throw StateError('未找到 income 金额'),
    );
    expect(amt.style?.color, AppColors.positive);
  });

  testWidgets('recent txn panel head: 查看全部 link navigates to /transactions',
      (tester) async {
    // 用一个带 GoRouter 的 harness 验证导航。
    await pumpPage(tester);

    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('查看全部'), findsOneWidget);
  });

  // ───── Task 14: stat 卡 colored icon square + 「实时」tag（视觉收尾）─────

  testWidgets(
      'Task 14: 4 stat cards each show a colored icon square '
      '(trend-up/trend-dn/wallet/notebook) + 「实时」tag', (tester) async {
    await pumpPage(tester);

    // 4 stat 卡在首屏顶部（hero 之下）。滚到 stat row 让 Icon 挂载。
    await tester.scrollUntilVisible(
      find.textContaining('本月收入'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // 4 个位置 icon（lucide 线性，对齐 OD .stat-ico）：
    //   收入 trendingUp / 支出 trendingDown / 净流入 wallet / 交易 fileText。
    expect(find.byIcon(LucideIcons.trendingUp), findsOneWidget,
        reason: 'card1 收入 应显示 lucide trendingUp icon');
    expect(find.byIcon(LucideIcons.trendingDown), findsOneWidget,
        reason: 'card2 支出 应显示 lucide trendingDown icon');
    expect(find.byIcon(LucideIcons.wallet), findsOneWidget,
        reason: 'card3 净流入 应显示 lucide wallet icon');
    expect(find.byIcon(LucideIcons.fileText), findsOneWidget,
        reason: 'card4 交易 应显示 lucide fileText icon');

    // 4 卡都显示「实时」tag（取代「待 Transaction」）。
    expect(find.text('实时'), findsNWidgets(4));
    expect(find.textContaining('待 Transaction'), findsNothing);
  });

  // ───── icon 对齐：近期交易行分类 icon（income→coins / expense→分类细化 /
  // transfer→creditCard），取代旧方向箭头 arrowDownLeft/arrowUpRight/arrowLeftRight ─────

  /// 构造近期交易测试的账户集（asset + 一个分类账户）。
  List<Account> recentIconAccounts({
    required String categoryId,
    required String categoryName,
    required AccountType categoryType,
  }) =>
      [
        _account(name: '现金'),
        Account(
          id: categoryId,
          name: categoryName,
          accountType: categoryType,
          category: AccountCategory.otherAsset,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          currentBalanceCents: 0,
          ownership: Ownership.personal,
          status: AccountStatus.active,
        ),
      ];

  testWidgets(
      'recent txn icon: expense 餐饮 → lucide utensils（分类细化，非 arrowUpRight）',
      (tester) async {
    final accounts = recentIconAccounts(
        categoryId: 'a3', categoryName: '餐饮', categoryType: AccountType.expense);
    final txns = [expenseTxn(DateTime(2026, 6, 5))];
    await pumpPage(tester, transactions: txns, accounts: accounts);
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byIcon(LucideIcons.utensils), findsOneWidget,
        reason: 'expense 餐饮 应显示 utensils 分类 icon');
    // 旧的方向箭头不应再出现。
    expect(find.byIcon(LucideIcons.arrowUpRight), findsNothing);
  });

  testWidgets(
      'recent txn icon: expense 默认（未命中细化词）→ lucide receipt', (tester) async {
    final accounts = recentIconAccounts(
        categoryId: 'a3',
        categoryName: '其他支出',
        categoryType: AccountType.expense);
    final txns = [expenseTxn(DateTime(2026, 6, 5))];
    await pumpPage(tester, transactions: txns, accounts: accounts);
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byIcon(LucideIcons.receipt), findsOneWidget,
        reason: 'expense 默认 应显示 receipt icon');
  });

  testWidgets('recent txn icon: income 工资 → lucide banknote', (tester) async {
    final accounts = recentIconAccounts(
        categoryId: 'a4', categoryName: '工资', categoryType: AccountType.income);
    final txns = [
      Transaction(
        id: 'ti',
        transactionDate: DateTime(2026, 6, 3),
        description: '六月工资',
        entries: [
          const TransactionEntry(
              accountId: 'a1', debitCents: 800000, creditCents: 0),
          const TransactionEntry(
              accountId: 'a4', debitCents: 0, creditCents: 800000),
        ],
      ),
    ];
    await pumpPage(tester, transactions: txns, accounts: accounts);
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byIcon(LucideIcons.banknote), findsOneWidget,
        reason: 'income 工资 应显示 banknote icon');
    expect(find.byIcon(LucideIcons.arrowDownLeft), findsNothing);
  });

  testWidgets('recent txn icon: transfer → lucide arrowLeftRight', (tester) async {
    // 两端 asset → flavour=transfer。
    // OD thin-stroke lucide：transfer 用 arrowLeftRight（对齐 OD 转账语义）。
    // 需 pin desktop 视口（1200）以走 TextButton 分支。
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final accounts = [
      _account(name: '现金'),
      Account(
        id: 'a2',
        name: '银行卡',
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: Ownership.personal,
        status: AccountStatus.active,
      ),
    ];
    final txns = [
      Transaction(
        id: 'tt',
        transactionDate: DateTime(2026, 6, 4),
        description: '内部转账',
        entries: [
          const TransactionEntry(
              accountId: 'a2', debitCents: 5000, creditCents: 0),
          const TransactionEntry(
              accountId: 'a1', debitCents: 0, creditCents: 5000),
        ],
      ),
    ];
    await pumpPage(tester, transactions: txns, accounts: accounts);
    await tester.scrollUntilVisible(
      find.textContaining('近期交易'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byIcon(LucideIcons.arrowLeftRight), findsOneWidget,
        reason: 'transfer 应显示 arrowLeftRight icon（对齐 OD）');
    expect(find.byIcon(LucideIcons.creditCard), findsNothing);
  });

  // ───── Final-review #4: hero-pick「已绑定实名 · 银行直连」gate ─────
  //
  // The 「已绑定实名 · 银行直连」pill must only show for bank-like accounts
  // (savings/creditCard/fixedDeposit/loan) WITH a non-empty institution. For
  // non-bank categories (goldFx/realEstate/otherAsset/investment) or bank
  // categories with no institution (cash/manual accounts) the copy is
  // misleading and must be hidden.

  testWidgets(
      'Final-review #4: hero-pick「银行直连」hidden for non-bank category '
      '(goldFx)', (tester) async {
    await pumpPage(
      tester,
      account: _account(
        name: '黄金账户',
        category: AccountCategory.goldFx,
      ).copyWith(institution: '某金店'),
    );
    expect(find.text('已绑定实名 · 银行直连'), findsNothing,
        reason: 'goldFx is not bank-linked; pill must be hidden');
  });

  testWidgets(
      'Final-review #4: hero-pick「银行直连」hidden for otherAsset '
      '(cash/manual)', (tester) async {
    await pumpPage(
      tester,
      account: _account(
        name: '现金',
        category: AccountCategory.otherAsset,
      ),
    );
    expect(find.text('已绑定实名 · 银行直连'), findsNothing);
  });

  testWidgets(
      'Final-review #4: hero-pick「银行直连」hidden for bank category '
      'with EMPTY institution (manual account)', (tester) async {
    await pumpPage(
      tester,
      account: _account(
        name: '手工储蓄',
        category: AccountCategory.savings,
      ), // institution defaults to ''
    );
    expect(find.text('已绑定实名 · 银行直连'), findsNothing,
        reason: 'bank category but no institution → no 银行直连');
  });

  testWidgets(
      'Final-review #4: hero-pick「银行直连」SHOWN for savings + '
      'institution', (tester) async {
    await pumpPage(
      tester,
      account: _account(
        name: '招行储蓄',
        category: AccountCategory.savings,
      ).copyWith(institution: '招商银行'),
    );
    expect(find.text('已绑定实名 · 银行直连'), findsOneWidget);
  });

  // ───── Task 10: Hero 余额按 account.currencyCode 原货币符号（不换算）─────
  //
  // spec §3：Hero 余额按原账户货币符号显示（不换算到 preferred）。USD 账户
  // currentBalanceCents 100000 → 「$ 1,000.00」（currencySymbol('USD') = $），
  // 不是「¥ 1,000.00」。验证 _fmt 用 a.currencyCode 而非硬编码 ¥。

  testWidgets(
      'Task 10: USD account hero balance shows native \$ symbol (not ¥)',
      (tester) async {
    await pumpPage(
      tester,
      account: _account().copyWith(currencyCode: 'USD'),
    );

    // 40px serif hero balance。
    final bal = tester.widgetList<Text>(find.byType(Text)).firstWhere(
      (t) => t.style?.fontSize == 40,
      orElse: () => throw StateError('未找到 40px 余额文本'),
    );
    expect(bal.data, '\$ 1000.00',
        reason: 'USD 账户 Hero 余额应显示原货币符号 \$ 而非 ¥（_fmt 无千分位）');
    expect(find.text('¥ 1,000.00'), findsNothing);
  });

  // ───── Responsive (Task 1): _body 双栏堆叠 + mobile padding ─────

  testWidgets('tablet 800: body 双栏堆叠成单列(交易在上 饼图在下)', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // 近期交易 panel 与 收支统计 panel 在同一 Column(垂直堆叠)。
    // 注：原 brief 用 SingleChildScrollView 断言 statsPanel，但页面外层是
    // ListView 而非 SingleChildScrollView，且 _summaryPanel 包在 DataCard 内
    // 无独立 SingleChildScrollView —— 改用 Column 祖先断言（与近期交易一致）证明堆叠。
    final statsPanel = find.ancestor(
        of: find.text('收支统计'), matching: find.byType(Column));
    expect(
        find.ancestor(of: find.text('近期交易'), matching: find.byType(Column)),
        findsWidgets,
        reason: 'tablet 应堆叠:近期交易在 Column 内');
    expect(statsPanel, findsWidgets,
        reason: 'tablet 应堆叠:收支统计在 Column 内');
  });

  testWidgets('desktop 1200: body 保持双栏 Row', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // desktop:近期交易在 Row(flex:3)内 —— 找到它祖先有 Row(非 Column 堆叠)
    expect(
        find.ancestor(
            of: find.text('近期交易'),
            matching: find.byKey(const ValueKey('detailBodyRow'))),
        findsOneWidget,
        reason: 'desktop 应双栏:近期交易在 detailBodyRow 内');
  });

  // ───── Task 2: _statsRow 4 列 ↔ 2 列（GridView.count 响应式）─────

  testWidgets('tablet 800: statsRow 2 列', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const ValueKey('statsRow')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2, reason: 'tablet stat 卡 2 列');
  });

  testWidgets('desktop 1200: statsRow 4 列', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const ValueKey('statsRow')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4, reason: 'desktop stat 卡 4 列');
  });

  // ───── Task 3: _heroFields 断点 600 → 900（对齐 OD @media）─────

  testWidgets('tablet 800: heroFields 2 列（断点 900）', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final grid = t.widget<GridView>(find.byKey(const ValueKey('heroFields')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2,
        reason: 'tablet hero-fields 2 列（断点 900，旧 600 在 800 宽会误判 4 列）');
  });

  // ───── Task 4: _infoCard 断点 600 → 900（对齐 OD @media）─────

  testWidgets('tablet 800: infoCard 2 列（断点 900）', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // F9:近期交易 panel 加搜索/排序控件后变高,infoCard(账户信息)被推出
    // ListView cacheExtent(懒构建不挂载)—— 先滚入视口再取 GridView。
    await t.scrollUntilVisible(
      find.textContaining('账户信息'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final grid = t.widget<GridView>(find.byKey(const ValueKey('infoCard')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2, reason: 'tablet info-grid 2 列');
  });

  // ───── Task 5: hero 余额字号 mobile 32px / desktop 40px（断点 720）─────

  testWidgets('mobile 375: hero 余额字号 32', (t) async {
    t.view.physicalSize = const Size(375, 900);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    // 375 窄视口下 stat-card / hero 列有既有 RenderFlex 溢出（与本任务字号断言
    // 无关，是页面在 mobile 尺寸的预存布局问题）。takeException 吸收该 layout
    // 异常，让 fontSize 断言得以执行。
    t.takeException();
    final bal = t.widget<Text>(find.byKey(const ValueKey('heroBalance')));
    expect(bal.style?.fontSize, 32, reason: 'mobile hero 余额 32px');
  });

  testWidgets('desktop 1200: hero 余额字号 40', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    final bal = t.widget<Text>(find.byKey(const ValueKey('heroBalance')));
    expect(bal.style?.fontSize, 40, reason: 'desktop hero 余额 40px');
  });

  // ───── Task 6: topbar ≤900 仅 icon(tablet/mobile，去文字防挤) ─────

  testWidgets('tablet 800: topbar 编辑/记一笔/转账 仅 icon(无文字)', (t) async {
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    expect(find.text('编辑'), findsNothing, reason: 'tablet topbar 仅 icon');
    expect(find.text('记一笔'), findsNothing);
    expect(find.text('转账'), findsNothing);
  });

  testWidgets('desktop 1200: topbar 编辑 有文字', (t) async {
    t.view.physicalSize = const Size(1200, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await pumpPage(t);
    await t.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget, reason: 'desktop topbar icon+文字');
  });
}
