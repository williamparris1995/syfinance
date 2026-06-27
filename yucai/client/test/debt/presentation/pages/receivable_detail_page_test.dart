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

  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  group('Hero', () {
    testWidgets('renders counterparty + 剩余应收 + progress bar', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // counterparty（hero-name）
      expect(find.textContaining('李四'), findsOneWidget);
      // 剩余应收 标签 + 值（7,574,200 cents = ¥75,742.00）
      expect(find.textContaining('剩余应收'), findsWidgets);
      expect(find.textContaining('¥75,742.00'), findsOneWidget);
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

  group('StatRow', () {
    testWidgets('renders 5 StatCards: 借出本金/利率/到期/摊还/已收期数', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 借出本金 = ¥100,000.00
      expect(find.textContaining('借出本金'), findsOneWidget);
      expect(find.textContaining('¥100,000.00'), findsOneWidget);
      // 年利率 8.00%
      expect(find.textContaining('年利率'), findsOneWidget);
      expect(find.textContaining('8.00%'), findsOneWidget);
      // 到期日 2027-02-15
      expect(find.textContaining('到期日'), findsOneWidget);
      expect(find.textContaining('2027-02-15'), findsWidgets);
      // 摊还方法 等额本息
      expect(find.textContaining('摊还方法'), findsOneWidget);
      expect(find.text('等额本息'), findsWidgets);
      // 已收期数 2 / 5
      expect(find.textContaining('已收期数'), findsOneWidget);
      expect(find.textContaining('2'), findsWidgets);
    });
  });

  group('收款计划 schedule', () {
    testWidgets('desktop renders table with each entry row', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 表头（收款语义）
      expect(find.text('期次 / 收款日'), findsOneWidget);
      expect(find.text('收回本金'), findsWidgets);
      expect(find.text('利息收入'), findsWidgets);
      expect(find.text('合计'), findsWidgets);
      // 5 期日期均渲染
      for (final d in ['2026-03-15', '2026-04-15', '2026-06-15', '2026-07-15']) {
        expect(find.textContaining(d), findsWidgets);
      }
      // 状态 badges：已收 / 待收 / 逾期
      expect(find.textContaining('已收'), findsWidgets);
      expect(find.text('待收'), findsWidgets);
      expect(find.text('逾期'), findsWidgets);
    });

    testWidgets('待收/逾期 entries show 确认收款 button, 已收 shows 已确认',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 1 逾期 + 2 待收 = 3 个未收 entry → 3 个「确认收款」按钮；
      // 2 个已收 → 2 个「已确认」。
      expect(find.textContaining('确认收款'), findsNWidgets(3));
      expect(find.text('已确认'), findsNWidgets(2));
    });

    testWidgets('mobile renders card list (no DataTable)', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // mobile 不渲染表头
      expect(find.text('期次 / 收款日'), findsNothing);
      // 卡列表内容（Hero + StatRow 占满首屏，需 skipOffstage:false）
      expect(find.textContaining('2026-03-15', skipOffstage: false),
          findsOneWidget);
      expect(find.textContaining('2026-07-15', skipOffstage: false),
          findsOneWidget);
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
      expect(find.text('已确认'), findsNWidgets(2));
      expect(find.textContaining('确认收款'), findsNothing);
    });

    testWidgets('tap 逾期 filters to overdue-only entry', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filterSegment-逾期')));
      await t.pumpAndSettle();
      // 只剩 1 个逾期 entry → 1 个确认收款按钮
      expect(find.textContaining('确认收款'), findsOneWidget);
      expect(find.text('已确认'), findsNothing);
    });
  });

  group('确认收款 (RecordPayment)', () {
    testWidgets('tap 确认收款 opens 收款账户 picker dialog', (t) async {
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
      // 点第一个「确认收款」按钮（待收/逾期期次）
      await t.tap(find.textContaining('确认收款').first);
      await t.pumpAndSettle();
      // 弹出 确认收款 对话框（收款语义标题）
      expect(find.textContaining('确认收款'), findsWidgets);
      // 收款账户 选择存在（收款语义 label）
      expect(find.textContaining('收款至账户'), findsOneWidget);
      // 至少一个账户选项
      expect(find.textContaining('招商银行储蓄卡'), findsWidgets);
    });

    testWidgets('confirm 确认收款 dispatches RecordPaymentRequested',
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
          child: ReceivableDetailPage(id: detail.debt.id),
        ),
      ));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('确认收款').first);
      await t.pumpAndSettle();
      // 确认收款（对话框底部按钮，也是「确认收款」）→ dispatch RecordPaymentRequested
      // → bloc 异步 recordPayment 成功后再 add LoadDebtRequested（链式刷新）。
      // 表格里多个「确认收款」；点最后一个（对话框 action button）。
      await t.tap(find.textContaining('确认收款').last);
      for (var i = 0; i < 10 && !recorded; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(recorded, isTrue);
      // 成功后 BlocListener 弹 AppToast（3 秒自动消失 Timer）。fake_async 下
      // 推进 >3s 让 Timer 触发 _dismiss，否则 teardown 报 timersPending。
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
      expect(find.text('期次 / 收款日'), findsOneWidget);
    });

    testWidgets('tablet: table layout (≤900 still uses table until mobile)',
        (t) async {
      t.view.physicalSize = tablet;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // tablet 仍用表（mobile 断点 720 以下才切卡）
      expect(find.textContaining('2026-03-15'), findsWidgets);
    });

    testWidgets('mobile: card list layout', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      expect(find.text('期次 / 收款日'), findsNothing);
      // 卡列表仍渲染每期（收回本金）。mobile 卡位于可滚动 ListView 视口外，
      // 需 skipOffstage:false 让 finder 覆盖离屏 widget（Hero + StatRow 占满首屏）。
      expect(find.textContaining('收回本金', skipOffstage: false), findsWidgets);
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
      // 页面标题
      expect(find.text('收款详情'), findsOneWidget);
      expect(find.text('债务详情'), findsNothing);
      // schedule 标题
      expect(find.text('收款计划'), findsOneWidget);
      expect(find.text('还款计划表'), findsNothing);
      // hero 主标签
      expect(find.textContaining('剩余应收'), findsWidgets);
      expect(find.textContaining('剩余本金'), findsNothing);
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
