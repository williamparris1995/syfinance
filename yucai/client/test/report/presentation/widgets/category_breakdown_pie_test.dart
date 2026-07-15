import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/widgets/category_breakdown_pie.dart';

void main() {
  testWidgets('有 slices:渲染 PieChart + 图例分类名', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CategoryBreakdownPie(slices: [
          CategorySlice(id: 'c1', name: '餐饮', amountCents: 60000),
          CategorySlice(id: 'c2', name: '交通', amountCents: 30000),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    // total>0 → 渲染真实 PieChart sections(非空态灰环)。
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
  });

  testWidgets('空 slices(total=0):空态提示', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: CategoryBreakdownPie(slices: const [])),
    ));
    await t.pumpAndSettle();

    // total≤0 → centerText 显示 emptyLabel(默认「暂无支出记录」)+ 图例「暂无分类数据」。
    expect(find.text('暂无支出记录'), findsOneWidget);
    expect(find.text('暂无分类数据'), findsOneWidget);
  });
}
