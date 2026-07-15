import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/widgets/monthly_comparison_bar.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

void main() {
  testWidgets('有 months:渲染 BarChart + 收入/支出图例', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MonthlyComparisonBar(months: [
          MonthlySummary(
              year: 2026, month: 2, incomeCents: 10000, expenseCents: 6000),
          MonthlySummary(
              year: 2026, month: 3, incomeCents: 11000, expenseCents: 7000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
  });

  testWidgets('空 months:空态提示,无 BarChart', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: MonthlyComparisonBar(months: const [])),
    ));
    await t.pumpAndSettle();

    expect(find.byType(BarChart), findsNothing);
    expect(find.text('暂无月度数据'), findsOneWidget);
  });
}
