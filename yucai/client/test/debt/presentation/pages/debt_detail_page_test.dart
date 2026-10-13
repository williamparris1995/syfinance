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
import 'package:design_kit/design_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/shell_detail_title.dart';
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
  double interestRate = 0.041,
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
  DebtDetail? detailAfterReload,
}) {
  final debtRepo = _MockDebtRepo();
  final accountRepo = _MockAccountRepo();
  // 详情页 initState 走 getIt<AccountRepository>().list() 拉 from_account 列表。
  // 注册到 GetIt（与 account_detail_page_test 同模式）。
  GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
  registerFallbackValue(const RecordPaymentRequested(
      debtId: '', scheduleEntryId: '', fromAccountId: ''));
  // F33:detailAfterReload 非空时,get 第 2 次起返回重拉后的详情(编辑保存
  // 返回场景);第 1 次仍为初始详情。
  var getCalls = 0;
  when(() => debtRepo.get(any())).thenAnswer((_) async {
    getCalls += 1;
    return dartz.Right(
        (detailAfterReload != null && getCalls > 1) ? detailAfterReload : detail);
  });
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
  GetIt.instance.registerLazySingleton<DataRefreshNotifier>(DataRefreshNotifier.new);

  // 详情页 initState 走 getIt<AccountRepository>；每个测试结束重置避免重复注册。
  tearDown(() {
    GetIt.instance.reset();
  });

  const desktop = Size(1400, 900);
  const tablet = Size(900, 1200);
  const mobile = Size(390, 844);

  // 镜像 receivables 后 schedule 在 ListView 下方(可能离屏)。锁定页面根 Scrollable。
  Finder pageScrollable() => find
      .descendant(
        of: find.byType(DebtDetailPage),
        matching: find.byType(Scrollable),
      )
      .first;

  group('Hero', () {
    testWidgets('renders counterparty + 剩余本金 + progress bar', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // counterparty（hero-name + side panel 债权方 → 多处）
      expect(find.textContaining('招商银行'), findsWidgets);
      // 剩余本金标签 + 值（2,1000,000 cents = ¥2,100,000.00）
      //   hero GoldAmount + hero-prog-meta「剩余 ¥…」→ findsWidgets。
      expect(find.textContaining('剩余本金'), findsWidgets);
      expect(find.textContaining('¥2,100,000.00'), findsWidgets);
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
    testWidgets(
        'renders 5 amount-dimension StatCards (mirror receivables): '
        '借款本金/已还合计/待还合计/累计还息/逾期应付', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 5-stat 镜像 receivables 金额维度(非 旧的 本金/利率/到期/摊还/期数)。
      // 借款本金 = ¥2,800,000.00(stat value + hero-sub「借款 ¥…」→ findsWidgets)
      expect(find.textContaining('借款本金'), findsOneWidget);
      expect(find.textContaining('¥2,800,000.00'), findsWidgets);
      // 已还合计 = paidTotal = 2,706,200 → ¥27,062.00
      //   (巧合:逾期应付 = 2 逾期期次合计 也 = ¥27,062.00 → findsWidgets)
      expect(find.textContaining('已还合计'), findsOneWidget);
      expect(find.textContaining('¥27,062.00'), findsWidgets);
      // 待还合计 = pendingTotal = 4,059,300 → ¥40,593.00
      //   (巧合:逾期应付 金额随 now 漂移,当 e5(paymentDate=2026-08-01)跨 overdue
      //    界限时,逾期合计恰好等于 pendingTotal → findsWidgets 容忍,与「已还合计」同模式)
      expect(find.textContaining('待还合计'), findsOneWidget);
      expect(find.textContaining('¥40,593.00'), findsWidgets);
      // 累计还息 = paidInterest = 1,898,800 → ¥18,988.00(成本 = 红)
      //   (也出现在 已还合计 sub「本金 ¥8,074.00 + 利息 ¥18,988.00」→ findsWidgets)
      expect(find.textContaining('累计还息'), findsOneWidget);
      expect(find.textContaining('¥18,988.00'), findsWidgets);
      // 逾期应付 标签渲染(具体金额随 now 漂移,仅断言 label)
      expect(find.textContaining('逾期应付'), findsOneWidget);
      // 年利率 / 到期日 / 已还期数 移至 hero-side 4-tile(镜像 receivables)。
      expect(find.text('年利率'), findsOneWidget);
      expect(find.text('到期日'), findsOneWidget);
      expect(find.text('已还期数'), findsOneWidget);
      // 利率值 4.10%(hero-side 年利率 tile + 累计还息 sub「年化 4.10%」→ 多处)
      expect(find.textContaining('4.10%'), findsWidgets);
    });
  });

  group('schedule', () {
    testWidgets('desktop renders table with each entry row', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 表头(镜像 receivables:期次/还款日 · 应还本金 · 利息 · 合计)
      expect(find.text('期次 / 还款日'), findsOneWidget);
      expect(find.textContaining('应还本金'), findsWidgets);
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

    testWidgets('待还/逾期 entries show 立即记账 button, 已还 shows 已结清',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // 镜像 receivables:行内 action label = 立即记账(debt sem.scheduleActionLabel)。
      // 1 逾期 + 2 待还 = 3 个未还 entry → 3 个「立即记账」按钮;2 已还 → 2「已结清」。
      expect(find.text('立即记账'), findsNWidgets(3));
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
      // 卡列表在 ListView 下方,滚动到「还款计划」构建 schedule 卡。
      await t.scrollUntilVisible(
        find.text('还款计划'),
        200,
        scrollable: pageScrollable(),
      );
      expect(find.textContaining('2026-04-01'), findsOneWidget);
      expect(find.textContaining('2026-07-01'), findsWidgets);
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
      // 已还 entry 2 个；待还/逾期被过滤。「已结清」仍 2 个；「立即记账」应为 0。
      expect(find.text('已结清'), findsNWidgets(2));
      expect(find.text('立即记账'), findsNothing);
    });

    testWidgets('tap 逾期 filters to overdue-only entry', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final detail = _detail();
      await t.pumpWidget(_harness(detail: detail));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('filterSegment-逾期')));
      await t.pumpAndSettle();
      // 逾期 entry 数随「现在」漂移(e3=2026-06-01 恒逾期;e4=2026-07-01 在
      // 2026-07-08 后也变逾期)→ 动态算预期值,避免硬编码日期。
      final now = DateTime.now();
      final expectedOverdue = detail.schedule
          .where((e) => !e.paid && e.paymentDate.isBefore(now))
          .length;
      expect(find.text('立即记账'), findsNWidgets(expectedOverdue));
      expect(find.text('已结清'), findsNothing);
    });
  });

  group('RecordPayment', () {
    testWidgets('tap 立即记账 opens from_account picker dialog', (t) async {
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
      // 镜像 receivables:立即记账 在 schedule 行内(页面下方),先滚出再点。
      final scrollable = pageScrollable();
      await t.drag(scrollable, const Offset(0, -600));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('立即记账').first);
      await t.pumpAndSettle();
      await t.tap(find.text('立即记账').first);
      await t.pumpAndSettle();
      // 弹出 dialog(镜像 receivables:标题「确认记账」,debt sem.dialogTitle)。
      expect(find.textContaining('确认记账'), findsWidgets);
      // from_account 选择存在(debt sem.dialogAccountLabel 含「从账户」)
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

      await t.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
            BlocProvider<CurrencyBloc>.value(
                value: _FakeCurrencyBloc(const CurrencyState())),
          ],
          child: DebtDetailPage(id: detail.debt.id),
        ),
      ));
      await t.pumpAndSettle();
      final scrollable = pageScrollable();
      await t.drag(scrollable, const Offset(0, -600));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('立即记账').first);
      await t.pumpAndSettle();
      await t.tap(find.text('立即记账').first);
      await t.pumpAndSettle();
      // 确认记账(dialog 标题 + 按钮同词 → 用 ElevatedButton 精确锁定 submit 按钮)
      await t.tap(find.widgetWithText(ElevatedButton, '确认记账'));
      for (var i = 0; i < 10 && !recorded; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(recorded, isTrue);
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    // Task 4 (ccs): RecordPayment 双写后 server 端 account 余额已变,详情页
    // 必须重新拉 account 列表。验证:list() 在 initState 调用一次后,RecordPayment
    // 成功(DebtDetailLoaded)再被调用。
    testWidgets(
        'RecordPayment success re-fetches account balances (double-write refresh)',
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
          child: DebtDetailPage(id: detail.debt.id),
        ),
      ));
      await t.pumpAndSettle();
      expect(listCalls, 1);
      final scrollable = pageScrollable();
      await t.drag(scrollable, const Offset(0, -600));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('立即记账').first);
      await t.pumpAndSettle();
      await t.tap(find.text('立即记账').first);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ElevatedButton, '确认记账'));
      for (var i = 0; i < 20 && listCalls < 2; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(listCalls, greaterThanOrEqualTo(2));
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
      // D3 双列:schedule 在 ListView 下方,skipOffstage:false 覆盖离屏 widget。
      expect(find.text('期次 / 还款日', skipOffstage: false), findsOneWidget);
    });

    testWidgets('tablet: table layout (≤900 still uses table until mobile)',
        (t) async {
      t.view.physicalSize = tablet;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // tablet 仍用表（mobile 断点 720 以下才切卡）
      expect(
          find.textContaining('2026-04-01', skipOffstage: false), findsWidgets);
    });

    testWidgets('mobile: card list layout', (t) async {
      t.view.physicalSize = mobile;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      expect(find.text('期次 / 还款日'), findsNothing);
      // 卡列表在 ListView 下方,滚动到「还款计划」构建 schedule 卡。
      await t.scrollUntilVisible(
        find.text('还款计划'),
        200,
        scrollable: pageScrollable(),
      );
      // 卡列表仍渲染每期(镜像 receivables:列名 应还本金)
      expect(find.textContaining('应还本金'), findsWidgets);
    });
  });

  // Task 9 — 信用卡 StatRow(subtype==creditCard 才显示)+ 列表 badge 持久化 label。
  group('credit-card StatRow (Task 9)', () {
    Account creditCardAccount({
      String id = 'cc-1',
      int creditLimitCents = 5000000, // ¥50,000
      int currentBalanceCents = 1500000, // ¥15,000 → 利用率 30%(绿)
      int? billingDay = 9,
      int? repaymentDay = 27,
      String tail = '8842',
    }) =>
        Account(
          id: id,
          name: '招行信用卡',
          accountType: AccountType.liability,
          category: AccountCategory.creditCard,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          currentBalanceCents: currentBalanceCents,
          ownership: Ownership.personal,
          status: AccountStatus.active,
          creditLimitCents: creditLimitCents,
          creditBillingDay: billingDay,
          creditRepaymentDay: repaymentDay,
          cardNumberTail: tail,
        );

    /// 构造带 subtype + accountId 的 Debt(_debt 默认 subtype='')。
    Debt debtWithSubtype({
      required String subtype,
      String accountId = 'cc-1',
      String counterparty = '招行信用卡',
      double interestRate = 0.18,
      AmortizationMethod amortization = AmortizationMethod.lumpSum,
    }) =>
        Debt(
          id: 'd1',
          accountId: accountId,
          counterparty: counterparty,
          interestRate: interestRate,
          amortization: amortization,
          startDate: DateTime(2021, 6, 15),
          dueDate: DateTime(2051, 6, 15),
          totalPrincipalCents: 280000000,
          remainingPrincipalCents: 210000000,
          version: 1,
          createdAt: DateTime(2021, 6, 15),
          updatedAt: DateTime(2026, 6, 1),
          type: DebtType.borrowedIn,
          subtype: subtype,
        );

    testWidgets('credit-card debt(subtype=creditCard) shows 信用卡区', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final ccDebt =
          debtWithSubtype(subtype: DebtSubtypes.creditCard, accountId: 'cc-1');
      await t.pumpWidget(_harness(
        detail: _detail(debt: ccDebt),
        accounts: [creditCardAccount()],
      ));
      await t.pumpAndSettle();
      // 信用卡 StatRow 存在(by ValueKey)
      expect(find.byKey(const ValueKey('creditCardStatsRow')), findsOneWidget);
      // 账单日 / 还款日 / 信用额度 / 利用率 标签均渲染
      expect(find.textContaining('账单日'), findsWidgets);
      expect(find.textContaining('还款日'), findsWidgets);
      expect(find.textContaining('信用额度'), findsWidgets);
      expect(find.textContaining('利用率'), findsWidgets);
      // 账单日值「每月 9 日」
      expect(find.textContaining('每月 9 日'), findsOneWidget);
      // 利用率 30.0%(1500000/5000000)
      expect(find.textContaining('30.0%'), findsWidgets);
    });

    testWidgets('non-credit-card debt does NOT show 信用卡区', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      // 房贷 subtype —— 不应显示信用卡区。
      final mortgageDebt =
          debtWithSubtype(subtype: DebtSubtypes.mortgage, accountId: 'a1');
      await t.pumpWidget(_harness(detail: _detail(debt: mortgageDebt)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('creditCardStatsRow')), findsNothing);
      expect(find.textContaining('利用率'), findsNothing);
    });

    testWidgets('legacy debt(subtype empty) does NOT show 信用卡区', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final legacyDebt = debtWithSubtype(subtype: '', accountId: 'a1');
      await t.pumpWidget(_harness(detail: _detail(debt: legacyDebt)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('creditCardStatsRow')), findsNothing);
    });
  });

  group('F33 didPopNext 详情重拉', () {
    // 最小 Debt 构造(subtype 驱动 badge 文字)。
    Debt subDebt(String subtype) => Debt(
          id: 'd1',
          accountId: 'a1',
          counterparty: '链路银行',
          interestRate: 0.05,
          amortization: AmortizationMethod.equalPrincipalInterest,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2027, 1, 1),
          totalPrincipalCents: 10000000,
          remainingPrincipalCents: 10000000,
          subtype: subtype,
          version: 1,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 9, 18),
        );

    testWidgets('编辑保存返回(didPopNext)重拉详情,badge 更新为新分类', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(
        detail: _detail(debt: subDebt(DebtSubtypes.mortgage)),
        detailAfterReload: _detail(debt: subDebt(DebtSubtypes.creditLoan)),
      ));
      await t.pumpAndSettle();
      // 初始:旧分类 badge 可见。
      expect(find.textContaining('房贷'), findsWidgets);
      // 模拟编辑保存返回:表单 pop 回本页触发 RouteAware.didPopNext。
      // (State 私有类静态类型无该方法,dynamic 调用之。)
      (t.state(find.byType(DebtDetailPage)) as dynamic).didPopNext();
      await t.pumpAndSettle();
      // 详情已重拉:badge 更新为新分类(FR-1 用户可见闭环)。
      expect(find.textContaining('信用贷款'), findsWidgets);
    });
  });

  // ───────── F50 计入挂接卡额度占用(详情只读行) ─────────
  group('F50 卡贷额度占用只读行', () {
    Account ccAccount() => Account(
          id: 'cc-1',
          name: '招行信用卡',
          accountType: AccountType.liability,
          category: AccountCategory.creditCard,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          currentBalanceCents: 0,
          ownership: Ownership.personal,
          status: AccountStatus.active,
          creditLimitCents: 5000000,
        );

    Debt cardLoanDebt({bool counts = true, String? collectionId = 'cc-1'}) =>
        Debt(
          id: 'd-cl',
          accountId: 'a1',
          counterparty: '招行e招贷',
          interestRate: 0.1,
          amortization: AmortizationMethod.equalPrincipalInterest,
          startDate: DateTime(2026, 7, 1),
          dueDate: DateTime(2027, 7, 1),
          totalPrincipalCents: 6000000,
          remainingPrincipalCents: 6000000,
          version: 1,
          subtype: DebtSubtypes.cardLoan,
          collectionAccountId: collectionId,
          countsTowardCardLimit: counts,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 8, 1),
        );

    testWidgets('挂接卡贷展示开关当前值:计入(true)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(
        detail: _detail(debt: cardLoanDebt(counts: true)),
        accounts: [ccAccount()],
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('cardLimitFlagRow')), findsOneWidget);
      expect(find.textContaining('计入挂接卡额度占用'), findsOneWidget);
      expect(find.text('计入'), findsOneWidget);
      expect(find.text('不计入'), findsNothing);
    });

    testWidgets('挂接卡贷展示开关当前值:不计入(false)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(
        detail: _detail(debt: cardLoanDebt(counts: false)),
        accounts: [ccAccount()],
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('cardLimitFlagRow')), findsOneWidget);
      expect(find.text('不计入'), findsOneWidget);
      expect(find.text('计入'), findsNothing);
    });

    testWidgets('非挂接(独立账单)卡贷不显示只读行', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(
        detail: _detail(debt: cardLoanDebt(collectionId: null)),
        accounts: [ccAccount()],
      ));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('cardLimitFlagRow')), findsNothing,
          reason: '独立账单卡贷无挂接卡,开关语义不适用');
    });

    testWidgets('普通债务(非卡贷)不显示只读行', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final mortgage = Debt(
        id: 'd-m',
        accountId: 'a1',
        counterparty: '招行房贷',
        interestRate: 0.04,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2021, 6, 15),
        dueDate: DateTime(2051, 6, 15),
        totalPrincipalCents: 280000000,
        remainingPrincipalCents: 210000000,
        version: 1,
        subtype: DebtSubtypes.mortgage,
        createdAt: DateTime(2021, 6, 15),
        updatedAt: DateTime(2026, 6, 1),
      );
      await t.pumpWidget(_harness(detail: _detail(debt: mortgage)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('cardLimitFlagRow')), findsNothing,
          reason: '非卡贷债务不显示额度占用只读行');
    });
  });

  // ───────────── F59 FR-2:删除淡显钮直达(菜单退役) ─────────────
  // C' 全平铺:删除为 muted 淡显常驻钮,零菜单一步直达既有二次确认弹窗。
  // (镜像 receivable_detail_page_test;删除成功信号 DebtsLoaded → go /debts)
  group("muted 删除钮(C' 直达)", () {
    Widget routerHarness(_MockDebtRepo debtRepo) {
      final router = GoRouter(
        initialLocation: '/debts/d1',
        routes: [
          GoRoute(
            path: '/debts',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('DEBTS_LIST'))),
          ),
          GoRoute(
            path: '/debts/:id',
            builder: (_, __) => const DebtDetailPage(id: 'd1'),
          ),
        ],
      );
      return MultiBlocProvider(
        providers: [
          BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
          BlocProvider<CurrencyBloc>.value(
              value: _FakeCurrencyBloc(const CurrencyState())),
        ],
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('muted 删除钮 → 直达确认弹窗 → 确认 → repo.delete + 返回列表页',
        (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(DebtType.borrowedIn);
      final detail = _detail();
      when(() => debtRepo.get(any()))
          .thenAnswer((_) async => dartz.Right(detail));
      var deletedId = '';
      when(() => debtRepo.delete(any())).thenAnswer((inv) async {
        deletedId = inv.positionalArguments.single as String;
        return const dartz.Right(null);
      });
      when(() => debtRepo.list(typeFilter: any(named: 'typeFilter')))
          .thenAnswer((_) async => const dartz.Right([]));
      when(() => accountRepo.list())
          .thenAnswer((_) async => const dartz.Right(<Account>[]));
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

      await t.pumpWidget(routerHarness(debtRepo));
      await t.pumpAndSettle();
      // 菜单模型退役:整页零 AnchoredMenu;删除一步直达确认弹窗。
      expect(find.byType(AnchoredMenu), findsNothing);
      expect(find.byTooltip('更多'), findsNothing);
      expect(find.textContaining('待接入'), findsNothing);
      await t.tap(find.byTooltip('删除债务'));
      await t.pumpAndSettle();
      // 直达既有二次确认弹窗(无中间菜单):标题 + 说明 + 确认按钮。
      expect(find.text('删除债务'), findsOneWidget);
      expect(find.textContaining('还款计划将一并删除'), findsOneWidget);
      expect(find.textContaining('已记录的还款交易保留'), findsOneWidget);
      await t.tap(find.widgetWithText(FilledButton, '删除'));
      for (var i = 0; i < 10 && deletedId.isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.pumpAndSettle();
      expect(deletedId, 'd1');
      expect(find.text('DEBTS_LIST'), findsOneWidget);
      // AppToast Timer 推进避免 teardown 报 timersPending。
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('确认弹窗 取消 → 不删除', (t) async {
      t.view.physicalSize = const Size(1400, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      registerFallbackValue(DebtType.borrowedIn);
      when(() => debtRepo.get(any()))
          .thenAnswer((_) async => dartz.Right(_detail()));
      when(() => accountRepo.list())
          .thenAnswer((_) async => const dartz.Right(<Account>[]));
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);

      await t.pumpWidget(routerHarness(debtRepo));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('删除债务'));
      await t.pumpAndSettle();
      await t.tap(find.text('取消'));
      await t.pumpAndSettle();
      expect(find.text('取消'), findsNothing);
      expect(find.byType(DebtDetailPage), findsOneWidget);
      verifyNever(() => debtRepo.delete(any()));
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });
  });

  // ───────────────── F58 T4:AppBar 退役 + 右下悬浮簇 + 标题注入 ─────────────────
  // FR-2/3/4/5 验收:页面无第二层导航条;dock 常驻右下(28 边距,不随滚动
  // 移动);操作映射(C' 重配,菜单退役)primary=立即记账 / secondary=编辑 /
  // muted=删除债务;滚动容器底部留白 ≥253;标题经 ShellDetailTitle port
  // 注入/清理。
  group('F58 悬浮簇 + AppBar 退役', () {
    testWidgets('FR-5 页面无 AppBar(第二层导航整条退役)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      // 回退唯一路径 = 顶栏面包屑 page 级(页面自身不承载导航语义)。
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets(
        'FR-3/FR-4 dock 常驻右下:primary=立即记账,secondary=[编辑],'
        'muted=[删除债务],滚动 bottom padding ≥253', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      // dock 存在且经 Positioned(right/bottom 28) 摆放(常驻,不随滚动)。
      expect(find.byType(FloatingActionDock), findsOneWidget);
      final pos = t.widget<Positioned>(
        find.ancestor(
            of: find.byType(FloatingActionDock),
            matching: find.byType(Positioned)),
      );
      expect(pos.right, 28);
      expect(pos.bottom, 28);
      // 操作映射(debt 语义 C'):primary=立即记账;secondary=[编辑];
      // muted=[删除债务](淡显,危险项离主钮最远)。
      final dock = t.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.tooltip, '立即记账');
      expect(dock.primary.onTap, isNotNull, reason: '已加载且有未还期次 → 可触发');
      expect(dock.secondary.map((a) => a.tooltip).toList(), ['编辑']);
      expect(dock.secondary.every((a) => a.onTap != null), isTrue);
      expect(dock.muted.map((a) => a.tooltip).toList(), ['删除债务']);
      expect(dock.muted.every((a) => a.onTap != null), isTrue);
      // F59 FR-2:菜单模型退役,页面零 AnchoredMenu 挂载。
      expect(find.byType(AnchoredMenu), findsNothing);
      expect(find.byTooltip('更多'), findsNothing);
      // FR-3 防遮挡:页面滚动容器底部留白 ≥ 253(C' 满配簇高 171
      // [52 主钮 + 2×44 次级 + 3×10 间距 + 分隔线 1] + 底边距 28 + 净空 54)。
      final list = t.widget<ListView>(find
          .descendant(
              of: find.byType(DebtDetailPage),
              matching: find.byType(ListView))
          .first);
      expect((list.padding as EdgeInsets?)?.bottom ?? 0,
          greaterThanOrEqualTo(253));
    });

    testWidgets('全部结清 → primary 禁用(无下期可记)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final allPaid = _detail(schedule: [
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
      ]);
      await t.pumpWidget(_harness(detail: allPaid));
      await t.pumpAndSettle();
      final dock = t.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.onTap, isNull, reason: '无未还期次 → 主操作禁用');
      // 次级操作(编辑/删除)不受影响 —— 操作集不缺席,仅禁用。
      expect(dock.secondary.every((a) => a.onTap != null), isTrue);
      expect(dock.muted.every((a) => a.onTap != null), isTrue);
    });

    testWidgets('卡贷(F48)→ primary 禁用(手工记账停用,防双重支付)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final cardLoan = Debt(
        id: 'd-cl',
        accountId: 'a1',
        counterparty: '招行e招贷',
        interestRate: 0.1,
        amortization: AmortizationMethod.equalPrincipalInterest,
        startDate: DateTime(2026, 7, 1),
        dueDate: DateTime(2027, 7, 1),
        totalPrincipalCents: 6000000,
        remainingPrincipalCents: 6000000,
        version: 1,
        subtype: DebtSubtypes.cardLoan,
        collectionAccountId: 'cc-1',
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 8, 1),
      );
      // schedule 含未还期次,但卡贷期次由账单日自动并入挂接卡。
      await t.pumpWidget(_harness(detail: _detail(debt: cardLoan)));
      await t.pumpAndSettle();
      final dock = t.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.onTap, isNull, reason: '卡贷手工记账停用(F48)');
      expect(dock.secondary.every((a) => a.onTap != null), isTrue);
      expect(dock.muted.every((a) => a.onTap != null), isTrue);
    });

    testWidgets('tap primary 立即记账 → 打开下期确认记账 dialog(复用既有逻辑)',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(
        detail: _detail(),
        accounts: [
          _assetAccount(id: 'acct-1', name: '招商银行储蓄卡'),
          _assetAccount(id: 'acct-2', name: '支付宝'),
        ],
      ));
      await t.pumpAndSettle();
      // dock primary(tooltip 区分 schedule 行内同名文字按钮)。
      await t.tap(find.byTooltip('立即记账'));
      await t.pumpAndSettle();
      // 打开既有 DebtRecordDialog(debt sem.dialogTitle=确认记账)。
      expect(find.text('确认记账'), findsWidgets);
      expect(find.textContaining('从账户'), findsOneWidget);
      // 下期 = 首个未还期次(e3,逾期 2026-06-01;e1/e2 已还)。
      expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('2026-06-01')),
        findsOneWidget,
      );
      // 收尾:取消关闭 dialog。
      await t.tap(find.widgetWithText(TextButton, '取消'));
      await t.pumpAndSettle();
    });

    testWidgets('tap 编辑 → push /debts/:id/edit 路由', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      final detail = _detail();
      when(() => debtRepo.get(any()))
          .thenAnswer((_) async => dartz.Right(detail));
      when(() => accountRepo.list())
          .thenAnswer((_) async => const dartz.Right(<Account>[]));
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
      final router = GoRouter(
        initialLocation: '/debts/d1',
        routes: [
          GoRoute(
            path: '/debts',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('DEBTS_LIST'))),
          ),
          GoRoute(
            path: '/debts/:id/edit',
            builder: (_, __) =>
                const Scaffold(body: Center(child: Text('EDIT_PAGE'))),
          ),
          GoRoute(
            path: '/debts/:id',
            builder: (_, __) => const DebtDetailPage(id: 'd1'),
          ),
        ],
      );
      await t.pumpWidget(MultiBlocProvider(
        providers: [
          BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
          BlocProvider<CurrencyBloc>.value(
              value: _FakeCurrencyBloc(const CurrencyState())),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('编辑'));
      await t.pumpAndSettle();
      // push 断言口径:go_router 14 的 imperative push 不改
      // currentConfiguration(探针实测),以「编辑页可见 + 详情仍在栈下」钉
      // push 叠栈语义(非 go 替换)。
      expect(find.text('EDIT_PAGE'), findsOneWidget);
      expect(find.byType(DebtDetailPage, skipOffstage: false), findsOneWidget,
          reason: 'push 叠栈:详情页仍在编辑页之下');
    });

    testWidgets('tap muted 删除钮 → 直达既有确认弹窗(零菜单)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('删除债务'));
      await t.pumpAndSettle();
      // 直达既有 confirmDeleteDebt 二次确认弹窗(无中间菜单)。
      expect(find.text('删除债务'), findsOneWidget);
      expect(find.textContaining('还款计划将一并删除'), findsOneWidget);
      // 收尾:取消关闭弹窗。
      await t.tap(find.widgetWithText(TextButton, '取消'));
      await t.pumpAndSettle();
    });

    testWidgets('FR-3(ADR-4) error 态恒渲染悬浮簇全禁用', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => debtRepo.get(any()))
          .thenAnswer((_) async => const dartz.Left(ServerFailure('加载失败')));
      when(() => accountRepo.list())
          .thenAnswer((_) async => const dartz.Right(<Account>[]));
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
      await t.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
            BlocProvider<CurrencyBloc>.value(
                value: _FakeCurrencyBloc(const CurrencyState())),
          ],
          child: const DebtDetailPage(id: 'd1'),
        ),
      ));
      await t.pumpAndSettle();
      // 恒渲染:error 态悬浮簇仍在(操作锚点恒定),全部动作禁用。
      expect(find.text('加载失败'), findsOneWidget);
      final dock = t.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.onTap, isNull, reason: 'error:主操作禁用');
      expect(dock.secondary.every((a) => a.onTap == null), isTrue,
          reason: 'error:次级全禁用');
      expect(dock.muted.every((a) => a.onTap == null), isTrue,
          reason: 'error:淡显组全禁用');
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('FR-2 标题注入:加载完成 set(counterparty);离开页面 clear',
        (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      GetIt.instance
          .registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
      await t.pumpWidget(_harness(detail: _detail()));
      await t.pumpAndSettle();
      expect(GetIt.instance<ShellDetailTitle>().value, '招商银行 · 个人住房贷款',
          reason: '加载完成 → counterparty 注入顶栏当前级');
      // 离开页面(unmount → dispose)→ 清理,不残留到后续页面。
      await t.pumpWidget(const MaterialApp());
      await t.pump();
      expect(GetIt.instance<ShellDetailTitle>().value, isNull);
    });

    testWidgets('FR-2 加载失败不注入标题(顶栏占位「…」由 shell 兜底)', (t) async {
      t.view.physicalSize = desktop;
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      GetIt.instance
          .registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
      final debtRepo = _MockDebtRepo();
      final accountRepo = _MockAccountRepo();
      when(() => debtRepo.get(any()))
          .thenAnswer((_) async => const dartz.Left(ServerFailure('加载失败')));
      when(() => accountRepo.list())
          .thenAnswer((_) async => const dartz.Right(<Account>[]));
      GetIt.instance.registerSingleton<AccountRepository>(accountRepo);
      await t.pumpWidget(MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DebtBloc>(create: (_) => DebtBloc(debtRepo)),
            BlocProvider<CurrencyBloc>.value(
                value: _FakeCurrencyBloc(const CurrencyState())),
          ],
          child: const DebtDetailPage(id: 'd1'),
        ),
      ));
      await t.pumpAndSettle();
      // 错误态页面可见且标题 port 保持 null。
      expect(find.text('加载失败'), findsOneWidget);
      expect(GetIt.instance<ShellDetailTitle>().value, isNull);
    });
  });
}
