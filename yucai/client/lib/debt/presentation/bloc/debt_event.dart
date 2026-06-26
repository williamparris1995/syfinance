import 'package:equatable/equatable.dart';

abstract class DebtEvent extends Equatable {
  const DebtEvent();
  @override
  List<Object?> get props => [];
}

class LoadDebtsRequested extends DebtEvent {}

class LoadDebtRequested extends DebtEvent {
  const LoadDebtRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// Parameters for creating a debt. Mirrors [DebtRepository.create] but allows
/// the form to start with null dates that the UI fills in before submit.
class CreateDebtParams extends Equatable {
  const CreateDebtParams({
    required this.accountId,
    required this.counterparty,
    required this.interestRate,
    required this.amortizationIndex,
    required this.startDateOption,
    required this.dueDateOption,
    required this.totalPrincipalCents,
  });
  final String accountId;
  final String counterparty;
  final double interestRate;
  final int amortizationIndex; // AmortizationMethod.index
  final DateTime? startDateOption;
  final DateTime? dueDateOption;
  final int totalPrincipalCents;

  @override
  List<Object?> get props => [
        accountId,
        counterparty,
        interestRate,
        amortizationIndex,
        startDateOption,
        dueDateOption,
        totalPrincipalCents,
      ];
}

class CreateDebtRequested extends DebtEvent {
  const CreateDebtRequested(this.params);
  final CreateDebtParams params;
  @override
  List<Object?> get props => [params];
}

class UpdateDebtParams extends Equatable {
  const UpdateDebtParams({
    required this.id,
    required this.counterparty,
    required this.interestRate,
    required this.version,
  });
  final String id;
  final String counterparty;
  final double interestRate;
  final int version;

  @override
  List<Object?> get props => [id, counterparty, interestRate, version];
}

class UpdateDebtRequested extends DebtEvent {
  const UpdateDebtRequested(this.params);
  final UpdateDebtParams params;
  @override
  List<Object?> get props => [params];
}

class DeleteDebtRequested extends DebtEvent {
  const DeleteDebtRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class RecordPaymentRequested extends DebtEvent {
  const RecordPaymentRequested({
    required this.debtId,
    required this.scheduleEntryId,
    required this.fromAccountId,
  });
  final String debtId;
  final String scheduleEntryId;
  final String fromAccountId;

  @override
  List<Object?> get props => [debtId, scheduleEntryId, fromAccountId];
}
