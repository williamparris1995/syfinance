import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/proto/transaction/v1/transaction.pb.dart' as pb;

/// Maps generated proto `TransactionDTO` / `EntryDTO` ↔ domain
/// [Transaction] / [TransactionEntry].
///
/// `transactionDate` is a proto `string` (`YYYY-MM-DD`); the domain holds it
/// as [DateTime]. The round-trip uses ISO-8601 date-only, which is what the
/// server emits.
@injectable
class TransactionMapper {
  const TransactionMapper();

  Transaction toDomain(pb.TransactionDTO dto) {
    return Transaction(
      id: dto.id,
      transactionDate: _parseDate(dto.transactionDate),
      description: dto.description,
      entries: dto.entries.map(_entryToDomain).toList(growable: false),
      version: dto.version.toInt(),
      transactionTime: _parseTransactionTime(dto.transactionTime),
      createdAt: dto.hasCreatedAt() ? dto.createdAt.toDateTime() : null,
      updatedAt: dto.hasUpdatedAt() ? dto.updatedAt.toDateTime() : null,
    );
  }

  TransactionEntry _entryToDomain(pb.EntryDTO dto) {
    return TransactionEntry(
      id: dto.id,
      accountId: dto.accountId,
      debitCents: dto.debitCents.toInt(),
      creditCents: dto.creditCents.toInt(),
      note: dto.note,
    );
  }

  /// Builds an [pb.EntryDTO] from a domain entry. Used by RecordTransaction /
  /// UpdateTransaction request construction in the datasource.
  pb.EntryDTO entryToProto(TransactionEntry e) {
    return pb.EntryDTO(
      id: e.id.isEmpty ? null : e.id,
      accountId: e.accountId,
      debitCents: _i64(e.debitCents),
      creditCents: _i64(e.creditCents),
      note: e.note,
    );
  }

  /// Maps a proto [pb.MonthlySummary] to the domain [MonthlySummary].
  ///
  /// `year`/`month` are not on the proto DTO; the caller (datasource) passes
  /// them in so the domain object echoes the request scope. Int64 → int via
  /// [Int64.toInt] (amounts are cents, well within int32 range).
  MonthlySummary summaryToDomain(
    pb.MonthlySummary dto, {
    required int year,
    required int month,
  }) {
    return MonthlySummary(
      year: year,
      month: month,
      incomeCents: dto.incomeCents.toInt(),
      expenseCents: dto.expenseCents.toInt(),
      netCents: dto.netCents.toInt(),
      dailyAvgCents: dto.dailyAvgCents.toInt(),
      byDay: [
        for (final d in dto.byDay)
          DailySummary(
            date: d.date,
            totalIncomeCents: d.totalIncome.toInt(),
            byCategory: [
              for (final c in d.byCategory)
                CategoryTotal(
                  categoryId: c.accountId,
                  name: c.name,
                  accountType: c.accountType,
                  amountCents: c.amount.toInt(),
                ),
            ],
          ),
      ],
    );
  }
}

/// Parses `YYYY-MM-DD` (the server's transactionDate wire format). Falls back
/// to a full ISO-8601 parse for forward-compat if the server ever widens the
/// format. On total parse failure returns the Unix epoch — callers should
/// treat that as suspicious; we do not throw in the read path to keep a
/// single malformed row from poisoning the whole list.
DateTime _parseDate(String s) {
  if (s.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final d = DateTime.tryParse(s);
  return d ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

/// Parses `transactionTime` (proto `string`, RFC3339). Returns `null` when the
/// server omits the field or sends an empty string, so the UI can fall back to
/// `transactionDate`. An unparseable value also yields `null` rather than
/// throwing — a single malformed row must not poison the list view.
DateTime? _parseTransactionTime(String s) {
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

Int64 _i64(int v) => Int64(v);

/// Formats a [DateTime] as the `YYYY-MM-DD` string the server expects for
/// `transaction_date`.
String formatTxnDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
