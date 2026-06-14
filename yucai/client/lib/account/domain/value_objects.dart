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
