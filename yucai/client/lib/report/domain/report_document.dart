/// F43 财务报告 —— 报告模型(immutable VO,纯 Dart domain)。
///
/// 金额一律 int cents;pct/率类派生字段在 factory 构造时算好(1 位小数),
/// 渲染层零计算。结构照 design.md LLD:ReportDocument 为 F43(汇编)/
/// F44(MD&A 规则输入)/F45(导出渲染)三票共享契约。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';

/// 报告期:自然月或自然年(FR-1)。
///
/// 边界为本地时区(对齐 transaction_local_ds 月界口径);终点含
/// (inclusive)到月末 23:59:59(秒粒度,对齐 spec FR-1 验收锚点)。
sealed class ReportPeriod {
  /// 自然月:monthly(2026, 8) → [08-01 00:00:00, 08-31 23:59:59]。
  ///
  /// [month] 须在 1..12,越界抛 [ArgumentError](防手滑构造出 13 月被
  /// DateTime 归一化成次年 1 月的隐性错期)。
  factory ReportPeriod.monthly(int year, int month) {
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', '报告期月份须在 1..12');
    }
    return ReportMonthly(year, month);
  }

  /// 自然年:yearly(2025) → [01-01 00:00:00, 12-31 23:59:59]。
  factory ReportPeriod.yearly(int year) = ReportYearly;

  const ReportPeriod();

  /// 期起点(含)。
  DateTime get start;

  /// 期终点(含)= 下期首日退 1 秒。
  DateTime get endInclusive;

  /// 中文标签:「2026 年 8 月」「2025 年度」。
  String get label;

  /// [moment] 是否落在报告期内(含两端:期内判定谓词的单一事实源,
  /// classifier/basis 一律调用本方法,不再各写一份边界比较)。
  bool contains(DateTime moment) =>
      !moment.isBefore(start) && !moment.isAfter(endInclusive);
}

/// 自然月报告期。
class ReportMonthly extends ReportPeriod {
  const ReportMonthly(this.year, this.month);

  final int year;
  final int month;

  @override
  DateTime get start => DateTime(year, month);

  @override
  DateTime get endInclusive =>
      DateTime(year, month + 1, 1).subtract(const Duration(seconds: 1));

  @override
  String get label => '$year 年 $month 月';

  @override
  bool operator ==(Object other) =>
      other is ReportMonthly && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash('monthly', year, month);
}

/// 自然年报告期。
class ReportYearly extends ReportPeriod {
  const ReportYearly(this.year);

  final int year;

  @override
  DateTime get start => DateTime(year);

  @override
  DateTime get endInclusive =>
      DateTime(year + 1, 1, 1).subtract(const Duration(seconds: 1));

  @override
  String get label => '$year 年度';

  @override
  bool operator ==(Object other) => other is ReportYearly && other.year == year;

  @override
  int get hashCode => Object.hash('yearly', year);
}

/// 四舍五入保留 1 位小数(pct/率类派生统一口径)。
double _round1(double v) => (v * 10).round() / 10;

/// 分类金额构成行(资产负债/收支章节共用)。
class CategoryAmount {
  const CategoryAmount({
    required this.category,
    required this.amountCents,
    required this.pct,
    this.name,
  });

  /// 构造时算 pct = amount/total(1 位小数);总额 0 → 0(空构成不除零)。
  factory CategoryAmount.create({
    required String category,
    String? name,
    required int amountCents,
    required int totalCents,
  }) =>
      CategoryAmount(
        category: category,
        name: name,
        amountCents: amountCents,
        pct: totalCents == 0 ? 0.0 : _round1(amountCents * 100 / totalCents),
      );

  /// 分类代码(资产负债=category 账类代码;收支=expense/income 科目账户 id)。
  final String category;

  /// 展示名(T5-R1 分类名称契约:收支维度 = 科目**账户名**,汇编层按
  /// id→name 映射填入;资产负债维度 = null,渲染层兜底转译 [category]
  /// 账类代码。null/空串均视为未提供)。
  final String? name;

  /// 金额(int cents)。
  final int amountCents;

  /// 构成占比 %(1 位小数)。
  final double pct;
}

/// 报告附注(design LLD 契约:overview.notes 为 List<ReportNote>)。
class ReportNote {
  const ReportNote({required this.title, required this.lines});

  /// 附注标题,如「口径说明」「未包含项」。
  final String title;

  /// 附注正文行(中文文案直写)。
  final List<String> lines;
}

/// 总览章节(FR-3 #1)。
class OverviewSection {
  const OverviewSection({
    required this.netWorthStartCents,
    required this.netWorthEndCents,
    required this.incomeCents,
    required this.expenseCents,
    required this.surplusCents,
    required this.savingsRate,
    required this.netWorthChangePct,
    required this.cashDeltaCents,
    required this.notes,
  });

  /// 构造时算结余 = income − expense、储蓄率 = 结余/收入 %(1 位小数;
  /// 收入 ≤ 0 → 0,不除零)、净资产变动 % = (期末−期初)/期初(1 位小数;
  /// 期初 ≤ 0 → null,除法无意义)——派生字段构造期收口,渲染层零计算
  /// (T5-R1)。
  factory OverviewSection.create({
    required int netWorthStartCents,
    required int netWorthEndCents,
    required int incomeCents,
    required int expenseCents,
    required int cashDeltaCents,
    required List<ReportNote> notes,
  }) {
    final surplus = incomeCents - expenseCents;
    return OverviewSection(
      netWorthStartCents: netWorthStartCents,
      netWorthEndCents: netWorthEndCents,
      incomeCents: incomeCents,
      expenseCents: expenseCents,
      surplusCents: surplus,
      savingsRate:
          incomeCents <= 0 ? 0.0 : _round1(surplus * 100 / incomeCents),
      netWorthChangePct: netWorthStartCents > 0
          ? _round1(
              (netWorthEndCents - netWorthStartCents) * 100 /
                  netWorthStartCents)
          : null,
      cashDeltaCents: cashDeltaCents,
      notes: notes,
    );
  }

  /// 期初净资产(int cents,回放口径,FR-4)。
  final int netWorthStartCents;

  /// 期末净资产。
  final int netWorthEndCents;

  /// 本期收入。
  final int incomeCents;

  /// 本期支出(经 ExpenseBasis 口径,FR-7)。
  final int expenseCents;

  /// 本期结余 = income − expense(构造时算)。
  final int surplusCents;

  /// 储蓄率 %(结余/收入,1 位小数;构造时算)。
  final double savingsRate;

  /// 净资产变动 % = (期末−期初)/期初(1 位小数;期初 ≤ 0 → null;
  /// 构造时算,T5-R1 渲染层零计算收口)。
  final double? netWorthChangePct;

  /// 现金及等价物净变动(= 现金流 netDelta,勾稽同源;多币种下为账本
  /// **原币直加**口径,不折 CNY——口径分工见现金流章节与附注)。
  final int cashDeltaCents;

  /// 口径附注 + 未包含项附注(FR-3/FR-4,见 [ReportNote])。
  final List<ReportNote> notes;
}

/// 资产负债章节(FR-3 #2):期末构成 + 期初/期末变动行 + 构造期算好的
/// 合计与资产负债率(渲染层零计算,T5-R1)。
class BalanceSheetSection {
  const BalanceSheetSection({
    required this.assets,
    required this.liabilities,
    required this.changes,
    required this.assetsTotalCents,
    required this.liabilitiesTotalCents,
    required this.debtRatioPct,
  });

  /// 按三列表构造,合计(Σ各行金额)与资产负债率 = 期末负债/期末资产 %
  /// (1 位小数;资产合计 ≤ 0 → null)构造时算好。
  factory BalanceSheetSection.create({
    required List<CategoryAmount> assets,
    required List<CategoryAmount> liabilities,
    required List<BalanceChange> changes,
  }) {
    final assetsTotal = assets.fold<int>(0, (s, r) => s + r.amountCents);
    final liabilitiesTotal =
        liabilities.fold<int>(0, (s, r) => s + r.amountCents);
    return BalanceSheetSection(
      assets: assets,
      liabilities: liabilities,
      changes: changes,
      assetsTotalCents: assetsTotal,
      liabilitiesTotalCents: liabilitiesTotal,
      debtRatioPct: assetsTotal > 0
          ? _round1(liabilitiesTotal * 100 / assetsTotal)
          : null,
    );
  }

  /// 期末资产构成(按 category 账类代码)。
  final List<CategoryAmount> assets;

  /// 期末负债构成。
  final List<CategoryAmount> liabilities;

  /// 期末−期初变动行(startVsEnd)。
  final List<BalanceChange> changes;

  /// 期末资产合计(int cents,构造时算)。
  final int assetsTotalCents;

  /// 期末负债合计(int cents,构造时算)。
  final int liabilitiesTotalCents;

  /// 资产负债率 %(期末负债/期末资产,1 位小数;资产合计 ≤ 0 → null;
  /// 构造时算)。
  final double? debtRatioPct;
}

/// 单分类期初/期末变动行(资产负债章节用)。
class BalanceChange {
  const BalanceChange({
    required this.category,
    required this.startCents,
    required this.endCents,
    required this.deltaCents,
  });

  /// 构造时算 delta = end − start。
  factory BalanceChange.create({
    required String category,
    required int startCents,
    required int endCents,
  }) =>
      BalanceChange(
        category: category,
        startCents: startCents,
        endCents: endCents,
        deltaCents: endCents - startCents,
      );

  /// 分类代码(同 CategoryAmount.category 维度)。
  final String category;

  /// 期初余额(int cents)。
  final int startCents;

  /// 期末余额。
  final int endCents;

  /// 变动额 = end − start(构造时算)。
  final int deltaCents;
}

/// 收支章节(FR-3 #3)。
class IncomeStatementSection {
  const IncomeStatementSection({
    required this.income,
    required this.expense,
    required this.dailyAvgCents,
    this.priorComparison,
  });

  /// 收入分类构成(income 科目维度)。
  final List<CategoryAmount> income;

  /// 支出分类构成(expense 科目维度,经 ExpenseBasis)。
  final List<CategoryAmount> expense;

  /// 日均:月报 = 结余/活跃日(TransactionSummary 同款);年报 = 全年
  /// 支出/当年自然天数(**报告定案口径**,TransactionSummary 仅月 scope
  /// 计算——差异理由见汇编服务 _dailyAvgCents 注释)。
  final int dailyAvgCents;

  /// 对比期(月报=环比上月;年报=同比上年);首期无对比数据 → null。
  final PriorComparison? priorComparison;
}

/// 对比期环比/同比(收支章节用)。
class PriorComparison {
  const PriorComparison({
    required this.label,
    required this.deltaPct,
  });

  /// 构造时算环比/同比 %(1 位小数):本期结余 vs 对比期结余;
  /// 对比期结余 ≤ 0 → 0(基准无意义,不除零/不除负)。
  factory PriorComparison.create({
    required String label,
    required int surplusCents,
    required int priorSurplusCents,
  }) =>
      PriorComparison(
        label: label,
        deltaPct: priorSurplusCents <= 0
            ? 0.0
            : _round1(
                (surplusCents - priorSurplusCents) * 100 / priorSurplusCents),
      );

  /// 对比期标签,如「较 2026 年 7 月」「较 2025 年度」。
  final String label;

  /// 结余变动 %(1 位小数,正=改善;构造时算)。
  final double deltaPct;
}

/// 现金流章节(FR-3 #4 / FR-5):三类活动流 + 净变动勾稽。
///
/// 多币种口径:各值为账本**原币直加**(勾稽与分录同单位,自洽);外币
/// 折 CNY 仅用于净资产/资产负债时点数(口径分工见总览附注)。
class CashFlowSection {
  const CashFlowSection({
    required this.operating,
    required this.investing,
    required this.financing,
    required this.netDeltaCents,
    required this.reconciled,
  });

  /// 经营活动流(对手 income/expense 科目)。
  final ActivityFlow operating;

  /// 投资活动流(对手投资类非现金资产)。
  final ActivityFlow investing;

  /// 融资活动流(对手负债/权益)。
  final ActivityFlow financing;

  /// 三类净额之和,== 期末−期初现金(汇编 assert 钉死,不等即抛)。
  final int netDeltaCents;

  /// 勾稽通过标记(走到这里即 true,留给渲染层显式表达)。
  final bool reconciled;
}

/// 单类活动现金流。
class ActivityFlow {
  const ActivityFlow({
    required this.inflowCents,
    required this.outflowCents,
    required this.netCents,
  });

  /// 构造时算 net = inflow − outflow。
  factory ActivityFlow.create({
    required int inflowCents,
    required int outflowCents,
  }) =>
      ActivityFlow(
        inflowCents: inflowCents,
        outflowCents: outflowCents,
        netCents: inflowCents - outflowCents,
      );

  /// 流入(int cents,恒 ≥ 0)。
  final int inflowCents;

  /// 流出(int cents,恒 ≥ 0)。
  final int outflowCents;

  /// 净额 = inflow − outflow(构造时算)。
  final int netCents;
}

/// 预算执行章节(FR-3 #5;本期无预算 → null 隐藏 + 附注披露)。
class BudgetSection {
  const BudgetSection({required this.items});

  /// 预算项视图列表。
  final List<ReportBudgetItem> items;
}

/// 单预算项视图。
///
/// 命名带 Report 前缀:与 budget 模块 entities.BudgetItemView 同名异构
/// (那边是 Equatable + accountName 等 DS 形态),避免跨模块混淆。
class ReportBudgetItem {
  const ReportBudgetItem({
    required this.name,
    required this.actualCents,
    required this.limitCents,
    required this.pct,
    required this.overran,
  });

  /// 构造时算使用率 pct = actual/limit %(1 位小数;limit ≤ 0 → 0)与
  /// overran = actual > limit。
  factory ReportBudgetItem.create({
    required String name,
    required int actualCents,
    required int limitCents,
  }) =>
      ReportBudgetItem(
        name: name,
        actualCents: actualCents,
        limitCents: limitCents,
        pct: limitCents <= 0 ? 0.0 : _round1(actualCents * 100 / limitCents),
        overran: actualCents > limitCents,
      );

  /// 预算项名称。
  final String name;

  /// 实际发生额(int cents)。
  final int actualCents;

  /// 预算额度。
  final int limitCents;

  /// 使用率 %(1 位小数;构造时算)。
  final double pct;

  /// 是否超支(构造时算)。
  final bool overran;
}

/// 投资绩效章节(FR-3 #6 / FR-6;无持仓 → null 隐藏 + 附注披露)。
class InvestmentSection {
  const InvestmentSection({
    required this.mvStartCents,
    required this.mvEndCents,
    required this.netBuyCents,
    required this.estGainCents,
    this.twr,
  });

  /// 构造时算估算收益 = 期末市值 − 期初市值 − 当期净买入(FR-6 口径)。
  factory InvestmentSection.create({
    required int mvStartCents,
    required int mvEndCents,
    required int netBuyCents,
    required double? twr,
  }) =>
      InvestmentSection(
        mvStartCents: mvStartCents,
        mvEndCents: mvEndCents,
        netBuyCents: netBuyCents,
        estGainCents: mvEndCents - mvStartCents - netBuyCents,
        twr: twr,
      );

  /// 期初市值(int cents)。
  final int mvStartCents;

  /// 期末市值。
  final int mvEndCents;

  /// 当期净买入(买入−卖出)。
  final int netBuyCents;

  /// 估算收益 = 期末 − 期初 − 净买入(构造时算)。
  final int estGainCents;

  /// 区间 TWR(Holding 域返回引擎口径);端点为零等 sentinel → null。
  final double? twr;
}

/// 财务报告文档(汇编一次性输出的 immutable 快照,ADR-1)。
class ReportDocument {
  const ReportDocument({
    required this.period,
    required this.generatedAt,
    required this.overview,
    required this.balanceSheet,
    required this.incomeStatement,
    required this.cashFlow,
    this.budget,
    this.investment,
    this.mda,
    required this.excludedSections,
  });

  /// 报告期。
  final ReportPeriod period;

  /// 生成时刻(UTC)。
  final DateTime generatedAt;

  /// 总览章节。
  final OverviewSection overview;

  /// 资产负债章节。
  final BalanceSheetSection balanceSheet;

  /// 收支章节。
  final IncomeStatementSection incomeStatement;

  /// 现金流章节。
  final CashFlowSection cashFlow;

  /// 预算执行章节(无预算 → null)。
  final BudgetSection? budget;

  /// 投资绩效章节(无持仓 → null)。
  final InvestmentSection? investment;

  /// 「诊断与建议」章节(F44,ADR-1 诊断随快照):规则引擎在汇编
  /// assembling 阶段对本文档执行后经 [withMda] 回填;直接构造缺省 null
  /// (兼容既有构造/测试)。**恒非空语义**(ADR-6:健康态也是发现集为
  /// 空的章节)——仅期外异常/直接构造时为 null。
  final MdaSection? mda;

  /// 未包含项附注文案来源(FR-3,如「预算执行(本期无预算)」)。
  final List<String> excludedSections;

  /// 回填诊断章节(F44):引擎输入含本文档快照(period/overview/构成),
  /// 故快照先构、章节后缀——generate() 末步调用。
  ReportDocument withMda(MdaSection mda) => ReportDocument(
        period: period,
        generatedAt: generatedAt,
        overview: overview,
        balanceSheet: balanceSheet,
        incomeStatement: incomeStatement,
        cashFlow: cashFlow,
        budget: budget,
        investment: investment,
        mda: mda,
        excludedSections: excludedSections,
      );
}
