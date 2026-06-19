import 'package:equatable/equatable.dart';

/// Events for [TransactionFormBloc].
///
/// The form is single-purpose: record one 记一笔. Three flavors mirror the
/// server's SimpleExpense / SimpleIncome / SimpleTransfer RPCs:
///   - 支出 → debit expense account, credit asset account
///   - 收入 → debit asset account, credit income account
///   - 转账 → debit destination asset, credit source asset
///
/// [LoadAccountsRequested] fires once on page open so the category dropdown
/// (account-as-category) has options. Filtering by [AccountType] happens in
/// the page — the bloc just holds the full list.
abstract class TransactionFormEvent extends Equatable {
  const TransactionFormEvent();
  @override
  List<Object?> get props => [];
}

class LoadAccountsRequested extends TransactionFormEvent {
  const LoadAccountsRequested();
}

class RecordExpenseRequested extends TransactionFormEvent {
  const RecordExpenseRequested({
    required this.transactionDate,
    required this.expenseAccountId,
    required this.assetAccountId,
    required this.amountCents,
    this.description = '',
    this.note = '',
  });

  final DateTime transactionDate;
  final String expenseAccountId;
  final String assetAccountId;
  final int amountCents;
  final String description;
  final String note;

  @override
  List<Object?> get props => [
        transactionDate,
        expenseAccountId,
        assetAccountId,
        amountCents,
        description,
        note,
      ];
}

class RecordIncomeRequested extends TransactionFormEvent {
  const RecordIncomeRequested({
    required this.transactionDate,
    required this.assetAccountId,
    required this.incomeAccountId,
    required this.amountCents,
    this.description = '',
    this.note = '',
  });

  final DateTime transactionDate;
  final String assetAccountId;
  final String incomeAccountId;
  final int amountCents;
  final String description;
  final String note;

  @override
  List<Object?> get props => [
        transactionDate,
        assetAccountId,
        incomeAccountId,
        amountCents,
        description,
        note,
      ];
}

class RecordTransferRequested extends TransactionFormEvent {
  const RecordTransferRequested({
    required this.transactionDate,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    this.description = '',
    this.note = '',
  });

  final DateTime transactionDate;
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final String description;
  final String note;

  @override
  List<Object?> get props => [
        transactionDate,
        fromAccountId,
        toAccountId,
        amountCents,
        description,
        note,
      ];
}
