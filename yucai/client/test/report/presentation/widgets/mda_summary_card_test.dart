/// F44 T3 总览诊断摘要卡 widget 测试(seam = MdaSummaryCard 公共构造)。
///
/// 覆盖:两态(有发现 = 计数头 + top-3 + 「查看全部」;零发现 = 单行
/// 健康徽章)/ top-3 截断(第 4 条起不渲染)/ 「查看全部」onViewAll 触发。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/presentation/widgets/mda_summary_card.dart';

// ── fixture(手算 oracle:计数由 fixture 自身给出,不由被测代码反推)──

/// 速构:第 n 条发现(结论文案 $n)。
MdaFinding _f(int n, MdaSeverity s) => MdaFinding(
      ruleId: 'X$n',
      severity: s,
      conclusion: '结论文案 $n',
      advice: '建议 $n',
    );

/// 5 条(2 warn + 3 info,按 findings 序):top-3 = 结论文案 1..3。
final _five = MdaSection.create(findings: [
  _f(1, MdaSeverity.warn),
  _f(2, MdaSeverity.warn),
  _f(3, MdaSeverity.info),
  _f(4, MdaSeverity.info),
  _f(5, MdaSeverity.info),
]);

/// 原型 v8 演示口径(0 风险 2 提示 1 关注)。
final _proto = MdaSection.create(findings: const [
  MdaFinding(
    ruleId: 'R2',
    severity: MdaSeverity.warn,
    conclusion: '购物超预算:4,120/3,500(118%)',
    advice: '建议复盘该类别或上调预算至实际水平',
  ),
  MdaFinding(
    ruleId: 'R4',
    severity: MdaSeverity.warn,
    conclusion: '可能闲置订阅:XX 音乐会员(年付 288.00,月度等价 24.00)',
    advice: '若仍在使用,记一笔时请关联该订阅',
  ),
  MdaFinding(
    ruleId: 'R5',
    severity: MdaSeverity.info,
    conclusion: '大额单笔:9 月 2 日单笔 3,600.00(年卡)',
    advice: '若为年付/预付类支出属正常现象',
  ),
]);

Widget _wrap(Widget child) => MaterialApp(
    theme: ThemeData(extensions: [YucaiTheme.light()]),
    home: Scaffold(body: child));

void main() {
  testWidgets('有发现态:计数头 + 基于 chip + top-3 + 「查看全部 ↓」', (t) async {
    await t.pumpWidget(_wrap(MdaSummaryCard(section: _proto, onViewAll: () {})));
    await t.pumpAndSettle();

    // 计数头(原型 .diag-full .card-head 文案)。
    expect(find.text('诊断摘要 · 0 风险 2 提示 1 关注'), findsOneWidget);
    expect(find.text('基于本期数据'), findsOneWidget);

    // top-3 结论直出。
    expect(find.text('购物超预算:4,120/3,500(118%)'), findsOneWidget);
    expect(find.text('大额单笔:9 月 2 日单笔 3,600.00(年卡)'), findsOneWidget);

    // 「查看全部 ↓」锚滚入口。
    expect(find.byKey(const ValueKey('mdaViewAllLink')), findsOneWidget);
    expect(find.text('查看全部 ↓'), findsOneWidget);

    // 健康徽章不出现在有发现态。
    expect(find.textContaining('未发现需关注项'), findsNothing);
  });

  testWidgets('top-3 截断:第 4/5 条结论文案不渲染', (t) async {
    await t.pumpWidget(_wrap(MdaSummaryCard(section: _five, onViewAll: () {})));
    await t.pumpAndSettle();

    expect(find.text('结论文案 1'), findsOneWidget);
    expect(find.text('结论文案 2'), findsOneWidget);
    expect(find.text('结论文案 3'), findsOneWidget);
    expect(find.text('结论文案 4'), findsNothing);
    expect(find.text('结论文案 5'), findsNothing);
    expect(find.text('诊断摘要 · 0 风险 2 提示 3 关注'), findsOneWidget);
  });

  testWidgets('零发现态:单行健康徽章,无计数头无查看全部', (t) async {
    final empty = MdaSection.create(findings: const []);
    await t.pumpWidget(_wrap(MdaSummaryCard(section: empty, onViewAll: () {})));
    await t.pumpAndSettle();

    expect(
        find.text('本期诊断:0 风险 0 提示 0 关注 · 未发现需关注项 ✓'),
        findsOneWidget);
    expect(find.textContaining('诊断摘要 ·'), findsNothing);
    expect(find.byKey(const ValueKey('mdaViewAllLink')), findsNothing);
  });

  testWidgets('「查看全部 ↓」tap → onViewAll 回调触发(锚滚到第七章节)', (t) async {
    var fired = 0;
    await t.pumpWidget(_wrap(
        MdaSummaryCard(section: _proto, onViewAll: () => fired++)));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('mdaViewAllLink')));
    await t.pump();
    expect(fired, 1);
  });
}
