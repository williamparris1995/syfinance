/// 信用卡还款日候选源(2026-09 催办):扫 drift Accounts 中
/// category=credit_card、active、已设还款日、**当前欠款 > 0**
/// (负债 credit-正;无欠款不打扰 —— 用户定案)的卡,按月推算还款日:
/// - 本月还款日未过 → advance 候选(id `cc:{accountId}:{yyyy-MM}`,
///   与还款对话框「本期不再提醒」共用 [creditCardCycleEntryId])。
/// - 本月还款日已过且仍有欠款 → 追加一条本月已过期次(overdue 催办),
///   同时下月候选照常返回。
/// 金额口径(T7 修正):候选/overdue totalCents = **上期账单应还**
/// ([CreditCardStatementDue] 共享推导;账单日未设降级 = 当前总欠款)。
/// **应还 ≤ 0 → 不产候选**(还清上期账单后即使本周期有消费也不再催
/// —— 用户领域规则);还清后(余额 ≤ 0)候选消失 = 催办自然终止。
library;

import 'package:drift/drift.dart' hide Column;

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/credit_card_statement.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';

/// drift 列存储编码(与 AccountLocalDataSource 的 index+1 口径一致):
/// creditCard=2(枚举序 1),active=1。
const int _kCreditCardCategoryCode = 2;
const int _kActiveStatusCode = 1;

class CreditCardDueSource implements DueScheduleSource {
  CreditCardDueSource(this.db, {this.configProvider, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final AppDatabase db;
  final DueReminderConfig Function()? configProvider;
  final DateTime Function() _now;

  int get _advanceDays =>
      configProvider?.call().advanceDays ??
      const DueReminderConfig().advanceDays;

  @override
  Future<List<DueScheduleEntry>> unpaidDueCandidates() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final windowEnd =
        DateTime(today.year, today.month, today.day).add(Duration(
      days: _advanceDays + 1,
    ));

    final rows = await (db.select(db.accounts)
          ..where((t) =>
              t.category.equals(_kCreditCardCategoryCode) &
              t.status.equals(_kActiveStatusCode) &
              t.creditRepaymentDay.isNotNull() &
              t.currentBalanceCents.isBiggerThanValue(0)))
        .get();

    final out = <DueScheduleEntry>[];
    for (final a in rows) {
      final day = a.creditRepaymentDay!;
      // T7:金额口径 = 上期账单应还(账单日未设降级 = 当前总欠款),
      // 与还款对话框同一共享推导 → 同一数字。
      final dueCents = await CreditCardStatementDue.compute(
        db: db,
        accountId: a.id,
        accountType: a.accountType,
        currentBalanceCents: a.currentBalanceCents,
        billingDay: a.creditBillingDay,
        clock: _now,
      );
      // 应还 ≤ 0(上期账单已还清)→ 不催,即使本周期有新消费。
      if (dueCents <= 0) continue;
      // 本月还款日(按月长 clamp:31→28/30)。
      final thisMonth =
          CreditCardStatementDue.clampDay(today.year, today.month, day);
      final nextMonth =
          CreditCardStatementDue.clampDay(today.year, today.month + 1, day);

      if (thisMonth.isBefore(today) || thisMonth.isAtSameMomentAs(today)) {
        // 已过(含当天):overdue 候选(仍欠款);下月到期仅在提前天数
        // 足够长(≥ 跨月)时才会落进窗口。
        out.add(DueScheduleEntry(
          id: creditCardCycleEntryId(a.id, today),
          debtName: a.name,
          totalCents: dueCents,
          paymentDate: thisMonth,
          target: AccountTarget(a.id),
        ));
        if (nextMonth.isBefore(windowEnd)) {
          out.add(DueScheduleEntry(
            id: creditCardCycleEntryId(a.id, nextMonth),
            debtName: a.name,
            totalCents: dueCents,
            paymentDate: nextMonth,
            target: AccountTarget(a.id),
          ));
        }
      } else if (thisMonth.isBefore(windowEnd)) {
        // 未过且在窗口内 → advance 候选。
        out.add(DueScheduleEntry(
          id: creditCardCycleEntryId(a.id, thisMonth),
          debtName: a.name,
          totalCents: dueCents,
          paymentDate: thisMonth,
          target: AccountTarget(a.id),
        ));
      }
    }
    return out;
  }
}
