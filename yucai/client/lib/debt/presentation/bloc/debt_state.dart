import 'package:equatable/equatable.dart';

import 'package:yucai_client/debt/domain/entities/debt_entity.dart';

abstract class DebtState extends Equatable {
  const DebtState();
  @override
  List<Object?> get props => [];
}

class DebtInitial extends DebtState {}

class DebtLoading extends DebtState {}

class DebtsLoaded extends DebtState {
  const DebtsLoaded(this.debts);
  final List<Debt> debts;
  @override
  List<Object?> get props => [debts];
}

class DebtDetailLoaded extends DebtState {
  const DebtDetailLoaded(this.detail);
  final DebtDetail detail;
  @override
  List<Object?> get props => [detail];
}

class DebtSubmitting extends DebtState {
  const DebtSubmitting(this.last);
  final List<Debt> last; // last-known list, so UI keeps context
  @override
  List<Object?> get props => [last];
}

class DebtError extends DebtState {
  const DebtError(this.message, {this.last = const []});
  final String message;
  final List<Debt> last; // last-known list, so UI keeps context
  @override
  List<Object?> get props => [message, last];
}
