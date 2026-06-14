import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/usecases/create_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/delete_account_usecase.dart';
import 'package:yucai_client/account/domain/usecases/list_accounts_usecase.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';

@injectable
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc(
    this._list,
    this._create,
    this._delete,
  ) : super(AccountInitial()) {
    on<LoadAccountsRequested>(_onLoad);
    on<CreateAccountRequested>(_onCreate);
    on<DeleteAccountRequested>(_onDelete);
  }

  final ListAccountsUseCase _list;
  final CreateAccountUseCase _create;
  final DeleteAccountUseCase _delete;

  List<Account> _last = const [];

  Future<void> _onLoad(LoadAccountsRequested event, Emitter<AccountState> emit) async {
    emit(AccountLoading());
    final result = await _list.call();
    result.fold(
      (failure) => emit(AccountError(failure.displayMessage, accounts: _last)),
      (accounts) {
        _last = accounts;
        emit(AccountsLoaded(accounts));
      },
    );
  }

  Future<void> _onCreate(CreateAccountRequested event, Emitter<AccountState> emit) async {
    emit(AccountFormSubmitting(_last));
    final result = await _create.call(event.params);
    result.fold(
      (failure) => emit(AccountError(failure.displayMessage, accounts: _last)),
      (_) => add(LoadAccountsRequested()), // refresh list on success
    );
  }

  Future<void> _onDelete(DeleteAccountRequested event, Emitter<AccountState> emit) async {
    final result = await _delete.call(event.id);
    result.fold(
      (failure) => emit(AccountError(failure.displayMessage, accounts: _last)),
      (_) => add(LoadAccountsRequested()), // refresh list on success
    );
  }
}
