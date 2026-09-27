import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/expense_basis.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

/// T1 report domain:ExpenseBasis 现金口径默认实现(FR-7/ADR-6)。
///
/// CashExpenseBasis:expense(5) 类型科目按 debit 单边汇总,分类
/// 维度 = expense 科目账户;期望值全部手算(G oracle)。
void main() {
  LedgerEntryRow e(String t, String a, DateTime date,
          {int debitCents = 0,
          int creditCents = 0,
          int type = 5,
          String? category}) =>
      LedgerEntryRow(
        transactionId: t,
        accountId: a,
        accountType: type,
        category: category,
        date: date,
        debitCents: debitCents,
        creditCents: creditCents,
      );

  final aug = ReportPeriod.monthly(2026, 8);
  const basis = CashExpenseBasis();

  test('多 expense 科目汇总:600+400 → 总额 1000、构成按账户维度', () {
    final entries = [
      e('t1', 'E1', DateTime(2026, 8, 5), debitCents: 600),
      e('t2', 'E2', DateTime(2026, 8, 20), debitCents: 400),
    ];
    expect(basis.totalExpense(entries, aug), 1000);
    final byCat = basis.expenseByCategory(entries, aug);
    expect(byCat, hasLength(2));
    // 按金额降序:E1 600(60.0%)在前,E2 400(40.0%)在后。
    expect(byCat.first.category, 'E1');
    expect(byCat.first.amountCents, 600);
    expect(byCat.first.pct, 60.0);
    expect(byCat.last.category, 'E2');
    expect(byCat.last.amountCents, 400);
    expect(byCat.last.pct, 40.0);
  });

  test('期内过滤:7 月末/9 月初的支出不计入 8 月', () {
    final entries = [
      e('t0', 'E1', DateTime(2026, 7, 31), debitCents: 700),
      e('t1', 'E1', DateTime(2026, 8, 5), debitCents: 600),
      e('t2', 'E1', DateTime(2026, 9, 1), debitCents: 900),
    ];
    expect(basis.totalExpense(entries, aug), 600);
    final byCat = basis.expenseByCategory(entries, aug);
    expect(byCat, hasLength(1));
    expect(byCat.single.amountCents, 600);
    // 总额即自身 → pct 100.0。
    expect(byCat.single.pct, 100.0);
  });

  test('debit 单边口径(对齐 TransactionSummary):退款 credit 不冲抵当期支出', () {
    final entries = [
      e('t1', 'E1', DateTime(2026, 8, 5), debitCents: 600),
      e('t2', 'E1', DateTime(2026, 8, 8), creditCents: 100),
    ];
    // spec FR-7「现状 TransactionSummary 语义」:expense 科目只取 debit
    // 单边(local_ds L425 同款),credit 退款不冲抵;净额(debit−credit)
    // 口径留待 R17 待摊 basis 变体。
    expect(basis.totalExpense(entries, aug), 600);
    expect(basis.expenseByCategory(entries, aug).single.amountCents, 600);
  });

  test('非 expense 科目不计:income/asset/liability 行被忽略', () {
    final entries = [
      e('t1', 'E1', DateTime(2026, 8, 5), debitCents: 600),
      e('t2', 'I1', DateTime(2026, 8, 6), creditCents: 5000, type: 4),
      e('t3', 'S1', DateTime(2026, 8, 7), creditCents: 300, type: 1, category: 'savings'),
      e('t4', 'C1', DateTime(2026, 8, 8), creditCents: 200, type: 2, category: 'creditCard'),
    ];
    expect(basis.totalExpense(entries, aug), 600);
    expect(basis.expenseByCategory(entries, aug).single.category, 'E1');
  });

  test('空账本:总额 0、构成空列表(不抛)', () {
    expect(basis.totalExpense(const [], aug), 0);
    expect(basis.expenseByCategory(const [], aug), isEmpty);
  });

  test('同科目多笔累计后参与降序排序:E3 1200 > E1 600', () {
    final entries = [
      e('t1', 'E1', DateTime(2026, 8, 5), debitCents: 600),
      e('t2', 'E3', DateTime(2026, 8, 6), debitCents: 700),
      e('t3', 'E3', DateTime(2026, 8, 7), debitCents: 500),
    ];
    final byCat = basis.expenseByCategory(entries, aug);
    expect(byCat.map((c) => c.category).toList(), ['E3', 'E1']);
    expect(byCat.first.pct, 66.7); // 1200/1800 → 66.666… → 66.7
  });

  test('契约形态:CashExpenseBasis 可当 ExpenseBasis 注入(构造注入,FR-7)', () {
    ExpenseBasis injected = const CashExpenseBasis();
    expect(
      injected.totalExpense(
          [e('t1', 'E1', DateTime(2026, 8, 5), debitCents: 250)], aug),
      250,
    );
  });
}
