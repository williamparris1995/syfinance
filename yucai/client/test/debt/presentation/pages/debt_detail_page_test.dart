// Task 7 — TDD widget tests for DebtDetailPage
// (Hero + StatCards + schedule 表/卡 + RecordPayment + 筛选 + 三端)。
//
// 对齐 debts_page_test 的 harness：mocktail DebtRepository → 真实 DebtBloc，
// 注入 DebtDetailLoaded。_Hero/_StatRow/_Schedule* 私有，故通过公开
// DebtDetailPage 驱动。
//
// 验证：
//   - Hero：counterparty + 剩余本金(大字) + progress bar(progressRatio)
//   - StatRow：总本金 / 利率 / 到期 / 摊还 / 已还期数
//   - schedule：每期(日期/本金/利息/合计/状态/记账)
//   - 筛选：全部/待还/已还/逾期 (segmented)
//   - RecordPayment：点待还期「记账」→ 弹 from_account 选择 → RecordPaymentRequested
//   - 三端：desktop 表 / mobile 卡列表
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
import 'package:yucai_client/debt/presentation/pages/debt_detail_page.dart';

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

Debt _debt({
  String id = 'd1',
  String counterparty = '招商银行 · 个人住房贷款',
  double interestRate = 4.10,
  AmortizationMethod amortization = AmortizationMethod.equalPrincipalInterest,
  DateTime? dueDate,
  int totalPrincipalCents = 280000000, // 280 万
  int remainingPrincipalCents = 210000000, // 剩 210 万 → 已还 25%
}) =>
    Debt(
      id: id,
      accountId: 'a1',
      counterparty: counterparty,
      interestRate: interestRate,
      amortization: amortization,
      startDate: DateTime(2021, 6, 15),
      dueDate: dueDate ?? DateTime(2051, 6, 15),
      totalPrincipalCents: totalPrincipalCents,
      remainingPrincipalCents: remainingPrincipalCents,
      version: 1,
      createdAt: DateTime(2021, 6, 15),
      updatedAt: DateTime(2026, 6, 1),
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
        paymentDate: DateTime(2026, 4, 1),
        principalCents: 403000,
        interestCents: 950100,
        paid: true),
    _entry(
        id: 'e2',
        paymentDate: DateTime(2026, 5, 1),
        principalCents: 404400,
        interestCents: 948700,
        paid: true),
    // 逾期：日期早于 now 且未还。
    _entry(
        id: 'e3',
        paymentDate: DateTime(2026, 6, 1),
        principalCents: 405800,
        interestCents: 947300,
        paid: false),
    // 待还：日期晚于 now。
    _entry(
        id: 'e4',
        paymentDate: DateTime(2026, 7, 1),
        principalCents: 407100,
        interestCents: 946000,
        paid: false),
    _entry(
        id: 'e5',
        paymentDate: DateTime(2026, 8, 1),
        principalCents: 408500,
        interestCents: 944600,
        paid: false),
  ];
  return DebtDetail(debt: debt ?? _debt(), schedule: schedule);
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
  // 详情页 initState 走 getIt<AccountRepository>().list() 拉 from_account 列表。
  // 注册到 GetIt（与 account_detail_page_test 同模式）。
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
      child: DebtDetailPage(id: detail.debt.id),
    ),
  );
}

void main() {
  // 详情页 initState 走 getIt<AccountRepository>；每个测试结束重置避免重复注册。
  tearDown(() {
    GetIt.instance.reset();
  });

  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  group('Hero', () {
    testWidgets('renders counterparty + 剩余本金 + progress bar', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // counterparty（hero-name）
      expect(find.textContaining('招商银行'), findsOneWidget);
      // 剩余本金标签 + 值（2,1000,000 cents = ¥2,100,000.00）
      expect(find.textContaining('剩余本金'), findsWidgets);
      expect(find.textContaining('¥2,100,000.00'), findsOneWidget);
      // Hero progress bar 存在（LinearProgressIndicator）
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('progress bar uses progressRatio (25%)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // progressRatio = (280-210)/280 = 0.25 → 25.0%
      expect(find.textContaining('25.0%'), findsWidgets);
    });
  });

  group('StatRow', () {
    testWidgets('renders 5 StatCards: 本金/利率/到期/摊还/已还期数', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 借款本金 = ¥2,800,000.00
      expect(find.textContaining('借款本金'), findsOneWidget);
      expect(find.textContaining('¥2,800,000.00'), findsOneWidget);
      // 年利率 4.10%
      expect(find.textContaining('年利率'), findsOneWidget);
      expect(find.textContaining('4.10%'), findsOneWidget);
      // 到期日 2051-06-15
      expect(find.textContaining('到期日'), findsOneWidget);
      expect(find.textContaining('2051-06-15'), findsWidgets);
      // 摊还方法 等额本息
      expect(find.textContaining('摊还方法'), findsOneWidget);
      expect(find.text('等额本息'), findsWidgets);
      // 已还期数 2 / 5
      expect(find.textContaining('已还期数'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
    });
  });

  group('schedule', () {
    testWidgets('desktop renders table with each entry row', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 表头
      expect(find.text('期次 / 还款日'), findsOneWidget);
      expect(find.text('本金'), findsWidgets);
      expect(find.text('利息'), findsWidgets);
      expect(find.text('合计'), findsWidgets);
      // 5 期日期均渲染
      for (final d in ['2026-04-01', '2026-05-01', '2026-06-01', '2026-07-01']) {
        expect(find.textContaining(d), findsWidgets);
      }
      // 状态 badges：已还 / 待还 / 逾期
      expect(find.textContaining('已还'), findsWidgets);
      expect(find.text('待还'), findsWidgets);
      expect(find.text('逾期'), findsWidgets);
    });

    testWidgets('待还/逾期 entries show 记账 button, 已还 shows 已结清',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 3 个待还/逾期 + 2 个已还 = 「记账」按钮 3 个（逾期 + 待还×2 待还期，
      // 注意本测试 schedule 有 1 逾期 + 2 待还 = 3 个未还 entry）
      expect(find.textContaining('记账'), findsNWidgets(3));
      expect(find.text('已结清'), findsNWidgets(2));
    });

    testWidgets('mobile renders card list (no DataTable)', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // mobile 不渲染表头
      expect(find.text('期次 / 还款日'), findsNothing);
      // 卡列表内容在可滚动 ListView 中，可能位于视口外 —— skipOffstage:false
      // 让 finder 覆盖离屏 widget（Hero + StatRow 占满首屏）。
      expect(find.textContaining('2026-04-01', skipOffstage: false),
          findsOneWidget);
      expect(find.textContaining('2026-07-01', skipOffstage: false),
          findsOneWidget);
    });
  });

  group('筛选 (segmented)', () {
    testWidgets('renders 全部/待还/已还/逾期 filter segments', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 4 个筛选 segment（by ValueKey，避开状态 badge/sum-pill 的同名文字）
      expect(find.byKey(const ValueKey('filterSegment-全部')), findsOneWidget);
      expect(find.byKey(const ValueKey('filterSegment-待还')), findsOneWidget);
      expect(find.byKey(const ValueKey('filterSegment-已还')), findsOneWidget);
      expect(find.byKey(const ValueKey('filterSegment-逾期')), findsOneWidget);
    });

    testWidgets('tap 已还 filters to paid-only entries', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 点筛选 segmented 的「已还」（by ValueKey 区分，避开状态 badge）
      await t.tap(find.byKey(const ValueKey('filterSegment-已还')));
      await t.pumpAndSettle();
      // 已还 entry 2 个；待还/逾期被过滤。「已结清」仍 2 个；「记账」按钮应为 0。
      expect(find.text('已结清'), findsNWidgets(2));
      expect(find.textContaining('记账'), findsNothing);
    });

    testWidgets('tap 逾期 filters to overdue-only entry', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filterSegment-逾期')));
      await t.pumpAndSettle();
      // 只剩 1 个逾期 entry → 1 个记账按钮
      expect(find.textContaining('记账'), findsOneWidget);
      expect(find.text('已结清'), findsNothing);
    });
  });

  group('RecordPayment', () {
    testWidgets('tap 记账 opens from_account picker dialog', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final accounts = [
        _assetAccount(id: 'acct-1', name: '招商银行储蓄卡'),
        _assetAccount(id: 'acct-2', name: '支付宝'),
      ];
      await t.pumpWidget(_harness(
        detail: _detail(),
        accounts: accounts,
      ));
      await t.pumpAndSettle();
      // 点第一个「记账」按钮（待还/逾期期次）
      await t.tap(find.textContaining('记账').first);
      await t.pumpAndSettle();
      // 弹出 RecordPayment 对话框
      expect(find.textContaining('记录还款'), findsOneWidget);
      // from_account 选择存在
      expect(find.textContaining('从账户'), findsOneWidget);
      // 至少一个账户选项
      expect(find.textContaining('招商银行储蓄卡'), findsWidgets);
    });

    testWidgets('confirm RecordPayment dispatches RecordPaymentRequested',
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
      var recorded = false;
      when(() => debtRepo.recordPayment(
              debtId: any(named: 'debtId'),
              scheduleEntryId: any(named: 'scheduleEntryId'),
              fromAccountId: any(named: 'fromAccountId')))
          .thenAnswer((inv) {
        recorded = true;
        return Future.value(dartz.Right(detail.schedule.first));
      });
      when(() => accountRepo.list()).thenAnswer(
          (_) async => dartz.Right([_assetAccount(id: 'acct-1')]));
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

      late DebtBloc bloc;
      await t.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DebtBloc>(
                create: (_) {
                  bloc = DebtBloc(debtRepo);
                  return bloc;
                }),
            BlocProvider<CurrencyBloc>.value(
                value: _FakeCurrencyBloc(const CurrencyState())),
          ],
          child: DebtDetailPage(id: detail.debt.id),
        ),
      ));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('记账').first);
      await t.pumpAndSettle();
      // 确认记账 → dispatch RecordPaymentRequested → bloc 异步 recordPayment
      // 成功后会再 add LoadDebtRequested（链式刷新）→ repo.get。逐帧 pump 让
      // 微任务链推进，直到 recordPayment 被调用（recorded 置 true）。
      await t.tap(find.text('确认记账'));
      for (var i = 0; i < 10 && !recorded; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(recorded, isTrue);
      // 成功后 BlocListener 弹 AppToast（3 秒自动消失 Timer）。在 fake_async
      // 下推进 >3s 让 Timer 触发 _dismiss，否则 teardown 报 timersPending。
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
      expect(find.text('期次 / 还款日'), findsOneWidget);
    });

    testWidgets('tablet: table layout (≤900 still uses table until mobile)',
        (t) async {
      t.view.physicalSize = tablet;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // tablet 仍用表（mobile 断点 720 以下才切卡）
      expect(find.textContaining('2026-04-01'), findsWidgets);
    });

    testWidgets('mobile: card list layout', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      expect(find.text('期次 / 还款日'), findsNothing);
      // 卡列表仍渲染每期
      expect(find.textContaining('本金'), findsWidgets);
    });
  });
}
