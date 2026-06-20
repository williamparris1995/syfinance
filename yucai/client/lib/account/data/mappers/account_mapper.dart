import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/proto/account/v1/account.pb.dart' as pb;

/// Maps generated proto AccountDTO ↔ domain Account.
@injectable
class AccountMapper {
  const AccountMapper();

  Account toDomain(pb.AccountDTO dto) {
    return Account(
      id: dto.id,
      name: dto.name,
      accountType: accountTypeFromProto(dto.accountType),
      category: accountCategoryFromProto(dto.category),
      currencyCode: dto.currencyCode,
      initialBalanceCents: dto.initialBalanceCents.toInt(),
      currentBalanceCents: dto.currentBalanceCents.toInt(),
      ownership: ownershipFromProto(dto.ownership),
      status: accountStatusFromProto(dto.status),
      icon: dto.icon,
      color: dto.color,
      parentId: dto.parentId,
      institution: dto.institution,
      creditLimitCents: dto.creditLimitCents.toInt(),
      cardNumberTail: dto.hasCardNumberTail() ? dto.cardNumberTail : '',
      notes: dto.hasNotes() ? dto.notes : '',
      openingDate: dto.hasOpeningDate() ? dto.openingDate.toDateTime() : null,
      interestRate: dto.hasInterestRate() ? dto.interestRate : null,
      creditBillingDay: dto.hasCreditBillingDay() ? dto.creditBillingDay : null,
      creditRepaymentDay:
          dto.hasCreditRepaymentDay() ? dto.creditRepaymentDay : null,
      creditAnnualFeeCents: dto.hasCreditAnnualFeeCents()
          ? dto.creditAnnualFeeCents.toInt()
          : null,
      investCostCents:
          dto.hasInvestCostCents() ? dto.investCostCents.toInt() : null,
      investMarketValueCents: dto.hasInvestMarketValueCents()
          ? dto.investMarketValueCents.toInt()
          : null,
      investReturnYtd: dto.hasInvestReturnYtd() ? dto.investReturnYtd : null,
      fixedPrincipalCents: dto.hasFixedPrincipalCents()
          ? dto.fixedPrincipalCents.toInt()
          : null,
      fixedStartDate:
          dto.hasFixedStartDate() ? dto.fixedStartDate.toDateTime() : null,
      fixedMaturityDate:
          dto.hasFixedMaturityDate() ? dto.fixedMaturityDate.toDateTime() : null,
      fixedTermMonths: dto.hasFixedTermMonths() ? dto.fixedTermMonths : null,
      goldProductType: dto.hasGoldProductType() ? dto.goldProductType : '',
      goldQuantity: dto.hasGoldQuantity() ? dto.goldQuantity : null,
      goldBuyPriceCents:
          dto.hasGoldBuyPriceCents() ? dto.goldBuyPriceCents.toInt() : null,
      goldCurrentPriceCents: dto.hasGoldCurrentPriceCents()
          ? dto.goldCurrentPriceCents.toInt()
          : null,
      estatePurchasePriceCents: dto.hasEstatePurchasePriceCents()
          ? dto.estatePurchasePriceCents.toInt()
          : null,
      estateCurrentValueCents: dto.hasEstateCurrentValueCents()
          ? dto.estateCurrentValueCents.toInt()
          : null,
      estatePurchaseDate: dto.hasEstatePurchaseDate()
          ? dto.estatePurchaseDate.toDateTime()
          : null,
      estateDepreciationRate:
          dto.hasEstateDepreciationRate() ? dto.estateDepreciationRate : null,
      loanOriginalCents:
          dto.hasLoanOriginalCents() ? dto.loanOriginalCents.toInt() : null,
      loanRemainingCents:
          dto.hasLoanRemainingCents() ? dto.loanRemainingCents.toInt() : null,
      loanMonthlyCents:
          dto.hasLoanMonthlyCents() ? dto.loanMonthlyCents.toInt() : null,
      loanNextPaymentDate: dto.hasLoanNextPaymentDate()
          ? dto.loanNextPaymentDate.toDateTime()
          : null,
      version: dto.version.toInt(),
      createdAt: dto.hasCreatedAt() ? dto.createdAt.toDateTime() : null,
    );
  }
}

AccountCategory accountCategoryFromProto(pb.AccountCategory c) {
  switch (c) {
    case pb.AccountCategory.ACCOUNT_CATEGORY_CREDIT_CARD:
      return AccountCategory.creditCard;
    case pb.AccountCategory.ACCOUNT_CATEGORY_INVESTMENT:
      return AccountCategory.investment;
    case pb.AccountCategory.ACCOUNT_CATEGORY_FIXED_DEPOSIT:
      return AccountCategory.fixedDeposit;
    case pb.AccountCategory.ACCOUNT_CATEGORY_GOLD_FX:
      return AccountCategory.goldFx;
    case pb.AccountCategory.ACCOUNT_CATEGORY_REAL_ESTATE:
      return AccountCategory.realEstate;
    case pb.AccountCategory.ACCOUNT_CATEGORY_LOAN:
      return AccountCategory.loan;
    case pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_ASSET:
      return AccountCategory.otherAsset;
    case pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_LIABILITY:
      return AccountCategory.otherLiability;
    default:
      return AccountCategory.savings;
  }
}

pb.AccountCategory accountCategoryToProto(AccountCategory c) {
  switch (c) {
    case AccountCategory.creditCard:
      return pb.AccountCategory.ACCOUNT_CATEGORY_CREDIT_CARD;
    case AccountCategory.investment:
      return pb.AccountCategory.ACCOUNT_CATEGORY_INVESTMENT;
    case AccountCategory.fixedDeposit:
      return pb.AccountCategory.ACCOUNT_CATEGORY_FIXED_DEPOSIT;
    case AccountCategory.goldFx:
      return pb.AccountCategory.ACCOUNT_CATEGORY_GOLD_FX;
    case AccountCategory.realEstate:
      return pb.AccountCategory.ACCOUNT_CATEGORY_REAL_ESTATE;
    case AccountCategory.loan:
      return pb.AccountCategory.ACCOUNT_CATEGORY_LOAN;
    case AccountCategory.otherAsset:
      return pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_ASSET;
    case AccountCategory.otherLiability:
      return pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_LIABILITY;
    default:
      return pb.AccountCategory.ACCOUNT_CATEGORY_SAVINGS;
  }
}
