// Task 11 — widget tests for GoalLinkPage(holding-D · goal 接真填)。
//
// 验证(对齐 brief):
//   - **真数据**:listInvestmentGoals → Right([2 goals,1 linked to holding.accountId,
//     1 other account])→ 客户端 filter 后渲染 1 goal + 概览头(总数1/超前或落后)+
//     该 holding 贡献占比。
//   - **空态**:Right([])或全属他账户 → 「该账户暂无投资目标」。
//   - **错误态**:Left(ServerFailure)→ 错误空态(displayMessage)。
//   - **关联 holding 选择**:同账户 holdings 渲染行(symbol + 市值),当前 holding 标记。
import 'dart:async';

import 'package:dartz/dartz.dart' as dartz;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/pages/goal_link_page.dart';

class _MockHoldingRepo extends Mock implements HoldingRepository {}

Holding _holding({
  String id = 'h1',
  String accountId = 'a1',
  String symbol = 'AAPL',
  String name = 'Apple Inc.',
  SecurityType type = SecurityType.stock,
  String currency = 'USD',
  int marketValueCents = 1750000, // $17,500.00
}) =>
    Holding(
      id: id,
      accountId: accountId,
      securityId: 's1',
      securityName: name,
      securitySymbol: symbol,
      quantity: 100,
      avgCostCents: 15000,
      marketValueCents: marketValueCents,
      unrealizedPnlCents: 250000,
      version: 1,
      currentPriceCents: 17500,
      securityType: type,
      currency: currency,
    );

GoalView _goal({
  String id = 'g1',
  String name = '退休金',
  String? linkedAccountId = 'a1',
  int targetCents = 20000000, // ¥200,000.00
  int currentCents = 12000000, // ¥120,000.00
  double progressPct = 60.0,
  bool isCompleted = false,
}) =>
    GoalView(
      id: id,
      name: name,
      targetCents: targetCents,
      currentCents: currentCents,
      progressPct: progressPct,
      linkedAccountId: linkedAccountId,
      isCompleted: isCompleted,
    );

/// harness:注入 HoldingBloc(mock repo,供 picker 的 listHoldings)+ 直接传
/// [holding] 与 [goalRepo](goal 区 FutureBuilder 调 listInvestmentGoals)。
Widget _harness({
  required _MockHoldingRepo repo,
  required Holding holding,
}) {
  return MaterialApp(
    home: BlocProvider<HoldingBloc>(
      create: (_) => HoldingBloc(repo),
      child: GoalLinkPage(holding: holding, goalRepo: repo),
    ),
  );
}

void _stubHoldings(_MockHoldingRepo repo, List<Holding> holdings) {
  when(() => repo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((_) async => dartz.Right(holdings));
}

void main() {
  // 高视口:让 ListView 一次性构建全部子项(概览 + goal 卡片 + picker + impl note),
  // 避免懒加载导致底部子项断言失败。
  Future<void> setViewport(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets(
      'renders filtered goals + overview + contribution when goals loaded',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    // listInvestmentGoals 返回 2 个 investment goal:1 个 linked 到 holding.accountId,
    // 1 个属他账户(客户端 filter 应只渲染前者)。
    when(() => repo.listInvestmentGoals()).thenAnswer((_) async => dartz.Right([
          _goal(
              id: 'g1',
              name: '退休金',
              linkedAccountId: 'a1', // == holding.accountId
              targetCents: 20000000,
              currentCents: 12000000,
              progressPct: 60.0),
          _goal(
              id: 'g2',
              name: '换车基金',
              linkedAccountId: 'a2', // 他账户 → 被 filter 掉
              progressPct: 90.0),
        ]));
    _stubHoldings(repo, [_holding()]);

    await t.pumpWidget(_harness(
      repo: repo,
      holding: _holding(marketValueCents: 10000000), // $100,000.00
    ));
    await t.pumpAndSettle();

    // ① 概览头:总数=1 / 落后=1(progress 60% < 80%)。
    expect(find.byKey(const ValueKey('goalOverviewTotal')), findsOneWidget);
    expect(find.text('1'), findsWidgets); // total=1, behind=1
    expect(find.byKey(const ValueKey('goalOverviewBehind')), findsOneWidget);

    // ② goal 卡片:只渲染 g1(g2 被 client filter 掉)。
    expect(find.byKey(const ValueKey('goalRow-g1')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalRow-g2')), findsNothing);
    expect(find.text('退休金'), findsOneWidget);
    expect(find.byKey(const ValueKey('goalRowName-g1')), findsOneWidget);
    // 进度 60.0%。
    expect(find.byKey(const ValueKey('goalRowPct-g1')), findsOneWidget);
    expect(find.text('60.0%'), findsOneWidget);
    // 该 holding 贡献占比 = 10000000 / 20000000 * 100 = 50.0%。
    expect(find.byKey(const ValueKey('goalRowContribution-g1')), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    // current / target(元)渲染。
    expect(find.byKey(const ValueKey('goalRowCurrent-g1')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalRowTarget-g1')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalRowBar-g1')), findsOneWidget);
  });

  testWidgets('overview buckets: over(>=100) / onTrack(80-100) / behind(<80)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    when(() => repo.listInvestmentGoals()).thenAnswer((_) async => dartz.Right([
          _goal(id: 'g1', progressPct: 120.0), // 超前
          _goal(id: 'g2', progressPct: 90.0), // 持平
          _goal(id: 'g3', progressPct: 50.0), // 落后
        ]));
    _stubHoldings(repo, [_holding()]);

    await t.pumpWidget(_harness(repo: repo, holding: _holding()));
    await t.pumpAndSettle();

    // 总数 3 / 超前 1 / 持平 1 / 落后 1。
    final total = find.descendant(
      of: find.byKey(const ValueKey('goalOverviewTotal')),
      matching: find.text('3'),
    );
    final over = find.descendant(
      of: find.byKey(const ValueKey('goalOverviewOver')),
      matching: find.text('1'),
    );
    final onTrack = find.descendant(
      of: find.byKey(const ValueKey('goalOverviewOnTrack')),
      matching: find.text('1'),
    );
    final behind = find.descendant(
      of: find.byKey(const ValueKey('goalOverviewBehind')),
      matching: find.text('1'),
    );
    expect(total, findsOneWidget);
    expect(over, findsOneWidget);
    expect(onTrack, findsOneWidget);
    expect(behind, findsOneWidget);
  });

  testWidgets('empty goals → 该账户暂无投资目标 empty state', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    when(() => repo.listInvestmentGoals())
        .thenAnswer((_) async => const dartz.Right([]));
    _stubHoldings(repo, [_holding()]);

    await t.pumpWidget(_harness(repo: repo, holding: _holding()));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('goalEmptyIcon')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalEmptyTitle')), findsOneWidget);
    expect(find.text('该账户暂无投资目标'), findsOneWidget);
    // 无 goal 卡片渲染。
    expect(find.byKey(const ValueKey('goalRow-g1')), findsNothing);
  });

  testWidgets('goals all linked to other account → empty state (client filter)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    when(() => repo.listInvestmentGoals()).thenAnswer((_) async => dartz.Right([
          _goal(id: 'g1', linkedAccountId: 'a2'), // 他账户
        ]));
    _stubHoldings(repo, [_holding()]); // holding.accountId = a1

    await t.pumpWidget(_harness(repo: repo, holding: _holding()));
    await t.pumpAndSettle();

    // 客户端 filter 后无 goal → 空态。
    expect(find.text('该账户暂无投资目标'), findsOneWidget);
    expect(find.byKey(const ValueKey('goalRow-g1')), findsNothing);
  });

  // sidebar 入口:context.go('/holdings/goals') 无 extra → router 兜底空 Holding
  // (accountId='')。此时不应 filter,显示全部投资目标(跨账户总览)。
  testWidgets(
      'empty holding (sidebar entry, accountId="") → shows ALL goals across accounts, no filter',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    when(() => repo.listInvestmentGoals()).thenAnswer((_) async => dartz.Right([
          _goal(id: 'g1', name: '退休金', linkedAccountId: 'a1', progressPct: 60.0),
          _goal(id: 'g2', name: '换车基金', linkedAccountId: 'a2', progressPct: 90.0),
          _goal(id: 'g3', name: '教育金', linkedAccountId: 'a3', progressPct: 110.0),
        ]));
    // 空 holding(accountId='')→ 同账户 picker 无意义,但 repo 仍需 stub。
    _stubHoldings(repo, [_holding(accountId: 'a1')]);

    // 镜像 router.dart 兜底空 Holding(accountId='', securitySymbol='')。
    const emptyHolding = Holding(
      id: '',
      accountId: '',
      securityId: '',
      securityName: '',
      securitySymbol: '',
      quantity: 0,
      avgCostCents: 0,
      marketValueCents: 0,
      unrealizedPnlCents: 0,
      version: 0,
    );

    await t.pumpWidget(
        _harness(repo: repo, holding: emptyHolding));
    await t.pumpAndSettle();

    // 不 filter:3 个跨账户 goal 全部渲染。
    expect(find.byKey(const ValueKey('goalRow-g1')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalRow-g2')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalRow-g3')), findsOneWidget);
    // 概览头总数 = 3。
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('goalOverviewTotal')),
            matching: find.text('3')),
        findsOneWidget);
    // 通用 header(不显具体 securitySymbol 的「· 」占位)。
    expect(find.text('投资目标(跨账户总览)'), findsOneWidget);
    // 跨账户总览无贡献口径 → 不显贡献占比 key。
    expect(find.byKey(const ValueKey('goalRowContribution-g1')), findsNothing);
    // 跨账户无 account 上下文 → 不显同账户持仓 picker。
    expect(find.text('同账户持仓'), findsNothing);
  });

  testWidgets(
      'empty holding (sidebar entry) with no goals → generic empty state (no 该账户)',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    when(() => repo.listInvestmentGoals())
        .thenAnswer((_) async => const dartz.Right([]));
    _stubHoldings(repo, const []);

    const emptyHolding = Holding(
      id: '',
      accountId: '',
      securityId: '',
      securityName: '',
      securitySymbol: '',
      quantity: 0,
      avgCostCents: 0,
      marketValueCents: 0,
      unrealizedPnlCents: 0,
      version: 0,
    );

    await t.pumpWidget(_harness(repo: repo, holding: emptyHolding));
    await t.pumpAndSettle();

    // 跨账户空态:通用文案,不显「该账户」。
    expect(find.text('暂无投资目标'), findsOneWidget);
    expect(find.text('该账户暂无投资目标'), findsNothing);
    expect(find.byKey(const ValueKey('goalEmptyIcon')), findsOneWidget);
  });

  testWidgets('Left(failure) → error state with displayMessage', (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    when(() => repo.listInvestmentGoals()).thenAnswer((_) async =>
        const dartz.Left(ServerFailure('goal service down')));
    _stubHoldings(repo, [_holding()]);

    await t.pumpWidget(_harness(repo: repo, holding: _holding()));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('goalErrorIcon')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalErrorTitle')), findsOneWidget);
    expect(find.text('加载失败'), findsOneWidget);
    // ServerFailure 无 displayMessage override → 直接返回 message。
    expect(find.byKey(const ValueKey('goalErrorMessage')), findsOneWidget);
    expect(find.text('goal service down'), findsOneWidget);
  });

  testWidgets('renders same-account holdings picker with current holding marked',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    when(() => repo.listInvestmentGoals())
        .thenAnswer((_) async => const dartz.Right([]));
    _stubHoldings(repo, [
      _holding(id: 'h1', symbol: 'AAPL', accountId: 'a1', marketValueCents: 1750000),
      _holding(id: 'h2', symbol: 'MSFT', accountId: 'a1', marketValueCents: 3200000),
      _holding(id: 'h3', symbol: 'BABA', accountId: 'a2', marketValueCents: 9900000),
    ]);

    await t.pumpWidget(_harness(repo: repo, holding: _holding(id: 'h1')));
    await t.pumpAndSettle();

    // 同账户(a1)的两行渲染;a2 的 BABA 被 client filter 掉。
    expect(find.byKey(const ValueKey('holdingRow-h1')), findsOneWidget);
    expect(find.byKey(const ValueKey('holdingRow-h2')), findsOneWidget);
    expect(find.byKey(const ValueKey('holdingRow-h3')), findsNothing);
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('MSFT'), findsOneWidget);
    expect(find.text('BABA'), findsNothing);
    // 当前 holding 标记。
    expect(find.text('当前'), findsOneWidget);
  });

  testWidgets('loading state shows circular indicator before future resolves',
      (t) async {
    await setViewport(t);
    final repo = _MockHoldingRepo();
    // 永不完成的 future → 卡在 loading。
    final completer = Completer<dartz.Either<Failure, List<GoalView>>>();
    when(() => repo.listInvestmentGoals())
        .thenAnswer((_) => completer.future);
    _stubHoldings(repo, [_holding()]);

    await t.pumpWidget(_harness(repo: repo, holding: _holding()));
    await t.pump();

    expect(find.byKey(const ValueKey('goalLoading')), findsOneWidget);
    expect(find.text('加载投资目标…'), findsOneWidget);
  });
}
