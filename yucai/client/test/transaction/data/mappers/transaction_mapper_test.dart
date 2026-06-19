import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as tspb;

import 'package:yucai_client/proto/transaction/v1/transaction.pb.dart' as pb;
import 'package:yucai_client/transaction/data/mappers/transaction_mapper.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

void main() {
  const mapper = TransactionMapper();

  test('maps TransactionDTO with entries to domain Transaction', () {
    final dto = pb.TransactionDTO()
      ..id = 't1'
      ..transactionDate = '2026-06-19'
      ..description = '午餐'
      ..version = Int64(3)
      ..createdAt = tspb.Timestamp.fromDateTime(
          DateTime.utc(2026, 6, 19, 1, 2, 3))
      ..entries.addAll([
        pb.EntryDTO()
          ..id = 'e1'
          ..accountId = 'acc-expense'
          ..debitCents = Int64(5000)
          ..creditCents = Int64(0)
          ..note = '食堂',
        pb.EntryDTO()
          ..id = 'e2'
          ..accountId = 'acc-cash'
          ..debitCents = Int64(0)
          ..creditCents = Int64(5000)
          ..note = '',
      ]);

    final t = mapper.toDomain(dto);

    expect(t.id, 't1');
    expect(t.transactionDate, DateTime.parse('2026-06-19'));
    expect(t.description, '午餐');
    expect(t.version, 3);
    expect(t.createdAt, DateTime.utc(2026, 6, 19, 1, 2, 3));

    expect(t.entries.length, 2);
    final debit = t.entries.first;
    expect(debit.id, 'e1');
    expect(debit.accountId, 'acc-expense');
    expect(debit.debitCents, 5000);
    expect(debit.creditCents, 0);
    expect(debit.note, '食堂');
    expect(debit.entrySide, EntrySide.debit);
    expect(debit.amountCents, 5000);

    final credit = t.entries.last;
    expect(credit.entrySide, EntrySide.credit);
    expect(credit.amountCents, 5000);

    // Balanced double-entry invariant.
    expect(t.totalDebitCents, 5000);
    expect(t.totalCreditCents, 5000);
    expect(t.isBalanced, isTrue);
  });

  test('maps empty/missing transactionDate to epoch (defensive)', () {
    final dto = pb.TransactionDTO()..id = 't2';
    final t = mapper.toDomain(dto);
    expect(t.transactionDate, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    expect(t.entries, isEmpty);
    expect(t.version, 0); // default Int64 → 0
  });

  test('entryToProto round-trips a debit entry', () {
    final entry = TransactionEntry(
      id: 'e1',
      accountId: 'acc-expense',
      debitCents: 5000,
      creditCents: 0,
      note: '食堂',
    );
    final proto = mapper.entryToProto(entry);
    expect(proto.id, 'e1');
    expect(proto.accountId, 'acc-expense');
    expect(proto.debitCents.toInt(), 5000);
    expect(proto.creditCents.toInt(), 0);
    expect(proto.note, '食堂');

    // Round-trip back to domain.
    expect(mapper.toDomain(pb.TransactionDTO()
          ..transactionDate = '2026-01-01'
          ..entries.addAll([proto])).entries.first,
        entry);
  });

  test('entryToProto omits empty id (server assigns on create)', () {
    final proto = mapper.entryToProto(const TransactionEntry(
      accountId: 'a',
      debitCents: 1,
      creditCents: 0,
    ));
    expect(proto.hasId(), isFalse);
  });

  test('formatTxnDate emits YYYY-MM-DD zero-padded', () {
    expect(formatTxnDate(DateTime(2026, 6, 9)), '2026-06-09');
    expect(formatTxnDate(DateTime(2026, 12, 31)), '2026-12-31');
  });

  group('summaryToDomain (Task 5.2)', () {
    test('maps MonthlySummary DTO totals + stamps request year/month', () {
      final dto = pb.MonthlySummary()
        ..incomeCents = Int64(1200000)
        ..expenseCents = Int64(800000)
        ..netCents = Int64(400000)
        ..dailyAvgCents = Int64(13333);

      final got = mapper.summaryToDomain(dto, year: 2026, month: 6);

      expect(got.year, 2026);
      expect(got.month, 6);
      expect(got.incomeCents, 1200000);
      expect(got.expenseCents, 800000);
      expect(got.netCents, 400000);
      expect(got.dailyAvgCents, 13333);
      expect(got.byDay, isEmpty);
    });

    test('maps per-day + per-category breakdown', () {
      final dto = pb.MonthlySummary()
        ..incomeCents = Int64(100)
        ..byDay.addAll([
          pb.DailyItem()
            ..date = '2026-06-19'
            ..totalIncome = Int64(50)
            ..byCategory.addAll([
              pb.CategoryItem()
                ..accountId = 'acc-food'
                ..name = '餐饮'
                ..accountType = 'EXPENSE'
                ..amount = Int64(50),
            ]),
        ]);

      final got = mapper.summaryToDomain(dto, year: 2026, month: 6);

      expect(got.byDay.length, 1);
      final day = got.byDay.single;
      expect(day.date, '2026-06-19');
      expect(day.totalIncomeCents, 50);
      final cat = day.byCategory.single;
      expect(cat.categoryId, 'acc-food');
      expect(cat.name, '餐饮');
      expect(cat.accountType, 'EXPENSE');
      expect(cat.amountCents, 50);
    });

    test('net cents preserves negative sign', () {
      final dto = pb.MonthlySummary()
        ..incomeCents = Int64(100)
        ..expenseCents = Int64(300)
        ..netCents = Int64(-200);
      final got = mapper.summaryToDomain(dto, year: 2026, month: 6);
      expect(got.netCents, -200);
    });

    test('empty DTO maps to zeroed totals (no crash)', () {
      final got = mapper.summaryToDomain(pb.MonthlySummary(),
          year: 2026, month: 6);
      expect(got.incomeCents, 0);
      expect(got.expenseCents, 0);
      expect(got.netCents, 0);
      expect(got.dailyAvgCents, 0);
      expect(got.byDay, isEmpty);
    });
  });
}
