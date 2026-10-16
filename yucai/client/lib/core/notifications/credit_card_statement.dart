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
/// F61(拍板 A):账单日当天交易归本期新区间([D, 次 D) 含 D),
/// 区间经 core/billing billingCycleOf 单一事实源(订正原 date>D 严格口径)。
library;

import 'package:drift/drift.dart' hide Column;

import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/billing/billing_cycle.dart';

/// 账单周期四值拆解(T8 信用卡详情「账单周期」面板数据源)。
/// 口径与 [CreditCardStatementDue] 库注释一致:
/// current = statement − R + S → statement = current − S + R;
/// remaining = max(0, current − S)(= compute 现值)。
class CreditCardStatementBreakdown {
  const CreditCardStatementBreakdown({
    required this.billingDate,
    required this.statementCents,
    required this.repaidSinceCents,
    required this.cycleNewCents,
    required this.remainingCents,
  });

  /// D:≤ 今天最近的已过账单日(月长 clamp / 跨月跨年归一)。
  final DateTime billingDate;

  /// 上期账单 = current − S + R(已出账原额,由当前欠款反推还原)。
  final int statementCents;

  /// 上期已还 R = 账单日后负向变动(还款)绝对值之和。
  final int repaidSinceCents;

  /// 本期账单(未出账)S = 账单日后正向变动(消费)之和(= compute 的 Δ)。
  final int cycleNewCents;

  /// 上期剩余应还 = max(0, current − S)(还款日应还,与催办/还款对话框同数)。
  final int remainingCents;
}

class CreditCardStatementDue {
  CreditCardStatementDue._();

  /// 上期账单**剩余**应还(分):账单 − 账单日后已还款 = 当前欠款 − 账单日
  /// 后正向消费(Δ,推导见库注释;行业「剩余未还」口径)。
  ///
  /// T8 起 = `breakdown().remainingCents` 委托(单一实现,既有消费方零改动);
  /// 账单日未设 → breakdown null → 降级当前欠款(现状口径,钉死)。
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
    final b = await breakdown(
      db: db,
      accountId: accountId,
      accountType: accountType,
      currentBalanceCents: currentBalanceCents,
      billingDay: billingDay,
      clock: clock,
    );
    return b?.remainingCents ?? currentBalanceCents;
  }

  /// 账单周期四值拆解(T8):D / 上期账单 / 上期已还 R / 本期账单 S / 上期剩余。
  /// 账单日未设 → null(无法分账单周期,调用方自行降级)。
  /// R 与 S 出自**同一查询**(一次 join,两个累加器,见循环内注释)。
  static Future<CreditCardStatementBreakdown?> breakdown({
    required AppDatabase db,
    required String accountId,
    required int accountType,
    required int currentBalanceCents,
    int? billingDay,
    DateTime Function()? clock,
  }) async {
    // 账单日未设:无法分账单周期,降级信号 = null(compute 回退当前总欠款)。
    if (billingDay == null) return null;

    final now = (clock ?? DateTime.now)();
    final today = DateTime(now.year, now.month, now.day);
    // F61:区间改经 core/billing 单一事实源(billingCycleOf)—— 边界为
    // 拍板 A(账单日当天交易归下期=本期新区间 [D, 次 D) 含 D 当天),订正
    // 原实现的 date>D 严格口径(当天消费掉缝)。
    final cycle = billingCycleOf(today, billingDay: billingDay);
    final d = cycle.start;

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

    // 一次遍历双累加器:S = Σ正向变动(消费,即 compute 的 Δ);
    // R = Σ|负向变动|(账单日后还款)—— 同一查询,不再发第二条 SQL。
    var cycleNew = 0;
    var repaidSince = 0;
    for (final r in rows) {
      final t = r.readTable(db.transactions);
      final date =
          DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
      // ≥ D(拍板 A:账单日当天归本期新区间);≤ 今日末(未来分录不计)。
      if (date.isBefore(d) || date.isAfter(today)) continue;
      final e = r.readTable(db.transactionEntries);
      final entryDelta = _entryDelta(accountType, e.debitCents, e.creditCents);
      if (entryDelta > 0) {
        cycleNew += entryDelta;
      } else if (entryDelta < 0) {
        repaidSince += -entryDelta;
      }
    }
    final remainingUnclamped = currentBalanceCents - cycleNew;
    return CreditCardStatementBreakdown(
      billingDate: d,
      statementCents: currentBalanceCents - cycleNew + repaidSince,
      repaidSinceCents: repaidSince,
      cycleNewCents: cycleNew,
      remainingCents:
          remainingUnclamped < 0 ? 0 : remainingUnclamped,
    );
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

  /// 下一个还款日(≥ [today] 的最近还款日;月长 clamp 同账单日)。
  /// 面板「还有 N 天」chip 与详情页还款提醒 callout 共用(单一口径,
  /// v5 原型 B「应还拆解」拍板引入)。[today] 须为日期零点(调用方归一)。
  static DateTime nextRepaymentDate(DateTime today, int repaymentDay) {
    final thisMonth = clampDay(today.year, today.month, repaymentDay);
    if (!thisMonth.isBefore(today)) return thisMonth;
    return clampDay(today.year, today.month + 1, repaymentDay);
  }
}
