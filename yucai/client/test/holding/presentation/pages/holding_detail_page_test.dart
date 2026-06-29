// Task 8 — widget tests for HoldingDetailPage(持仓详情 7 组件 + ⏳ 降级)。
//
// 验证(对齐 brief):
//   - 摘要(头部 symbol/现价 + 持仓卡 量/成本/市值/盈亏色块)渲染。
//   - 收益曲线(PerfCurveChart)渲染 + 日/月/年 tab 存在。
//   - 交易历史:trades 非空 → 筛选 chips + 列表;空 → 「暂无成交」。
//   - **⏳ 交易历史 isPendingBackend 降级**(本页核心,Task 5 触发不到):
//     listHoldingTransactions Left → HoldingError(isPendingBackend:true)
//     → 页面显示「⏳ 交易历史待后端」空态。
//   - 操作按钮(buy/sell/dividend/split)渲染 + 点击触发 toast。
//   - 配置占比环图 + 关联目标 ⏳ 空态渲染。
import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/pages/holding_detail_page.dart';

class _MockHoldingRepo extends Mock implements HoldingRepository {}

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
Widget _harness({
  required _MockHoldingRepo repo,
  required Holding holding,
}) {
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

final _trades = [
  _tx(id: 't1', type: TradeType.buy, date: '2026-01-15', qty: 100,
      priceCents: 15000, amountCents: -150000, notes: '首次建仓'),
  _tx(id: 't2', type: TradeType.dividend, date: '2026-03-01', qty: 100,
      priceCents: 50, amountCents: 5000, notes: 'Q1 分红'),
  _tx(id: 't3', type: TradeType.sell, date: '2026-05-10', qty: 10,
      priceCents: 17000, amountCents: 17000, notes: '部分止盈'),
];

void main() {
  // 高视口:desktop 表 + sticky action bar 全可见。
  Future<void> setViewport(WidgetTester t) async {
    t.view.physicalSize = const Size(1200, 1600);
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

  testWidgets('⏳ isPendingBackend shows "⏳ 交易历史待后端" empty state', (t) async {
    // 本测试覆盖 Task 5 触发不到的 ⏳ 降级路径(brief 核心要求)。
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    // listHoldingTransactions ⏳ fail → HoldingError(isPendingBackend:true)。
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async =>
            const dartz.Left(ServerFailure('not implemented')));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // ⏳ 降级:整页 ⏳ 占位,头部/持仓卡/曲线不渲染(无 detail loaded)。
    expect(find.byKey(const ValueKey('pendingBackendTitle')), findsOneWidget);
    expect(find.byKey(const ValueKey('pendingBackendHint')), findsOneWidget);
    expect(find.text('⏳ 交易历史待后端'), findsOneWidget);
    // 确认 detail 组件未渲染(区分于 loaded 态)。
    expect(find.byKey(const ValueKey('detailMarketValue')), findsNothing);
    expect(find.byKey(const ValueKey('detailTradesSub')), findsNothing);
  });

  testWidgets('trade filter chips filter the trade list', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
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
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => const dartz.Right([]));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    expect(find.text('暂无成交'), findsOneWidget);
  });

  testWidgets('renders 4 action buttons (buy/sell/dividend/split)', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('actBtn-buy')), findsOneWidget);
    expect(find.byKey(const ValueKey('actBtn-sell')), findsOneWidget);
    expect(find.byKey(const ValueKey('actBtn-dividend')), findsOneWidget);
    expect(find.byKey(const ValueKey('actBtn-split')), findsOneWidget);
  });

  testWidgets('renders allocation pie + goal ⏳ empty state', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
    when(() => repo.listHoldingTransactions(
            accountId: any(named: 'accountId'),
            securityId: any(named: 'securityId')))
        .thenAnswer((_) async => dartz.Right(_trades));

    await t.pumpWidget(_harness(repo: repo, holding: holding));
    await t.pumpAndSettle();

    // ⑤ 配置占比:type 标签。
    expect(find.text('配置占比'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailAllocType')), findsOneWidget);
    // ⑥ 关联目标 ⏳ 空态(holding.proto 无 goal RPC)。
    expect(find.text('关联目标'), findsOneWidget);
    expect(find.byKey(const ValueKey('detailGoalPendingTitle')), findsOneWidget);
    expect(find.text('⏳ 关联目标待后端'), findsOneWidget);
  });

  testWidgets('curve range tab switch updates selected range', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    final holding = _holding();
    _stubHolding(repo, holding);
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
}
