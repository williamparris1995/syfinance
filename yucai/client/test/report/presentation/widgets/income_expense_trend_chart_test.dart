import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/widgets/income_expense_trend_chart.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 构造单日 summary(byCategory 拆 income/expense,对齐 _incomeOf/_expenseOf 逻辑)。
DailySummary _day(String date, {int income = 0, int expense = 0}) => DailySummary(
      date: date,
      byCategory: [
        if (income > 0)
          CategoryTotal(
              categoryId: 'inc',
              name: '收入',
              accountType: 'income',
              amountCents: income),
        if (expense > 0)
          CategoryTotal(
              categoryId: 'exp',
              name: '支出',
              accountType: 'expense',
              amountCents: expense),
      ],
    );

void main() {
  testWidgets('有数据(≥2 点含正金额):渲染 LineChart + 收入/支出图例', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IncomeExpenseTrendChart(byDay: [
          _day('2026-07-01', income: 10000, expense: 5000),
          _day('2026-07-02', income: 8000, expense: 3000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
  });

  testWidgets('空数据(<2 点):显示空态,无 LineChart', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IncomeExpenseTrendChart(byDay: [
          _day('2026-07-01', income: 1000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('所选区间暂无收支记录'), findsOneWidget);
  });
}
