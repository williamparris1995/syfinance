import 'package:equatable/equatable.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';

abstract class AccountState extends Equatable {
  const AccountState();
  @override
  List<Object?> get props => [];
}

class AccountInitial extends AccountState {}

class AccountLoading extends AccountState {}

class AccountsLoaded extends AccountState {
  const AccountsLoaded(this.accounts);
  final List<Account> accounts;
  @override
  List<Object?> get props => [accounts];
}

class AccountFormSubmitting extends AccountState {
  const AccountFormSubmitting(this.accounts);
  final List<Account> accounts;
  @override
  List<Object?> get props => [accounts];
}

class AccountDetailLoaded extends AccountState {
  const AccountDetailLoaded(this.account);
  final Account account;
  @override
  List<Object?> get props => [account];
}

class AccountError extends AccountState {
  const AccountError(this.message, {this.accounts = const []});
  final String message;
  final List<Account> accounts; // last-known list, so UI keeps context
  @override
  List<Object?> get props => [message, accounts];
}
