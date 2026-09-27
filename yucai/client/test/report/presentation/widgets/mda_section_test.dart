/// F44 T3 第七章节 widget 测试(seam = MdaSection 公共构造;pump 直渲染)。
///
/// 覆盖:severity 分组渲染(空组头不渲染)/三计数 chip/逐字文案/
/// actionLink 跳转按钮(context.push)/零发现健康态(储蓄率+资产负债率
/// 从 doc 取数;资产 0 → 资产负债率段省略)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/widgets/mda_section.dart';

// ── fixture:手算 oracle(期望值独立构造,不复用被测代码计算)──

const _w2 = MdaFinding(
  ruleId: 'R2',
  severity: MdaSeverity.warn,
  conclusion: '购物超预算:4,120/3,500(118%),超支 620.00',
  advice: '建议复盘该类别或上调预算至实际水平',
);

const _w4 = MdaFinding(
  ruleId: 'R4',
  severity: MdaSeverity.warn,
  conclusion: '可能闲置订阅:XX 音乐会员(年付 288.00,月度等价 24.00)',
  advice: '若仍在使用,记一笔时请关联该订阅',
  actionLink: '/accounts/subscriptions',
);

const _i5 = MdaFinding(
  ruleId: 'R5',
  severity: MdaSeverity.info,
  conclusion: '大额单笔:9 月 2 日单笔 3,600.00(年卡),≥ 日均支出×3',
  advice: '若为年付/预付类支出属正常现象',
);

const _r1 = MdaFinding(
  ruleId: 'R1',
  severity: MdaSeverity.risk,
  conclusion: '储蓄率 8.3%,低于 10% 的风险线',
  advice: '优先压缩可选支出,把储蓄率提到 10% 以上',
);

/// 最小 doc:储蓄率/资产负债率由 factory 派生(1 位小数,手算):
/// 收入 ¥32,500 − 支出 ¥17,670 → 储蓄率 45.6%;
/// 资产 ¥400,000 / 负债 ¥107,600 → 资产负债率 26.9%。
ReportDocument _doc({int assetsCents = 40000000, int liabCents = 10760000}) =>
    ReportDocument(
      period: const ReportMonthly(2026, 8),
      generatedAt: DateTime.utc(2026, 9, 1),
      overview: OverviewSection.create(
        netWorthStartCents: 0,
        netWorthEndCents: 0,
        incomeCents: 3250000,
        expenseCents: 1767000,
        cashDeltaCents: 0,
        notes: const [],
      ),
      balanceSheet: BalanceSheetSection.create(
        assets: [
          if (assetsCents > 0)
            CategoryAmount.create(
                category: 'cash', amountCents: assetsCents, totalCents: assetsCents),
        ],
        liabilities: [
          if (liabCents > 0)
            CategoryAmount.create(
                category: 'loan', amountCents: liabCents, totalCents: liabCents),
        ],
        changes: const [],
      ),
      incomeStatement: const IncomeStatementSection(
        income: [],
        expense: [],
        dailyAvgCents: 0,
      ),
      cashFlow: const CashFlowSection(
        operating: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
        investing: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
        financing: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
        netDeltaCents: 0,
        reconciled: true,
      ),
      excludedSections: const [],
    );

Widget _wrap(Widget child) =>
    MaterialApp(theme: ThemeData(extensions: [YucaiTheme.light()]), home: Scaffold(body: child));

void main() {
  testWidgets('分组渲染:三计数 chip + 组头(空风险组不渲染)+ 逐字文案', (t) async {
    final section = MdaSection.create(findings: [_w2, _w4, _i5]);
    await t.pumpWidget(_wrap(MdaChapter(section: section, doc: _doc())));
    await t.pumpAndSettle();

    // 章节头三计数 chip(0 风险 / 2 提示 / 1 关注)。
    expect(find.text('0 风险'), findsOneWidget);
    expect(find.text('2 提示'), findsOneWidget);
    expect(find.text('1 关注'), findsOneWidget);

    // 组头:提示 · 2 / 关注 · 1;风险组空 → 组头不渲染。
    expect(find.text('提示 · 2'), findsOneWidget);
    expect(find.text('关注 · 1'), findsOneWidget);
    expect(find.textContaining('风险 ·'), findsNothing);

    // 逐字文案:结论 + 建议直出 Finding 字符串(widget 不重算)。
    expect(find.text('购物超预算:4,120/3,500(118%),超支 620.00'), findsOneWidget);
    expect(find.text('建议复盘该类别或上调预算至实际水平'), findsOneWidget);
    expect(find.text('大额单笔:9 月 2 日单笔 3,600.00(年卡),≥ 日均支出×3'),
        findsOneWidget);
    expect(find.text('若为年付/预付类支出属正常现象'), findsOneWidget);

    // 尾部 severity chip(提示×2 / 关注×1)。
    expect(find.text('提示'), findsNWidgets(2));
    expect(find.text('关注'), findsOneWidget);

    // 健康卡不出现在有发现态。
    expect(find.text('本期诊断未发现需关注项'), findsNothing);
  });

  testWidgets('风险组在位:风险 · 1 组头 + 1 风险 chip + 风险 severity chip', (t) async {
    final section = MdaSection.create(findings: [_r1, _w2]);
    await t.pumpWidget(_wrap(MdaChapter(section: section, doc: _doc())));
    await t.pumpAndSettle();

    expect(find.text('1 风险'), findsOneWidget);
    expect(find.text('风险 · 1'), findsOneWidget);
    expect(find.text('储蓄率 8.3%,低于 10% 的风险线'), findsOneWidget);
    expect(find.text('风险'), findsOneWidget); // severity chip
  });

  testWidgets('零发现:居中健康卡,三指标(储蓄率+资产负债率+runway)取数', (t) async {
    // doc:收入 3,250,000c − 支出 1,767,000c → 储蓄率 45.6%;
    // 资产 40,000,000c / 负债 10,760,000c → 资产负债率 26.9%(手算);
    // healthyRunwayMonths 3.2 由章节字段直出(引擎回填)。
    final section =
        MdaSection.create(findings: const [], healthyRunwayMonths: 3.2);
    await t.pumpWidget(_wrap(MdaChapter(section: section, doc: _doc())));
    await t.pumpAndSettle();

    expect(find.text('本期诊断未发现需关注项'), findsOneWidget);
    expect(
        find.text('储蓄率 45.6%、资产负债率 26.9%、现金可支撑约 3.2 个月,'
            '均在健康区间'),
        findsOneWidget);
    // 有发现态的分组结构不出现在健康态。
    expect(find.textContaining('提示 ·'), findsNothing);
    expect(find.textContaining('关注 ·'), findsNothing);
  });

  testWidgets('零发现+资产负债率 null(资产 0):健康行省略资产负债率段', (t) async {
    final section = MdaSection.create(findings: const []);
    await t.pumpWidget(
        _wrap(MdaChapter(section: section, doc: _doc(assetsCents: 0))));
    await t.pumpAndSettle();

    expect(find.text('储蓄率 45.6%,均在健康区间'), findsOneWidget);
    expect(find.textContaining('资产负债率'), findsNothing);
    expect(find.textContaining('现金可支撑'), findsNothing); // runway 缺省 null 同省略
  });

  testWidgets('actionLink:「前往订阅中心 →」按钮 context.push 到订阅中心', (t) async {
    final section = MdaSection.create(findings: [_w4]);
    // 导航断言需要 GoRouter(actionLink onTap = context.push)。
    final router = GoRouter(
      initialLocation: '/reports/full',
      routes: [
        GoRoute(
          path: '/reports/full',
          builder: (_, __) => _wrap(MdaChapter(section: section, doc: _doc())),
        ),
        GoRoute(
          path: '/accounts/subscriptions',
          builder: (_, __) => const Scaffold(body: Text('订阅中心占位')),
        ),
      ],
    );
    await t.pumpWidget(MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [YucaiTheme.light()]),
    ));
    await t.pumpAndSettle();

    final link = find.byKey(const ValueKey('mdaActionLink'));
    expect(link, findsOneWidget);
    expect(find.text('前往订阅中心 →'), findsOneWidget);
    await t.tap(link);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('订阅中心占位'), findsOneWidget);
  });

  testWidgets('零裸色守卫:risk 严重度图标底 = negative 令牌 13% 调(NFR-3)', (t) async {
    final section = MdaSection.create(findings: [_r1]);
    await t.pumpWidget(_wrap(MdaChapter(section: section, doc: _doc())));
    await t.pumpAndSettle();

    // risk 严重度图标容器底色应为 negative 令牌 13% 调(零裸色硬门)。
    final riskTint = YucaiTheme.light().negative.withValues(alpha: 0.13);
    final iconTile = find.descendant(
      of: find.byType(Row),
      matching: find.byType(Container),
    );
    var found = false;
    for (final c in t.widgetList<Container>(iconTile)) {
      final d = c.decoration;
      if (d is BoxDecoration &&
          d.color == riskTint &&
          c.constraints == const BoxConstraints.tightFor(width: 32, height: 32)) {
        found = true;
      }
    }
    expect(found, isTrue,
        reason: 'risk 严重度图标 32×32 底应为 negative.withValues(alpha: 0.13)');
  });

  testWidgets('v8 对齐:info 计数 chip 恒中性(仅 risk/warn 计数着色)', (t) async {
    // 1 条 info → 「1 关注」计数 chip 仍中性(透明底 + muted 字,
    // v8 .ch-head 三 chip 中「关注」为默认态)。
    final section = MdaSection.create(findings: const [_i5]);
    await t.pumpWidget(_wrap(MdaChapter(section: section, doc: _doc())));
    await t.pumpAndSettle();

    final chipBg = t.widget<Container>(
      find.ancestor(of: find.text('1 关注'), matching: find.byType(Container)).first,
    );
    final d = chipBg.decoration as BoxDecoration;
    expect(d.color, Colors.transparent,
        reason: 'info 计数 chip 底应中性(不着 info 色)');
    expect(
      t.widget<Text>(find.text('1 关注')).style?.color,
      YucaiTheme.light().muted,
    );
  });
}
