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
