import 'package:dartz/dartz.dart' as dartz;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/report/presentation/pages/report_page.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockTxnRepo extends Mock implements TransactionRepository {}

/// 非空 summary(≥2 byDay 含 income/expense,触发 chart 渲染分支)。
MonthlySummary _summary({int income = 100000, int expense = 60000}) =>
    MonthlySummary(
      year: 2026,
      month: 7,
      incomeCents: income,
      expenseCents: expense,
      netCents: income - expense,
      dailyAvgCents: (income - expense) ~/ 30,
      byDay: [
        DailySummary(date: '2026-07-01', byCategory: [
          CategoryTotal(
              categoryId: 'c1',
              name: '工资',
              accountType: 'income',
              amountCents: income),
          CategoryTotal(
              categoryId: 'c2',
              name: '餐饮',
              accountType: 'expense',
              amountCents: expense),
        ]),
        DailySummary(date: '2026-07-02', byCategory: [
          CategoryTotal(
              categoryId: 'c2',
              name: '餐饮',
              accountType: 'expense',
              amountCents: 20000),
        ]),
      ],
      scope: SummaryScope.month,
    );

Widget _harness(TransactionRepository repo) {
  GetIt.instance.registerSingleton<TransactionRepository>(repo);
  return const MaterialApp(home: ReportPage());
}

/// 跨 RichText 文本查找(对齐 home_page_test 范式)。
Finder _textContaining(String needle) => find.byWidgetPredicate((w) {
      if (w is Text) {
        return (w.data ?? '').contains(needle) ||
            (w.textSpan?.toPlainText() ?? '').contains(needle);
      }
      if (w is RichText) return w.text.toPlainText().contains(needle);
      return false;
    });

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    // summary 的 scope: 命名参数用 any(),需 fallback(SummaryScope 枚举)。
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() => getIt.reset());

  testWidgets('success:渲染汇总条 + 3 section 标题 + LineChart', (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(), scope: any(named: 'scope')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    // 汇总条 4 stat label。
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('结余'), findsOneWidget);
    // 3 section 标题。
    expect(find.text('收支趋势'), findsOneWidget);
    expect(find.text('支出分类占比'), findsOneWidget);
    expect(find.text('近 6 月对比'), findsOneWidget);
    // 趋势图渲染(月度对比 chart 在独立 FutureBuilder,有数据时也渲染)。
    expect(find.byType(LineChart), findsWidgets);
  });

  testWidgets('error:summary 返 Left → 显示错误消息 + 重试', (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(), scope: any(named: 'scope')))
        .thenAnswer((_) async =>
            dartz.Left<Failure, MonthlySummary>(ServerFailure('连接失败')));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    // ReportPage 显示 f.message(非空)。
    expect(find.text('连接失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('period 切换:点「年」→ summary 以 scope:year 再次调用',
      (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(), scope: any(named: 'scope')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    await t.tap(find.text('年'));
    await t.pumpAndSettle();

    // initState 只调 month scope;year scope 仅在 _switchScope → _load 后调用。
    verify(() => repo.summary(any(), any(), scope: SummaryScope.year))
        .called(greaterThanOrEqualTo(1));
  });
}
