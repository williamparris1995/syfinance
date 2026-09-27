/// T5 财务报告页 widget 测试(seam = FinancialReportPage 公共构造 +
/// bloc 注入;真实 bloc + mock ReportAssemblyService)。
///
/// 覆盖:Initial 引导/面包屑、期选择(月↔年/上一期/下一期/跨年回绕)、
/// 生成→Loading(>300ms 进度门)→Loaded 六章节、附注两卡、变体 B 锚点、
/// 自适应章节缺席、Error→Retry。
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/report/domain/report_assembly_service.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/presentation/financial_report_bloc.dart';
import 'package:yucai_client/report/presentation/pages/financial_report_page.dart';

class _MockAssembly extends Mock implements ReportAssemblyService {}

// ── fixture:手算 oracle(数值独立构造,不复用被测代码计算)──

const _fixPeriod = ReportMonthly(2026, 8);

/// 全章节文档(预算+投资默认在;bool 开关可关掉验证自适应缺席):
/// 期望显示值全部手算。
/// 概算:期初 ¥286,450.00 → 期末 ¥301,280.00(+¥14,830.00 = +5.2%);
/// 收入 ¥32,500.00 / 支出 ¥17,670.00 / 结余 +¥14,830.00 / 储蓄率 45.6%。
ReportDocument _fullDoc({
  bool includeBudget = true,
  bool includeInvestment = true,
}) =>
    ReportDocument(
      period: _fixPeriod,
      generatedAt: DateTime.utc(2026, 9, 1),
      overview: OverviewSection.create(
        netWorthStartCents: 28645000,
        netWorthEndCents: 30128000,
        incomeCents: 3250000,
        expenseCents: 1767000,
        cashDeltaCents: 853000,
        notes: const [
          ReportNote(title: '口径说明', lines: [
            '期初/期末余额由全量分录回放重建。',
            '现金及等价物仅含 savings(活期)类账户。',
          ]),
          ReportNote(title: '未包含项', lines: ['未包含:目标回顾(本期暂不提供)']),
        ],
      ),
      balanceSheet: BalanceSheetSection(
        assets: [
          CategoryAmount.create(
              category: 'realEstate', amountCents: 28000000, totalCents: 33373000),
          CategoryAmount.create(
              category: 'savings', amountCents: 5373000, totalCents: 33373000),
        ],
        liabilities: [
          CategoryAmount.create(
              category: 'loan', amountCents: 10784000, totalCents: 10784000),
        ],
        changes: [
          BalanceChange.create(
              category: 'savings', startCents: 4520000, endCents: 5373000),
        ],
      ),
      incomeStatement: IncomeStatementSection(
        income: [
          CategoryAmount.create(
              category: 'income-salary', amountCents: 2800000, totalCents: 3250000),
          CategoryAmount.create(
              category: 'income-side', amountCents: 450000, totalCents: 3250000),
        ],
        expense: [
          CategoryAmount.create(
              category: 'expense-food', amountCents: 620000, totalCents: 1767000),
          CategoryAmount.create(
              category: 'expense-shop', amountCents: 1147000, totalCents: 1767000),
        ],
        dailyAvgCents: 57000,
        priorComparison: PriorComparison.create(
            label: '较 2026 年 7 月',
            surplusCents: 1483000,
            priorSurplusCents: 1200000),
      ),
      cashFlow: CashFlowSection(
        operating:
            ActivityFlow.create(inflowCents: 3250000, outflowCents: 1697000),
        investing: ActivityFlow.create(inflowCents: 0, outflowCents: 500000),
        financing: ActivityFlow.create(inflowCents: 0, outflowCents: 200000),
        netDeltaCents: 853000,
        reconciled: true,
      ),
      budget: includeBudget
          ? BudgetSection(items: [
              ReportBudgetItem.create(
                  name: '餐饮', actualCents: 285000, limitCents: 300000),
              ReportBudgetItem.create(
                  name: '购物', actualCents: 412000, limitCents: 350000),
            ])
          : null,
      investment: includeInvestment
          ? InvestmentSection.create(
              mvStartCents: 4277000,
              mvEndCents: 4577000,
              netBuyCents: 200000,
              twr: 2.3)
          : null,
      excludedSections: const [],
    );

/// 把 mock 的 onPhase 命名参数取出并逐阶段回调。
void Function(ReportPhase)? _onPhaseOf(Invocation inv) =>
    inv.namedArguments[const Symbol('onPhase')]
        as void Function(ReportPhase)?;

/// 桩:generate 立即走完四阶段并返回 [doc](或第 [failAt] 次抛错)。
void _stubGenerate(_MockAssembly assembly, ReportDocument doc, {int failAt = 0}) {
  var calls = 0;
  when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
      .thenAnswer((inv) async {
    calls++;
    final onPhase = _onPhaseOf(inv);
    for (final p in ReportPhase.values) {
      onPhase?.call(p);
    }
    if (calls == failAt) throw StateError('boom');
    return doc;
  });
}

void main() {
  late _MockAssembly assembly;

  setUpAll(() {
    registerFallbackValue(ReportPeriod.monthly(2026, 8));
  });

  setUp(() {
    assembly = _MockAssembly();
  });

  Widget harness({ReportPeriod initialPeriod = const ReportMonthly(2026, 8)}) {
    final bloc = FinancialReportBloc(assembly);
    return MaterialApp(
      key: ValueKey('fr-harness-${initialPeriod.label}'),
      home: BlocProvider<FinancialReportBloc>.value(
        value: bloc,
        child: FinancialReportPage(initialPeriod: initialPeriod),
      ),
    );
  }

  testWidgets('initial: 面包屑 + 引导文案 + 默认期标签 + 生成按钮', (t) async {
    await t.pumpWidget(harness());
    await t.pumpAndSettle();

    // 顶栏面包屑「报表分析 › 财务报告」。
    expect(find.text('报表分析'), findsOneWidget);
    expect(find.text('财务报告'), findsAtLeastNWidgets(1));
    // Initial 引导(gen-idle)。
    expect(find.text('报告尚未生成'), findsOneWidget);
    // 默认期显示(initialPeriod 注入 2026-08)。
    expect(find.text('2026 年 8 月'), findsOneWidget);
    // 主按钮 + 引导卡内次按钮。
    expect(find.text('生成报告'), findsNWidgets(2));
  });

  testWidgets('期选择:上一期/下一期 + 月跨年回绕 + 切年口径', (t) async {
    await t.pumpWidget(harness());
    await t.pumpAndSettle();

    // 上一期:2026-08 → 2026-07。
    await t.tap(find.byTooltip('上一期'));
    await t.pump();
    expect(find.text('2026 年 7 月'), findsOneWidget);
    // 下一期两次 → 2026-09。
    await t.tap(find.byTooltip('下一期'));
    await t.pump();
    await t.tap(find.byTooltip('下一期'));
    await t.pump();
    expect(find.text('2026 年 9 月'), findsOneWidget);

    // 切「年」:标签变年度口径(ReportPeriod.yearly.label = 「YYYY 年度」);
    // 上一期 → 2025 年度。
    await t.tap(find.text('年'));
    await t.pump();
    expect(find.text('2026 年度'), findsOneWidget);
    await t.tap(find.byTooltip('上一期'));
    await t.pump();
    expect(find.text('2025 年度'), findsOneWidget);

    // 月跨年回绕:2026-01 的上一期 = 2025 年 12 月。
    await t.pumpWidget(harness(initialPeriod: ReportPeriod.monthly(2026, 1)));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('上一期'));
    await t.pump();
    expect(find.text('2025 年 12 月'), findsOneWidget);
  });

  testWidgets('生成→Loaded:引导/进度退场,六章节+手算数值渲染', (t) async {
    _stubGenerate(assembly, _fullDoc());
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    // 引导与进度退场。
    expect(find.text('报告尚未生成'), findsNothing);
    expect(find.text('正在生成报告…'), findsNothing);

    // 六章节标题(章节头 + 变体 B 锚点标签各一份)。
    for (final title in ['总览', '资产负债', '收支', '现金流', '预算执行', '投资绩效']) {
      expect(find.text(title), findsNWidgets(2),
          reason: '章节头与锚点标签都应含「$title」');
    }

    // 01 总览:hero 期初→期末 + 变动 chip + 四卡 + 现金净变动 + 附注两卡。
    // (hero 期初/期末值同时出现在「期初→期末变动」表 → 各 2 处;结余/现金
    // 净变动在 hero chip、四卡、变动表多处重复 → 按实际布局计份数。)
    expect(find.text('¥286,450.00'), findsNWidgets(2));
    expect(find.text('¥301,280.00'), findsNWidgets(2));
    expect(find.text('+¥14,830.00'), findsNWidgets(3)); // hero chip+结余卡+变动表
    expect(find.text('+5.2%'), findsOneWidget); // 净资产变动 %
    // 收入值 4 处:收入卡 + 收入构成合计 + 现金流(经营流入/合计流入)。
    expect(find.text('¥32,500.00'), findsNWidgets(4));
    expect(find.text('¥17,670.00'), findsNWidgets(2)); // 支出卡 + 支出分类合计
    expect(find.text('45.6%'), findsOneWidget); // 储蓄率
    // 现金净变动 4 处:hero foot + slim 卡 + 变动行 + 现金流合计净额。
    expect(find.text('+¥8,530.00'), findsNWidgets(4));
    expect(find.text('口径说明'), findsOneWidget);
    expect(find.text('未包含项'), findsOneWidget);
    expect(find.text('· 未包含:目标回顾(本期暂不提供)'), findsOneWidget);

    // 02 资产负债:构成(账类代码转中文)+ 变动表。
    expect(find.text('固定资产'), findsOneWidget); // realEstate
    expect(find.text('储蓄'), findsNWidgets(2)); // savings 构成条 + 变动行
    expect(find.text('贷款'), findsOneWidget); // loan
    expect(find.text('¥333,730.00'), findsOneWidget); // 资产合计 33,373,000c

    // 03 收支:收入/支出构成 + 日均 + 环比。
    expect(find.text('income-salary'), findsOneWidget); // 收入维度=账户 id 原样
    expect(find.text('¥570.00'), findsOneWidget); // 日均结余
    expect(find.text('较 2026 年 7 月'), findsOneWidget);
    expect(find.text('+23.6%'), findsOneWidget); // (1483000-1200000)/1200000

    // 04 现金流:三行 + 合计 + 勾稽。
    expect(find.text('经营活动'), findsOneWidget);
    expect(find.text('+¥15,530.00'), findsOneWidget); // 经营净额
    expect(find.text('-¥5,000.00'), findsOneWidget); // 投资净额

    // 05 预算执行:使用率 + 超支警示。
    expect(find.text('95.0%'), findsOneWidget);
    expect(find.text('117.7% 超支'), findsOneWidget);

    // 06 投资绩效:五数值卡。
    expect(find.text('¥42,770.00'), findsOneWidget); // 期初市值
    expect(find.text('+¥1,000.00'), findsOneWidget); // 估算收益
    expect(find.text('+2.3%'), findsOneWidget); // 区间 TWR
  });

  testWidgets('变体 B 锚点:全量文档 6 圆点;点击滚动到目标章', (t) async {
    _stubGenerate(assembly, _fullDoc());
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    // 6 个圆点锚点(sectionDot-0..5)。
    expect(find.byKey(const ValueKey('sectionDot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('sectionDot-5')), findsOneWidget);
    // 悬停标签在树内(透明度 0,AnimatedOpacity 包裹)。
    expect(find.text('预算执行'), findsNWidgets(2)); // 章节头 + 锚点标签

    // 点击最后一个圆点 → 平滑滚动(ensureVisible 动画)→ 仍可 settle。
    await t.tap(find.byKey(const ValueKey('sectionDot-5')));
    await t.pumpAndSettle();
  });

  testWidgets('自适应缺席:预算/投资 null → 章节+锚点不渲染 + 未包含项披露',
      (t) async {
    _stubGenerate(
      assembly,
      _fullDoc(includeBudget: false, includeInvestment: false),
    );
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    expect(find.text('预算执行'), findsNothing);
    expect(find.text('投资绩效'), findsNothing);
    // 锚点只到 index 3(总览/资产负债/收支/现金流)。
    expect(find.byKey(const ValueKey('sectionDot-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('sectionDot-4')), findsNothing);
  });

  testWidgets('进度门(FR-8):<300ms 紧凑提示,>300ms 展开四阶段步进', (t) async {
    // 桩:首阶段后滞留 600ms(模拟慢生成),随后完成。
    when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
        .thenAnswer((inv) async {
      final onPhase = _onPhaseOf(inv);
      onPhase?.call(ReportPhase.loadingLedger);
      await Future<void>.delayed(const Duration(milliseconds: 600));
      onPhase?.call(ReportPhase.replaying);
      onPhase?.call(ReportPhase.assembling);
      onPhase?.call(ReportPhase.performance);
      return _fullDoc();
    });
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pump(); // 生成开始,<300ms。

    // 快速阶段:仅紧凑提示,四阶段步进不可见(不闪进度)。
    expect(find.text('正在生成报告…'), findsOneWidget);
    expect(find.text('回放余额'), findsNothing);
    expect(find.text('汇编章节'), findsNothing);

    // 300ms 门到期仍在 Loading → 步进展开(四阶段标签 + n/4 chip)。
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('正在生成报告…'), findsNothing);
    expect(find.text('回放余额'), findsOneWidget);
    expect(find.text('汇编章节'), findsOneWidget);
    expect(find.byKey(const ValueKey('reportProgressStepNo')), findsOneWidget);

    // 生成完成:步进退场,报告体接管。(600ms 桩延迟需显式推进时钟——
    // 步进卡静态无帧,pumpAndSettle 不会替我们走完 Future.delayed。)
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    expect(find.text('回放余额'), findsNothing);
    expect(find.text('总览'), findsNWidgets(2));
  });

  testWidgets('Error 态:错误文案 + 重试 → 同报告期重生成成功(FR-8 场景3)',
      (t) async {
    _stubGenerate(assembly, _fullDoc(), failAt: 1);
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    expect(find.text('报告生成失败,请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('报告尚未生成'), findsNothing);

    // 重试 → 第二次成功 → 六章节渲染。
    await t.tap(find.byKey(const ValueKey('reportRetryButton')));
    await t.pumpAndSettle();
    expect(find.text('报告生成失败,请重试'), findsNothing);
    expect(find.text('现金流'), findsNWidgets(2));
  });
}
