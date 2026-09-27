/// F43 财务报告 —— 支出口径抽象(FR-7/ADR-6,domain port)。
///
/// 支出聚合一律经 [ExpenseBasis] 暴露,汇编服务构造注入;默认实现
/// [CashExpenseBasis] = 现金口径(现状 TransactionSummary 语义:expense
/// 科目借方计量)。R17 待摊口径届时提供第二实现,接口测试以假 basis 替换
/// 验证章节结构不变(本票只留接入点,不实现待摊)。
library;

import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

/// 支出口径抽象:报告期支出总额与分类构成。
abstract class ExpenseBasis {
  /// 支出分类构成:分类维度由实现决定(现金口径 = expense 科目账户),
  /// pct 在 [CategoryAmount.create] 构造时按总额算好(1 位小数)。
  List<CategoryAmount> expenseByCategory(
      List<LedgerEntryRow> entries, ReportPeriod period);

  /// 报告期支出总额(int cents)。
  int totalExpense(List<LedgerEntryRow> entries, ReportPeriod period);
}

/// 现金口径默认实现:expense(5) 类型科目按 debit − credit 汇总
/// (credit = 退款/返现冲抵当期支出),分类维度 = expense 科目账户 id,
/// 构成按金额降序(对齐 TransactionSummary byCategory 排序惯例)。
class CashExpenseBasis implements ExpenseBasis {
  const CashExpenseBasis();

  @override
  List<CategoryAmount> expenseByCategory(
      List<LedgerEntryRow> entries, ReportPeriod period) {
    final byAccount = _expenseByAccount(entries, period);
    final total = byAccount.values.fold(0, (a, b) => a + b);
    final rows = [
      for (final entry in byAccount.entries)
        CategoryAmount.create(
          category: entry.key,
          amountCents: entry.value,
          totalCents: total,
        ),
    ];
    rows.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return rows;
  }

  @override
  int totalExpense(List<LedgerEntryRow> entries, ReportPeriod period) =>
      _expenseByAccount(entries, period)
          .values
          .fold(0, (a, b) => a + b);

  /// 期内 expense 科目分录按账户累计(debit − credit)。
  static Map<String, int> _expenseByAccount(
      List<LedgerEntryRow> entries, ReportPeriod period) {
    final byAccount = <String, int>{};
    for (final e in entries) {
      if (e.accountType != 5) continue; // 仅 expense 科目
      final inPeriod = !e.date.isBefore(period.start) &&
          !e.date.isAfter(period.endInclusive);
      if (!inPeriod) continue;
      byAccount[e.accountId] =
          (byAccount[e.accountId] ?? 0) + (e.debitCents - e.creditCents);
    }
    return byAccount;
  }
}
