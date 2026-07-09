// Task 9 — widget tests for PerformancePage(收益统计 6 组件 + ⏳C 降级)。
//
// 验证(对齐 brief):
//   - 概览头:总收益(Σ unrealized)+ 收益率 pill + 成本/市值 sub。
//   - 总收益曲线:PerfCurveChart 渲染 + 日/月/年 tab + ⏳C 空态(emptyHint)。
//   - 收益分解:unrealized ✅ 渲染;realized ⏳C 空态("⏳C 待后端")。
//   - 年化:累计 ✅;年化/基准 ⏳ 占位。
//   - 持仓贡献:每 holding unrealized 行(正绿负红)。
//   - 类型贡献:按 SecurityType 聚合行。
//   - Loading / Error 状态。
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/performance_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/holding/presentation/pages/performance_page.dart';
import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart';

/// 包一层 GoRouter(HoldingModuleNav 调 GoRouterState.of,需 GoRouter 祖先)。
Widget _routed(Widget child) => MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, __) => child),
        ],
      ),
    );

class _MockHoldingRepo extends Mock implements HoldingRepository {}

/// Fake CurrencySettings — returns a fixed base currency code (Task 12 D-currency)。
/// performance_page initState 经 getIt<CurrencySettings>().getBaseCurrency() 读 base,
/// 透传到 LoadPortfolioPerformanceRequested → getPortfolioPerformance(baseCurrency:)。
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
}) =>
    Holding(
      id: id,
      accountId: 'a1',
      securityId: 's_$id',
      securityName: 'Apple Inc.',
      securitySymbol: symbol,
      quantity: qty,
      avgCostCents: avgCostCents,
      marketValueCents: marketValueCents,
      unrealizedPnlCents: unrealizedPnlCents,
      version: 1,
      currentPriceCents: 17500,
      securityType: type,
      currency: currency,
    );

/// harness:注入 HoldingBloc + PerformanceBloc(mock repo)。
/// listHoldings / getPortfolioPerformance 由 stub 控制。
/// [baseCurrency] 注册 CurrencySettings fake(Task 12 D-currency;默认 CNY)。
Widget _harness({
  required _MockHoldingRepo repo,
  String baseCurrency = 'CNY',
}) {
  final getIt = GetIt.instance;
  if (!getIt.isRegistered<CurrencySettings>()) {
    getIt.registerSingleton<CurrencySettings>(
        _FakeCurrencySettings(baseCurrency));
  }
  return _routed(MultiBlocProvider(
    providers: [
      BlocProvider<HoldingBloc>(create: (_) => HoldingBloc(repo)),
      BlocProvider<PerformanceBloc>(create: (_) => PerformanceBloc(repo)),
    ],
    child: const PerformancePage(),
  ));
}

void _stubHoldings(_MockHoldingRepo repo, List<Holding> holdings) {
  when(() => repo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((_) async => dartz.Right(holdings));
}

/// 默认 perf stub:Left → PerformanceError(非 Loaded),各 ⏳C 空态分支激活
/// (曲线空 / realized「⏳C 待后端」/ 年化「⏳」/ 基准 mock)。对齐旧 degrade 断言。
/// 页面不为 perf error 显示整页错误(仅 HoldingError 才整页错误)。
/// 含 baseCurrency named param(Task 12 D-currency;stub 用 any(named:) 兼容)。
void _stubPerfEmpty(_MockHoldingRepo repo) {
  when(() => repo.getPortfolioPerformance(
        range: any(named: 'range'),
        accountId: any(named: 'accountId'),
        includeBenchmark: any(named: 'includeBenchmark'),
        baseCurrency: any(named: 'baseCurrency'),
      )).thenAnswer((_) async =>
      const dartz.Left(ServerFailure('perf not implemented')));
}

void main() {
  final getIt = GetIt.instance;

  setUp(() {
    getIt.reset();
  });

  tearDown(() {
    if (getIt.isRegistered<CurrencySettings>()) {
      getIt.unregister<CurrencySettings>();
    }
  });

  Future<void> setViewport(WidgetTester t) async {
    t.view.physicalSize = const Size(1200, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('renders overview header with summed unrealized + pct',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final h1 = _holding(
        id: 'h1',
        symbol: 'AAPL',
        type: SecurityType.stock,
        unrealizedPnlCents: 250000);
    final h2 = _holding(
        id: 'h2',
        symbol: 'MSFT',
        type: SecurityType.stock,
        avgCostCents: 30000,
        marketValueCents: 3200000,
        unrealizedPnlCents: 200000);
    _stubHoldings(repo, [h1, h2]);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ① 概览头:label + 总收益(+$4,500 = 250000+200000 cents)+ 收益率 pill。
    expect(find.byKey(const ValueKey('perfHeaderLabel')), findsOneWidget);
    expect(find.byKey(const ValueKey('perfTotalPnl')), findsOneWidget);
    // 收益率 = 450000 / (100*15000 + 100*30000) = 450000/4500000 = 10.00%。
    // 注:+10.00% 同时出现在概览 pill 与年化累计(相同公式),故取 key 节点的 text。
    expect(
        t.widget<Text>(find.byKey(const ValueKey('perfPnlPct'))).data,
        '+10.00%');
  });

  testWidgets('renders total curve (PerfCurveChart) with day/month/year tabs '
      'and ⏳C empty state', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding()]);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ② 曲线:title + 日/月/年 tab。
    expect(find.text('收益曲线'), findsOneWidget);
    expect(find.byKey(const ValueKey('perfRange-day')), findsOneWidget);
    expect(find.byKey(const ValueKey('perfRange-month')), findsOneWidget);
    expect(find.byKey(const ValueKey('perfRange-year')), findsOneWidget);
    // ⏳C 空态文案(本页覆盖的 emptyHint)。
    expect(find.text('⏳C 收益快照待后端'), findsOneWidget);
  });

  testWidgets('split card shows unrealized value + realized ⏳C degrade',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding(unrealizedPnlCents: 250000)]);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ③ 收益分解:标题 + ⏳C badge。
    expect(find.text('收益分解'), findsOneWidget);
    expect(find.byKey(const ValueKey('splitBadge')), findsOneWidget);
    // unrealized ✅ 数值(+$2,500.00)。
    expect(find.byKey(const ValueKey('splitUnrealizedVal')), findsOneWidget);
    // realized ⏳C 空态文案。
    expect(find.byKey(const ValueKey('splitRealizedVal')), findsOneWidget);
    expect(find.text('⏳C 待后端'), findsWidgets);
    expect(find.byKey(const ValueKey('splitRealizedHint')), findsOneWidget);
  });

  testWidgets('annualized card: cumulative computed, annual/benchmark ⏳',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding(unrealizedPnlCents: 250000)]);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ④ 年化:标题 + 年化(⏳)+ 累计(✅ 16.67% = 250000/1500000)。
    expect(find.text('年化收益率'), findsOneWidget);
    expect(find.byKey(const ValueKey('annualValue')), findsOneWidget);
    // 累计 = 250000 / (100*15000) = 16.67%。+16.67% 同时出现在概览 pill,
    // 故取 annualCumulative key 节点的 text。
    expect(
        t.widget<Text>(find.byKey(const ValueKey('annualCumulative'))).data,
        '+16.67%');
  });

  testWidgets('holding contribution rows render per holding (green/red)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final h1 =
        _holding(id: 'h1', symbol: 'AAPL', unrealizedPnlCents: 250000);
    final h2 =
        _holding(id: 'h2', symbol: 'TSLA', unrealizedPnlCents: -80000);
    _stubHoldings(repo, [h1, h2]);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ⑤ 持仓贡献:标题 + 两行(按 value 降序:AAPL 正在前,TSLA 负在后)。
    expect(find.text('持仓贡献'), findsOneWidget);
    expect(find.byKey(const ValueKey('contribHold-AAPL-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('contribHold-TSLA-1')), findsOneWidget);
  });

  testWidgets('type contribution aggregates by SecurityType', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    // 2 stock(+250000) + 1 bond(-30000) → stock + bond 两行。
    _stubHoldings(repo, [
      _holding(
          id: 'h1', symbol: 'AAPL', type: SecurityType.stock, unrealizedPnlCents: 250000),
      _holding(
          id: 'h2', symbol: '600519', type: SecurityType.stock, unrealizedPnlCents: 100000),
      _holding(
          id: 'h3', symbol: 'GBOND', type: SecurityType.bond, unrealizedPnlCents: -30000),
    ]);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ⑥ 类型贡献:标题 + 股票(+350000)+ 债券(-30000) 两行。
    expect(find.text('类型贡献'), findsOneWidget);
    expect(find.byKey(const ValueKey('contribType-stock-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('contribType-bond-1')), findsOneWidget);
  });

  testWidgets('empty holdings: contribution cards show empty states', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, const []);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // 持仓贡献空态。
    expect(find.text('暂无持仓'), findsOneWidget);
    // 类型贡献空态。
    expect(find.text('暂无盈亏'), findsOneWidget);
  });

  testWidgets('api-note ⏳C badge + text render at page bottom', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding()]);
    _stubPerfEmpty(repo);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('apiNoteBadge')), findsOneWidget);
    expect(find.byKey(const ValueKey('apiNoteText')), findsOneWidget);
  });

  // Task 13:PerformanceLoaded 真数据路径 —— ①曲线/③realized/④年化/⑤基准
  // 全部从 server PortfolioPerformance 渲染(非 ⏳C 空态)。
  testWidgets(
      'Task 13: renders server perf data (curve/realized/annualized/benchmark)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding(unrealizedPnlCents: 250000)]);
    // server 真数据:2 点曲线 + realized 80000 + 年化 12.3% + 基准「沪深300」。
    when(() => repo.getPortfolioPerformance(
          range: any(named: 'range'),
          accountId: any(named: 'accountId'),
          includeBenchmark: any(named: 'includeBenchmark'),
          baseCurrency: any(named: 'baseCurrency'),
        )).thenAnswer((_) async => dartz.Right(PortfolioPerformance(
          portfolioPoints: [
            PerfPoint(time: DateTime(2026, 6, 1), value: 100),
            PerfPoint(time: DateTime(2026, 6, 30), value: 120),
          ],
          realizedCents: 80000,
          unrealizedCents: 250000,
          totalCents: 330000,
          annualizedPct: 12.3,
          benchmarkName: '沪深300',
        )));

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ① 曲线:2 点 → 不渲染空态「⏳C 收益快照待后端」。
    expect(find.text('⏳C 收益快照待后端'), findsNothing);
    // ③ realized 真数据(+$800.00),不再「⏳C 待后端」;无 ⏳C badge。
    expect(find.text('⏳C 待后端'), findsNothing);
    expect(find.byKey(const ValueKey('splitBadge')), findsNothing);
    expect(t.widget<Text>(find.byKey(const ValueKey('splitRealizedVal'))).data,
        '+\$800.00');
    // ④ 年化真数据(+12.3%)。
    expect(t.widget<Text>(find.byKey(const ValueKey('annualValue'))).data,
        '+12.3%');
    // ⑤ 基准 sub 标签:server benchmarkName「沪深300」。
    expect(t.widget<Text>(find.byKey(const ValueKey('annualBenchLabel'))).data,
        '基准 沪深300');
  });

  testWidgets('shows CircularProgressIndicator while loading', (t) async {
    final repo = _MockHoldingRepo();
    // 用 Completer 阻塞 listHoldings(避免 Future.delayed 泄漏 pending timer)。
    final completer = Completer<dartz.Either<Failure, List<Holding>>>();
    when(() => repo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) => completer.future);
    _stubPerfEmpty(repo); // PerformanceBloc initState dispatch 需 stub。

    await t.pumpWidget(_harness(repo: repo));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // resolve 让 bloc 完成,避免 widget 树 dispose 时仍有 pending future。
    completer.complete(const dartz.Right(<Holding>[]));
    await t.pumpAndSettle();
  });

  testWidgets('shows error message on listHoldings failure', (t) async {
    final repo = _MockHoldingRepo();
    when(() => repo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async =>
            const dartz.Left(ServerFailure('boom')));
    _stubPerfEmpty(repo); // PerformanceBloc initState dispatch 需 stub。

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    expect(find.text('boom'), findsOneWidget);
  });

  // Task 12 D-currency:performance_page initState 从 CurrencySettings 读 base →
  // 透传到 getPortfolioPerformance(baseCurrency:)。验证非默认 base(USD)被传入。
  testWidgets(
      'Task 12 D-currency: passes baseCurrency (USD) to getPortfolioPerformance',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding()]);
    _stubPerfEmpty(repo);

    // harness 注册 baseCurrency=USD 的 CurrencySettings fake。
    await t.pumpWidget(_harness(repo: repo, baseCurrency: 'USD'));
    await t.pumpAndSettle();

    // initState 读 base 后 dispatch → repo 收到 baseCurrency='USD'。
    verify(() => repo.getPortfolioPerformance(
          range: any(named: 'range'),
          accountId: any(named: 'accountId'),
          includeBenchmark: any(named: 'includeBenchmark'),
          baseCurrency: 'USD',
        )).called(greaterThanOrEqualTo(1));
    // 绝未以默认空串调用(暴露 base 未透传回归)。
    verifyNever(() => repo.getPortfolioPerformance(
          range: any(named: 'range'),
          accountId: any(named: 'accountId'),
          includeBenchmark: any(named: 'includeBenchmark'),
          baseCurrency: '',
        ));
  });

  // Task 1 bench-mini(⑤ 基准对比条):有 benchmarkPoints → 中线条 + 超额。
  // 对齐 OD .bench-mini:我的组合 vs 基准 中线对比条 + 超额数值。
  testWidgets('bench-mini 渲染:有 benchmarkPoints → 中线条 + 超额', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding(unrealizedPnlCents: 250000)]);
    when(() => repo.getPortfolioPerformance(
          range: any(named: 'range'),
          accountId: any(named: 'accountId'),
          includeBenchmark: any(named: 'includeBenchmark'),
          baseCurrency: any(named: 'baseCurrency'),
        )).thenAnswer((_) async => dartz.Right(PortfolioPerformance(
              realizedCents: 100,
              unrealizedCents: 200,
              totalCents: 300,
              annualizedPct: 12.3,
              totalPct: 8.0,
              benchmarkName: '沪深300',
              benchmarkPoints: [
                PerfPoint(time: DateTime(2026, 1, 1), value: 100),
                PerfPoint(time: DateTime(2026, 7, 1), value: 105.4),
              ],
            )));

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // bench-mini 容器存在。
    expect(find.byKey(const ValueKey('benchmarkMiniBar')), findsOneWidget);
    // 我的年化 +12.3%(同时出现在 ④ annualValue 与 bench-mini 我的组合行)。
    expect(find.text('+12.3%'), findsWidgets);
    // 超额行渲染。
    expect(find.textContaining('超额'), findsOneWidget);
  });

  // Task 1 bench-mini 降级:无 benchmarkPoints → 容器渲染但无超额行。
  testWidgets('bench-mini 降级:无 benchmarkPoints → 不渲染超额', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding(unrealizedPnlCents: 250000)]);
    when(() => repo.getPortfolioPerformance(
          range: any(named: 'range'),
          accountId: any(named: 'accountId'),
          includeBenchmark: any(named: 'includeBenchmark'),
          baseCurrency: any(named: 'baseCurrency'),
        )).thenAnswer((_) async => dartz.Right(PortfolioPerformance(
              realizedCents: 0,
              unrealizedCents: 0,
              totalCents: 0,
              annualizedPct: 5.0,
              benchmarkPoints: const [],
            )));

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // 容器仍渲染(我的组合行在),但无 benchmarkPoints → 无超额行。
    expect(find.byKey(const ValueKey('benchmarkMiniBar')), findsOneWidget);
    expect(find.textContaining('超额'), findsNothing);
  });
}
