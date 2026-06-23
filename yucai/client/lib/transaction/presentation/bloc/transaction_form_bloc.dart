import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_state.dart';

/// Bloc backing the 记一笔 form page.
///
/// Two repositories: [TransactionRepository] for the record RPCs,
/// [AccountRepository] for the dropdown options (account-as-category). The
/// page is constructed via [BlocProvider] with both repos injected from
/// `getIt` (see [TransactionFormPage]); this keeps the bloc DI-light and
/// unit-testable without regenerating injectable config.
class TransactionFormBloc
    extends Bloc<TransactionFormEvent, TransactionFormState> {
  TransactionFormBloc(this._txnRepo, this._accountRepo)
      : super(TransactionFormInitial()) {
    on<LoadAccountsRequested>(_onLoad);
    on<RecordExpenseRequested>(_onExpense);
    on<RecordIncomeRequested>(_onIncome);
    on<RecordTransferRequested>(_onTransfer);
  }

  final TransactionRepository _txnRepo;
  final AccountRepository _accountRepo;

  Future<void> _onLoad(
      LoadAccountsRequested event, Emitter<TransactionFormState> emit) async {
    emit(TransactionFormLoading());
    final result = await _accountRepo.list();
    result.fold(
      (failure) => emit(TransactionFormError(failure.displayMessage)),
      (accounts) => emit(TransactionFormReady(accounts: accounts)),
    );
  }

  Future<void> _onExpense(
      RecordExpenseRequested e, Emitter<TransactionFormState> emit) async {
    final accounts = _readyAccounts;
    emit(TransactionFormSubmitting(accounts));
    final params = RecordExpenseParams(
      transactionDate: e.transactionDate,
      expenseAccountId: e.expenseAccountId,
      assetAccountId: e.assetAccountId,
      amountCents: e.amountCents,
      description: e.description,
      note: e.note,
      transactionTime: e.transactionTime,
    );
    final result = await _txnRepo.recordExpense(params);
    result.fold(
      (failure) => emit(TransactionFormReady(
          accounts: accounts, error: failure.displayMessage)),
      (_) => emit(TransactionFormSuccess()),
    );
  }

  Future<void> _onIncome(
      RecordIncomeRequested e, Emitter<TransactionFormState> emit) async {
    final accounts = _readyAccounts;
    emit(TransactionFormSubmitting(accounts));
    final params = RecordIncomeParams(
      transactionDate: e.transactionDate,
      assetAccountId: e.assetAccountId,
      incomeAccountId: e.incomeAccountId,
      amountCents: e.amountCents,
      description: e.description,
      note: e.note,
      transactionTime: e.transactionTime,
    );
    final result = await _txnRepo.recordIncome(params);
    result.fold(
      (failure) => emit(TransactionFormReady(
          accounts: accounts, error: failure.displayMessage)),
      (_) => emit(TransactionFormSuccess()),
    );
  }

  Future<void> _onTransfer(
      RecordTransferRequested e, Emitter<TransactionFormState> emit) async {
    final accounts = _readyAccounts;
    emit(TransactionFormSubmitting(accounts));
    final params = RecordTransferParams(
      transactionDate: e.transactionDate,
      fromAccountId: e.fromAccountId,
      toAccountId: e.toAccountId,
      amountCents: e.amountCents,
      description: e.description,
      note: e.note,
      transactionTime: e.transactionTime,
    );
    final result = await _txnRepo.recordTransfer(params);
    result.fold(
      (failure) => emit(TransactionFormReady(
          accounts: accounts, error: failure.displayMessage)),
      (_) => emit(TransactionFormSuccess()),
    );
  }

  /// Snapshot of accounts from the most recent Ready state, so the submitting
  /// state can keep the dropdown populated. Empty when no Ready yet.
  List<Account> get _readyAccounts {
    final s = state;
    if (s is TransactionFormReady) return s.accounts;
    if (s is TransactionFormSubmitting) return s.accounts;
    return const [];
  }
}
