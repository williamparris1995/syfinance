// Task 2 C benchmark⑤+CAGR — widget tests for PerfCurveChart rebase 100 +
// benchmark 灰虚线 + 图例。
//
// 验证(对齐 brief Step 6):
//   - 空 points(< 2)→ 空态(emptyHint),不渲染 LineChart。
//   - portfolio >= 2 + benchmark >= 2 → 2 LineChartBarData(portfolio + benchmark)。
//   - _rebase 100:首点 y=100,后续 y=value/start×100(量纲归一,斜率可比)。
//   - benchmark < 2 → 单 LineChartBarData(仅 portfolio),无图例。
//   - 图例(legend):_hasBenchmark 时渲染「组合」+ benchmarkName。
//   - rebase start=0 防除零 → 100 平线(y=100)。
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/holding/presentation/widgets/perf_curve_chart.dart';

PerfPoint _p(DateTime t, double v) => PerfPoint(time: t, value: v);

Widget _routed(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('empty state: < 2 portfolio points → emptyHint, no LineChart',
      (t) async {
    await t.pumpWidget(_routed(PerfCurveChart(
      points: [_p(DateTime(2026, 7, 1), 100)],
      emptyHint: '⏳ TEST EMPTY',
    )));
    await t.pumpAndSettle();

    expect(find.text('⏳ TEST EMPTY'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets(
      'Task 2: portfolio + benchmark (>=2 each) → 2 LineChartBarData + legend',
      (t) async {
    await t.pumpWidget(_routed(PerfCurveChart(
      points: [
        _p(DateTime(2026, 6, 1), 100),
        _p(DateTime(2026, 6, 15), 110),
        _p(DateTime(2026, 6, 30), 120),
      ],
      benchmarkPoints: [
        _p(DateTime(2026, 6, 1), 1000),
        _p(DateTime(2026, 6, 30), 1050),
      ],
      benchmarkName: '沪深300',
    )));
    await t.pumpAndSettle();

    // LineChart 渲染。
    final chart = t.widget<LineChart>(find.byType(LineChart));
    // 2 LineChartBarData:portfolio + benchmark。
    expect(chart.data.lineBarsData.length, 2);

    // 图例:_hasBenchmark → 渲染「组合」+ benchmarkName。
    expect(find.byKey(const ValueKey('perfCurveLegend')), findsOneWidget);
    expect(find.text('组合'), findsOneWidget);
    expect(find.text('沪深300'), findsOneWidget);
  });

  testWidgets('Task 2: _rebase100 portfolio spots start=100, slope = value/start*100',
      (t) async {
    await t.pumpWidget(_routed(PerfCurveChart(
      points: [
        _p(DateTime(2026, 6, 1), 100),
        _p(DateTime(2026, 6, 15), 110),
        _p(DateTime(2026, 6, 30), 120),
      ],
    )));
    await t.pumpAndSettle();

    final chart = t.widget<LineChart>(find.byType(LineChart));
    final portSpots = chart.data.lineBarsData.single.spots;
    // 起点 = 100(rebase)。
    expect(portSpots.first.y, 100);
    // 110/100*100 = 110;120/100*100 = 120(相对增长)。
    expect(portSpots[1].y, closeTo(110, 0.001));
    expect(portSpots[2].y, closeTo(120, 0.001));
    // X = 索引(0,1,2)。
    expect(portSpots.first.x, 0);
    expect(portSpots.last.x, 2);
    // minY/maxY 自适应(~100 附近,非 0-1)。
    expect(chart.data.minY, 100);
    expect(chart.data.maxY, 120);
  });

  testWidgets(
      'Task 2: _rebase100 normalizes benchmark to 100 start (cross-unit slope compare)',
      (t) async {
    await t.pumpWidget(_routed(PerfCurveChart(
      points: [
        _p(DateTime(2026, 6, 1), 10000), // portfolio 元
        _p(DateTime(2026, 6, 30), 12000),
      ],
      benchmarkPoints: [
        _p(DateTime(2026, 6, 1), 1000.0), // benchmark 点位(不同量纲)
        _p(DateTime(2026, 6, 30), 1050.0),
      ],
    )));
    await t.pumpAndSettle();

    final chart = t.widget<LineChart>(find.byType(LineChart));
    final portSpots = chart.data.lineBarsData[0].spots;
    final benchSpots = chart.data.lineBarsData[1].spots;
    // portfolio:12000/10000*100 = 120。
    expect(portSpots.first.y, 100);
    expect(portSpots.last.y, closeTo(120, 0.001));
    // benchmark:1050/1000*100 = 105(同起点 100,斜率与 portfolio 可比)。
    expect(benchSpots.first.y, 100);
    expect(benchSpots.last.y, closeTo(105, 0.001));
  });

  testWidgets(
      'Task 2: _rebase100 start=0 → 100 平线(防除零,对齐 §9 风险 3)', (t) async {
    await t.pumpWidget(_routed(PerfCurveChart(
      points: [
        _p(DateTime(2026, 6, 1), 0), // start=0 → 防除零
        _p(DateTime(2026, 6, 30), 100),
      ],
    )));
    await t.pumpAndSettle();

    final chart = t.widget<LineChart>(find.byType(LineChart));
    final portSpots = chart.data.lineBarsData.single.spots;
    // start=0 退化:两点都 y=100(平线,避免除零 NaN)。
    expect(portSpots.first.y, 100);
    expect(portSpots.last.y, 100);
  });

  testWidgets(
      'Task 2: benchmark < 2 points → single LineChartBarData (portfolio only), no legend',
      (t) async {
    await t.pumpWidget(_routed(PerfCurveChart(
      points: [
        _p(DateTime(2026, 6, 1), 100),
        _p(DateTime(2026, 6, 30), 120),
      ],
      benchmarkPoints: [
        // 仅 1 点 → _rebase100 退化为 100 平线,视为无基准。
        _p(DateTime(2026, 6, 30), 1050),
      ],
      benchmarkName: '沪深300',
    )));
    await t.pumpAndSettle();

    final chart = t.widget<LineChart>(find.byType(LineChart));
    // 仅 portfolio(单点 benchmark 不绘第二线,避免无意义 100 平线)。
    expect(chart.data.lineBarsData.length, 1);
    // 图例不渲染(_hasBenchmark=false)。
    expect(find.byKey(const ValueKey('perfCurveLegend')), findsNothing);
    expect(find.text('组合'), findsNothing);
  });

  testWidgets(
      'Task 2: benchmark 灰虚线 — barWidth 1.4, color #8A8A8A, dashArray [4,3]',
      (t) async {
    await t.pumpWidget(_routed(PerfCurveChart(
      points: [
        _p(DateTime(2026, 6, 1), 100),
        _p(DateTime(2026, 6, 30), 120),
      ],
      benchmarkPoints: [
        _p(DateTime(2026, 6, 1), 1000),
        _p(DateTime(2026, 6, 30), 1050),
      ],
    )));
    await t.pumpAndSettle();

    final chart = t.widget<LineChart>(find.byType(LineChart));
    final benchBar = chart.data.lineBarsData[1];
    expect(benchBar.color, const Color(0xFF8A8A8A));
    expect(benchBar.barWidth, 1.4);
    expect(benchBar.dashArray, [4, 3]);
    // portfolio barWidth 1.8(主位更粗)。
    expect(chart.data.lineBarsData[0].barWidth, 1.8);
    expect(chart.data.lineBarsData[0].dashArray, isNull); // 实线
  });
}
