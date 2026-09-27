import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/balance_replay.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

/// T1 report domain:BalanceReplay 回放(FR-4/ADR-3)。
///
/// delta 规则照抄 transaction/data/balance_updater.dart L40-52:
/// asset(1)/expense(5) → debit−credit;liability(2)/equity(3)/income(4)
/// → credit−debit;未知类型 → 0。期望值全部手算(G oracle)。
void main() {
  // 便捷构造:asset(1) 储蓄账户。
  AccountRow acc(String id,
          {int type = 1,
          String? category = 'savings',
          int initialBalanceCents = 0}) =>
      AccountRow(
        id: id,
        type: type,
        category: category,
        initialBalanceCents: initialBalanceCents,
        currencyCode: 'CNY',
      );

  // 便捷构造:分录行(所属交易 t、账户 a、日期、借/贷)。
  LedgerEntryRow entry(String t, String a, DateTime date,
          {int debitCents = 0, int creditCents = 0, int type = 1}) =>
      LedgerEntryRow(
        transactionId: t,
        accountId: a,
        accountType: type,
        category: 'savings',
        date: date,
        debitCents: debitCents,
        creditCents: creditCents,
      );

  final aug = ReportPeriod.monthly(2026, 8);

  test('FR-4 场景:initial 0,8-15 一笔 debit 1000 → 期初 0/期末 1000', () {
    final result = BalanceReplay().replay(
      accounts: [acc('X')],
      entries: [entry('t1', 'X', DateTime(2026, 8, 15), debitCents: 1000)],
      period: aug,
    );
    expect(result['X']!.startCents, 0);
    expect(result['X']!.endCents, 1000);
  });

  test('无分录账户照常出现在输出(start=end=initial)', () {
    final result = BalanceReplay().replay(
      accounts: [acc('X', initialBalanceCents: 500), acc('Y')],
      entries: [entry('t1', 'X', DateTime(2026, 8, 15), debitCents: 1000)],
      period: aug,
    );
    expect(result['Y']!.startCents, 0);
    expect(result['Y']!.endCents, 0);
    expect(result['X']!.startCents, 500);
    expect(result['X']!.endCents, 1500);
  });

  test('跨期边界:7 月末分录计入 8 月期初前缀,9 月分录两头都不影响', () {
    final result = BalanceReplay().replay(
      accounts: [acc('X')],
      entries: [
        entry('t1', 'X', DateTime(2026, 7, 31), debitCents: 500),
        entry('t2', 'X', DateTime(2026, 8, 15), debitCents: 1000),
        entry('t3', 'X', DateTime(2026, 9, 5), debitCents: 200),
      ],
      period: aug,
    );
    // start = 500(7-31 已过);end = 500+1000 = 1500(9-05 未及)。
    expect(result['X']!.startCents, 500);
    expect(result['X']!.endCents, 1500);
  });

  test('期末边界含当天:8-31 23:59:59 计入期末,9-01 00:00:00 不计', () {
    final result = BalanceReplay().replay(
      accounts: [acc('X')],
      entries: [
        entry('t1', 'X', DateTime(2026, 8, 31, 23, 59, 59), debitCents: 700),
        entry('t2', 'X', DateTime(2026, 9, 1), debitCents: 50),
      ],
      period: aug,
    );
    // 若 9-01 误计入,end 会是 750;钉死其为 700。
    expect(result['X']!.endCents, 700);
  });

  test('负债方向(规则照抄 balance_updater):credit 增加余额、debit 减少', () {
    final result = BalanceReplay().replay(
      accounts: [acc('L', type: 2, category: 'creditCard')],
      entries: [
        entry('t1', 'L', DateTime(2026, 8, 20), creditCents: 300, type: 2),
        entry('t2', 'L', DateTime(2026, 8, 25), debitCents: 100, type: 2),
      ],
      period: aug,
    );
    // credit−debit:300 − 100 = 200(信用卡欠款净增 200)。
    expect(result['L']!.startCents, 0);
    expect(result['L']!.endCents, 200);
  });

  test('equity/income 同为 credit 方向;同账户多分录累计', () {
    final result = BalanceReplay().replay(
      accounts: [acc('E', type: 3, category: null), acc('I', type: 4)],
      entries: [
        entry('t1', 'E', DateTime(2026, 8, 2), creditCents: 50, type: 3),
        entry('t2', 'I', DateTime(2026, 8, 3), creditCents: 80, type: 4),
        entry('t3', 'I', DateTime(2026, 8, 4), creditCents: 20, type: 4),
      ],
      period: aug,
    );
    expect(result['E']!.endCents, 50);
    expect(result['I']!.endCents, 100);
  });

  test('同日多笔顺序无关(和可交换):8-10 两笔 debit 合计计入期末', () {
    final result = BalanceReplay().replay(
      accounts: [acc('X')],
      entries: [
        entry('t1', 'X', DateTime(2026, 8, 10), debitCents: 300),
        entry('t2', 'X', DateTime(2026, 8, 10), debitCents: 400),
      ],
      period: aug,
    );
    expect(result['X']!.endCents, 700);
  });
}
