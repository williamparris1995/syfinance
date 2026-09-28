import 'dart:async';

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
///
/// dev 反馈⑧b:首次 [LoadAccountsRequested] 走一次性 [AccountRepository.list]
/// (首屏语义不变),随后挂 [AccountRepository.watchAccounts] 本地漂移 watch ——
/// 表单打开期间别处(分类管理页/本表单新建入口)创建的分类账户实时合入
/// Ready.accounts,下拉即时出现,不再需要重开表单。
class TransactionFormBloc
    extends Bloc<TransactionFormEvent, TransactionFormState> {
  TransactionFormBloc(this._txnRepo, this._accountRepo)
      : super(TransactionFormInitial()) {
    on<LoadAccountsRequested>(_onLoad);
    on<AccountsChanged>(_onAccountsChanged);
    on<RecordExpenseRequested>(_onExpense);
    on<RecordIncomeRequested>(_onIncome);
    on<RecordTransferRequested>(_onTransfer);
    on<UpdateTransactionRequested>(_onUpdate);
  }

  final TransactionRepository _txnRepo;
  final AccountRepository _accountRepo;

  /// Live tail of the local accounts table; null until the first load.
  StreamSubscription<List<Account>>? _accountsWatch;

  Future<void> _onLoad(
      LoadAccountsRequested event, Emitter<TransactionFormState> emit) async {
    emit(TransactionFormLoading());
    final result = await _accountRepo.list();
    result.fold(
      (failure) => emit(TransactionFormError(failure.displayMessage)),
      (accounts) => emit(TransactionFormReady(accounts: accounts)),
    );
    _startAccountsWatch();
  }

  /// Idempotent lazy subscribe (first load only). Deliberately NOT awaited:
  /// bloc's default sequential transformer would otherwise let a
  /// never-completing watch handler starve every later record/submit event.
  /// A repo that throws synchronously (unstubbed test double) just means no
  /// live tail — the one-shot load above already painted the form.
  void _startAccountsWatch() {
    if (_accountsWatch != null) return;
    try {
      _accountsWatch = _accountRepo.watchAccounts().listen(
            (accounts) => add(AccountsChanged(accounts)),
            // Live-cache tail only: errors degrade to the last Ready state.
            onError: (Object _) {},
          );
    } catch (_) {}
  }

  /// Merge a watch emission into the current state.
  ///
  /// Guards: [TransactionFormSubmitting] / [TransactionFormSuccess] are
  /// skipped — recording a txn updates account *balances*, which re-fires the
  /// accounts watch mid-submit; resurrecting Ready there would un-absorb the
  /// form during flight (and after Success the page is already popping). An
  /// inline [TransactionFormReady.error] is preserved so a failed submit's
  /// message stays visible while the options refresh.
  Future<void> _onAccountsChanged(
      AccountsChanged event, Emitter<TransactionFormState> emit) async {
    final s = state;
    if (s is TransactionFormSubmitting || s is TransactionFormSuccess) return;
    final prevError = s is TransactionFormReady ? s.error : null;
    emit(TransactionFormReady(accounts: event.accounts, error: prevError));
  }

  @override
  Future<void> close() async {
    await _accountsWatch?.cancel();
    return super.close();
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
      (txn) => emit(TransactionFormSuccess(transactionId: txn.id)),
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
      (txn) => emit(TransactionFormSuccess(transactionId: txn.id)),
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
      (txn) => emit(TransactionFormSuccess(transactionId: txn.id)),
    );
  }

  Future<void> _onUpdate(
      UpdateTransactionRequested e, Emitter<TransactionFormState> emit) async {
    final accounts = _readyAccounts;
    emit(TransactionFormSubmitting(accounts));
    final params = UpdateTransactionParams(
      id: e.id,
      version: e.version,
      transactionDate: e.transactionDate,
      description: e.description,
      entries: e.entries,
    );
    final result = await _txnRepo.update(params);
    result.fold(
      (failure) => emit(TransactionFormReady(
          accounts: accounts, error: failure.displayMessage)),
      (_) => emit(TransactionFormSuccess(transactionId: e.id)),
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
