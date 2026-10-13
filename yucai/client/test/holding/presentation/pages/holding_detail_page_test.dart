// Task 8 — widget tests for HoldingDetailPage(持仓详情 7 组件 + ⏳ 降级)。
//
// 验证(对齐 brief):
//   - 摘要(头部 symbol/现价 + 持仓卡 量/成本/市值/盈亏色块)渲染。
//   - 收益曲线(PerfCurveChart)渲染 + 日/月/年 tab 存在。
//   - 交易历史:trades 非空 → 筛选 chips + 列表;空 → 「暂无成交」。
//   - **⏳ 交易历史 isPendingBackend 降级**(本页核心,Task 5 触发不到):
//     listHoldingTransactions Left → HoldingError(isPendingBackend:true)
//     → 页面显示「⏳ 交易历史待后端」空态。
//   - F59 T3:底部 sticky 操作条退役 → 右下悬浮簇(加仓金圆 + 减仓/分红/拆分
//     次级,操作语义照原 handler 原样迁移 trade sheet)。
//   - 配置占比环图 + 关联目标 ⏳ 空态渲染。
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:design_kit/design_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/shell_detail_title.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/pages/holding_detail_page.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart';

class _MockHoldingRepo extends Mock implements HoldingRepository {}

/// Fake CurrencySettings — returns a fixed base currency code (Task 12
/// D-currency). HoldingDetailPage field-init reads
/// getIt<CurrencySettings>().getBaseCurrency() in _loadCurve → passed to
/// LoadHoldingCurveRequested → getHoldingPerformance(baseCurrency:).
class _FakeCurrencySettings extends Fake implements CurrencySettings {
  _FakeCurrencySettings(this._base) : _notifier = ValueNotifier<String>(_base);
  final String _base;
  final ValueNotifier<String> _notifier;

  @override
  ValueListenable<String> get listenable => _notifier;

  @override
  String get value => _base;

  @override
  Future<String> getBaseCurrency() async => _base;
}

Holding _holding({
  String id = 'h1',
  String symbol = 'AAPL',
  SecurityType type = SecurityType.stock,
  String currency = 'USD',
  double qty = 100,
  int avgCostCents = 15000, // $150.00
  int marketValueCents = 1750000, // $17,500.00
  int unrealizedPnlCents = 250000, // +$2,500.00
  int currentPriceCents = 17500, // $175.00
}) =>
    Holding(
      id: id,
      accountId: 'a1',
      securityId: 's1',
      securityName: 'Apple Inc.',
      securitySymbol: symbol,
      quantity: qty,
      avgCostCents: avgCostCents,
      marketValueCents: marketValueCents,
      unrealizedPnlCents: unrealizedPnlCents,
      version: 1,
      currentPriceCents: currentPriceCents,
      securityType: type,
      currency: currency,
    );

HoldingTransaction _tx({
  required String id,
  required TradeType type,
  required String date,
  double qty = 10,
  int priceCents = 15000,
  int amountCents = 150000,
  String? notes,
}) =>
    HoldingTransaction(
      id: id,
      accountId: 'a1',
      securityId: 's1',
      tradeType: type,
      quantity: qty,
      priceCents: priceCents,
      amountCents: amountCents,
      feeCents: 0,
      tradeDate: date,
      notes: notes,
    );

/// harness:注入 HoldingBloc(mock repo)。listHoldings 固定返回 [holding];
/// listHoldingTransactions 由 [tradesResult] 控制(Right(trades) 成功路径 /
/// Left(failure) ⏳ 降级路径)。
///
/// Task 12 D-currency:HoldingDetailPage field-init 经
/// getIt<CurrencySettings>() 读 base(透传 getHoldingPerformance),故 harness
/// 注册 fake(base 默认 CNY)。[baseCurrency] 让 D-currency 专项测试可注入 USD。
Widget _harness({
  required _MockHoldingRepo repo,
  required Holding holding,
  String baseCurrency = 'CNY',
}) {
  final getIt = GetIt.instance;
  // setUp 已注册默认 CNY;非默认 base 时替换为指定 code(D-currency 专项测试)。
  if (getIt.isRegistered<CurrencySettings>()) {
    getIt.unregister<CurrencySettings>();
  }
  getIt.registerSingleton<CurrencySettings>(
      _FakeCurrencySettings(baseCurrency));
  return MaterialApp(
    home: BlocProvider<HoldingBloc>(
      create: (_) => HoldingBloc(repo),
      child: HoldingDetailPage(id: holding.id),
    ),
  );
}

void _stubHolding(_MockHoldingRepo repo, Holding holding) {
  when(() => repo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((_) async => dartz.Right([holding]));
}

/// Task 13:曲线 stub。默认空(HoldingPerformance 空曲线)—— detail 页
/// LoadHoldingCurveRequested 在 initState 触发,需 stub 否则 MissingDummyError。
/// [points] / [realizedCents] 非空时模拟 server 真数据。
/// [annualizedPct] / [rangeAnnualizedPct] Task 7 XIRR(全期/区间,可空)。
/// [twrAnnualizedPct] Task 6 TWR(全期 时间加权,可空)。
/// [cagrAnnualizedPct] Task 2 C CAGR(全期 price-based 复合年化,可空)。
/// 含 baseCurrency named param(Task 12 D-currency;stub 用 any(named:) 兼容)。
void _stubCurve(
  _MockHoldingRepo repo, {
  List<PerfPoint> points = const [],
  int realizedCents = 0,
  double? annualizedPct,
  double? rangeAnnualizedPct,
  double? twrAnnualizedPct,
  double? cagrAnnualizedPct,
}) {
  when(() => repo.getHoldingPerformance(
        holdingId: any(named: 'holdingId'),
        range: any(named: 'range'),
        baseCurrency: any(named: 'baseCurrency'),
      )).thenAnswer((_) async => dartz.Right(HoldingPerformance(
        pricePoints: points,
        realizedCents: realizedCents,
        unrealizedCents: 0,
        totalCents: realizedCents,
        annualizedPct: annualizedPct,
        rangeAnnualizedPct: rangeAnnualizedPct,
        twrAnnualizedPct: twrAnnualizedPct,
        cagrAnnualizedPct: cagrAnnualizedPct,
      )));
}

final _trades = [
  _tx(id: 't1', type: TradeType.buy, date: '2026-01-15', qty: 100,
      priceCents: 15000, amountCents: -150000, notes: '首次建仓'),
  _tx(id: 't2', type: TradeType.dividend, date: '2026-03-01', qty: 100,
      priceCents: 50, amountCents: 5000, notes: 'Q1 分红'),
  _tx(id: 't3', type: TradeType.sell, date: '2026-05-10', qty: 10,
      priceCents: 17000, amountCents: 17000, notes: '部分止盈'),
];

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    getIt.reset();
    // Task 12 D-currency:HoldingDetailPage field-init 经 getIt 读 base。
    // 全局注册 fake(默认 CNY);_harness [baseCurrency] 覆盖仅 D-currency 专项
    // 测试需(它在 pumpWidget 前 unregister + 重注册 USD)。
    getIt.registerSingleton<CurrencySettings>(
        _FakeCurrencySettings('CNY'));
  });

  tearDown(() {
    if (getIt.isRegistered<CurrencySettings>()) {
      getIt.unregister<CurrencySettings>();
    }
  });

  // 高视口:desktop 表 + 右下悬浮簇全可见。
  // Task 7:1600 → 2400(XIRR 卡加入后 content 变长,在 1600 视口下需要滚动,
  // ensureVisible 的 alignment policy 无法对齐 goal card;调大至 2400 让整页
  // content 不需滚动避开)。注:production 布局正常(ListView 296px bottom
  // padding − 242px 簇占位 = 54px clearance,goal card 可点不被簇遮挡)。
  Future<void> setViewport(WidgetTester t) async {
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('renders header + position summary + curve + trades when loaded',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // ① 头部:symbol + 现价。
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailPrice')), findsOneWidget);
    // ② 持仓卡:市值 + 盈亏 pill + 持有量/成本价/现价/总成本。
    expect(find.byKey(const ValueKey('detailMarketValue')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailPnlPill')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailQty')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailAvgCost')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailCurPrice')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailTotalCost')), findsOneWidget);
    // ③ 收益曲线:title + 日/月/年 tab。
    expect(find.text('收益曲线'), findsOneWidget);
    expect(find.byKey(const ValueKey('perfRange-day')), findsOneWidget);
    expect(find.byKey(const ValueKey('perfRange-month')), findsOneWidget);
    expect(find.byKey(const ValueKey('perfRange-year')), findsOneWidget);
    // ④ 交易历史:标题 + 副标题 + 筛选 chips(全部/买入/卖出/分红/拆分)。
    expect(find.byKey(const ValueKey('detailTradesSub')), findsOneWidget);
    expect(find.byKey(const ValueKey('tradeFilter-all')), findsOneWidget);
    expect(find.byKey(const ValueKey('tradeFilter-buy')), findsOneWidget);
    expect(find.byKey(const ValueKey('tradeFilter-sell')), findsOneWidget);
    expect(find.byKey(const ValueKey('tradeFilter-dividend')), findsOneWidget);
    expect(find.byKey(const ValueKey('tradeFilter-split')), findsOneWidget);
    // trade rows 出现日期(all 筛选下 3 条)。
    expect(find.text('2026-01-15'), findsOneWidget);
    expect(find.text('2026-05-10'), findsOneWidget);
  });

  testWidgets('⏳ isPendingBackend keeps holding card + shows "⏳ 交易历史待后端" '
      'in trades region only (not whole page)', (t) async {
    // 本测试覆盖 Task 5 触发不到的 ⏳ 降级路径(brief 核心要求):
    // listHoldingTransactions ⏳ fail → HoldingDetailLoaded(isPendingBackend:true)。
    // brief 要求:交易历史区空态,但 holding 卡/曲线/配置仍可见。
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    // listHoldingTransactions ⏳ fail → HoldingDetailLoaded(isPendingBackend:true)。
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async =>
            const dartz.Left(ServerFailure('not implemented')));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // 主体 7 组件仍渲染(holding 仍带):头部 symbol + 持仓卡 + 曲线 + 配置/目标。
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailMarketValue')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailQty')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailTotalCost')), findsOneWidget);
    expect(find.text('收益曲线'), findsOneWidget);
    expect(find.text('配置占比'), findsOneWidget);
    expect(find.text('关联目标'), findsOneWidget);
    // 交易历史区子标题仍在(文案切换为 ⏳),但不渲染筛选 chips/表格。
    expect(find.byKey(const ValueKey('detailTradesSub')), findsOneWidget);
    expect(find.byKey(const ValueKey('tradeFilter-all')), findsNothing);
    // ⏳ 交易历史区降级空态(hourglass 图标 + 标题 + 文案)。
    expect(find.byKey(const ValueKey('pendingBackendTitle')), findsOneWidget);
    expect(find.byKey(const ValueKey('pendingBackendHint')), findsOneWidget);
    expect(find.text('⏳ 交易历史待后端'), findsOneWidget);
  });

  testWidgets('trade filter chips filter the trade list', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // all:3 条全在(buy 2026-01-15 / dividend 2026-03-01 / sell 2026-05-10)。
    expect(find.text('2026-01-15'), findsOneWidget);
    expect(find.text('2026-03-01'), findsOneWidget);
    // 点「买入」筛选 → 仅 buy 行。
    await t.tap(find.byKey(const ValueKey('tradeFilter-buy')));
    await t.pumpAndSettle();
    expect(find.text('2026-01-15'), findsOneWidget); // buy 仍在
    expect(find.text('2026-03-01'), findsNothing); // dividend 被过滤
    expect(find.text('2026-05-10'), findsNothing); // sell 被过滤
  });

  testWidgets('empty trades list shows 暂无成交 empty state', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => const dartz.Right([]));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    expect(find.text('暂无成交'), findsOneWidget);
  });

  testWidgets('F59 T3: dock renders 4 trade ops (加仓 primary + 减仓/分红/拆分 '
      'secondary),action bar keys gone', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // 底部 sticky 操作条退役:actBtn-* 零残留。
    expect(find.byKey(const ValueKey('actBtn-buy')), findsNothing);
    expect(find.byKey(const ValueKey('actBtn-sell')), findsNothing);
    expect(find.byKey(const ValueKey('actBtn-dividend')), findsNothing);
    expect(find.byKey(const ValueKey('actBtn-split')), findsNothing);
    // 簇四操作全在场(tooltip 承载原文字标签,零功能丢失)。
    expect(find.byTooltip('加仓'), findsOneWidget);
    expect(find.byTooltip('减仓'), findsOneWidget);
    expect(find.byTooltip('分红'), findsOneWidget);
    expect(find.byTooltip('拆分'), findsOneWidget);
  });

  testWidgets('renders allocation pie + goal nav card (Task 11: 接导航入口)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // ⑤ 配置占比:type 标签。
    expect(find.text('配置占比'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailAllocType')), findsOneWidget);
    // ⑥ 关联目标卡(导航入口 → /holdings/goals,Task 11 接真替换 ⏳D 存根)。
    expect(find.text('关联目标'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailGoalCard')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailGoalSubtitle')), findsOneWidget);
    expect(find.text('查看本持仓目标进度'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailGoalChevron')), findsOneWidget);
    // 原 ⏳D 存根内容应已彻底移除。
    expect(find.byKey(const ValueKey('detailGoalPendingTitle')), findsNothing);
    expect(find.text('⏳ 关联目标待后端'), findsNothing);
    expect(find.text('⏳ D'), findsNothing);
  });

  // Task 11(D-goal):详情页 _goalCard 是 GoalLinkPage 的进入入口。
  // 点击 → push '/holdings/goals' + extra={'holding': holding}。
  // 用 GoRouter harness 验证导航(plain MaterialApp 无 GoRouter 祖先时
  // context.push 会 assert-fail,故此处包一层带 stub 路由的 router)。
  testWidgets('tapping 关联目标 card pushes /holdings/goals with holding extra',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    // 本测试用 GoRouter harness(非 _harness),setUp 已注册 CurrencySettings
    // fake;防御性确认注册(D-currency: HoldingDetailPage field-init 经 getIt 读 base)。
    if (!getIt.isRegistered<CurrencySettings>()) {
      getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings('CNY'));
    }

    Object? pushedExtra;
    final router = GoRouter(
      initialLocation: '/holdings/${holding.id}',
      routes: [
        // 字面量 goals 路由必须先于 :id 通配,否则 "goals" 会被 :id 捕获。
        GoRoute(
          path: '/holdings/goals',
          builder: (_, state) {
            pushedExtra = state.extra;
            return const Scaffold(body: Center(child: Text('GOAL_LINK_STUB')));
          },
        ),
        GoRoute(
          path: '/holdings/:id',
          builder: (_, __) => BlocProvider<HoldingBloc>(
            create: (_) => HoldingBloc(repo),
            child: HoldingDetailPage(id: holding.id),
          ),
        ),
      ],
    );

    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();

    await t.ensureVisible(find.byKey(const ValueKey('detailGoalCard')));
    await t.tap(find.byKey(const ValueKey('detailGoalCard')));
    await t.pumpAndSettle();

    // 导航发生:GoalLinkPage stub 文案出现 + extra 携带 holding。
    expect(find.text('GOAL_LINK_STUB'), findsOneWidget);
    expect(pushedExtra, isA<Map<String, dynamic>>());
    expect((pushedExtra as Map<String, dynamic>)['holding'], same(holding));
  });

  testWidgets('curve range tab switch updates selected range', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // 默认「日」(近 30 天)。点「月」→ 副文案变「近 12 月」。
    expect(find.text('近 30 天'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('perfRange-month')));
    await t.pumpAndSettle();
    expect(find.text('近 12 月'), findsOneWidget);
    expect(find.text('近 30 天'), findsNothing);
  });

  // Task 13(holding-C):detail 曲线接 server getHoldingPerformance 真数据。
  // ②曲线 = pricePoints(2 点 → 非空态);⑥realized = server FIFO(foot 渲染)。
  testWidgets('Task 13: detail curve renders server pricePoints + realized',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo,
        points: [
          PerfPoint(time: DateTime(2026, 6, 1), value: 100),
          PerfPoint(time: DateTime(2026, 6, 30), value: 120),
        ],
        realizedCents: 5000);
    when(() => repo.listHoldingTransactions(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
        )).thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // ② 曲线:2 点 → 不渲染空态「该证券尚未接入行情源」(PerfCurveChart 空态文案)。
    expect(find.text('该证券尚未接入行情源'), findsNothing);
    expect(find.text('收益曲线'), findsOneWidget);
    // ⑥ realized:server FIFO 5000 cents($50.00)→ foot「已实现」cell 渲染。
    // foot realized 用 fmtRaw(无符号),故 $50.00。
    expect(find.text('\$50.00'), findsWidgets);
  });

  // Task 12 D-currency:detail page field-init 从 CurrencySettings 读 base →
  // 透传到 getHoldingPerformance(baseCurrency:)。验证非默认 base(USD)被传入。
  testWidgets(
      'Task 12 D-currency: passes baseCurrency (USD) to getHoldingPerformance',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    // harness 注册 baseCurrency=USD 的 CurrencySettings fake。
    await t.pumpWidget(_harness(repo: repo, holding: holding, baseCurrency: 'USD'));
    await t.pumpAndSettle();

    // initState _loadCurve 读 base 后 dispatch → repo 收到 baseCurrency='USD'。
    verify(() => repo.getHoldingPerformance(
          holdingId: any(named: 'holdingId'),
          range: any(named: 'range'),
          baseCurrency: 'USD',
        )).called(greaterThanOrEqualTo(1));
    // 绝未以默认空串调用(暴露 base 未透传回归)。
    verifyNever(() => repo.getHoldingPerformance(
          holdingId: any(named: 'holdingId'),
          range: any(named: 'range'),
          baseCurrency: '',
        ));
  });

  // Task 7 XIRR:detail 曲线 foot 区附 XIRR 行(全期 + 区间),null → 「—」。
  testWidgets(
      'Task 7: detail renders XIRR row (full + range) when annualizedPct non-null',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo,
        annualizedPct: 8.5,
        rangeAnnualizedPct: 12.3,
        points: [
          PerfPoint(time: DateTime(2026, 6, 1), value: 100),
          PerfPoint(time: DateTime(2026, 6, 30), value: 120),
        ]);
    when(() => repo.listHoldingTransactions(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
        )).thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // XIRR 行容器渲染 + 全期数值 + 区间数值。
    expect(find.byKey(const ValueKey('detailXirrCard')), findsOneWidget);
    expect(find.byKey(const ValueKey('detailXirrFull')), findsOneWidget);
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrFull'))).data,
        '+8.5%');
    expect(find.textContaining('12.3%'), findsOneWidget);
  });

  testWidgets('Task 7: detail shows — when holdingAnnualizedPct null (degraded)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo); // 默认 annualizedPct/rangeAnnualizedPct null
    when(() => repo.listHoldingTransactions(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
        )).thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // XIRR 卡仍渲染但数值显「—」(null 降级)。
    expect(find.byKey(const ValueKey('detailXirrCard')), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('detailXirrFull'))).data,
        '—');
    expect(t.widget<Text>(find.byKey(const ValueKey('detailXirrRange'))).data,
        '—');
  });

  // Task 6 TWR(时间加权):detail 卡新增 TWR 行,twrAnnualizedPct 非空 → 渲染数值。
  testWidgets(
      'Task 6: detail renders TWR row when twrAnnualizedPct non-null (dual-metric)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo,
        annualizedPct: 8.5,
        rangeAnnualizedPct: 12.3,
        twrAnnualizedPct: 7.2,
        points: [
          PerfPoint(time: DateTime(2026, 6, 1), value: 100),
          PerfPoint(time: DateTime(2026, 6, 30), value: 120),
        ]);
    when(() => repo.listHoldingTransactions(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
        )).thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // 卡标题改为「年化收益率」(双维度),label 含「资金加权」+「时间加权」。
    expect(find.text('年化收益率'), findsOneWidget);
    expect(find.text('资金加权 · 全期'), findsOneWidget);
    expect(find.text('资金加权 · 区间'), findsOneWidget);
    expect(find.text('时间加权 · 全期'), findsOneWidget);
    // XIRR 全期 +8.5%(detailXirrFull key 节点)。
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrFull'))).data,
        '+8.5%');
    // TWR 全期 +7.2%(detailXirrTwr key 节点)。
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrTwr'))).data,
        '+7.2%');
  });

  // Task 6 TWR 降级:twrAnnualizedPct null → TWR 行显「—」(独立于 XIRR)。
  testWidgets(
      'Task 6: detail shows — when twrAnnualizedPct null (TWR degraded, XIRR intact)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo,
        annualizedPct: 8.5,
        rangeAnnualizedPct: 12.3,
        // twrAnnualizedPct 故意省 → null(TWR 降级,但 XIRR 仍正常)。
        points: [
          PerfPoint(time: DateTime(2026, 6, 1), value: 100),
          PerfPoint(time: DateTime(2026, 6, 30), value: 120),
        ]);
    when(() => repo.listHoldingTransactions(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
        )).thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // XIRR 仍正常:全期 +8.5% / 区间 +12.3%。
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrFull'))).data,
        '+8.5%');
    // TWR 行渲染但显「—」(null 降级)。
    expect(find.text('时间加权 · 全期'), findsOneWidget);
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrTwr'))).data, '—');
  });

  // Task 2 C CAGR(复合年化 全期 price-based):cagrAnnualizedPct 非空 →
  // detailXirrCagr 渲染数值。与 XIRR(资金加权)+ TWR(时间加权)并列,
  // 三维度收益视角。
  testWidgets(
      'Task 2 C: detail shows CAGR row when cagrAnnualizedPct non-null',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo,
        annualizedPct: 8.5,
        rangeAnnualizedPct: 12.3,
        twrAnnualizedPct: 7.2,
        cagrAnnualizedPct: 6.5,
        points: [
          PerfPoint(time: DateTime(2026, 6, 1), value: 100),
          PerfPoint(time: DateTime(2026, 6, 30), value: 120),
        ]);
    when(() => repo.listHoldingTransactions(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
        )).thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // 复合年化 · 全期 label 渲染(detailXirrCagr key)。
    expect(find.text('复合年化 · 全期'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('detailXirrCagr'))).data,
        '+6.5%');
    // 卡副标题含「复合年化(CAGR)」。
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrSub'))).data,
        contains('复合年化(CAGR)'));
  });

  // Task 2 C CAGR 降级:cagrAnnualizedPct null → detailXirrCagr 显「—」
  // (独立于 XIRR/TWR;XIRR/TWR 仍正常)。
  testWidgets(
      'Task 2 C: detail shows — when cagrAnnualizedPct null (CAGR degraded)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    _stubCurve(repo,
        annualizedPct: 8.5,
        rangeAnnualizedPct: 12.3,
        twrAnnualizedPct: 7.2,
        // cagrAnnualizedPct 故意省 → null(CAGR 降级,但 XIRR/TWR 仍正常)。
        points: [
          PerfPoint(time: DateTime(2026, 6, 1), value: 100),
          PerfPoint(time: DateTime(2026, 6, 30), value: 120),
        ]);
    when(() => repo.listHoldingTransactions(
          accountId: any(named: 'accountId'),
          securityId: any(named: 'securityId'),
        )).thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // XIRR/TWR 仍正常:+8.5% / +7.2%。
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrFull'))).data,
        '+8.5%');
    expect(
        t.widget<Text>(find.byKey(const ValueKey('detailXirrTwr'))).data,
        '+7.2%');
    // CAGR 行渲染但显「—」(null 降级)。
    expect(find.text('复合年化 · 全期'), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const ValueKey('detailXirrCagr'))).data,
        '—');
  });

  // ───────── F59 T3:AppBar/操作条退役 + 悬浮簇(C')+ 标题注入 ─────────

  group('F59 T3 迁移', () {
    testWidgets('AppBar 退役;dock=加仓(primary)+[减仓,分红,拆分](secondary)'
        ' 常驻右下 28', (t) async {
      await setViewport(t);
      final repo = _MockHoldingRepo();
      final holding = _holding();
      _stubHolding(repo, holding);
      _stubCurve(repo);
      when(() => repo.listHoldingTransactions(
              accountId: any(named: 'accountId'),
              securityId: any(named: 'securityId')))
          .thenAnswer((_) async => dartz.Right(_trades));

      await t.pumpWidget(_harness(repo: repo, holding: holding));
      await t.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing, reason: 'F59:AppBar 退役');
      expect(find.byType(FloatingActionDock), findsOneWidget);
      final pos = t.widget<Positioned>(
          find.ancestor(
              of: find.byType(FloatingActionDock),
              matching: find.byType(Positioned)).first);
      expect(pos.right, 28);
      expect(pos.bottom, 28);
      // 三段映射:加仓进金圆;减仓/分红/拆分次级(减仓最贴 primary);
      // muted 空 —— 持仓模块无删除事件(brief「删除(若有」):无此操作不缺席造)。
      final dock = t.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.tooltip, '加仓');
      expect(dock.primary.onTap, isNotNull, reason: 'loaded → 可触发');
      expect(dock.secondary.map((a) => a.tooltip).toList(),
          ['减仓', '分红', '拆分']);
      expect(dock.secondary.every((a) => a.onTap != null), isTrue);
      expect(dock.muted, isEmpty);
    });

    testWidgets('dock tap → push /holdings/trade(操作语义照原 handler 迁移)',
        (t) async {
      await setViewport(t);
      final repo = _MockHoldingRepo();
      final holding = _holding();
      _stubHolding(repo, holding);
      _stubCurve(repo);
      when(() => repo.listHoldingTransactions(
              accountId: any(named: 'accountId'),
              securityId: any(named: 'securityId')))
          .thenAnswer((_) async => dartz.Right(_trades));
      if (!getIt.isRegistered<CurrencySettings>()) {
        getIt.registerSingleton<CurrencySettings>(_FakeCurrencySettings('CNY'));
      }

      Object? pushedExtra;
      final router = GoRouter(
        initialLocation: '/holdings/${holding.id}',
        routes: [
          GoRoute(
            path: '/holdings/trade',
            builder: (_, state) {
              pushedExtra = state.extra;
              return const Scaffold(body: Center(child: Text('TRADE_STUB')));
            },
          ),
          GoRoute(
            path: '/holdings/:id',
            builder: (_, __) => BlocProvider<HoldingBloc>(
              create: (_) => HoldingBloc(repo),
              child: HoldingDetailPage(id: holding.id),
            ),
          ),
        ],
      );

      await t.pumpWidget(MaterialApp.router(routerConfig: router));
      await t.pumpAndSettle();

      await t.tap(find.byTooltip('加仓'));
      await t.pumpAndSettle();

      expect(find.text('TRADE_STUB'), findsOneWidget);
      // 原 _onAction 语义原样:extra {'type': tradeType.name} 决定初始 TradeType。
      expect(pushedExtra, isA<Map<String, dynamic>>());
      expect((pushedExtra as Map<String, dynamic>)['type'], 'buy');
      // Drain the 3s AppToast timer _onAction schedules.
      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();
    });

    testWidgets('loading 恒渲染 dock:全动作禁用', (t) async {
      await setViewport(t);
      final repo = _MockHoldingRepo();
      final holding = _holding();
      // listHoldings 永不完成 → 保持 HoldingLoading(listHoldingTransactions
      // 并行拉取,需 stub 防 mock 返 null 抛型错)。
      final completer = Completer<dartz.Either<Failure, List<Holding>>>();
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) => completer.future);
      when(() => repo.listHoldingTransactions(
              accountId: any(named: 'accountId'),
              securityId: any(named: 'securityId')))
          .thenAnswer((_) async => const dartz.Right(<HoldingTransaction>[]));
      _stubCurve(repo);

      await t.pumpWidget(_harness(repo: repo, holding: holding));
      await t.pump(); // 不 settle(保持 HoldingLoading)。

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FloatingActionDock), findsOneWidget,
          reason: 'F59 FR-3:loading 态恒渲染悬浮簇');
      final dock = t.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.onTap, isNull, reason: 'loading:主操作禁用');
      expect(dock.secondary.every((a) => a.onTap == null), isTrue,
          reason: 'loading:次级全禁用');

      completer.complete(dartz.Right([holding]));
      await t.pumpAndSettle();
    });

    testWidgets('error 恒渲染 dock:全动作禁用', (t) async {
      await setViewport(t);
      final repo = _MockHoldingRepo();
      final holding = _holding();
      // listHoldings 失败 → HoldingError(真业务错误,无 holding)。
      when(() => repo.listHoldings(accountId: any(named: 'accountId')))
          .thenAnswer((_) async =>
              const dartz.Left<Failure, List<Holding>>(ServerFailure('读取失败')));
      when(() => repo.listHoldingTransactions(
              accountId: any(named: 'accountId'),
              securityId: any(named: 'securityId')))
          .thenAnswer((_) async => const dartz.Right(<HoldingTransaction>[]));
      _stubCurve(repo);

      await t.pumpWidget(_harness(repo: repo, holding: holding));
      await t.pumpAndSettle();

      expect(find.textContaining('读取失败'), findsOneWidget);
      expect(find.byType(FloatingActionDock), findsOneWidget,
          reason: 'F59 FR-3:error 态恒渲染悬浮簇');
      final dock = t.widget<FloatingActionDock>(find.byType(FloatingActionDock));
      expect(dock.primary.onTap, isNull, reason: 'error:主操作禁用');
      expect(dock.secondary.every((a) => a.onTap == null), isTrue,
          reason: 'error:次级全禁用');
    });

    testWidgets('标题注入:加载完成 set(持仓名);离开页面 clear', (t) async {
      await setViewport(t);
      final repo = _MockHoldingRepo();
      final holding = _holding();
      _stubHolding(repo, holding);
      _stubCurve(repo);
      when(() => repo.listHoldingTransactions(
              accountId: any(named: 'accountId'),
              securityId: any(named: 'securityId')))
          .thenAnswer((_) async => dartz.Right(_trades));
      if (!getIt.isRegistered<ShellDetailTitle>()) {
        getIt.registerLazySingleton<ShellDetailTitle>(ShellDetailTitle.new);
      }

      await t.pumpWidget(_harness(repo: repo, holding: holding));
      await t.pumpAndSettle();

      expect(getIt<ShellDetailTitle>().value, 'Apple Inc.',
          reason: '加载完成 → 持仓名(securityName)注入顶栏面包屑当前级');

      await t.pumpWidget(const MaterialApp());
      await t.pump();
      expect(getIt<ShellDetailTitle>().value, isNull);
    });
  });
}
