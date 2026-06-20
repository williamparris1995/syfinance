import 'package:equatable/equatable.dart';

import 'package:yucai_client/account/domain/value_objects.dart';

/// Account aggregate (client-side read model). Monetary amounts are int64 cents
/// — never float — matching the server contract.
class Account extends Equatable {
  const Account({
    required this.id,
    required this.name,
    required this.accountType,
    required this.category,
    required this.currencyCode,
    required this.initialBalanceCents,
    required this.currentBalanceCents,
    required this.ownership,
    required this.status,
    this.icon = '',
    this.color = '',
    this.parentId = '',
    this.institution = '',
    this.creditLimitCents = 0,
    this.cardNumberTail = '',
    this.notes = '',
    this.openingDate,
    this.interestRate,
    this.creditBillingDay,
    this.creditRepaymentDay,
    this.creditAnnualFeeCents,
    this.investCostCents,
    this.investMarketValueCents,
    this.investReturnYtd,
    this.fixedPrincipalCents,
    this.fixedStartDate,
    this.fixedMaturityDate,
    this.fixedTermMonths,
    this.goldProductType = '',
    this.goldQuantity,
    this.goldBuyPriceCents,
    this.goldCurrentPriceCents,
    this.estatePurchasePriceCents,
    this.estateCurrentValueCents,
    this.estatePurchaseDate,
    this.estateDepreciationRate,
    this.loanOriginalCents,
    this.loanRemainingCents,
    this.loanMonthlyCents,
    this.loanNextPaymentDate,
    this.version = 1,
    this.createdAt,
  });

  final String id;
  final String name;
  final AccountType accountType;
  final AccountCategory category;
  final String currencyCode;
  final int initialBalanceCents;
  final int currentBalanceCents;
  final Ownership ownership;
  final AccountStatus status;
  final String icon;
  final String color;
  /// 二级分类的父分类 id（account-as-category；空 = 一级）。
  final String parentId;
  final String institution;
  final int creditLimitCents;

  // ---- Category-specific fields (26) ----
  final String cardNumberTail; // 卡号/账号尾号（金融类）
  final String notes; // 备注
  final DateTime? openingDate; // 开户日期
  final double? interestRate; // 年化利率(%): 储蓄/定期/贷款利率、信用卡 APR
  final int? creditBillingDay; // 信用卡账单日（1-31）
  final int? creditRepaymentDay; // 信用卡还款日（1-31）
  final int? creditAnnualFeeCents; // 信用卡年费
  final int? investCostCents; // 投资投入成本
  final int? investMarketValueCents; // 投资当前市值
  final double? investReturnYtd; // 投资今年收益率(%)
  final int? fixedPrincipalCents; // 定期本金
  final DateTime? fixedStartDate; // 定期起息日
  final DateTime? fixedMaturityDate; // 定期到期日
  final int? fixedTermMonths; // 定期期限（月）
  final String goldProductType; // 黄金外汇品种
  final double? goldQuantity; // 黄金外汇数量
  final int? goldBuyPriceCents; // 黄金外汇买入价
  final int? goldCurrentPriceCents; // 黄金外汇现价
  final int? estatePurchasePriceCents; // 固定资产买入价
  final int? estateCurrentValueCents; // 固定资产现估值
  final DateTime? estatePurchaseDate; // 固定资产买入日期
  final double? estateDepreciationRate; // 固定资产折旧率(%)
  final int? loanOriginalCents; // 贷款原始本金
  final int? loanRemainingCents; // 贷款剩余本金
  final int? loanMonthlyCents; // 贷款月供
  final DateTime? loanNextPaymentDate; // 贷款下次还款日

  final int version;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id, name, accountType, category, currencyCode, initialBalanceCents,
        currentBalanceCents, ownership, status, icon, color, parentId,
        institution, creditLimitCents,
        cardNumberTail, notes, openingDate, interestRate,
        creditBillingDay, creditRepaymentDay, creditAnnualFeeCents,
        investCostCents, investMarketValueCents, investReturnYtd,
        fixedPrincipalCents, fixedStartDate, fixedMaturityDate, fixedTermMonths,
        goldProductType, goldQuantity, goldBuyPriceCents, goldCurrentPriceCents,
        estatePurchasePriceCents, estateCurrentValueCents, estatePurchaseDate,
        estateDepreciationRate,
        loanOriginalCents, loanRemainingCents, loanMonthlyCents,
        loanNextPaymentDate,
        version, createdAt,
      ];

  /// Returns a copy with the given fields overridden. Nullable fields use the
  /// simple `?? this.x` pattern: callers cannot distinguish "omit" from
  /// "explicitly set to null". That is acceptable for edit/copy-seed flows
  /// (which always pass concrete values); explicit-clear flows need a separate
  /// method.
  Account copyWith({
    String? id,
    String? name,
    AccountType? accountType,
    AccountCategory? category,
    String? currencyCode,
    int? initialBalanceCents,
    int? currentBalanceCents,
    Ownership? ownership,
    AccountStatus? status,
    String? icon,
    String? color,
    String? parentId,
    String? institution,
    int? creditLimitCents,
    String? cardNumberTail,
    String? notes,
    DateTime? openingDate,
    double? interestRate,
    int? creditBillingDay,
    int? creditRepaymentDay,
    int? creditAnnualFeeCents,
    int? investCostCents,
    int? investMarketValueCents,
    double? investReturnYtd,
    int? fixedPrincipalCents,
    DateTime? fixedStartDate,
    DateTime? fixedMaturityDate,
    int? fixedTermMonths,
    String? goldProductType,
    double? goldQuantity,
    int? goldBuyPriceCents,
    int? goldCurrentPriceCents,
    int? estatePurchasePriceCents,
    int? estateCurrentValueCents,
    DateTime? estatePurchaseDate,
    double? estateDepreciationRate,
    int? loanOriginalCents,
    int? loanRemainingCents,
    int? loanMonthlyCents,
    DateTime? loanNextPaymentDate,
    int? version,
    DateTime? createdAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      category: category ?? this.category,
      currencyCode: currencyCode ?? this.currencyCode,
      initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
      currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
      ownership: ownership ?? this.ownership,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      institution: institution ?? this.institution,
      creditLimitCents: creditLimitCents ?? this.creditLimitCents,
      cardNumberTail: cardNumberTail ?? this.cardNumberTail,
      notes: notes ?? this.notes,
      openingDate: openingDate ?? this.openingDate,
      interestRate: interestRate ?? this.interestRate,
      creditBillingDay: creditBillingDay ?? this.creditBillingDay,
      creditRepaymentDay: creditRepaymentDay ?? this.creditRepaymentDay,
      creditAnnualFeeCents: creditAnnualFeeCents ?? this.creditAnnualFeeCents,
      investCostCents: investCostCents ?? this.investCostCents,
      investMarketValueCents:
          investMarketValueCents ?? this.investMarketValueCents,
      investReturnYtd: investReturnYtd ?? this.investReturnYtd,
      fixedPrincipalCents: fixedPrincipalCents ?? this.fixedPrincipalCents,
      fixedStartDate: fixedStartDate ?? this.fixedStartDate,
      fixedMaturityDate: fixedMaturityDate ?? this.fixedMaturityDate,
      fixedTermMonths: fixedTermMonths ?? this.fixedTermMonths,
      goldProductType: goldProductType ?? this.goldProductType,
      goldQuantity: goldQuantity ?? this.goldQuantity,
      goldBuyPriceCents: goldBuyPriceCents ?? this.goldBuyPriceCents,
      goldCurrentPriceCents: goldCurrentPriceCents ?? this.goldCurrentPriceCents,
      estatePurchasePriceCents:
          estatePurchasePriceCents ?? this.estatePurchasePriceCents,
      estateCurrentValueCents:
          estateCurrentValueCents ?? this.estateCurrentValueCents,
      estatePurchaseDate: estatePurchaseDate ?? this.estatePurchaseDate,
      estateDepreciationRate:
          estateDepreciationRate ?? this.estateDepreciationRate,
      loanOriginalCents: loanOriginalCents ?? this.loanOriginalCents,
      loanRemainingCents: loanRemainingCents ?? this.loanRemainingCents,
      loanMonthlyCents: loanMonthlyCents ?? this.loanMonthlyCents,
      loanNextPaymentDate: loanNextPaymentDate ?? this.loanNextPaymentDate,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
