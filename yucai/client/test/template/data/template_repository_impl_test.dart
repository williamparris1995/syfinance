import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/template/data/template_remote_ds.dart';
import 'package:yucai_client/template/data/template_repository_impl.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';

class _MockRemote extends Mock implements TemplateRemoteDataSource {}

final _now = DateTime.utc(2026, 7, 14);

Template _sampleTemplate({
  String id = 'tpl1',
  bool paused = false,
  int version = 1,
}) =>
    Template(
      id: id,
      name: '房租',
      description: '月租',
      amountCents: 300000,
      direction: TemplateDirection.expense,
      sourceAccountId: null,
      destinationAccountId: null,
      cycle: TemplateCycle.monthly,
      cycleDays: 0,
      billingDay: 1,
      nextDate: '2026-08-01',
      startDate: '2026-01-01',
      endDate: null,
      autoRecord: true,
      paused: paused,
      lastTransactionId: null,
      category: '住房',
      version: version,
      createdAt: _now,
      updatedAt: _now,
    );

const _sampleResult = RecordResult(transactionId: 'txn-new');

void main() {
  late _MockRemote remote;

  setUp(() {
    remote = _MockRemote();
    registerFallbackValue(TemplateDirection.unspecified);
    registerFallbackValue(TemplateCycle.unspecified);
  });

  group('TemplateRepositoryImpl.list', () {
    test('success returns Right(List)', () async {
      when(() => remote.list(paused: any(named: 'paused')))
          .thenAnswer((_) async => [_sampleTemplate()]);
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.list();
      expect(result.isRight(), true);
      result.fold((_) => fail('should be right'), (list) => expect(list.length, 1));
    });

    test('grpc unavailable maps to NetworkFailure', () async {
      when(() => remote.list(paused: any(named: 'paused')))
          .thenThrow(GrpcError.unavailable('down'));
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.list();
      result.fold((f) => expect(f, isA<NetworkFailure>()), (_) => fail('should be left'));
    });
  });

  group('TemplateRepositoryImpl.create', () {
    test('success returns Right(Template)', () async {
      when(() => remote.create(
            name: any(named: 'name'),
            description: any(named: 'description'),
            amountCents: any(named: 'amountCents'),
            direction: any(named: 'direction'),
            sourceAccountId: any(named: 'sourceAccountId'),
            destinationAccountId: any(named: 'destinationAccountId'),
            cycle: any(named: 'cycle'),
            cycleDays: any(named: 'cycleDays'),
            billingDay: any(named: 'billingDay'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            autoRecord: any(named: 'autoRecord'),
            category: any(named: 'category'),
          )).thenAnswer((_) async => _sampleTemplate());
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.create(name: '房租', amountCents: 300000);
      expect(result.isRight(), true);
    });

    test('grpc invalidArgument maps to ValidationFailure', () async {
      when(() => remote.create(
            name: any(named: 'name'),
            description: any(named: 'description'),
            amountCents: any(named: 'amountCents'),
            direction: any(named: 'direction'),
            sourceAccountId: any(named: 'sourceAccountId'),
            destinationAccountId: any(named: 'destinationAccountId'),
            cycle: any(named: 'cycle'),
            cycleDays: any(named: 'cycleDays'),
            billingDay: any(named: 'billingDay'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            autoRecord: any(named: 'autoRecord'),
            category: any(named: 'category'),
          )).thenThrow(GrpcError.invalidArgument('bad'));
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.create(name: '', amountCents: 0);
      result.fold((f) => expect(f, isA<ValidationFailure>()), (_) => fail('should be left'));
    });
  });

  group('TemplateRepositoryImpl.get', () {
    test('success returns Right(Template)', () async {
      when(() => remote.get('tpl1')).thenAnswer((_) async => _sampleTemplate());
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.get('tpl1');
      expect(result.isRight(), true);
    });
  });

  group('TemplateRepositoryImpl.pause', () {
    test('success returns paused Template', () async {
      when(() => remote.pause('tpl1'))
          .thenAnswer((_) async => _sampleTemplate(paused: true));
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.pause('tpl1');
      result.fold((_) => fail('should be right'),
          (t) => expect(t.paused, true));
    });
  });

  group('TemplateRepositoryImpl.resume', () {
    test('success returns resumed Template', () async {
      when(() => remote.resume('tpl1'))
          .thenAnswer((_) async => _sampleTemplate(paused: false));
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.resume('tpl1');
      expect(result.isRight(), true);
    });
  });

  group('TemplateRepositoryImpl.delete', () {
    test('success returns Right(void)', () async {
      when(() => remote.delete('tpl1')).thenAnswer((_) async {});
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.delete('tpl1');
      expect(result.isRight(), true);
    });
  });

  group('TemplateRepositoryImpl.record', () {
    test('success returns Right(RecordResult)', () async {
      when(() => remote.record('tpl1')).thenAnswer((_) async => _sampleResult);
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.record('tpl1');
      result.fold((_) => fail('should be right'),
          (r) => expect(r.transactionId, 'txn-new'));
    });

    test('grpc error maps to ServerFailure by default', () async {
      when(() => remote.record('tpl1'))
          .thenThrow(GrpcError.notFound('missing'));
      final repo = TemplateRepositoryImpl(remote);
      final result = await repo.record('tpl1');
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('should be left'));
    });
  });
}
