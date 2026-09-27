/// F44 T1 测试脚手架:最小可诊断 ReportDocument / MdaSupplement 构造器。
///
/// 纯手算 oracle 用——只填被测规则消费的字段,其余给中性零值;
/// 期望值一律手工推算,不用被测代码反推。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 默认报告期:2026 年 8 月(31 天,月报主场景)。
final aug2026 = ReportPeriod.monthly(2026, 8);

/// 构造最小 ReportDocument。
///
/// - 储蓄率由 OverviewSection.create 按收入/支出派生(1 位小数);
/// - 资产负债率由 assets/liabilities 原始 cents 派生(1 位小数;
///   assetsCents ≤ 0 → null);
/// - [expenseBreakdown] 为收支章节支出构成(按传入原序,引擎/规则按
///   H1 语义取首条为最大类)。
ReportDocument mdaDoc({
  ReportPeriod? period,
  required int incomeCents,
  required int expenseCents,
  List<CategoryAmount> expenseBreakdown = const [],
  int assetsCents = 0,
  int liabilitiesCents = 0,
  BudgetSection? budget,
  InvestmentSection? investment,
}) {
  final reportPeriod = period ?? aug2026;
  const zeroFlow = ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0);
  return ReportDocument(
    period: reportPeriod,
    generatedAt: DateTime.utc(2026, 9, 1),
    overview: OverviewSection.create(
      netWorthStartCents: 0,
      netWorthEndCents: 0,
      incomeCents: incomeCents,
      expenseCents: expenseCents,
      cashDeltaCents: 0,
      notes: const [],
    ),
    balanceSheet: BalanceSheetSection.create(
      assets: [
        if (assetsCents > 0)
          CategoryAmount(
              category: 'cash', amountCents: assetsCents, pct: 100.0),
      ],
      liabilities: [
        if (liabilitiesCents > 0)
          CategoryAmount(
              category: 'loan', amountCents: liabilitiesCents, pct: 100.0),
      ],
      changes: const [],
    ),
    incomeStatement: IncomeStatementSection(
      income: const [],
      expense: expenseBreakdown,
      dailyAvgCents: 0,
    ),
    cashFlow: const CashFlowSection(
      operating: zeroFlow,
      investing: zeroFlow,
      financing: zeroFlow,
      netDeltaCents: 0,
      reconciled: true,
    ),
    budget: budget,
    investment: investment,
    excludedSections: const [],
  );
}

/// 构造 MdaSupplement(缺省=空模板/空交易/零 trailing,健康输入)。
MdaSupplement mdaSupplement({
  List<TemplateRowVO> templates = const [],
  List<LargeTxnVO> transactions = const [],
  int trailing3mExpenseCents = 0,
  int cashStartCents = 0,
  int cashEndCents = 0,
  List<CategoryAmount> priorExpense = const [],
}) =>
    MdaSupplement(
      templates: templates,
      transactions: transactions,
      trailing3mExpenseCents: trailing3mExpenseCents,
      cashStartCents: cashStartCents,
      cashEndCents: cashEndCents,
      priorExpense: priorExpense,
    );

/// 支出模板行速构(R4 用;expectedDates 为期内应扣日,date-only)。
TemplateRowVO expenseTemplate({
  required String id,
  required String name,
  required int amountCents,
  bool paused = false,
  DateTime? nextDate,
  DateTime? lastRecordedDate,
  List<DateTime> expectedDates = const [],
}) =>
    TemplateRowVO(
      id: id,
      name: name,
      expense: true,
      amountCents: amountCents,
      paused: paused,
      autoRecord: false,
      nextDate: nextDate,
      lastRecordedDate: lastRecordedDate,
      expectedDates: expectedDates,
    );

/// 大额单笔交易行速构(R5 用)。
LargeTxnVO txn(
  String transactionId,
  DateTime date,
  String description,
  int expenseCents,
) =>
    LargeTxnVO(
      transactionId: transactionId,
      date: date,
      description: description,
      expenseCents: expenseCents,
    );

/// 支出构成行速构(pct 由 total 派生,1 位小数)。
CategoryAmount expenseRow(String category, String? name, int amountCents,
        int totalCents) =>
    CategoryAmount.create(
      category: category,
      name: name,
      amountCents: amountCents,
      totalCents: totalCents,
    );
