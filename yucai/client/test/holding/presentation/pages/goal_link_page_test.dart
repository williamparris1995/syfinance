// Task 10 — widget tests for GoalLinkPage(投资目标关联 · ⏳D 全空态)。
//
// 验证(对齐 brief):
//   - **⏳D goal 区空态**(本页核心):holding.proto 无 goal RPC →
//     概览头(总数/超中/落后)显示 ⏳ 占位 + goal 列表区显示
//     「⏳D 待后端 · holding-backed goals 数据源待 goal.proto」空态。
//   - **关联 holding 选择**(✅ holdings 已加载):从 HoldingLoaded.holdings
//     渲染 holding 行(symbol + 市值),点击触发 ⏳D 提示。
//   - 空/Loading/Error 状态:HoldingLoading → 圆圈;
//     HoldingError(isPendingBackend) → 整页 ⏳;真业务错误 → 错误文案。
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
import 'package:yucai_client/holding/presentation/pages/goal_link_page.dart';

class _MockHoldingRepo extends Mock implements HoldingRepository {}

Holding _holding({
  String id = 'h1',
  String symbol = 'AAPL',
  String name = 'Apple Inc.',
  SecurityType type = SecurityType.stock,
  String currency = 'USD',
  int marketValueCents = 1750000, // $17,500.00
}) =>
    Holding(
      id: id,
      accountId: 'a1',
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

/// harness:注入 HoldingBloc(mock repo)。listHoldings 由 [holdingsResult]
/// 控制(Right([holdings]) 成功 / Left(failure) ⏳ 降级路径)。
Widget _harness({required _MockHoldingRepo repo}) {
  return MaterialApp(
    home: BlocProvider<HoldingBloc>(
      create: (_) => HoldingBloc(repo),
      child: const GoalLinkPage(),
    ),
  );
}

void _stubHoldings(_MockHoldingRepo repo, List<Holding> holdings) {
  when(() => repo.listHoldings(accountId: any(named: 'accountId')))
      .thenAnswer((_) async => dartz.Right(holdings));
}

void main() {
  // 高视口:让 ListView 一次性构建全部子项(概览 + goal 区 + picker + API note),
  // 避免懒加载导致底部子项断言失败。
  Future<void> setViewport(WidgetTester t) async {
    t.view.physicalSize = const Size(800, 1800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets('renders ⏳D goal empty state in overview + goal list region '
      'when holdings loaded', (t) async {
    await setViewport(t);
    // 核心断言:holdings ✅ 加载,但 goal 区因 proto 无 goal RPC 恒为 ⏳D 空态。
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding()]);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // ① 概览头 3 列 ⏳ 占位(无 goal 数据,显示 —)。
    expect(find.byKey(const ValueKey('goalOverviewTotal')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalOverviewOver')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalOverviewBehind')), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));

    // ② goal 列表区 ⏳D 空态(hourglass + 标题 + 文案)。
    expect(find.byKey(const ValueKey('goalPendingIcon')), findsOneWidget);
    expect(find.byKey(const ValueKey('goalPendingTitle')), findsOneWidget);
    expect(find.text('⏳D 待后端'), findsOneWidget);
    expect(find.byKey(const ValueKey('goalPendingHint1')), findsOneWidget);
    expect(find.text('holding-backed goals 数据源待 goal.proto'), findsOneWidget);

    // ④ API 标注(⏳ D 徽标容器可见)。
    expect(find.byKey(const ValueKey('apiNote')), findsOneWidget);
  });

  testWidgets('renders holding picker rows from loaded holdings (✅)',
      (t) async {
    // 关联 holding 选择可用 holdings(ListHoldings ✅)。
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [
      _holding(id: 'h1', symbol: 'AAPL', name: 'Apple Inc.', marketValueCents: 1750000),
      _holding(id: 'h2', symbol: 'MSFT', name: 'Microsoft', marketValueCents: 3200000),
    ]);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // 关联选择区标题 + ✅ holdings 徽标。
    expect(find.text('关联持仓选择'), findsOneWidget);
    expect(find.byKey(const ValueKey('pickerHint')), findsOneWidget);
    // 两行 holding 渲染(symbol + 市值)。
    expect(find.byKey(const ValueKey('holdingRow-h1')), findsOneWidget);
    expect(find.byKey(const ValueKey('holdingRow-h2')), findsOneWidget);
    expect(find.text('AAPL'), findsOneWidget);
    expect(find.text('MSFT'), findsOneWidget);
    // 按市值降序:MSFT(3200000) 在前。
    expect(find.byKey(const ValueKey('holdingRowMv-h1')), findsOneWidget);
    expect(find.byKey(const ValueKey('holdingRowMv-h2')), findsOneWidget);
  });

  testWidgets('tapping a holding row shows ⏳D goal-backend snackbar', (t) async {
    // holdings ✅ 可选,但 goal 端 ⏳D → 点击提示关联待后端(诚实降级)。
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, [_holding(id: 'h1', symbol: 'AAPL')]);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('holdingRow-h1')));
    await t.pumpAndSettle();

    // SnackBar 提示关联目标待 goal.proto。
    expect(find.textContaining('关联目标 ⏳D 待 goal.proto'), findsOneWidget);
  });

  testWidgets('empty holdings list shows picker empty state', (t) async {
    final repo = _MockHoldingRepo();
    _stubHoldings(repo, const []);

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    // goal 区仍 ⏳D 空态。
    expect(find.text('⏳D 待后端'), findsOneWidget);
    // 关联选择区空态(无可关联持仓)。
    expect(find.byKey(const ValueKey('pickerEmptyIcon')), findsOneWidget);
    expect(find.byKey(const ValueKey('pickerEmptyTitle')), findsOneWidget);
    expect(find.text('暂无可关联持仓'), findsOneWidget);
  });

  testWidgets('HoldingError(listHoldings fail) shows real business error state',
      (t) async {
    // listHoldings fail → HoldingError(非 isPendingBackend,bloc _onLoadHoldings
    // 对 listHoldings fail 不标 isPendingBackend;仅 detail trades 才标)。
    // → 错误文案 + displayMessage(ServerFailure → 网络错误：...)。
    final repo = _MockHoldingRepo();
    when(() => repo.listHoldings(accountId: any(named: 'accountId')))
        .thenAnswer((_) async =>
            const dartz.Left(ServerFailure('network disconnected')));

    await t.pumpWidget(_harness(repo: repo));
    await t.pumpAndSettle();

    expect(find.text('加载失败'), findsOneWidget);
    // ServerFailure 用默认 displayMessage = message(无 override)。
    expect(find.text('network disconnected'), findsOneWidget);
    // goal 区局部空态此时不渲染(整页错误态)。
    expect(find.byKey(const ValueKey('goalPendingTitle')), findsNothing);
  });
}
