import 'package:dartz/dartz.dart' as dartz;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/report/presentation/pages/report_page.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockTxnRepo extends Mock implements TransactionRepository {}
class _MockTagRepo extends Mock implements TagRepository {}

const _tag = Tag(id: 'tag-1', name: '日常', color: '#b08d57', version: 1);

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

Widget _harness(TransactionRepository repo, {TagRepository? tagRepo}) {
  GetIt.instance.registerSingleton<TransactionRepository>(repo);
  // 标签下拉(F8)选项源;不传 → 未注册 → 空选项(下拉仅「全部标签」)。
  if (tagRepo != null) GetIt.instance.registerSingleton<TagRepository>(tagRepo);
  return const MaterialApp(home: ReportPage());
}

void main() {
  final getIt = GetIt.instance;

  setUpAll(() {
    // summary 的 scope: 命名参数用 any(),需 fallback(SummaryScope 枚举)。
    registerFallbackValue(SummaryScope.month);
  });

  setUp(() => getIt.reset());

  testWidgets('success:渲染汇总条 + 3 section 标题 + LineChart', (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    // 汇总条 4 stat label。
    expect(find.text('结余'), findsOneWidget);
    expect(find.text('日均'), findsOneWidget);
    // 3 section 标题。
    expect(find.text('收支趋势'), findsOneWidget);
    expect(find.text('支出分类占比'), findsOneWidget);
    expect(find.text('近 6 月对比'), findsOneWidget);
    // 趋势图渲染(月度对比 chart 在独立 FutureBuilder,有数据时也渲染)。
    expect(find.byType(LineChart), findsWidgets);
  });

  testWidgets('error:summary 返 Left → 显示错误消息 + 重试', (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
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
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    await t.tap(find.text('年'));
    await t.pumpAndSettle();

    // initState 只调 month scope;year scope 仅在 _switchScope → _load 后调用。
    verify(() => repo.summary(any(), any(),
            scope: SummaryScope.year, tagId: any(named: 'tagId')))
        .called(greaterThanOrEqualTo(1));
  });

  // ───────────────── P0-2:历史日期选择 ─────────────────

  testWidgets('默认:顶栏日期按钮显示当月（DateTime.now() 的年月）', (t) async {
    final repo = _MockTxnRepo();
    final now = DateTime.now();
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    // 默认 month scope → 「YYYY 年 M 月」标签(_SummaryStrip 也渲染同文案,
    // 故 descendant 限定到日期按钮内,避免歧义)。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reportDateButton')),
        matching: find.text('${now.year} 年 ${now.month} 月'),
      ),
      findsOneWidget,
    );
    // _load 用 DateTime.now() 的 year/month 调 summary：1 次（_load）+
    // 1 次（_loadMonthlyComparison 6 月窗口的最后一月 = 当前月）= 2 次。
    verify(() => repo.summary(now.year, now.month,
            scope: SummaryScope.month, tagId: any(named: 'tagId')))
        .called(2);
  });

  testWidgets('scope 切到年:日期按钮标签变「YYYY 年」(无月)', (t) async {
    final repo = _MockTxnRepo();
    final now = DateTime.now();
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    await t.tap(find.text('年'));
    await t.pumpAndSettle();

    // 日期按钮内:month 标签消失,year 标签出现(只剩年份)。
    final dateBtn = find.byKey(const ValueKey('reportDateButton'));
    expect(
      find.descendant(
          of: dateBtn,
          matching: find.text('${now.year} 年 ${now.month} 月')),
      findsNothing,
    );
    expect(
      find.descendant(
          of: dateBtn, matching: find.text('${now.year} 年')),
      findsOneWidget,
    );
  });

  testWidgets(
      '选历史月:打开 picker → 上一月 → 选 15 号 → summary 用上一月 year/month 重 load',
      (t) async {
    final repo = _MockTxnRepo();
    final now = DateTime.now();
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    await t.pumpWidget(_harness(repo));
    await t.pumpAndSettle();

    // 打开 picker：点顶栏日期按钮(lucide calendar icon)。
    await t.tap(find.byKey(const ValueKey('reportDateButton')));
    await t.pumpAndSettle();

    // Material date picker dialog 可见（CalendarDatePicker）。
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    // 上一月：Material 图标 chevron_left(lucide chevronLeft 是不同 icon,不冲突)。
    await t.tap(find.byIcon(Icons.chevron_left));
    await t.pumpAndSettle();

    // 选当月 15 号(任一月 15 都在可见网格中)。
    await t.tap(find.text('15'));
    await t.pumpAndSettle();

    // 确认 OK(en_US default locale)。
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();

    // 期望 year/month = now 的上一月(DateTime 构造器自动跨年处理)。
    final prev = DateTime(now.year, now.month - 1);
    verify(() => repo.summary(prev.year, prev.month,
            scope: SummaryScope.month, tagId: any(named: 'tagId')))
        .called(greaterThanOrEqualTo(1));
    // 标签同步更新(descendant 限定到日期按钮:_SummaryStrip 也渲染同文案,见 122-128)。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reportDateButton')),
        matching: find.text('${prev.year} 年 ${prev.month} 月'),
      ),
      findsOneWidget,
    );
  });

  // ───────────────── F8 FR-4/ADR-5:标签口径筛选 ─────────────────

  testWidgets('F8 FR-4: 选标签 → summary 以 tagId 重查(主图 + 近 6 月对比锚月)',
      (t) async {
    final repo = _MockTxnRepo();
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
        .thenAnswer((_) async => dartz.Right(_summary()));
    final tagRepo = _MockTagRepo();
    when(() => tagRepo.list()).thenAnswer((_) async => const dartz.Right([_tag]));
    await t.pumpWidget(_harness(repo, tagRepo: tagRepo));
    await t.pumpAndSettle();

    // 打开头部标签下拉 → 选「日常」。
    await t.tap(find.text('全部标签'));
    await t.pumpAndSettle();
    await t.tap(find.text('日常').last);
    await t.pumpAndSettle();

    // 主 summary(month scope)1 次 + 近 6 月对比锚月 6 次 = 7 次全部携带
    // tagId(重查口径一致,两图不脱节)。
    verify(() => repo.summary(any(), any(),
            scope: SummaryScope.month, tagId: 'tag-1'))
        .called(7);
  });

  testWidgets('F8 FR-4: 「全部」= 现状(tagId null,零变化)', (t) async {
    final repo = _MockTxnRepo();
    // 计数桩:mocktail 的 verify 会消费已匹配调用记录,累计断言用计数器
    // 而非重复 verify(同 matcher 二次 verify 只见新增)。
    var nullCalls = 0;
    var tagCalls = 0;
    when(() => repo.summary(any(), any(),
            scope: any(named: 'scope'), tagId: any(named: 'tagId')))
        .thenAnswer((inv) async {
      (inv.namedArguments[#tagId] as String?) == null
          ? nullCalls++
          : tagCalls++;
      return dartz.Right(_summary());
    });
    final tagRepo = _MockTagRepo();
    when(() => tagRepo.list()).thenAnswer((_) async => const dartz.Right([_tag]));
    await t.pumpWidget(_harness(repo, tagRepo: tagRepo));
    await t.pumpAndSettle();

    // 初始(全部):主图 1 + 近 6 月对比 6 = 7 次不带 tagId。
    expect(nullCalls, 7);
    expect(tagCalls, 0);

    // 选「日常」→ 7 次带 tag-1(全部侧不再新增)。
    await t.tap(find.text('全部标签'));
    await t.pumpAndSettle();
    await t.tap(find.text('日常').last);
    await t.pumpAndSettle();
    expect(tagCalls, 7);
    expect(nullCalls, 7);

    // 切回「全部」→ 再来 7 次不带 tagId(累计 14)。
    await t.tap(find.text('日常'));
    await t.pumpAndSettle();
    await t.tap(find.text('全部标签'));
    await t.pumpAndSettle();
    expect(nullCalls, 14);
    expect(tagCalls, 7);
  });
}
