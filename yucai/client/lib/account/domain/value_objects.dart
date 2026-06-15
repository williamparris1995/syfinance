import 'package:yucai_client/proto/account/v1/account.pb.dart' as pb;

// Account enums mirror proto yucai.account.v1. Domain-side enums keep the UI
// decoupled from generated code; mappers convert between the two.

enum AccountType {
  asset,
  liability,
  equity,
  income,
  expense,
}

extension AccountTypeProto on AccountType {
  pb.AccountType toProto() {
    switch (this) {
      case AccountType.asset:
        return pb.AccountType.ACCOUNT_TYPE_ASSET;
      case AccountType.liability:
        return pb.AccountType.ACCOUNT_TYPE_LIABILITY;
      case AccountType.equity:
        return pb.AccountType.ACCOUNT_TYPE_EQUITY;
      case AccountType.income:
        return pb.AccountType.ACCOUNT_TYPE_INCOME;
      case AccountType.expense:
        return pb.AccountType.ACCOUNT_TYPE_EXPENSE;
    }
  }

  String get label {
    switch (this) {
      case AccountType.asset:
        return '资产';
      case AccountType.liability:
        return '负债';
      case AccountType.equity:
        return '权益';
      case AccountType.income:
        return '收入';
      case AccountType.expense:
        return '支出';
    }
  }
}

AccountType accountTypeFromProto(pb.AccountType t) {
  switch (t) {
    case pb.AccountType.ACCOUNT_TYPE_ASSET:
      return AccountType.asset;
    case pb.AccountType.ACCOUNT_TYPE_LIABILITY:
      return AccountType.liability;
    case pb.AccountType.ACCOUNT_TYPE_EQUITY:
      return AccountType.equity;
    case pb.AccountType.ACCOUNT_TYPE_INCOME:
      return AccountType.income;
    case pb.AccountType.ACCOUNT_TYPE_EXPENSE:
      return AccountType.expense;
    default:
      return AccountType.asset;
  }
}

enum Ownership { personal, joint }

extension OwnershipProto on Ownership {
  pb.Ownership toProto() =>
      this == Ownership.personal ? pb.Ownership.OWNERSHIP_PERSONAL : pb.Ownership.OWNERSHIP_JOINT;
  String get label => this == Ownership.personal ? '个人' : '共同';
}

Ownership ownershipFromProto(pb.Ownership o) {
  switch (o) {
    case pb.Ownership.OWNERSHIP_JOINT:
      return Ownership.joint;
    default:
      return Ownership.personal;
  }
}

enum AccountStatus { active, archived }

extension AccountStatusProto on AccountStatus {
  pb.AccountStatus toProto() => this == AccountStatus.active
      ? pb.AccountStatus.ACCOUNT_STATUS_ACTIVE
      : pb.AccountStatus.ACCOUNT_STATUS_ARCHIVED;
}

AccountStatus accountStatusFromProto(pb.AccountStatus s) {
  switch (s) {
    case pb.AccountStatus.ACCOUNT_STATUS_ARCHIVED:
      return AccountStatus.archived;
    default:
      return AccountStatus.active;
  }
}

/// 用户面向账户分类（9 类，匹配原型 + 行业惯例 Mint/YNAB/Quicken）。
/// category 派生会计 [AccountType]（复式记账用），不暴露给用户。
enum AccountCategory {
  savings,
  creditCard,
  investment,
  fixedDeposit,
  goldFx,
  realEstate,
  loan,
  otherAsset,
  otherLiability,
}

extension AccountCategoryX on AccountCategory {
  String get label {
    switch (this) {
      case AccountCategory.savings: return '储蓄';
      case AccountCategory.creditCard: return '信用卡';
      case AccountCategory.investment: return '投资';
      case AccountCategory.fixedDeposit: return '定期';
      case AccountCategory.goldFx: return '黄金外汇';
      case AccountCategory.realEstate: return '固定资产';
      case AccountCategory.loan: return '贷款';
      case AccountCategory.otherAsset: return '其他资产';
      case AccountCategory.otherLiability: return '其他负债';
    }
  }

  String get description {
    switch (this) {
      case AccountCategory.savings: return '活期/定期、现金、数字钱包余额';
      case AccountCategory.creditCard: return '信用卡、花呗、免息分期';
      case AccountCategory.investment: return '证券、基金、理财、数字货币';
      case AccountCategory.fixedDeposit: return '大额存单、结构性存款';
      case AccountCategory.goldFx: return '实物黄金、外币';
      case AccountCategory.realEstate: return '房产、车辆';
      case AccountCategory.loan: return '房贷、车贷、消费贷';
      case AccountCategory.otherAsset: return '古董、字画、收藏品、保险现金价值';
      case AccountCategory.otherLiability: return '其他欠款、应付款';
    }
  }

  /// 派生会计类型（复式记账用）。
  AccountType get accountType {
    switch (this) {
      case AccountCategory.creditCard:
      case AccountCategory.loan:
      case AccountCategory.otherLiability:
        return AccountType.liability;
      default:
        return AccountType.asset;
    }
  }
}
