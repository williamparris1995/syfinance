/// 到期候选的强类型路由目标(2026-09 到期常显提醒,design ADR-2):
/// 期次候选 → 债务详情页;信用卡还款日候选 → 还款对话框。
/// spec FR-3 明令禁止解析 id 字符串前缀的脆弱契约,故候选携带本 sealed
/// 目标,消费方 switch 穷尽处理。
library;

/// 直达路由目标(sealed:两源各自构造,消费方穷尽分支)。
sealed class DueTarget {
  const DueTarget();
}

/// 账户目标:信用卡还款日候选,直达该卡还款对话框。
class AccountTarget extends DueTarget {
  const AccountTarget(this.accountId);

  /// 卡所在账户 id(CreditCardDueSource 构造时原持)。
  final String accountId;
}

/// 债务目标:期次候选,直跳该债务详情页。
class DebtTarget extends DueTarget {
  const DebtTarget(this.debtId);

  /// 债务 id(DriftDueSource join 行的期次 debtId)。
  final String debtId;
}
