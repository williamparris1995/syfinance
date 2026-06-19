import 'package:equatable/equatable.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';

/// States for [TransactionFormBloc].
///
/// Lifecycle: [Loading] (fetching accounts) → [Ready] (form editable) →
/// [Submitting] (RPC in flight) → either [Success] (pop) or back to [Ready]
/// with an inline error. [Error] is a terminal-ish hold for the load step;
/// submit failures reuse [Ready] with [Ready.error] set so the user keeps
/// their typed values.
abstract class TransactionFormState extends Equatable {
  const TransactionFormState();
  @override
  List<Object?> get props => [];
}

class TransactionFormInitial extends TransactionFormState {}

class TransactionFormLoading extends TransactionFormState {}

/// Form is ready for input. [accounts] drives both the asset-account dropdown
/// and the category dropdown (filtered by [AccountType] in the page).
class TransactionFormReady extends TransactionFormState {
  const TransactionFormReady({
    this.accounts = const [],
    this.error,
  });

  final List<Account> accounts;
  /// Inline submit / load error message. null = no error shown.
  final String? error;

  @override
  List<Object?> get props => [accounts, error];
}

class TransactionFormSubmitting extends TransactionFormState {
  const TransactionFormSubmitting(this.accounts);
  final List<Account> accounts;
  @override
  List<Object?> get props => [accounts];
}

/// Record succeeded → the page pops. Carries the resulting transaction so a
/// caller (list page) could refresh.
class TransactionFormSuccess extends TransactionFormState {}

/// Account load failed (terminal). Submit failures do NOT use this — they
/// fall back to [TransactionFormReady] with an error so the form stays editable.
class TransactionFormError extends TransactionFormState {
  const TransactionFormError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
