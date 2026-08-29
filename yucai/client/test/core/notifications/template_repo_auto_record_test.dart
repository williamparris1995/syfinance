import 'package:dartz/dartz.dart' hide iif;
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';

/// 适配器单测(review R1:此前零覆盖,DI 崩溃即藏在此)。
class FakeRepo implements TemplateRepository {
  FakeRepo(this._list, this._record);
  final Future<Either<Failure, List<Template>>> Function() _list;
  final Future<Either<Failure, RecordResult>> Function(String id) _record;

  @override
  Future<Either<Failure, List<Template>>> list({bool? paused}) async => _list();
  @override
  Future<Either<Failure, RecordResult>> record(String id) async => _record(id);
  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Template t(
  String id, {
  bool autoRecord = true,
  bool paused = false,
  String? nextDate,
}) =>
    Template(
      id: id, name: 'n', description: '', amountCents: 1, direction: TemplateDirection.expense,
      sourceAccountId: 's', destinationAccountId: null, cycle: TemplateCycle.monthly, cycleDays: 0, billingDay: 0,
      nextDate: nextDate, startDate: '2026-01-01', endDate: null,
      autoRecord: autoRecord, paused: paused, lastTransactionId: null, category: 'c',
      version: 1, createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  test('过滤:autoRecord=false / paused 剔除;nextDate/endDate String 解析', () async {
    final a = TemplateRepoAutoRecord(FakeRepo(
      () async => Right([t('a'), t('b', autoRecord: false), t('c', paused: true, nextDate: '2026-09-01')]),
      (_) => throw UnimplementedError(),
    ));
    final out = await a.listAutoRecordDue();
    expect(out.map((e) => e.id), ['a']);
  });

  test('list Left → 抛(调度器按失败计数)', () async {
    final a = TemplateRepoAutoRecord(FakeRepo(() async => Left(ServerFailure('x')), (_) => throw UnimplementedError()));
    expect(a.listAutoRecordDue(), throwsStateError);
  });

  test('record Right → nextDate 透传;Left → 抛', () async {
    final ok = TemplateRepoAutoRecord(FakeRepo(
        () async => const Right(<Template>[]),
        (_) async => const Right(RecordResult(transactionId: 'tx1', nextDate: null))));
    expect(await ok.record('a'), isNull);
    final bad = TemplateRepoAutoRecord(FakeRepo(
        () async => const Right(<Template>[]),
        (_) async => Left(ServerFailure('offline'))));
    expect(bad.record('a'), throwsStateError);
  });
}
