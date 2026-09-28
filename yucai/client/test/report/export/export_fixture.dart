/// F45 T1 导出域测试夹具:手算 oracle 的 ReportDocument 变体。
///
/// 金额全部 int cents;派生值(合计/百分比/结余)在注释里手算钉死,
/// 断言以注释为准(独立来源,不用被测代码回算)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 全量文档:预算+投资+诊断齐备(导出布局七章节)。
///
/// 手算 oracle(F43/F44 factory 派生):
/// - 总览:结余 = 20,000,000 − 12,000,000 = 8,000,000(+¥80,000.00);
///   储蓄率 = 8,000,000×100/20,000,000 = 40.0%;
///   净资产变动 = 125,000,000 − 100,000,000 = 25,000,000(+¥250,000.00),
///   变动 % = 25,000,000×100/100,000,000 = 25.0%。
/// - 资产负债:资产合计 100,000,000、负债合计 50,000,000、
///   资产负债率 50.0%;资产构成 pct 60.0/40.0(储蓄/投资),负债
///   60.0/40.0(贷款/信用卡,按金额降序惯例);
///   变动行 delta 均 +5,000,000。
/// - 收支:收入 pct 75.0/25.0、支出 58.3/41.7;
///   环比 = (8,000,000−6,000,000)×100/6,000,000 = 33.3%。
/// - 现金流:经营净 +8,000,000、投资净 −5,000,000、融资净 0;
///   净变动合计 +3,000,000(== cashDelta,勾稽自洽)。
/// - 预算:70.0%(正常)/ 96.0%(临界 warn)/ 133.3%(超支 risk)。
/// - 投资:估算收益 = 46,000,000 − 40,000,000 − 3,000,000 = 3,000,000;
///   TWR 7.2(pct 口径)。
/// - 诊断:1 风险(R1)/ 1 提示(R2)/ 1 关注(R6),runway 6.0。
ReportDocument fullDocument() => ReportDocument(
      period: ReportPeriod.monthly(2026, 8),
      generatedAt: DateTime.utc(2026, 9, 1, 2, 3, 4),
      overview: OverviewSection.create(
        netWorthStartCents: 100000000, // ¥1,000,000.00
        netWorthEndCents: 125000000, // ¥1,250,000.00
        incomeCents: 20000000, // ¥200,000.00
        expenseCents: 12000000, // ¥120,000.00
        cashDeltaCents: 3000000, // +¥30,000.00
        notes: const [
          ReportNote(title: '口径说明', lines: ['口径行一', '口径行二']),
        ],
      ),
      balanceSheet: BalanceSheetSection.create(
        assets: [
          CategoryAmount.create(
              category: 'savings', amountCents: 60000000, totalCents: 100000000),
          CategoryAmount.create(
              category: 'investment',
              amountCents: 40000000,
              totalCents: 100000000),
        ],
        liabilities: [
          // 汇编层排序惯例:按金额降序(assembly「rows.sort(desc)」);
          // 夹具遵循同序,「首行满条」基准才与真实文档一致。
          CategoryAmount.create(
              category: 'loan', amountCents: 30000000, totalCents: 50000000),
          CategoryAmount.create(
              category: 'creditCard',
              amountCents: 20000000,
              totalCents: 50000000),
        ],
        changes: [
          BalanceChange.create(
              category: 'savings', startCents: 55000000, endCents: 60000000),
          BalanceChange.create(
              category: 'investment',
              startCents: 35000000,
              endCents: 40000000),
        ],
      ),
      incomeStatement: IncomeStatementSection(
        income: [
          CategoryAmount.create(
              category: 'acc-salary',
              name: '工资',
              amountCents: 15000000,
              totalCents: 20000000),
          CategoryAmount.create(
              category: 'acc-bonus',
              name: '奖金',
              amountCents: 5000000,
              totalCents: 20000000),
        ],
        expense: [
          CategoryAmount.create(
              category: 'acc-food',
              name: '餐饮',
              amountCents: 7000000,
              totalCents: 12000000),
          CategoryAmount.create(
              category: 'acc-transport',
              name: '交通',
              amountCents: 5000000,
              totalCents: 12000000),
        ],
        dailyAvgCents: 250000, // ¥2,500.00
        priorComparison: PriorComparison.create(
          label: '较 2026 年 7 月',
          surplusCents: 8000000,
          priorSurplusCents: 6000000,
        ),
      ),
      cashFlow: CashFlowSection(
        operating: ActivityFlow.create(inflowCents: 20000000, outflowCents: 12000000),
        investing: ActivityFlow.create(inflowCents: 1000000, outflowCents: 6000000),
        financing: ActivityFlow.create(inflowCents: 0, outflowCents: 0),
        netDeltaCents: 3000000,
        reconciled: true,
      ),
      budget: BudgetSection(items: [
        ReportBudgetItem.create(
            name: '餐饮', actualCents: 7000000, limitCents: 10000000),
        ReportBudgetItem.create(
            name: '交通', actualCents: 4800000, limitCents: 5000000),
        ReportBudgetItem.create(
            name: '娱乐', actualCents: 2000000, limitCents: 1500000),
      ]),
      investment: InvestmentSection.create(
        mvStartCents: 40000000,
        mvEndCents: 46000000,
        netBuyCents: 3000000,
        twr: 7.2,
      ),
      mda: MdaSection.create(
        findings: [
          const MdaFinding(
            ruleId: 'R1',
            severity: MdaSeverity.risk,
            conclusion: '本期储蓄率 40.0%,连续低于 10% 警戒线。',
            advice: '建议优先建立 3-6 个月应急备用金。',
          ),
          const MdaFinding(
            ruleId: 'R2',
            severity: MdaSeverity.warn,
            conclusion: '预算「娱乐」使用率 133.3%,已超支。',
            advice: '建议上调预算额度或压缩非必要支出。',
            actionLink: '/accounts/subscriptions',
          ),
          const MdaFinding(
            ruleId: 'R6',
            severity: MdaSeverity.info,
            conclusion: '现金可支撑约 6.0 个月基本支出。',
            advice: '现金储备处于健康区间。',
          ),
        ],
        healthyRunwayMonths: 6.0,
      ),
      excludedSections: const [],
    );

/// 最小文档:无预算/无持仓/mda 缺席(期外异常形态)→ 四章节 + 未包含项附注。
ReportDocument minimalDocument() => ReportDocument(
      period: ReportPeriod.monthly(2026, 8),
      generatedAt: DateTime.utc(2026, 9, 1, 2, 3, 4),
      overview: OverviewSection.create(
        netWorthStartCents: 100000000,
        netWorthEndCents: 125000000,
        incomeCents: 20000000,
        expenseCents: 12000000,
        cashDeltaCents: 3000000,
        notes: const [
          ReportNote(title: '口径说明', lines: ['口径行一']),
          ReportNote(title: '未包含项', lines: [
            '未包含:预算执行(本期无预算)',
            '未包含:投资绩效(本期无持仓)',
          ]),
        ],
      ),
      balanceSheet: fullDocument().balanceSheet,
      incomeStatement: IncomeStatementSection(
        income: fullDocument().incomeStatement.income,
        expense: fullDocument().incomeStatement.expense,
        dailyAvgCents: 250000,
        priorComparison: null, // 首期无对比
      ),
      cashFlow: fullDocument().cashFlow,
      excludedSections: const ['预算执行(本期无预算)', '投资绩效(本期无持仓)'],
    );

/// 健康诊断变体:零发现(诊断章节健康卡分支;runway 6.0)。
ReportDocument healthyMdaDocument() => fullDocument().withMda(
      MdaSection.create(findings: const [], healthyRunwayMonths: 6.0),
    );

/// 年报变体:默认文件名/期标签的年度形态断言用(「2025年度」)。
ReportDocument yearlyDocument() {
  final base = minimalDocument();
  return ReportDocument(
    period: ReportPeriod.yearly(2025),
    generatedAt: base.generatedAt,
    overview: base.overview,
    balanceSheet: base.balanceSheet,
    incomeStatement: base.incomeStatement,
    cashFlow: base.cashFlow,
    budget: base.budget,
    investment: base.investment,
    mda: base.mda,
    excludedSections: base.excludedSections,
  );
}
