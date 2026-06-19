import 'package:equatable/equatable.dart';

import 'package:yucai_client/transaction/domain/value_objects.dart';

/// One line of a double-entry transaction.
///
/// Mutually exclusive: exactly one of [debitCents] / [creditCents] is > 0.
/// [entrySide] exposes that as a typed enum for the UI; both cents fields are
/// retained because the proto wire format stores both per-line.
class TransactionEntry extends Equatable {
  const TransactionEntry({
    required this.accountId,
    required this.debitCents,
    required this.creditCents,
    this.id = '',
    this.note = '',
  });

  /// Server-assigned on read; empty when the caller is constructing a new
  /// entry for RecordTransaction.
  final String id;
  final String accountId;
  final int debitCents;
  final int creditCents;
  final String note;

  /// Derived: which side of the ledger this line hits.
  EntrySide get entrySide =>
      debitCents > 0 ? EntrySide.debit : EntrySide.credit;

  /// The non-zero amount in cents, regardless of side.
  int get amountCents => debitCents > 0 ? debitCents : creditCents;

  TransactionEntry copyWith({
    String? id,
    String? accountId,
    int? debitCents,
    int? creditCents,
    String? note,
  }) {
    return TransactionEntry(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      debitCents: debitCents ?? this.debitCents,
      creditCents: creditCents ?? this.creditCents,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [id, accountId, debitCents, creditCents, note];
}

/// Transaction aggregate (client-side read model). Mirrors
/// `yucai.transaction.v1.TransactionDTO`: a header ([transactionDate],
/// [description], [version]) plus the ordered list of [entries].
///
/// `transactionDate` is a proto `string` (`YYYY-MM-DD`); the domain holds it
/// as [DateTime] for ergonomics. The mapper converts at the data boundary.
class Transaction extends Equatable {
  const Transaction({
    required this.transactionDate,
    required this.entries,
    this.id = '',
    this.description = '',
    this.version = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DateTime transactionDate;
  final String description;
  final List<TransactionEntry> entries;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Sum of debit lines. Must equal sum of credit lines for a balanced txn.
  int get totalDebitCents =>
      entries.fold(0, (sum, e) => sum + e.debitCents);

  /// Sum of credit lines. Must equal [totalDebitCents] for a balanced txn.
  int get totalCreditCents =>
      entries.fold(0, (sum, e) => sum + e.creditCents);

  bool get isBalanced => totalDebitCents == totalCreditCents;

  Transaction copyWith({
    String? id,
    DateTime? transactionDate,
    String? description,
    List<TransactionEntry>? entries,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      transactionDate: transactionDate ?? this.transactionDate,
      description: description ?? this.description,
      entries: entries ?? this.entries,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        transactionDate,
        description,
        entries,
        version,
        createdAt,
        updatedAt,
      ];
}
