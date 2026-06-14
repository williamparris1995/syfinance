import 'package:dartz/dartz.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/error/failures.dart';

/// Port interface for account operations. Data layer implements this.
abstract class AccountRepository {
  Future<Either<Failure, List<Account>>> list();
  Future<Either<Failure, Account>> create(CreateAccountParams params);
  Future<Either<Failure, void>> delete(String id);
}

/// Parameters for creating an account (kept here next to the repo that consumes
/// it so the domain layer is self-contained).
class CreateAccountParams {
  const CreateAccountParams({
    required this.name,
    required this.accountType,
    required this.currencyCode,
    required this.initialBalanceCents,
    required this.ownership,
    this.icon = '',
    this.color = '',
  });

  final String name;
  final AccountType accountType;
  final String currencyCode;
  final int initialBalanceCents;
  final Ownership ownership;
  final String icon;
  final String color;
}
