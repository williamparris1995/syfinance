/// 摊还方法(对齐 proto AmortizationMethod)。
enum AmortizationMethod {
  equalPrincipalInterest, // 等额本息
  equalPrincipal, // 等额本金
  lumpSum, // 一次性
}

enum PaymentStatus { paid, pending, overdue }
