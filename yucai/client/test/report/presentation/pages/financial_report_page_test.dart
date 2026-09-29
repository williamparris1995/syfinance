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

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
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
  MdaSection? mda,
  DateTime? generatedAt,
}) =>
    ReportDocument(
      period: _fixPeriod,
      generatedAt: generatedAt ?? DateTime.utc(2026, 9, 1),
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
      balanceSheet: BalanceSheetSection.create(
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
          // T5-R1:收支构成行带科目账户名(category 保留 id 维度)。
          CategoryAmount.create(
              category: 'income-salary',
              name: '工资',
              amountCents: 2800000,
              totalCents: 3250000),
          CategoryAmount.create(
              category: 'income-side',
              name: '副业',
              amountCents: 450000,
              totalCents: 3250000),
        ],
        expense: [
          CategoryAmount.create(
              category: 'expense-food',
              name: '伙食费',
              amountCents: 620000,
              totalCents: 1767000),
          CategoryAmount.create(
              category: 'expense-shop',
              name: '日用',
              amountCents: 1147000,
              totalCents: 1767000),
        ],
        dailyAvgCents: 57000,
        priorComparison: PriorComparison.create(
            label: '环比上月支出',
            expenseCents: 1767000,
            priorExpenseCents: 1630000),
      ),
      cashFlow: CashFlowSection(
        operating:
            ActivityFlow.create(inflowCents: 3250000, outflowCents: 1697000),
        investing: ActivityFlow.create(
          inflowCents: 0,
          outflowCents: 500000,
          // 明细列数据源(视觉对齐批次):定期 300,000 + 投资 200,000。
          counterpartyCents: {'fixedDeposit': 300000, 'investment': 200000},
        ),
        financing: ActivityFlow.create(
          inflowCents: 0,
          outflowCents: 200000,
          counterpartyCents: {'creditCard': 200000},
        ),
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
      mda: mda,
      excludedSections: const [],
    );

/// F44 T3:诊断章节 fixture(原型 v8 演示口径 0 风险 2 提示 1 关注;
/// [empty] = 健康态零发现 + healthyRunwayMonths 3.2(引擎回填形态)。
MdaSection _mda({bool empty = false}) => MdaSection.create(
  findings: empty
      ? const []
      : const [
          MdaFinding(
            ruleId: 'R2',
            severity: MdaSeverity.warn,
            conclusion: '购物超预算:4,120/3,500(118%),超支 620.00',
            advice: '建议复盘该类别或上调预算至实际水平',
            chip: MdaChip(label: '超支 620.00', tone: MdaChipTone.negative),
          ),
          MdaFinding(
            ruleId: 'R4',
            severity: MdaSeverity.warn,
            conclusion: '可能闲置订阅:XX 音乐会员(年付 288.00,月度等价 24.00)',
            advice: '若仍在使用,记一笔时请关联该订阅',
            actionLink: '/accounts/subscriptions',
          ),
          MdaFinding(
            ruleId: 'R5',
            severity: MdaSeverity.info,
            conclusion: '大额单笔:9 月 2 日单笔 3,600.00(年卡),≥ 日均支出×3',
            advice: '若为年付/预付类支出属正常现象',
            chip: MdaChip(label: '≥ 日均支出×3', tone: MdaChipTone.neutral),
          ),
        ],
      healthyRunwayMonths: empty ? 3.2 : null,
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

    // 视觉对齐批次:自带顶栏退役(面包屑由 shell 承载,生产经 branch 10
    // 的 AppShell 顶栏渲染;挂页 harness 无 shell)——页面内不再有
    // 「报表分析」串;「财务报告」= 页头标题一处。
    expect(find.text('报表分析'), findsNothing);
    expect(find.text('财务报告'), findsOneWidget);
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
    // 视觉对齐批次:hero 大数字升档(期初 38 / 期末 46)+ 小数「.00」24px
    // 分段着色 → hero 金额拆整数/小数两段文本,变动表仍为全串。
    expect(find.text('¥286,450'), findsOneWidget); // hero 期初整数段
    expect(find.text('¥301,280'), findsOneWidget); // hero 期末整数段
    expect(find.text('.00'), findsNWidgets(2)); // hero 两金额小数段
    expect(find.text('¥286,450.00'), findsOneWidget); // 变动表净资产行
    expect(find.text('¥301,280.00'), findsOneWidget);
    expect(find.text('+¥14,830.00'), findsNWidgets(3)); // hero chip+结余卡+变动表
    expect(find.text('+5.2%'), findsOneWidget); // 净资产变动 %
    // hero 档位钉死:期初 38px / 期末 46px / 小数 24px(原型 v9 .hero-amount)。
    expect(
        t.widget<Text>(find.text('¥286,450')).style?.fontSize, 38,
        reason: 'hero 期初档位 38px(原型 .hero-amount.sm)');
    expect(
        t.widget<Text>(find.text('¥301,280')).style?.fontSize, 46,
        reason: 'hero 期末档位 46px(原型 .hero-amount)');
    expect(t.widget<Text>(find.text('.00').first).style?.fontSize, 24,
        reason: 'hero 小数段 24px(原型 .hero-amount .cents)');
    // 数字本体 = 令牌渐变(accent→accentDeep,暗金/亮绿同式,零裸色)。
    expect(
        find
            .ancestor(
                of: find.text('¥301,280'),
                matching: find.byType(ShaderMask))
            .evaluate(),
        isNotEmpty,
        reason: 'hero 整数段经 ShaderMask 渐变着色');
    // 收入值 4 处:收入卡 + 收入构成合计 + 现金流(经营流入/合计流入)。
    expect(find.text('¥32,500.00'), findsNWidgets(4));
    expect(find.text('¥17,670.00'), findsNWidgets(2)); // 支出卡 + 支出分类合计
    // 储蓄率 2 处:hero-foot(视觉对齐批次第三项)+ 四卡储蓄率卡。
    expect(find.text('45.6%'), findsNWidgets(2));
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

    // 03 收支:收入/支出构成(科目账户名,非 id)+ 日均 + 环比。
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('伙食费'), findsOneWidget);
    expect(find.text('income-salary'), findsNothing); // id 不再上屏
    expect(find.text('¥570.00'), findsOneWidget); // 日均支出
    expect(find.text('环比上月支出'), findsOneWidget);
    expect(find.text('+8.4%'), findsOneWidget); // (1,767,000−1,630,000)/1,630,000

    // 04 现金流:三行 + 合计 + 勾稽。
    expect(find.text('经营活动'), findsOneWidget);
    expect(find.text('+¥15,530.00'), findsOneWidget); // 经营净额
    expect(find.text('-¥5,000.00'), findsOneWidget); // 投资净额
    // 明细列(视觉对齐批次,原型 v9 五列):表头 + 各行解释文本 ——
    // 经营 = 分类器矩阵语义(收支科目两侧);投资/融资 = 对手分类净额
    // (按绝对额降序,原型「定期存入 ¥3,000.00 + …」措辞风格)。
    expect(find.text('明细'), findsOneWidget);
    expect(find.text('工资等日常收入 · 日常消费支出'), findsOneWidget);
    expect(find.text('定期 ¥3,000.00 + 投资 ¥2,000.00'), findsOneWidget);
    expect(find.text('信用卡 ¥2,000.00'), findsOneWidget);

    // 05 预算执行:使用率 + 超支警示。
    expect(find.text('95.0%'), findsOneWidget);
    expect(find.text('117.7% 超支'), findsOneWidget);

    // 06 投资绩效:五数值卡(值档 22,视觉对齐批次 L1)。
    expect(find.text('¥42,770.00'), findsOneWidget); // 期初市值
    expect(find.text('+¥1,000.00'), findsOneWidget); // 估算收益
    expect(find.text('+2.3%'), findsOneWidget); // 区间 TWR
    expect(t.widget<Text>(find.text('¥42,770.00')).style?.fontSize, 22,
        reason: 'perf 值档 22(原型 .mini-big)');

    // 卡头标题档 15(原型 .card-head h2;「三类活动现金流」仅现金流卡头)。
    expect(t.widget<Text>(find.text('三类活动现金流')).style?.fontSize, 15,
        reason: '章节卡头标题档 15');
  });

  testWidgets('视觉对齐批次:页标题 24 档 + 内容列 980 + 月/年 segmented 淡金选中态',
      (t) async {
    _stubGenerate(assembly, _fullDoc());
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    // 页标题档 24(原型 .page-head h1;仅页头一处,顶栏已并入 shell)。
    expect(t.widget<Text>(find.text('财务报告')).style?.fontSize, 24,
        reason: '页标题档 24(原型 24px)');

    // 内容列宽 ≈976-1000(原型 ≈976;980 落区间)。
    final boxes =
        t.widgetList<ConstrainedBox>(find.byType(ConstrainedBox));
    expect(
        boxes.any((b) => b.constraints.maxWidth == 980), isTrue,
        reason: '内容列 980(1120 → 原型 ≈976-1000)');

    // 月/年 segmented 选中态:淡金底 + 金字描边(原型 .pills a.on =
    // nav-active 9% 底 + nav-active-fg 字;非实心金)。
    final theme = YucaiTheme.light(); // harness 无 extension → 亮色回落。
    final monthSeg = t.widget<AnimatedContainer>(
        find.byKey(const ValueKey('reportScopeSegMonth')));
    expect((monthSeg.decoration as BoxDecoration).color, theme.sidebarActiveBg,
        reason: '选中段底 = nav-active 淡金(9%)');
    final monthLabel = t.widget<Text>(find.descendant(
        of: find.byKey(const ValueKey('reportScopeSegMonth')),
        matching: find.text('月')));
    expect(monthLabel.style?.color, theme.sidebarActiveFg,
        reason: '选中段字 = nav-active-fg 金');
    // 未选段:透明底 + muted 字(对照)。
    final yearSeg = t.widget<AnimatedContainer>(
        find.byKey(const ValueKey('reportScopeSegYear')));
    expect((yearSeg.decoration as BoxDecoration).color, Colors.transparent);
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

  // ── F44 T3:第七章节 + 总览摘要卡(随 doc.mda)──────────────────────

  testWidgets('mda 有发现:第七章入锚点链(7 圆点)+ 摘要卡 + 查看全部锚滚',
      (t) async {
    // 加高测试视口(默认 800×600 下摘要卡在折叠线下,tap 不可达)。
    t.view.physicalSize = const Size(1000, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    _stubGenerate(assembly, _fullDoc(mda: _mda()));
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    // 第七章入链:章节头 + 锚点标签各一份;变体 B 锚点第 7 个圆点在位。
    expect(find.text('诊断与建议'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('sectionDot-6')), findsOneWidget);

    // 总览摘要卡(有发现态):计数头 + top-3 首条(摘要卡 + 第七章各一份)+ 查看全部。
    expect(find.text('诊断摘要 · 0 风险 2 提示 1 关注'), findsOneWidget);
    expect(find.text('购物超预算:4,120/3,500(118%),超支 620.00'),
        findsNWidgets(2));
    expect(find.byKey(const ValueKey('mdaViewAllLink')), findsOneWidget);
    // 行尾语义 chip(视觉对齐批次,原型 .diag-row):R2 neg「超支 620.00」+
    // R5 中性「≥ 日均支出×3」各只在摘要卡渲染一处;R4 无 chip。
    expect(find.text('超支 620.00'), findsOneWidget);
    expect(find.text('≥ 日均支出×3'), findsOneWidget);

    // 第七章体:actionLink 跳转按钮渲染(R4)。
    expect(find.byKey(const ValueKey('mdaActionLink')), findsOneWidget);

    // 「查看全部 ↓」→ 锚滚到第七章节(滚动发生:offset 离开顶部)。
    final scrollState = t.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollState.position.pixels, 0);
    await t.tap(find.byKey(const ValueKey('mdaViewAllLink')));
    await t.pumpAndSettle();
    expect(scrollState.position.pixels, greaterThan(0));
  });

  testWidgets('mda 零发现:第七章健康卡 + 总览单行健康徽章(两态随 doc.mda)',
      (t) async {
    _stubGenerate(assembly, _fullDoc(mda: _mda(empty: true)));
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    // 第七章健康卡三指标(doc:储蓄率 45.6%/资产负债率 32.3% 手算;
    // runway 3.2 为章节字段)。
    expect(find.text('诊断与建议'), findsNWidgets(2));
    expect(find.text('本期诊断未发现需关注项'), findsOneWidget);
    expect(
        find.text('储蓄率 45.6%、资产负债率 32.3%、现金可支撑约 3.2 个月,'
            '均在健康区间'),
        findsOneWidget);

    // 总览摘要卡 = 单行健康徽章。
    expect(find.text('本期诊断:0 风险 0 提示 0 关注 · 未发现需关注项 ✓'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('mdaViewAllLink')), findsNothing);
  });

  testWidgets('mda null(期外异常):第七章节与摘要卡均不渲染', (t) async {
    _stubGenerate(assembly, _fullDoc());
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();

    expect(find.text('诊断与建议'), findsNothing);
    expect(find.textContaining('诊断摘要'), findsNothing);
    expect(find.textContaining('未发现需关注项'), findsNothing);
    // 锚点仍止于第 6 个(六章节)。
    expect(find.byKey(const ValueKey('sectionDot-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('sectionDot-6')), findsNothing);
  });

  testWidgets('mdaChapterIndex 自适应:预算/投资缺席组合下「查看全部」仍锚滚第七章',
      (t) async {
    // 加高视口(摘要卡需在折叠线上方可 tap)。
    t.view.physicalSize = const Size(1000, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);

    // (budget, investment) 三组合;章节总数 = 4 固定 + b + i + 1(mda)。
    const combos = [(true, false), (false, true), (false, false)];
    for (final (b, i) in combos) {
      _stubGenerate(
        assembly,
        _fullDoc(
            includeBudget: b, includeInvestment: i, mda: _mda()),
      );
      await t.pumpWidget(harness());
      // 页面状态跨迭代复用:复位残留滚动(上一迭代锚滚停底部,页头
      // 生成按钮需回可视区,否则 tap 落空)。
      t.state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pump();
      await t.tap(find.byKey(const ValueKey('generateReportButton')));
      await t.pumpAndSettle();

      // 锚点链长度随自适应章节收缩;诊断章为末位点。
      final lastDot = 4 + (b ? 1 : 0) + (i ? 1 : 0);
      expect(find.byKey(ValueKey('sectionDot-$lastDot')), findsOneWidget,
          reason: 'b=$b,i=$i 时诊断章应占锚点 $lastDot');
      expect(find.byKey(ValueKey('sectionDot-${lastDot + 1}')), findsNothing);

      // 「查看全部」锚滚目标 = 第七章头(滚动后章节头进入视口顶部区)。
      // 「查看全部」锚滚目标 = 第七章(各组合下均为末章):意图滚动量
      // 超出 maxScrollExtent → 钳到最大(章头整卡进入视口)。锚错索引
      // (如指到预算/投资章)会中途停靠 → pixels < max。
      await t.tap(find.byKey(const ValueKey('mdaViewAllLink')));
      await t.pumpAndSettle();
      final st = t.state<ScrollableState>(find.byType(Scrollable).first);
      expect(st.position.pixels, closeTo(st.position.maxScrollExtent, 0.5),
          reason: 'b=$b,i=$i 时应滚到底(第七章=末章)');
      final head =
          t.renderObject(find.text('诊断与建议').first) as RenderBox;
      final dy = head.localToGlobal(Offset.zero).dy;
      expect(dy, greaterThanOrEqualTo(0), reason: 'b=$b,i=$i 章头在视口内');
      expect(dy + head.size.height, lessThanOrEqualTo(2000));
    }
  });

  testWidgets(
      '回归:期变更自动重生成不触发 GlobalKey 重叠(AnimatedSwitcher 过渡)',
      (t) async {
    // 世界:两次生成各返回不同 generatedAt 的文档(翻期即新文档);
    // Loaded → 翻期 → 自动重生成(反馈②),新报告体在旧体 300ms 淡出
    // 完成前入场 —— 旧实现章节锚 GlobalKey 池跨文档复用,过渡帧内同一
    // GlobalKey 同时挂在淡出旧体与入场新体 → 「Duplicate keys」异常。
    var n = 0;
    when(() => assembly.generate(any(), onPhase: any(named: 'onPhase')))
        .thenAnswer((inv) async {
      for (final p in ReportPhase.values) {
        _onPhaseOf(inv)?.call(p);
      }
      n++;
      return _fullDoc(generatedAt: DateTime.utc(2026, 9, 1, 0, 0, n));
    });
    await t.pumpWidget(harness());
    await t.tap(find.byKey(const ValueKey('generateReportButton')));
    await t.pumpAndSettle();
    expect(find.text('2026 年 8 月'), findsOneWidget);

    // 翻期:同步桩一帧内直达新 Loaded;随后推进过渡中段帧 + 收尾。
    await t.tap(find.byTooltip('上一期'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 150)); // 淡出/入场交叠帧
    await t.pumpAndSettle();
    expect(find.text('2026 年 7 月'), findsOneWidget);
    // 报告体健在(新文档七章渲染)。
    expect(find.text('总览'), findsNWidgets(2));
  });
}
