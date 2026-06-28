/// 摊还方法(对齐 proto AmortizationMethod)。
enum AmortizationMethod {
  equalPrincipalInterest, // 等额本息
  equalPrincipal, // 等额本金
  lumpSum, // 一次性
}

enum PaymentStatus { paid, pending, overdue }

/// 债务方向(对齐 proto DebtType,客户端独立枚举;data 层 mapper 负责转换)。
/// borrowedIn = 借入(负债,默认值,匹配服务端旧行为);
/// borrowedOut = 借出(债权 / 应收)。
enum DebtType { borrowedIn, borrowedOut }

/// borrowedIn 子类型 const(英文 key + 中文 label)。判断用 const,禁裸字符串。
abstract final class DebtSubtypes {
  static const mortgage = 'mortgage';
  static const autoLoan = 'auto_loan';
  static const creditCard = 'credit_card';
  static const family = 'family';
  static const other = 'other';
  static const all = [mortgage, autoLoan, creditCard, family, other];
  static const labels = {
    mortgage: '房贷',
    autoLoan: '车贷',
    creditCard: '信用卡',
    family: '亲友借款',
    other: '其他',
  };
}

/// borrowedOut 子类型 const。
abstract final class ReceivableSubtypes {
  static const personal = 'personal';
  static const business = 'business';
  static const family = 'family';
  static const other = 'other';
  static const all = [personal, business, family, other];
  static const labels = {
    personal: '私人',
    business: '商业',
    family: '亲友',
    other: '其他',
  };
}
