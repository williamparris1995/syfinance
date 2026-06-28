import 'package:equatable/equatable.dart';

import 'package:yucai_client/debt/domain/value_objects.dart';

abstract class DebtEvent extends Equatable {
  const DebtEvent();
  @override
  List<Object?> get props => [];
}

/// 拉取债务列表。`typeFilter` 非空时只取该方向(borrowedIn/borrowedOut),
/// 为 null(默认)时不过滤 → 既有 debts_page「列出全部」行为保持不变。
class LoadDebtsRequested extends DebtEvent {
  const LoadDebtsRequested({this.typeFilter});
  final DebtType? typeFilter;
  @override
  List<Object?> get props => [typeFilter];
}

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
    this.type = DebtType.borrowedIn,
    this.subtype = '',
    this.sourceAccountId,
  });
  final String accountId;
  final String counterparty;
  final double interestRate;
  final int amortizationIndex; // AmortizationMethod.index
  final DateTime? startDateOption;
  final DateTime? dueDateOption;
  final int totalPrincipalCents;
  /// 债务方向。默认 borrowedIn → 既有 debts_page/form 行为不变;
  /// receivables 表单显式传 borrowedOut。
  final DebtType type;
  /// 债务子类型(纯 String,无枚举映射)。默认 '' → 既有调用点编译不变。
  final String subtype;
  /// borrowedOut 双写:借出资金的来源账户(cash asset)。borrowedOut 必填;
  /// borrowedIn 忽略(不双写)。null → 空字符串 → 不双写。
  final String? sourceAccountId;

  @override
  List<Object?> get props => [
        accountId,
        counterparty,
        interestRate,
        amortizationIndex,
        startDateOption,
        dueDateOption,
        totalPrincipalCents,
        type,
        subtype,
        sourceAccountId,
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
