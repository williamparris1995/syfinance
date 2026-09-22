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

  group('transactionTime (Task 4)', () {
    test('maps RFC3339 transactionTime to local wall-clock DateTime', () {
      final dto = pb.TransactionDTO()
        ..id = 't3'
        ..transactionDate = '2026-06-19'
        ..transactionTime = '2026-06-19T13:45:30Z';
      final t = mapper.toDomain(dto);
      // Wall-clock invariant: entity is local (civil .hour is what the UI
      // shows), same instant as the wire UTC timestamp.
      expect(t.transactionTime,
          DateTime.utc(2026, 6, 19, 13, 45, 30).toLocal());
      expect(t.transactionTime!.isUtc, isFalse);
      expect(
          t.transactionTime!.toUtc(), DateTime.utc(2026, 6, 19, 13, 45, 30));
    });

    test('missing transactionTime maps to null', () {
      final dto = pb.TransactionDTO()
        ..id = 't4'
        ..transactionDate = '2026-06-19';
      final t = mapper.toDomain(dto);
      expect(t.transactionTime, isNull);
    });

    test('empty transactionTime string maps to null', () {
      final dto = pb.TransactionDTO()
        ..id = 't5'
        ..transactionDate = '2026-06-19'
        ..transactionTime = '';
      final t = mapper.toDomain(dto);
      expect(t.transactionTime, isNull);
    });

    test('preserves timezone offset in transactionTime', () {
      final dto = pb.TransactionDTO()
        ..id = 't6'
        ..transactionDate = '2026-06-19'
        ..transactionTime = '2026-06-19T21:30:00+08:00';
      final t = mapper.toDomain(dto);
      expect(t.transactionTime,
          DateTime.parse('2026-06-19T21:30:00+08:00').toLocal());
      // Equivalent UTC instant.
      expect(t.transactionTime!.toUtc(),
          DateTime.utc(2026, 6, 19, 13, 30, 0));
    });

    // Regression (copy-transaction 8h skew): the wall clock the UI shows must
    // survive a full round trip — encode wall → UTC RFC3339 (form submit),
    // parse back (mapper) → same wall hour, regardless of the device zone.
    test('wall-clock round trip is zone-stable (copy 8h regression)', () {
      final wall = DateTime(2026, 6, 19, 21, 30);
      final wire = wall.toUtc().toIso8601String();
      final back = mapper
          .toDomain(pb.TransactionDTO()
            ..id = 't7'
            ..transactionDate = '2026-06-19'
            ..transactionTime = wire)
          .transactionTime!;
      expect(back.hour, wall.hour,
          reason: 'copy prefill / list HH:MM must show the wall hour');
      expect(back.minute, wall.minute);
    });
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

    // Task 9: scope is stamped from the request (the proto DTO doesn't carry
    // it). Default = null (backward-compat for pre-Task-9 callers).
    test('scope is stamped when provided (Task 9)', () {
      final got = mapper.summaryToDomain(pb.MonthlySummary(),
          year: 2026, month: 6, scope: SummaryScope.year);
      expect(got.scope, SummaryScope.year);
    });

    test('scope defaults to null when omitted (backward-compat)', () {
      final got = mapper.summaryToDomain(pb.MonthlySummary(),
          year: 2026, month: 6);
      expect(got.scope, isNull);
    });
  });
}
