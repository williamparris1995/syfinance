import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/template/presentation/bloc/template_bloc.dart';
import 'package:yucai_client/template/presentation/bloc/template_event.dart';
import 'package:yucai_client/template/presentation/bloc/template_state.dart';

class _MockRepo extends Mock implements TemplateRepository {}

Template _sampleTemplate() => Template(
      id: 'tpl1',
      name: '房租',
      description: '月租',
      amountCents: 300000,
      direction: TemplateDirection.expense,
      sourceAccountId: null,
      destinationAccountId: 'acc1',
      cycle: TemplateCycle.monthly,
      cycleDays: 0,
      billingDay: 1,
      nextDate: '2026-08-01',
      startDate: null,
      endDate: null,
      autoRecord: false,
      paused: false,
      lastTransactionId: null,
      category: '住房',
      version: 1,
      createdAt: DateTime(2026, 7, 14),
      updatedAt: DateTime(2026, 7, 14),
    );

const _createEvent = CreateTemplateRequested(
  name: '房租',
  description: '月租',
  amountCents: 300000,
  direction: TemplateDirection.expense,
  destinationAccountId: 'acc1',
  cycle: TemplateCycle.monthly,
  cycleDays: 0,
  billingDay: 1,
  autoRecord: false,
  category: '住房',
);

void main() {
  blocTest<TemplateBloc, TemplateState>(
    'load success emits Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(LoadTemplatesRequested()),
    expect: () => [
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'load failure emits Loading → Error',
    build: () {
      final repo = _MockRepo();
      when(() => repo.list())
          .thenAnswer((_) async => const Left(ServerFailure('boom')));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(LoadTemplatesRequested()),
    expect: () => [
      isA<TemplateLoading>(),
      isA<TemplateError>().having((s) => s.message, 'message', 'boom'),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'create success emits Submitting → ActionSuccess → Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.create(
            name: '房租',
            description: '月租',
            amountCents: 300000,
            direction: TemplateDirection.expense,
            sourceAccountId: null,
            destinationAccountId: 'acc1',
            cycle: TemplateCycle.monthly,
            cycleDays: 0,
            billingDay: 1,
            startDate: null,
            endDate: null,
            autoRecord: false,
            category: '住房',
          )).thenAnswer((_) async => Right(_sampleTemplate()));
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(_createEvent),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateActionSuccess>()
          .having((s) => s.message, 'message', '模板已创建'),
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'create failure emits Submitting → Error',
    build: () {
      final repo = _MockRepo();
      when(() => repo.create(
            name: '房租',
            description: '月租',
            amountCents: 300000,
            direction: TemplateDirection.expense,
            sourceAccountId: null,
            destinationAccountId: 'acc1',
            cycle: TemplateCycle.monthly,
            cycleDays: 0,
            billingDay: 1,
            startDate: null,
            endDate: null,
            autoRecord: false,
            category: '住房',
          )).thenAnswer((_) async => const Left(ServerFailure('bad')));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(_createEvent),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateError>().having((s) => s.message, 'message', 'bad'),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'update success emits Submitting → ActionSuccess(已更新) → refresh',
    build: () {
      final repo = _MockRepo();
      when(() => repo.update(
            id: 'tpl1',
            version: 1,
            name: '房租2',
            amountCents: 350000,
          )).thenAnswer((_) async => Right(_sampleTemplate()));
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(const UpdateTemplateRequested(
      id: 'tpl1',
      version: 1,
      name: '房租2',
      amountCents: 350000,
    )),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateActionSuccess>()
          .having((s) => s.message, 'message', '模板已更新'),
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'delete success emits Submitting → ActionSuccess(已删除) → refresh',
    build: () {
      final repo = _MockRepo();
      when(() => repo.delete('tpl1'))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(const DeleteTemplateRequested('tpl1')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateActionSuccess>()
          .having((s) => s.message, 'message', '模板已删除'),
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'pause success emits Submitting → ActionSuccess(已暂停) → refresh',
    build: () {
      final repo = _MockRepo();
      when(() => repo.pause('tpl1'))
          .thenAnswer((_) async => Right(_sampleTemplate()));
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(const PauseTemplateRequested('tpl1')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateActionSuccess>()
          .having((s) => s.message, 'message', '模板已暂停'),
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'resume success emits Submitting → ActionSuccess(已恢复) → refresh',
    build: () {
      final repo = _MockRepo();
      when(() => repo.resume('tpl1'))
          .thenAnswer((_) async => Right(_sampleTemplate()));
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(const ResumeTemplateRequested('tpl1')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateActionSuccess>()
          .having((s) => s.message, 'message', '模板已恢复'),
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'record success with nextDate emits ActionSuccess with formatted date',
    build: () {
      final repo = _MockRepo();
      when(() => repo.record('tpl1')).thenAnswer((_) async => const Right(
            RecordResult(
              transactionId: 'txn1',
              nextDate: null,
            ),
          ));
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(const RecordTemplateRequested('tpl1')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TemplateSubmitting>(),
      // nextDate null → message '已记录'
      isA<TemplateActionSuccess>()
          .having((s) => s.message, 'message', '已记录'),
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'record success with nextDate message formats date',
    build: () {
      final repo = _MockRepo();
      // DateTime 非 const → 用非 const RecordResult
      when(() => repo.record('tpl1')).thenAnswer((_) async => Right(
            RecordResult(
              transactionId: 'txn1',
              nextDate: DateTime(2026, 8, 1),
            ),
          ));
      when(() => repo.list())
          .thenAnswer((_) async => Right([_sampleTemplate()]));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(const RecordTemplateRequested('tpl1')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateActionSuccess>()
          .having((s) => s.message, 'message', '已记录(下次 2026-08-01)'),
      isA<TemplateLoading>(),
      isA<TemplatesLoaded>(),
    ],
  );

  blocTest<TemplateBloc, TemplateState>(
    'record failure emits Submitting → Error',
    build: () {
      final repo = _MockRepo();
      when(() => repo.record('tpl1'))
          .thenAnswer((_) async => const Left(ServerFailure('denied')));
      return TemplateBloc(repo);
    },
    act: (b) => b.add(const RecordTemplateRequested('tpl1')),
    expect: () => [
      isA<TemplateSubmitting>(),
      isA<TemplateError>().having((s) => s.message, 'message', 'denied'),
    ],
  );
}
