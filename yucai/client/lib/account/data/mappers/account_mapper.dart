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
      currencyCode: dto.currencyCode,
      initialBalanceCents: dto.initialBalanceCents.toInt(),
      currentBalanceCents: dto.currentBalanceCents.toInt(),
      ownership: ownershipFromProto(dto.ownership),
      status: accountStatusFromProto(dto.status),
      icon: dto.icon,
      color: dto.color,
      institution: dto.institution,
      creditLimitCents: dto.creditLimitCents.toInt(),
      version: dto.version.toInt(),
      createdAt: dto.hasCreatedAt() ? dto.createdAt.toDateTime() : null,
    );
  }
}
