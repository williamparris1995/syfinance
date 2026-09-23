/// 信用卡「上期账单应还」共享推导(2026-09 T7 口径修正):
/// 还款日应还的是**上期账单**,与当前总欠款分开(银行/支付宝/Chase 同行
/// 实践)。提醒源 [CreditCardDueSource 详见 credit_card_due_source.dart] 与
/// 还款对话框(account/presentation/widgets/credit_card_repay_dialog.dart,
/// 经组合根算好注入)共用本推导,保证 toast/聚合条/收件箱/对话框同一数字。
///
/// 口径(领域规则,用户验收定案 + 评审裁决修订):
/// - 账单日未设 → 无法分账单周期,降级 = currentBalanceCents(= 旧行为,
///   注释钉死不得静默改)。
/// - D = ≤ 今天最近的账单日(月长 clamp:31 → 28/30,跨月/跨年归一)。
/// - Δ = 该卡分录(join Transactions 取 transactionDate)在
///   date(transactionDate) > D 且 ≤ 今天 的**正向变动**之和
///   (单笔 credit − debit > 0 计入,即消费;**还款分录为负不进 Δ**)。
///   **账单日当天消费算已出账**(date > D 严格;各行账单日当天归属不同,
///   按此默认,注释声明口径)。
/// - 应还 = max(0, currentBalanceCents − Δ) = 上期账单**剩余**应还。
///   推导:current = statement − R + S(R = 账单日后已还款、S = 账单日后
///   消费 = Δ)→ 剩余应还 = statement − R = current − S —— 与行业口径一致
///   (支付宝「剩余未还」/银行);不重建账单日历史原额(那会把已还部分
///   加回,评审裁决废弃)。
/// - 本推导**只读**,不动余额、不写任何表;时钟注入可测。
library;

import 'package:drift/drift.dart' hide Column;

import 'package:yucai_client/core/localdb/app_database.dart';

class CreditCardStatementDue {
  CreditCardStatementDue._();

  /// 上期账单**剩余**应还(分):账单 − 账单日后已还款 = 当前欠款 − 账单日
  /// 后正向消费(Δ,推导见库注释;行业「剩余未还」口径)。
  ///
  /// [accountType] 为 drift/backup 契约 int(asset=1…expense=5);
  /// [billingDay] 信用卡账单日(1-31),null = 降级当前欠款;
  /// [clock] 时钟注入(缺省系统时间)。
  static Future<int> compute({
    required AppDatabase db,
    required String accountId,
    required int accountType,
    required int currentBalanceCents,
    int? billingDay,
    DateTime Function()? clock,
  }) async {
    // 账单日未设:无法分账单周期,降级 = 当前总欠款(现状口径,钉死)。
    if (billingDay == null) return currentBalanceCents;

    final now = (clock ?? DateTime.now)();
    final today = DateTime(now.year, now.month, now.day);
    final thisMonth = clampDay(today.year, today.month, billingDay);
    // 最近已过账单日 D:本月账单日未到 → 上月(月长 clamp / 跨年归一)。
    final d = thisMonth.isAfter(today)
        ? clampDay(today.year, today.month - 1, billingDay)
        : thisMonth;

    // SQL 粗筛 [D, 明日):epoch 下界取本地 D 零点,保证日历日 ≥ D 的行
    // (无论以 UTC 还是本地零点落库)不漏;再在 Dart 侧按日历日严格复核
    // (date > D 且 ≤ 今日末),口径见库注释。
    final rows = await (db.select(db.transactionEntries).join([
      innerJoin(db.transactions,
          db.transactions.id.equalsExp(db.transactionEntries.transactionId)),
    ])
          ..where(db.transactionEntries.accountId.equals(accountId) &
              db.transactions.transactionDate.isBiggerOrEqualValue(d) &
              db.transactions.transactionDate.isSmallerThanValue(
                  DateTime(today.year, today.month, today.day + 1))))
        .get();

    var delta = 0;
    for (final r in rows) {
      final t = r.readTable(db.transactions);
      final date =
          DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
      // date > D 严格(账单日当天 = 已出账);≤ 今日末(未来分录不计)。
      if (!date.isAfter(d) || date.isAfter(today)) continue;
      final e = r.readTable(db.transactionEntries);
      final entryDelta = _entryDelta(accountType, e.debitCents, e.creditCents);
      // 只累计正向变动(消费);还款为负不进 Δ —— 剩余口径,见库注释。
      if (entryDelta > 0) delta += entryDelta;
    }
    final due = currentBalanceCents - delta;
    return due < 0 ? 0 : due;
  }

  /// asset(1)/expense(5) → debit−credit;liability(2)/equity(3)/income(4)
  /// → credit−debit;unknown → 0。与 transaction/data/balance_updater.dart
  /// `_entryDelta` 同源(server ApplyEntryDirection 的逐字照抄);core 不
  /// import feature 模块(跨模块 port 约束),故在此内联同规则。
  static int _entryDelta(int accountType, int debitCents, int creditCents) {
    switch (accountType) {
      case 1:
      case 5:
        return debitCents - creditCents;
      case 2:
      case 3:
      case 4:
        return creditCents - debitCents;
      default:
        return 0;
    }
  }

  /// 月长 clamp(2 月 31 → 28/29;小月 31 → 30;月份双向归一:13 → 次年 1,
  /// 0 → 上年 12)。自 credit_card_due_source.dart `_clampDay` 提为共享静态
  /// (还款日/账单日同一 clamp 规则);DateTime 构造会自动溢出
  /// (2026-02-31 → 2026-03-03),须先求月长再取天。
  static DateTime clampDay(int year, int month, int day) {
    var y = year, m = month;
    while (m > 12) {
      m -= 12;
      y += 1;
    }
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    final length = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, day > length ? length : day);
  }
}
