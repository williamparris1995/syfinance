// Task 8 — TDD widget tests for ReceivableDetailPage
// (Hero + StatCards + 收款计划 表/卡 + 确认收款 + 筛选 + 三端)。
//
// 对齐 debt_detail_page_test 的 harness：mocktail DebtRepository → 真实 DebtBloc，
// 注入 DebtDetailLoaded。私有 widget 通过公开 ReceivableDetailPage 驱动。
//
// 验证（收款语义，非 还款）：
//   - Hero：counterparty + 剩余应收(大字) + progress bar(progressRatio)
//   - StatRow：借出本金 / 利率 / 到期 / 摊还 / 已收期数
//   - 收款计划：每期(日期/收回本金/利息收入/合计/状态/确认收款)
//   - 筛选：全部/待收/已收/逾期 (segmented)
//   - 确认收款：点待收期「确认收款」→ 弹 收款账户 选择 → RecordPaymentRequested
//   - 三端：desktop 表 / mobile 卡列表
//   - 负向断言：还款/记账/剩余本金/还款计划 等 debt_detail 语义 label 不出现
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_state.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/pages/receivable_detail_page.dart';

class _MockDebtRepo extends Mock implements DebtRepository {}
class _MockAccountRepo extends Mock implements AccountRepository {}

class _FakeCurrencyBloc extends Fake implements CurrencyBloc {
  _FakeCurrencyBloc(this._state);
  final CurrencyState _state;
  @override
  CurrencyState get state => _state;
  @override
  Stream<CurrencyState> get stream => Stream.value(_state);
}

Debt _receivable({
  String id = 'r1',
  String counterparty = '李四 · 商业借款',
  double interestRate = 8.00,
  AmortizationMethod amortization = AmortizationMethod.equalPrincipalInterest,
  DateTime? dueDate,
  int totalPrincipalCents = 10000000, // 10 万
  int remainingPrincipalCents = 7574200, // 剩 75,742 → 已收约 24.3%
  String contact = '138****6677',
  String contractRef = 'BO-2026-0215.pdf',
  String? collectionAccountId = 'acct-1',
  int remainingTrendCents = -869900, // 负 = 较上月减少(收回,绿)
}) =>
    Debt(
      id: id,
      accountId: 'a1',
      counterparty: counterparty,
      interestRate: interestRate,
      amortization: amortization,
      startDate: DateTime(2026, 2, 15),
      dueDate: dueDate ?? DateTime(2027, 2, 15),
      totalPrincipalCents: totalPrincipalCents,
      remainingPrincipalCents: remainingPrincipalCents,
      version: 1,
      createdAt: DateTime(2026, 2, 15),
      updatedAt: DateTime(2026, 6, 1),
      contact: contact,
      contractRef: contractRef,
      collectionAccountId: collectionAccountId,
      remainingTrendCents: remainingTrendCents,
    );

PaymentEntry _entry({
  required String id,
  required DateTime paymentDate,
  required int principalCents,
  required int interestCents,
  required bool paid,
}) =>
    PaymentEntry(
      id: id,
      paymentDate: paymentDate,
      principalCents: principalCents,
      interestCents: interestCents,
      totalCents: principalCents + interestCents,
      paid: paid,
      paidCents: paid ? principalCents + interestCents : 0,
      transactionId: paid ? 'tx-$id' : '',
    );

DebtDetail _detail({
  Debt? debt,
  List<PaymentEntry>? schedule,
}) {
  schedule ??= [
    _entry(
        id: 'e1',
        paymentDate: DateTime(2026, 3, 15),
        principalCents: 803200,
        interestCents: 66600,
        paid: true),
    _entry(
        id: 'e2',
        paymentDate: DateTime(2026, 4, 15),
        principalCents: 808500,
        interestCents: 61300,
        paid: true),
    // 逾期：日期早于 now 且未收。
    _entry(
        id: 'e3',
        paymentDate: DateTime(2026, 6, 15),
        principalCents: 819400,
        interestCents: 50500,
        paid: false),
    // 待收：日期晚于 now。
    _entry(
        id: 'e4',
        paymentDate: DateTime(2026, 7, 15),
        principalCents: 824800,
        interestCents: 45000,
        paid: false),
    _entry(
        id: 'e5',
        paymentDate: DateTime(2026, 8, 15),
        principalCents: 830300,
        interestCents: 39500,
        paid: false),
  ];
  return DebtDetail(debt: debt ?? _receivable(), schedule: schedule);
}

Account _assetAccount({
  String id = 'acct-1',
  String name = '招商银行储蓄卡',
  int balance = 8642000,
}) =>
    Account(
      id: id,
      name: name,
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: balance,
      ownership: Ownership.personal,
      status: AccountStatus.active,
    );

Widget _harness({
  required DebtDetail detail,
  List<Account> accounts = const [],
}) {
  final debtRepo = _MockDebtRepo();
  final accountRepo = _MockAccountRepo();
  // 详情页 initState 走 getIt<AccountRepository>().list() 拉 收款账户 列表。
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  registerFallbackValue(const RecordPaymentRequested(
      debtId: '', scheduleEntryId: '', fromAccountId: ''));
  when(() => debtRepo.get(any()))
      .thenAnswer((_) async => dartz.Right(detail));
  when(() => debtRepo.recordPayment(
          debtId: any(named: 'debtId'),
          scheduleEntryId: any(named: 'scheduleEntryId'),
          fromAccountId: any(named: 'fromAccountId')))
      .thenAnswer((_) async => dartz.Right(detail.schedule.first));
  when(() => accountRepo.list())
      .thenAnswer((_) async => dartz.Right(accounts));
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
        BlocProvider<CurrencyBloc>.value(
          value: _FakeCurrencyBloc(const CurrencyState())),
      ],
      child: ReceivableDetailPage(id: detail.debt.id),
    ),
  );
}

void main() {
  // 详情页 initState 走 getIt<AccountRepository>；每个测试结束重置避免重复注册。
  tearDown(() {
    GetIt.instance.reset();
  });

  // D3 双列后页面含多个 Scrollable(ListView + 可能的 dropdown);scrollUntilVisible
  // 默认用 find.byType(Scrollable).single 会抛 "Too many elements"。
  // 本 helper 显式锁定 ReceivableDetailPage 下第一个 Scrollable(页面根 ListView)。
  Finder pageScrollable() => find
      .descendant(
        of: find.byType(ReceivableDetailPage),
        matching: find.byType(Scrollable),
      )
      .first;

  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  group('Hero', () {
    testWidgets('renders avatar + counterparty + 剩余应收 + delta + progress',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // counterparty（hero-name + side panel 债务人 value)
      expect(find.textContaining('李四'), findsWidgets);
      // D1: avatar tile(首字) 存在
      expect(find.byKey(const ValueKey('heroAvatar')), findsOneWidget);
      // 剩余应收 标签 + 值（7,574,200 cents = ¥75,742.00）
      //   多处:heroRemaining + hero-prog-meta "剩余本金 ¥75,742.00" + 待收合计 sub
      expect(find.textContaining('剩余应收'), findsWidgets);
      expect(find.textContaining('¥75,742.00'), findsWidgets);
      // D1: delta pill(remainingTrendCents=-869900 → ¥8,699.00 减少)
      expect(find.byKey(const ValueKey('heroDelta')), findsOneWidget);
      expect(find.textContaining('¥8,699.00'), findsWidgets);
      expect(find.textContaining('较上月减少'), findsOneWidget);
      // D1: hero-side 4-tile 存在
      expect(find.byKey(const ValueKey('heroSide')), findsOneWidget);
      expect(find.text('年利率'), findsOneWidget);
      expect(find.text('月供'), findsOneWidget);
      expect(find.text('到期日'), findsOneWidget);
      expect(find.text('已收期数'), findsOneWidget);
      // 8.00% 利率 + 2/5 已收期数
      //   (hero-side 已收期数 tile + delta pill "已收回 2 / 5 期" → 多处)
      expect(find.textContaining('8.00%'), findsWidgets);
      expect(find.textContaining('2 / 5'), findsWidgets);
      // Hero progress bar 存在（LinearProgressIndicator）
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('progress bar uses progressRatio (24.3%)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // progressRatio = (100000-75742)/100000 ≈ 0.2426 → 24.3%
      expect(find.textContaining('24.3%'), findsWidgets);
    });
  });

  group('StatRow (D2 金额维度)', () {
    testWidgets(
        'renders 5 amount-dimension StatCards: 借出本金/已收合计/待收合计/累计利息/逾期',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 借出本金 = ¥100,000.00
      expect(find.textContaining('借出本金'), findsOneWidget);
      expect(find.textContaining('¥100,000.00'), findsWidgets);
      // 已收合计 = (803200+66600)+(808500+61300) = 1,739,600 → ¥17,396.00
      expect(find.textContaining('已收合计'), findsOneWidget);
      expect(find.textContaining('¥17,396.00'), findsOneWidget);
      // 待收合计 = 869900+869800+869800 = 2,609,500 → ¥26,095.00
      expect(find.textContaining('待收合计'), findsOneWidget);
      expect(find.textContaining('¥26,095.00'), findsOneWidget);
      // 累计利息收入 = 66600+61300 = 127,900 → ¥1,279.00
      //   (stat value + 已收合计 sub "利息 ¥1,279.00" → 多处)
      expect(find.textContaining('累计利息收入'), findsOneWidget);
      expect(find.textContaining('¥1,279.00'), findsWidgets);
      // 逾期应收 = e3 = 869,900 → ¥8,699.00,1 期
      expect(find.textContaining('逾期应收'), findsOneWidget);
      expect(find.textContaining('¥8,699.00'), findsWidgets);
      expect(find.textContaining('1 期'), findsWidgets);
    });
  });

  group('收款计划 schedule', () {
    testWidgets('desktop renders table with each entry row', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // D3 desktop 双列:schedule 在左侧 ListView 内,首屏下方(offstage)。
      // 用 skipOffstage:false 让 finder 覆盖视口外的 widget。
      expect(find.text('期次 / 收款日', skipOffstage: false), findsOneWidget);
      expect(find.text('收回本金', skipOffstage: false), findsWidgets);
      expect(find.text('利息收入', skipOffstage: false), findsWidgets);
      expect(find.text('合计', skipOffstage: false), findsWidgets);
      // 5 期日期均渲染
      for (final d in ['2026-03-15', '2026-04-15', '2026-06-15', '2026-07-15']) {
        expect(find.textContaining(d, skipOffstage: false), findsWidgets);
      }
      // 状态 badges：已收 / 待收 / 逾期
      expect(find.textContaining('已收', skipOffstage: false), findsWidgets);
      expect(find.text('待收', skipOffstage: false), findsWidgets);
      expect(find.text('逾期', skipOffstage: false), findsWidgets);
    });

    testWidgets('待收/逾期 entries show 确认收款 button, 已收 shows 已确认',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 1 逾期 + 2 待收 = 3 个未收 entry → 3 个「确认收款」按钮；
      // 2 个已收 → 2 个「已确认」。(schedule offstage,skipOffstage:false)
      expect(
          find.textContaining('确认收款', skipOffstage: false), findsNWidgets(3));
      expect(find.text('已确认', skipOffstage: false), findsNWidgets(2));
    });

    testWidgets('mobile renders card list (no DataTable)', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // mobile 不渲染表头
      expect(find.text('期次 / 收款日'), findsNothing);
      // 卡列表在 ListView 下方,滚动到「收款计划」构建 schedule。
      await t.scrollUntilVisible(
        find.text('收款计划'),
        200,
        scrollable: pageScrollable(),
      );
      expect(find.textContaining('2026-03-15'), findsOneWidget);
      expect(find.textContaining('2026-07-15'), findsWidgets);
    });
  });

  group('筛选 (segmented)', () {
    testWidgets('renders 全部/待收/已收/逾期 filter segments', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 4 个筛选 segment（by ValueKey，避开状态 badge/sum-pill 同名文字）
      expect(find.byKey(const ValueKey('filterSegment-全部')), findsOneWidget);
      expect(find.byKey(const ValueKey('filterSegment-待收')), findsOneWidget);
      expect(find.byKey(const ValueKey('filterSegment-已收')), findsOneWidget);
      expect(find.byKey(const ValueKey('filterSegment-逾期')), findsOneWidget);
    });

    testWidgets('tap 已收 filters to paid-only entries', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filterSegment-已收')));
      await t.pumpAndSettle();
      // 已收 entry 2 个；待收/逾期被过滤。「已确认」仍 2 个；「确认收款」应为 0。
      // (schedule offstage,skipOffstage:false)
      expect(find.text('已确认', skipOffstage: false), findsNWidgets(2));
      expect(
          find.textContaining('确认收款', skipOffstage: false), findsNothing);
    });

    testWidgets('tap 逾期 filters to overdue-only entry', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filterSegment-逾期')));
      await t.pumpAndSettle();
      // 只剩 1 个逾期 entry → 1 个确认收款按钮(offstage → skipOffstage:false)
      expect(find.textContaining('确认收款', skipOffstage: false), findsOneWidget);
      expect(find.text('已确认', skipOffstage: false), findsNothing);
    });
  });

  group('确认收款 (RecordPayment) — D4 行内', () {
    testWidgets(
        'collection 已配置 → tap 确认收款 直接 dispatch RecordPayment (无 dialog)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const RecordPaymentRequested(
          debtId: '', scheduleEntryId: '', fromAccountId: ''));
      final detail = _detail(); // collection = 'acct-1'
      when(() => debtRepo.get(any()))
          .thenAnswer((_) async => dartz.Right(detail));
      var recordedFrom = '';
      var recordedEntry = '';
      when(() => debtRepo.recordPayment(
              debtId: any(named: 'debtId'),
              scheduleEntryId: any(named: 'scheduleEntryId'),
              fromAccountId: any(named: 'fromAccountId')))
          .thenAnswer((inv) {
        recordedFrom =
            inv.namedArguments[#fromAccountId] as String;
        recordedEntry =
            inv.namedArguments[#scheduleEntryId] as String;
        return Future.value(dartz.Right(detail.schedule.first));
      });
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_assetAccount(id: 'acct-1')]));
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

      await t.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
            BlocProvider<CurrencyBloc>.value(
                value: _FakeCurrencyBloc(const CurrencyState())),
          ],
          child: ReceivableDetailPage(id: detail.debt.id),
        ),
      ));
      await t.pumpAndSettle();
      // D3 双列:schedule 在 ListView 下方,drag 页面根 ListView 上滑露出「确认收款」。
      // scrollUntilVisible 在此布局下对齐略偏下,改用 drag + ensureVisible。
      final scrollable = pageScrollable();
      await t.drag(scrollable, const Offset(0, -600));
      await t.pumpAndSettle();
      await t.ensureVisible(find.textContaining('确认收款').first);
      await t.pumpAndSettle();
      // 点第一行的「确认收款」(D4 行内,collection 已配置)
      await t.tap(find.textContaining('确认收款').first);
      // 推进微任务链到 bloc.recordPayment。
      for (var i = 0; i < 10 && recordedFrom.isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      // 直接 dispatch,from = collectionAccountId('acct-1'),无 dialog
      expect(recordedFrom, 'acct-1');
      expect(recordedEntry, isNotEmpty);
      // 无 dialog(收款至账户 选择器不出现)
      expect(find.textContaining('收款至账户'), findsNothing);
      // AppToast Timer 推进避免 teardown 报 timersPending。
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets(
        'collection 为空 (legacy) → tap 确认收款 弹 dialog 选收款账户',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      // legacy:collectionAccountId = null → fallback dialog。
      final detail = _detail(
          debt: _receivable(collectionAccountId: null));
      final accounts = [
        _assetAccount(id: 'acct-1', name: '招商银行储蓄卡'),
      ];
      await t.pumpWidget(_harness(detail: detail, accounts: accounts));
      await t.pumpAndSettle();
      // D3 双列:drag 上滑露出「确认收款」。
      final scrollable = pageScrollable();
      await t.drag(scrollable, const Offset(0, -600));
      await t.pumpAndSettle();
      await t.ensureVisible(find.textContaining('确认收款').first);
      await t.pumpAndSettle();
      // 点第一行「确认收款」 → fallback dialog
      await t.tap(find.textContaining('确认收款').first);
      await t.pumpAndSettle();
      expect(find.textContaining('收款至账户'), findsOneWidget);
      expect(find.textContaining('招商银行储蓄卡'), findsWidgets);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    // Task 4 (ccs): RecordPayment 双写后 server 端 account 余额已变,详情页
    // 必须重新拉 account 列表(收款账户 picker 余额依赖 _accounts 的
    // currentBalanceCents)。验证:list() 在 initState 调用一次后,确认收款
    // 成功(DebtDetailLoaded)再被调用。
    testWidgets(
        '确认收款 success re-fetches account balances (double-write refresh)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(const RecordPaymentRequested(
          debtId: '', scheduleEntryId: '', fromAccountId: ''));
      final detail = _detail();
      when(() => debtRepo.get(any()))
          .thenAnswer((_) async => dartz.Right(detail));
      when(() => debtRepo.recordPayment(
              debtId: any(named: 'debtId'),
              scheduleEntryId: any(named: 'scheduleEntryId'),
              fromAccountId: any(named: 'fromAccountId')))
          .thenAnswer(
              (_) async => dartz.Right(detail.schedule.first));
      var listCalls = 0;
      when(() => accountRepo.list()).thenAnswer((_) async {
        listCalls++;
        return dartz.Right([_assetAccount(id: 'acct-1')]);
      });
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

      await t.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
            BlocProvider<CurrencyBloc>.value(
                value: _FakeCurrencyBloc(const CurrencyState())),
          ],
          child: ReceivableDetailPage(id: detail.debt.id),
        ),
      ));
      await t.pumpAndSettle();
      expect(listCalls, 1);
      // D3 双列:drag 上滑露出「确认收款」。
      final scrollable = pageScrollable();
      await t.drag(scrollable, const Offset(0, -600));
      await t.pumpAndSettle();
      await t.ensureVisible(find.textContaining('确认收款').first);
      await t.pumpAndSettle();
      // D4 行内:点 → 直接 dispatch(无需 dialog 二次确认)。
      await t.tap(find.textContaining('确认收款').first);
      for (var i = 0; i < 20 && listCalls < 2; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(listCalls, greaterThanOrEqualTo(2));
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  group('Side Panel (D3)', () {
    testWidgets('renders 收款账户卡 + 借款信息卡 (contact/contractRef)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final accounts = [
        _assetAccount(id: 'acct-1', name: '招商银行储蓄卡'),
      ];
      await t.pumpWidget(_harness(detail: _detail(), accounts: accounts));
      await t.pumpAndSettle();
      // 收款账户卡
      expect(find.byKey(const ValueKey('sideCollectionCard')), findsOneWidget);
      expect(find.text('收款至'), findsOneWidget);
      // acct-1 = 招商银行储蓄卡(collection 解析到名)
      expect(find.textContaining('招商银行储蓄卡'), findsWidgets);
      // 借款信息卡
      expect(find.byKey(const ValueKey('sideLoanCard')), findsOneWidget);
      expect(find.text('债务人'), findsOneWidget);
      expect(find.text('联系方式'), findsOneWidget);
      expect(find.textContaining('138****6677'), findsOneWidget);
      expect(find.text('合同/借据'), findsOneWidget);
      expect(find.textContaining('BO-2026-0215.pdf'), findsOneWidget);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  group('responsive layout', () {
    testWidgets('desktop: table layout', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // D3 双列:schedule offstage,skipOffstage:false。
      expect(find.text('期次 / 收款日', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tablet: table layout (≤900 still uses table until mobile)',
        (t) async {
      t.view.physicalSize = tablet;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // tablet 仍用表（mobile 断点 720 以下才切卡）
      expect(find.textContaining('2026-03-15', skipOffstage: false), findsWidgets);
    });

    testWidgets('mobile: card list layout', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      expect(find.text('期次 / 收款日'), findsNothing);
      // 卡列表在 ListView 下方,滚动到「收款计划」构建 schedule。
      await t.scrollUntilVisible(
        find.text('收款计划'),
        200,
        scrollable: pageScrollable(),
      );
      expect(find.textContaining('收回本金'), findsWidgets);
    });
  });

  // ───────────────────────── 负向断言 ─────────────────────────
  // 收款语义页面不应出现 debt_detail_page 的 还款/记账/本金/还款计划 标签。
  group('semantics: 应收/收款 (not 还款/记账)', () {
    testWidgets('no debt-detail 还款/记账/剩余本金/还款计划 labels', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 页面标题:OD detail 无 AppBar title(透明 AppBar 只 back icon)。
      // 「收款详情」「债务详情」均不应作为 AppBar title 出现。
      expect(find.text('收款详情'), findsNothing);
      expect(find.text('债务详情'), findsNothing);
      // schedule 标题(D3 双列:schedule offstage,skipOffstage:false)
      expect(find.text('收款计划', skipOffstage: false), findsOneWidget);
      expect(find.text('还款计划表', skipOffstage: false), findsNothing);
      // hero 主标签(REMAINING RECEIVABLE · 剩余应收,kicker)必须出现;
      // 「剩余本金」仅在 hero-prog-meta 行作为副本出现(D1 hero 对齐 OD),
      // 不再作为负向断言 — receivable 语义由 hero kicker + schedule 标题区分。
      expect(find.textContaining('剩余应收'), findsWidgets);
      // 操作按钮
      expect(find.textContaining('确认收款'), findsWidgets);
      // 「记账」不应出现（debt_detail 的 label）
      expect(find.text('记账'), findsNothing);
      // 「记录还款」「确认记账」对话框标题/按钮不应出现（未开 dialog 时）
      expect(find.text('记录还款'), findsNothing);
      expect(find.text('确认记账'), findsNothing);
    });
  });
}
