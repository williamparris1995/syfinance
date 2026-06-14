import 'package:equatable/equatable.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';

abstract class AccountEvent extends Equatable {
  const AccountEvent();
  @override
  List<Object?> get props => [];
}

class LoadAccountsRequested extends AccountEvent {}

class CreateAccountRequested extends AccountEvent {
  const CreateAccountRequested(this.params);
  final CreateAccountParams params;
  @override
  List<Object?> get props => [params];
}

class DeleteAccountRequested extends AccountEvent {
  const DeleteAccountRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}
