/// F43 财务报告 —— 余额回放引擎(纯函数,FR-4/ADR-3)。
///
/// 从全量分录单遍重建任意时点余额:
/// balance@T = initialBalanceCents + Σ(T 前该账户分录 delta)。
/// delta 规则照抄 `transaction/data/balance_updater.dart` L40-52(与
/// server ApplyEntryDirection 同款):asset(1)/expense(5) → debit−credit;
/// liability(2)/equity(3)/income(4) → credit−debit;未知类型 → 0。
///
/// 期初 = 期起点**前**前缀(date < start,exclusive);
/// 期末 = 期终点**含**前缀(date <= endInclusive,inclusive)。
/// 单遍按条目独立比较归类,结果与输入顺序无关(LLD 的提前 break 为排序
/// 输入下的优化,此处以全量比较保证对未排序输入同样正确)。
library;

import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

/// 账户期初/期末余额对(int cents)。
class BalanceAtPeriod {
  const BalanceAtPeriod({required this.startCents, required this.endCents});

  /// 期初余额(期起点前前缀)。
  final int startCents;

  /// 期末余额(期终点含前缀)。
  final int endCents;
}

/// 余额回放引擎:无状态纯函数,O(n) 单遍。
class BalanceReplay {
  /// 回放 [accounts] 在 [period] 期初/期末两时点的余额。
  ///
  /// 输出对每个账户(含无分录账户)给出一项:
  /// start = initial + Σ(date < period.start 的 delta);
  /// end = initial + Σ(date <= period.endInclusive 的 delta)。
  Map<String, BalanceAtPeriod> replay({
    required List<AccountRow> accounts,
    required List<LedgerEntryRow> entries,
    required ReportPeriod period,
  }) {
    final startPrefix = <String, int>{};
    final endPrefix = <String, int>{};
    for (final e in entries) {
      final delta = _entryDelta(e.accountType, e.debitCents, e.creditCents);
      // 期末前缀 ⊇ 期初前缀:凡 date <= endInclusive 一律累入期末。
      if (!e.date.isAfter(period.endInclusive)) {
        endPrefix[e.accountId] = (endPrefix[e.accountId] ?? 0) + delta;
        // 期初前缀只收 date < start 的更早分录。
        if (e.date.isBefore(period.start)) {
          startPrefix[e.accountId] = (startPrefix[e.accountId] ?? 0) + delta;
        }
      }
    }
    return {
      for (final a in accounts)
        a.id: BalanceAtPeriod(
          startCents: a.initialBalanceCents + (startPrefix[a.id] ?? 0),
          endCents: a.initialBalanceCents + (endPrefix[a.id] ?? 0),
        ),
    };
  }

  /// 分录对账户余额的增量(规则照抄 balance_updater._entryDelta)。
  static int _entryDelta(int accountType, int debitCents, int creditCents) {
    switch (accountType) {
      case 1: // asset
      case 5: // expense
        return debitCents - creditCents;
      case 2: // liability
      case 3: // equity
      case 4: // income
        return creditCents - debitCents;
      default:
        return 0;
    }
  }
}
