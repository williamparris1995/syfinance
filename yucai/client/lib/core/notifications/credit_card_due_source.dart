/// 信用卡还款日候选源(2026-09 催办):扫 drift Accounts 中
/// category=credit_card、active、已设还款日、**当前欠款 > 0**
/// (负债 credit-正;无欠款不打扰 —— 用户定案)的卡,按月推算还款日:
/// - 本月还款日未过 → advance 候选(id `cc:{accountId}:{yyyy-MM}`,
///   与还款对话框「本期不再提醒」共用 [creditCardCycleEntryId])。
/// - 本月还款日已过且仍有欠款 → 追加一条本月已过期次(overdue 催办),
///   同时下月候选照常返回。
/// 还清后(余额 ≤ 0)候选消失 = 催办自然终止。
library;

import 'package:drift/drift.dart' hide Column;

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
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
      final debtCents = a.currentBalanceCents;
      // 本月还款日(按月长 clamp:31→28/30)。
      final thisMonth = _clampDay(today.year, today.month, day);
      final nextMonth =
          _clampDay(today.year, today.month + 1, day);

      if (thisMonth.isBefore(today) || thisMonth.isAtSameMomentAs(today)) {
        // 已过(含当天):overdue 候选(仍欠款);下月到期仅在提前天数
        // 足够长(≥ 跨月)时才会落进窗口。
        out.add(DueScheduleEntry(
          id: creditCardCycleEntryId(a.id, today),
          debtName: a.name,
          totalCents: debtCents,
          paymentDate: thisMonth,
        ));
        if (nextMonth.isBefore(windowEnd)) {
          out.add(DueScheduleEntry(
            id: creditCardCycleEntryId(a.id, nextMonth),
            debtName: a.name,
            totalCents: debtCents,
            paymentDate: nextMonth,
          ));
        }
      } else if (thisMonth.isBefore(windowEnd)) {
        // 未过且在窗口内 → advance 候选。
        out.add(DueScheduleEntry(
          id: creditCardCycleEntryId(a.id, thisMonth),
          debtName: a.name,
          totalCents: debtCents,
          paymentDate: thisMonth,
        ));
      }
    }
    return out;
  }

  /// 月长 clamp(2 月 31 → 28/29;小月 31 → 30)。
  static DateTime _clampDay(int year, int month, int day) {
    var y = year, m = month;
    if (m > 12) {
      y += m ~/ 12;
      m = m % 12;
      if (m == 0) {
        m = 12;
        y -= 1;
      }
    }
    // DateTime 构造自动 clamp 溢出天(2026-02-31 → 2026-03-03),须先求月长。
    final length = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day > length ? length : day);
  }
}
