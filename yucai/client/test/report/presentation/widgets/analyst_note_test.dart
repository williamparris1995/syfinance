// F46 T2(2026-09-28):分析师解读小节 widget 测试(seam = AnalystNote 公共
// 构造;文案逐字 prototype v9 financial-report.html .ch7-llm)。
//
// 覆盖:idle 缺席/loading/done(SelectableText + 「由 {model} 生成」chip)/
// error(解读失败:{msg} + 重试)/免责脚注恒显/重新解读回调。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/report/presentation/widgets/analyst_note.dart';

Widget _host(AnalystNoteState state, {VoidCallback? onRegenerate}) =>
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              AnalystNote(state: state, onRegenerate: onRegenerate ?? () {}),
            ],
          ),
        ),
      ),
    );

void main() {
  group('三态(ADR-5:页面旁挂 state,idle = 小节缺席)', () {
    testWidgets('idle:小节整体缺席(入口 = 页头「AI 解读」按钮)', (tester) async {
      await tester.pumpWidget(_host(const AnalystNoteState.idle()));
      await tester.pumpAndSettle();
      expect(find.text('分析师解读'), findsNothing);
      expect(find.byType(AnalystNote), findsOneWidget); // 组件在树,idle 自隐
    });

    testWidgets('loading:「解读生成中…」逐字 + 脚注恒显', (tester) async {
      await tester.pumpWidget(_host(const AnalystNoteState.loading()));
      // loading 态有无限 spinner —— pump 不 settle(报告页同款约束)。
      await tester.pump();
      expect(find.text('分析师解读'), findsOneWidget);
      expect(find.text('解读生成中…'), findsOneWidget);
      expect(find.text('由 glm-4.6 生成'), findsNothing, reason: 'chip 仅 done');
    });

    testWidgets('done:SelectableText 呈现 + 「由 {model} 生成」chip', (tester) async {
      await tester.pumpWidget(_host(
          const AnalystNoteState.done('总体评价:本期储蓄率 45.6%…', 'glm-4.6')));
      await tester.pumpAndSettle();
      expect(find.text('分析师解读'), findsOneWidget);
      expect(find.text('由 glm-4.6 生成'), findsOneWidget);
      final sel = find
          .widgetWithText(SelectableText, '总体评价:本期储蓄率 45.6%…');
      expect(sel, findsOneWidget, reason: 'ADR-5:文本 SelectableText');
    });

    testWidgets('error:「解读失败:{msg}」+ 重试钮', (tester) async {
      await tester.pumpWidget(
          _host(const AnalystNoteState.error('LLM 调用失败:TimeoutException(open.bigmodel.cn)')));
      await tester.pumpAndSettle();
      expect(find.text('分析师解读'), findsOneWidget);
      expect(
          find.text(
              '解读失败:LLM 调用失败:TimeoutException(open.bigmodel.cn)'),
          findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    });
  });

  group('脚注与回调(v9 .llm-foot)', () {
    testWidgets('免责脚注恒显(三态都在)+ 逐字', (tester) async {
      const foot = '以上解读由 AI 基于脱敏汇总数据生成,仅供参考,不构成投资建议;数字以报告为准。';
      for (final s in [
        const AnalystNoteState.loading(),
        const AnalystNoteState.done('t', 'm'),
        const AnalystNoteState.error('e'),
      ]) {
        await tester.pumpWidget(_host(s));
        await tester.pump(); // loading 态 spinner 不 settle
        expect(find.text(foot), findsOneWidget, reason: '脚注恒显:$s');
      }
    });

    testWidgets('「重新解读」→ onRegenerate(done 态)', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_host(const AnalystNoteState.done('t', 'm'),
          onRegenerate: () => calls++));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新解读'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('「重试」→ onRegenerate(error 态,同一缝)', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_host(const AnalystNoteState.error('boom'),
          onRegenerate: () => calls++));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(calls, 1);
    });
  });

  group('守门(硬约束)', () {
    testWidgets('小节头:标题左、chip 右(评审 R3,对齐 v9 .llm-head)',
        (tester) async {
      await tester.pumpWidget(
          _host(const AnalystNoteState.done('t', 'glm-4.6')));
      await tester.pump();
      // chip 的最近 Row 祖先 = 小节头 Row;断言 spaceBetween 撑开两端。
      final headRow = tester.widget<Row>(find
          .ancestor(
              of: find.text('由 glm-4.6 生成'),
              matching: find.byType(Row))
          .first);
      expect(headRow.mainAxisAlignment, MainAxisAlignment.spaceBetween);
    });

    test('源码静态检查:无裸色/AppColors/不 import data 层(llm_http 等)', () {
      final src = File('lib/report/presentation/widgets/analyst_note.dart')
          .readAsStringSync();
      expect(src.contains('Color(0x'), isFalse, reason: '禁裸色');
      expect(src.contains('AppColors'), isFalse, reason: 'legacy 色禁用');
      expect(src.contains('llm_http'), isFalse,
          reason: 'presentation 不直接 import llm_http');
      expect(src.contains('llm_mda_narrator'), isFalse,
          reason: '页面经 MdaNarrator port,不碰实现');
    });
  });
}
