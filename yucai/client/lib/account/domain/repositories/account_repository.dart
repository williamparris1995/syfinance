import 'package:dartz/dartz.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';

/// Port interface for account operations. Data layer implements this.
abstract class AccountRepository {
  Future<Either<Failure, List<Account>>> list();
  Future<Either<Failure, Account>> create(CreateAccountParams params);
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, Account>> getById(String id);
  Future<Either<Failure, Account>> update(UpdateAccountParams params);
}

/// Parameters for creating an account (kept here next to the repo that consumes
/// it so the domain layer is self-contained).
///
/// Includes 25 nullable category-specific fields (Task 2282). Callers set only
/// the fields relevant to [category]; the data layer forwards non-null /
/// non-empty values to the proto request.
class CreateAccountParams {
  const CreateAccountParams({
    required this.name,
    required this.accountType,
    required this.category,
    required this.currencyCode,
    required this.initialBalanceCents,
    required this.ownership,
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
  });

  final String name;
  final AccountType accountType;
  final AccountCategory category;
  final String currencyCode;
  final int initialBalanceCents;
  final Ownership ownership;
  final String icon;
  final String color;
  final String parentId;

  // Shared / credit-card fields.
  final String institution;
  final int creditLimitCents;
  final String cardNumberTail;
  final String notes;
  final DateTime? openingDate;

  // Credit card.
  final double? interestRate;
  final int? creditBillingDay;
  final int? creditRepaymentDay;
  final int? creditAnnualFeeCents;

  // Investment.
  final int? investCostCents;
  final int? investMarketValueCents;
  final double? investReturnYtd;

  // Fixed deposit.
  final int? fixedPrincipalCents;
  final DateTime? fixedStartDate;
  final DateTime? fixedMaturityDate;
  final int? fixedTermMonths;

  // Gold / FX.
  final String goldProductType;
  final double? goldQuantity;
  final int? goldBuyPriceCents;
  final int? goldCurrentPriceCents;

  // Real estate.
  final int? estatePurchasePriceCents;
  final int? estateCurrentValueCents;
  final DateTime? estatePurchaseDate;
  final double? estateDepreciationRate;

  // Loan.
  final int? loanOriginalCents;
  final int? loanRemainingCents;
  final int? loanMonthlyCents;
  final DateTime? loanNextPaymentDate;
}

/// Parameters for updating an account. Only non-null / non-empty fields are
/// forwarded to the proto; absent fields are left untouched server-side.
///
/// [status] is nullable: null = do not change, [AccountStatus.archived] =
/// close the account. [version] is required for optimistic concurrency.
class UpdateAccountParams {
  const UpdateAccountParams({
    required this.id,
    required this.version,
    this.name = '',
    this.icon = '',
    this.color = '',
    this.parentId = '',
    this.institution = '',
    this.cardNumberTail = '',
    this.notes = '',
    this.goldProductType = '',
    this.creditLimitCents = 0,
    this.status,
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
    this.currentBalanceCents,
  });

  final String id;
  final int version;

  // Identity / shared editable fields.
  final String name;
  final String icon;
  final String color;
  final String parentId;
  final String institution;
  final String cardNumberTail;
  final String notes;
  final String goldProductType;
  final int creditLimitCents;

  /// null = do not change status; [AccountStatus.archived] closes the account.
  final AccountStatus? status;

  final DateTime? openingDate;
  final double? interestRate;
  final int? creditBillingDay;
  final int? creditRepaymentDay;
  final int? creditAnnualFeeCents;
  final int? investCostCents;
  final int? investMarketValueCents;
  final double? investReturnYtd;
  final int? fixedPrincipalCents;
  final DateTime? fixedStartDate;
  final DateTime? fixedMaturityDate;
  final int? fixedTermMonths;
  final double? goldQuantity;
  final int? goldBuyPriceCents;
  final int? goldCurrentPriceCents;
  final int? estatePurchasePriceCents;
  final int? estateCurrentValueCents;
  final DateTime? estatePurchaseDate;
  final double? estateDepreciationRate;
  final int? loanOriginalCents;
  final int? loanRemainingCents;
  final int? loanMonthlyCents;
  final DateTime? loanNextPaymentDate;

  /// null = 不更新；非 null = 手工覆盖当前余额（信用卡「当前欠款」编辑，
  /// 对账单校正例外通道）。负债余额为 credit-正（欠款 = 正数）。
  final int? currentBalanceCents;
}
