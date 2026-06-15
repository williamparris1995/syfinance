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
    this.institution = '',
    this.creditLimitCents = 0,
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
  final String institution;
  final int creditLimitCents;
  final int version;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id, name, accountType, category, currencyCode, initialBalanceCents,
        currentBalanceCents, ownership, status, icon, color, institution,
        creditLimitCents, version, createdAt,
      ];
}
