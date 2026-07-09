// Task 6 — widget tests for TradeSheetPage(统一 buy/sell/dividend/split form)。
//
// 验证(对齐 brief):
//   - 4 类型 segmented 切换(字段随类型显隐:buy/sell 有 from-account picker;
//     dividend/split 无)。
//   - from-account picker 加载:asset 非 otherAsset 过滤(应收/收藏品 excluded)。
//   - 跨币种 disabled(security.currency != account.currencyCode)。
//   - 提交触发对应 event(Buy/Sell/RecordDividend/RecordSplit)。
//   - proto 对齐:dividend 无 from-account picker;split 用单一 ratio。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/pages/trade_sheet_page.dart';

class _MockHoldingRepo extends Mock implements HoldingRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}

Account _account({
  required String id,
  required String name,
  AccountType type = AccountType.asset,
  AccountCategory category = AccountCategory.savings,
  String currency = 'CNY',
  int balanceCents = 500000, // ¥5,000.00
}) =>
    Account(
      id: id,
      name: name,
      accountType: type,
      category: category,
      currencyCode: currency,
      initialBalanceCents: balanceCents,
      currentBalanceCents: balanceCents,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Security _security({
  required String id,
  required String symbol,
  String currency = 'CNY',
}) =>
    Security(
      id: id,
      symbol: symbol,
      name: '$symbol Inc.',
      securityType: SecurityType.stock,
      currency: currency,
      currentPriceCents: 10000,
    );

/// harness:注入 HoldingBloc(mock repo)+ GetIt<AccountRepository>(mock)。
/// securities 由 [securities] 参数预置(listSecurities thenAnswer Right);
/// accounts 由 [accounts] 参数预置(account repo.list thenAnswer Right)。
Widget _harness({
  List<Security> securities = const [],
  List<Account> accounts = const [],
  TradeType initialType = TradeType.buy,
  String? initialSecurityId,
  String? initialAccountId,
  String? initialFromAccountId,
}) {
  final holdingRepo = _MockHoldingRepo();
  _stubHoldingRepo(holdingRepo, securities: securities);
  final accountRepo = _MockAccountRepo();
  when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(accounts));
  // GetIt 注册放在 pumpWidget 之前(harness 在 pumpWidget 调用前执行),
  // initState 里 _loadSourceAccounts 才能取到。tearDown 统一 reset。
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  return MaterialApp(
    home: BlocProvider<HoldingBloc>(
      create: (_) => HoldingBloc(holdingRepo),
      child: TradeSheetPage(
        initialType: initialType,
        initialSecurityId: initialSecurityId,
        initialAccountId: initialAccountId,
        initialFromAccountId: initialFromAccountId,
      ),
    ),
  );
}

/// 公用 holding repo stub(securities + 业务事件成功路径)。
void _stubHoldingRepo(_MockHoldingRepo holdingRepo,
    {List<Security> securities = const []}) {
  when(() => holdingRepo.listSecurities(type: any(named: 'type')))
      .thenAnswer((_) async => dartz.Right(securities));
  when(() => holdingRepo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((_) async => const dartz.Right([]));
  when(() => holdingRepo.buy(
        accountId: any(named: 'accountId'),
        securityId: any(named: 'securityId'),
        fromAccountId: any(named: 'fromAccountId'),
        quantity: any(named: 'quantity'),
        priceCents: any(named: 'priceCents'),
        feeCents: any(named: 'feeCents'),
        tradeDate: any(named: 'tradeDate'),
        notes: any(named: 'notes'),
      )).thenAnswer((_) async => dartz.Right(_txStub('buy')));
  when(() => holdingRepo.sell(
        accountId: any(named: 'accountId'),
        securityId: any(named: 'securityId'),
        fromAccountId: any(named: 'fromAccountId'),
        quantity: any(named: 'quantity'),
        priceCents: any(named: 'priceCents'),
        feeCents: any(named: 'feeCents'),
        tradeDate: any(named: 'tradeDate'),
        notes: any(named: 'notes'),
      )).thenAnswer((_) async => dartz.Right(_txStub('sell')));
  when(() => holdingRepo.recordDividend(
        accountId: any(named: 'accountId'),
        securityId: any(named: 'securityId'),
        quantity: any(named: 'quantity'),
        cashPerShareCents: any(named: 'cashPerShareCents'),
        totalAmountCents: any(named: 'totalAmountCents'),
        tradeDate: any(named: 'tradeDate'),
        notes: any(named: 'notes'),
      )).thenAnswer((_) async => dartz.Right(_txStub('dividend')));
  when(() => holdingRepo.recordSplit(
        accountId: any(named: 'accountId'),
        securityId: any(named: 'securityId'),
        ratio: any(named: 'ratio'),
        splitDate: any(named: 'splitDate'),
        notes: any(named: 'notes'),
      )).thenAnswer((_) async => dartz.Right(_txStub('split')));
}

HoldingTransaction _txStub(String type) => HoldingTransaction(
      id: 'tx-$type',
      accountId: 'a1',
      securityId: 's1',
      tradeType: TradeType.buy,
      quantity: 1,
      priceCents: 100,
      amountCents: 100,
      feeCents: 0,
      tradeDate: '2026-06-29',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const LoadSecuritiesRequested());
  });

  // tearDown reset GetIt:每个测试在 harness/inline 里 registerSingleton,
  // 下一个测试前清空避免残留(对齐 debt_form_page_test 模式)。
  tearDown(() {
    GetIt.instance.reset();
  });

  // 表单字段较多(类型 chips + security + account + from-account + qty/price/fee
  // + 日期 + 备注 + 预览 + submit),默认 800×600 视口下 submit / dropdown 越界。
  // 设置高视口确保全部可点击。tests 完成后 reset。
  Future<void> setViewport(WidgetTester t) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  final securities = [
    _security(id: 's1', symbol: 'AAPL', currency: 'CNY'),
    _security(id: 's2', symbol: 'USD-SEC', currency: 'USD'),
  ];
  final accounts = [
    _account(id: 'a1', name: '储蓄账户', currency: 'CNY', balanceCents: 500000),
    _account(id: 'a2', name: '美元账户', currency: 'USD', balanceCents: 100000),
    _account(id: 'a3', name: '投资账户', category: AccountCategory.investment,
        currency: 'CNY'),
    // 应收/收藏品(otherAsset):不应出现在候选。
    _account(id: 'a4', name: '应收账款', category: AccountCategory.otherAsset),
    // 非资产(income):不应出现。
    _account(id: 'a5', name: '工资收入', type: AccountType.income),
  ];

  testWidgets('renders 4 type chips (buy/sell/dividend/split)', (t) async {
    await setViewport(t);
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
    ));
    await t.pumpAndSettle();
    expect(find.text('买入'), findsOneWidget);
    expect(find.text('卖出'), findsOneWidget);
    expect(find.text('分红'), findsOneWidget);
    expect(find.text('拆分'), findsOneWidget);
  });

  testWidgets('switching to dividend hides from-account picker', (t) async {
    await setViewport(t);
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
      initialType: TradeType.buy,
      initialSecurityId: 's1',
      initialAccountId: 'a1',
      initialFromAccountId: 'a1',
    ));
    await t.pumpAndSettle();
    // buy:有资金账户 picker。
    expect(find.byKey(const ValueKey('fromAccountDropdown')), findsOneWidget);
    // 切到 dividend:from-account picker 消失。
    await t.tap(find.text('分红'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('fromAccountDropdown')), findsNothing);
    // dividend 有每股股息字段(split 无、buy/sell 是 price/fee)。
    expect(find.byKey(const ValueKey('perShareField')), findsOneWidget);
  });

  testWidgets('split uses single ratio field (no from-account, no price)',
      (t) async {
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
      initialType: TradeType.split,
      initialSecurityId: 's1',
      initialAccountId: 'a1',
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ratioField')), findsOneWidget);
    expect(find.byKey(const ValueKey('fromAccountDropdown')), findsNothing);
    expect(find.byKey(const ValueKey('priceField')), findsNothing);
    expect(find.byKey(const ValueKey('feeField')), findsNothing);
  });

  testWidgets('from-account picker filters: asset non-otherAsset only',
      (t) async {
    await setViewport(t);
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
      initialType: TradeType.buy,
      initialSecurityId: 's1',
      initialAccountId: 'a1',
      initialFromAccountId: 'a1', // 选中 a1 → 折叠态显示「储蓄账户」证明通过过滤
    ));
    await t.pumpAndSettle();
    // 折叠态:选中 a1(储蓄)在持仓账户 + 资金账户两个 dropdown 都显示其名;
    // 应收 a4 / 收入 a5 因被 _loadSourceAccounts 过滤(asset 非 otherAsset)
    // 永远不会作为候选 —— 整页任何位置都不应出现。
    expect(find.text('储蓄账户'), findsWidgets);
    expect(find.text('应收账款'), findsNothing);
    expect(find.text('工资收入'), findsNothing);
    // 打开 dropdown 验证其他资产类候选(投资账户)可见。
    await t.ensureVisible(find.byKey(const ValueKey('fromAccountDropdown')));
    await t.tap(find.byKey(const ValueKey('fromAccountDropdown')));
    await t.pumpAndSettle();
    expect(find.text('投资账户'), findsWidgets);
  });

  testWidgets('cross-currency account is disabled in from-account picker',
      (t) async {
    await setViewport(t);
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
      initialType: TradeType.buy,
      initialSecurityId: 's2', // USD security
      initialAccountId: 'a1',
    ));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('fromAccountDropdown')));
    await t.pumpAndSettle();
    // CNY 账户(a1 储蓄)跨币种 disabled → 显示 "(跨币种)" 标记。
    expect(find.textContaining('跨币种'), findsWidgets);
  });

  testWidgets('buy submit dispatches BuyRequested (repo.buy called)', (t) async {
    await setViewport(t);
    final holdingRepo = _MockHoldingRepo();
    _stubHoldingRepo(holdingRepo, securities: securities);

    final accountRepo = _MockAccountRepo();
    when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(accounts));
    GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

    await t.pumpWidget(MaterialApp(
      home: BlocProvider<HoldingBloc>(
        create: (_) => HoldingBloc(holdingRepo),
        child: const TradeSheetPage(
          initialType: TradeType.buy,
          initialSecurityId: 's1',
          initialAccountId: 'a1',
          initialFromAccountId: 'a1',
        ),
      ),
    ));
    await t.pumpAndSettle();
    // 输入 qty / price。
    await t.enterText(find.byKey(const ValueKey('qtyField')), '10');
    await t.enterText(find.byKey(const ValueKey('priceField')), '100');
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await t.tap(find.byKey(const ValueKey('submitButton')));
    await t.pumpAndSettle();
    verify(() => holdingRepo.buy(
          accountId: 'a1',
          securityId: 's1',
          fromAccountId: 'a1',
          quantity: 10.0,
          priceCents: 10000,
          feeCents: 0,
          tradeDate: any(named: 'tradeDate'),
          notes: any(named: 'notes'),
        )).called(1);
  });

  testWidgets('split submit dispatches RecordSplitRequested (ratio double)',
      (t) async {
    await setViewport(t);
    final holdingRepo = _MockHoldingRepo();
    _stubHoldingRepo(holdingRepo, securities: securities);

    final accountRepo = _MockAccountRepo();
    when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(accounts));
    GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

    await t.pumpWidget(MaterialApp(
      home: BlocProvider<HoldingBloc>(
        create: (_) => HoldingBloc(holdingRepo),
        child: const TradeSheetPage(
          initialType: TradeType.split,
          initialSecurityId: 's1',
          initialAccountId: 'a1',
        ),
      ),
    ));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('ratioField')), '2');
    await t.tap(find.byKey(const ValueKey('submitButton')));
    await t.pumpAndSettle();
    verify(() => holdingRepo.recordSplit(
          accountId: 'a1',
          securityId: 's1',
          ratio: 2.0,
          splitDate: any(named: 'splitDate'),
          notes: any(named: 'notes'),
        )).called(1);
  });

  testWidgets('dividend submit dispatches RecordDividendRequested (no from acct)',
      (t) async {
    await setViewport(t);
    final holdingRepo = _MockHoldingRepo();
    _stubHoldingRepo(holdingRepo, securities: securities);

    final accountRepo = _MockAccountRepo();
    when(() => accountRepo.list()).thenAnswer((_) async => dartz.Right(accounts));
    GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

    await t.pumpWidget(MaterialApp(
      home: BlocProvider<HoldingBloc>(
        create: (_) => HoldingBloc(holdingRepo),
        child: const TradeSheetPage(
          initialType: TradeType.dividend,
          initialSecurityId: 's1',
          initialAccountId: 'a1',
        ),
      ),
    ));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('qtyField')), '100');
    await t.enterText(find.byKey(const ValueKey('perShareField')), '0.30');
    await t.tap(find.byKey(const ValueKey('submitButton')));
    await t.pumpAndSettle();
    verify(() => holdingRepo.recordDividend(
          accountId: 'a1',
          securityId: 's1',
          quantity: 100.0,
          cashPerShareCents: 30, // ¥0.30
          totalAmountCents: 3000, // ¥30.00
          tradeDate: any(named: 'tradeDate'),
          notes: any(named: 'notes'),
        )).called(1);
  });

  // Task 3(late-align)— 类型色:seg selected 按 TradeType 上色
  // (buy=金/sell=红/dividend=绿/split=蓝灰),split preview 蓝灰 soft 背景。
  // 对齐 OD design-output/holding/styles.css:524-527。
  testWidgets('seg selected chip color: buy=accent (金)', (t) async {
    await setViewport(t);
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
      initialType: TradeType.buy,
    ));
    await t.pumpAndSettle();
    final chip = t.widget<AnimatedContainer>(
      find.ancestor(
          of: find.text('买入'), matching: find.byType(AnimatedContainer)),
    );
    final decor = chip.decoration as BoxDecoration;
    expect(decor.color, AppColors.accent);
  });

  testWidgets('seg selected chip color: sell=negative (红)', (t) async {
    await setViewport(t);
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
      initialType: TradeType.sell,
    ));
    await t.pumpAndSettle();
    final chip = t.widget<AnimatedContainer>(
      find.ancestor(
          of: find.text('卖出'), matching: find.byType(AnimatedContainer)),
    );
    final decor = chip.decoration as BoxDecoration;
    expect(decor.color, AppColors.negative);
  });

  testWidgets('split preview uses 蓝灰 soft background', (t) async {
    await t.pumpWidget(_harness(
      securities: securities,
      accounts: accounts,
      initialType: TradeType.split,
      initialSecurityId: 's1',
      initialAccountId: 'a1',
    ));
    await t.pumpAndSettle();
    final preview =
        t.widget<Container>(find.byKey(const ValueKey('splitPreview')));
    final decor = preview.decoration as BoxDecoration;
    expect(decor.color, const Color(0xFFE7EAEF)); // _kSplitSoft
  });
}
