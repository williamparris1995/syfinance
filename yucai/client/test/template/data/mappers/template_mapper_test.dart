import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as wl;

import 'package:yucai_client/proto/template/v1/template.pb.dart' as pb;
import 'package:yucai_client/template/data/mappers/template_mapper.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';

void main() {
  group('TemplateMapper.toDomain', () {
    test('maps all 20 fields', () {
      final created = wl.Timestamp(seconds: Int64(1718000000));
      final updated = wl.Timestamp(seconds: Int64(1718100000));
      final dto = pb.TemplateDTO(
        id: 'tpl1',
        name: '房租',
        description: '月租',
        amountCents: Int64(300000),
        direction: pb.TemplateDirection.DIRECTION_EXPENSE,
        sourceAccountId: 'acc-src',
        destinationAccountId: 'acc-dst',
        cycle: pb.TemplateCycle.CYCLE_MONTHLY,
        cycleDays: 0,
        billingDay: 1,
        nextDate: '2026-08-01',
        startDate: '2026-01-01',
        endDate: '',
        autoRecord: true,
        paused: false,
        lastTransactionId: 'txn-9',
        category: '住房',
        version: Int64(2),
        createdAt: created,
        updatedAt: updated,
      );

      final t = TemplateMapper.toDomain(dto);

      expect(t.id, 'tpl1');
      expect(t.name, '房租');
      expect(t.description, '月租');
      expect(t.amountCents, 300000);
      expect(t.direction, TemplateDirection.expense);
      expect(t.sourceAccountId, 'acc-src');
      expect(t.destinationAccountId, 'acc-dst');
      expect(t.cycle, TemplateCycle.monthly);
      expect(t.cycleDays, 0);
      expect(t.billingDay, 1);
      expect(t.nextDate, '2026-08-01');
      expect(t.startDate, '2026-01-01');
      expect(t.endDate, isNull); // '' → null
      expect(t.autoRecord, true);
      expect(t.paused, false);
      expect(t.lastTransactionId, 'txn-9');
      expect(t.category, '住房');
      expect(t.version, 2);
      expect(t.createdAt, created.toDateTime());
      expect(t.updatedAt, updated.toDateTime());
    });

    test('empty optional strings become null', () {
      final ts = wl.Timestamp(seconds: Int64(100));
      final dto = pb.TemplateDTO(
        id: 'tpl2',
        name: 'n',
        description: '',
        amountCents: Int64(0),
        direction: pb.TemplateDirection.DIRECTION_UNSPECIFIED,
        cycle: pb.TemplateCycle.CYCLE_UNSPECIFIED,
        version: Int64(0),
        createdAt: ts,
        updatedAt: ts,
      );
      final t = TemplateMapper.toDomain(dto);
      expect(t.sourceAccountId, isNull);
      expect(t.destinationAccountId, isNull);
      expect(t.nextDate, isNull);
      expect(t.startDate, isNull);
      expect(t.endDate, isNull);
      expect(t.lastTransactionId, isNull);
      expect(t.category, isNull);
      expect(t.direction, TemplateDirection.unspecified);
      expect(t.cycle, TemplateCycle.unspecified);
    });

    test('maps all direction enum values', () {
      final ts = wl.Timestamp();
      pb.TemplateDirection make(pb.TemplateDirection d) =>
          pb.TemplateDTO(id: 'x', direction: d, createdAt: ts, updatedAt: ts).direction;
      expect(TemplateMapper.toDomain(pb.TemplateDTO(id: 'x', direction: make(pb.TemplateDirection.DIRECTION_INCOME), createdAt: ts, updatedAt: ts)).direction,
          TemplateDirection.income);
      expect(TemplateMapper.toDomain(pb.TemplateDTO(id: 'x', direction: make(pb.TemplateDirection.DIRECTION_TRANSFER), createdAt: ts, updatedAt: ts)).direction,
          TemplateDirection.transfer);
    });

    test('maps all cycle enum values', () {
      final ts = wl.Timestamp();
      final base = pb.TemplateDTO(
        id: 'x',
        cycle: pb.TemplateCycle.CYCLE_WEEKLY,
        createdAt: ts,
        updatedAt: ts,
      );
      expect(TemplateMapper.toDomain(base).cycle, TemplateCycle.weekly);
      expect(
          TemplateMapper.toDomain(pb.TemplateDTO(id: 'x', cycle: pb.TemplateCycle.CYCLE_YEARLY, createdAt: ts, updatedAt: ts)).cycle,
          TemplateCycle.yearly);
      expect(
          TemplateMapper.toDomain(pb.TemplateDTO(id: 'x', cycle: pb.TemplateCycle.CYCLE_CUSTOM, createdAt: ts, updatedAt: ts)).cycle,
          TemplateCycle.custom);
    });
  });

  group('TemplateMapper.toRecordResult', () {
    test('maps transactionId and nextDate when present', () {
      final ts = wl.Timestamp(seconds: Int64(1718000000));
      final res = pb.RecordTransactionResponse(
        transactionId: 'txn-new',
        nextDate: ts,
      );
      final r = TemplateMapper.toRecordResult(res);
      expect(r.transactionId, 'txn-new');
      expect(r.nextDate, ts.toDateTime());
    });

    test('nextDate null when absent', () {
      final res = pb.RecordTransactionResponse(transactionId: 'txn-new');
      final r = TemplateMapper.toRecordResult(res);
      expect(r.transactionId, 'txn-new');
      expect(r.nextDate, isNull);
    });
  });

  group('TemplateMapper enum round-trip', () {
    test('direction toPb/toDomain round-trip', () {
      for (final d in TemplateDirection.values) {
        expect(TemplateMapper.toDomainDirection(TemplateMapper.toPbDirection(d)), d);
      }
    });

    test('cycle toPb/toDomain round-trip', () {
      for (final c in TemplateCycle.values) {
        expect(TemplateMapper.toDomainCycle(TemplateMapper.toPbCycle(c)), c);
      }
    });
  });
}
