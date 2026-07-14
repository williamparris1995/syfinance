import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_bloc.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_event.dart';
import 'package:yucai_client/tag/presentation/bloc/tag_state.dart';

class _MockRepo extends Mock implements TagRepository {}

const _sample = Tag(id: 't1', name: '日常', color: '#b08d57', version: 1);

void main() {
  blocTest<TagBloc, TagState>(
    'load success emits Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
      return TagBloc(repo);
    },
    act: (b) => b.add(LoadTagsRequested()),
    expect: () => [isA<TagLoading>(), const TagsLoaded([_sample])],
  );

  blocTest<TagBloc, TagState>(
    'load failure emits Loading → Error',
    build: () {
      final repo = _MockRepo();
      when(() => repo.list()).thenAnswer((_) async => const Left(ServerFailure('boom')));
      return TagBloc(repo);
    },
    act: (b) => b.add(LoadTagsRequested()),
    expect: () => [
      isA<TagLoading>(),
      isA<TagError>().having((s) => s.message, 'message', 'boom'),
    ],
  );

  blocTest<TagBloc, TagState>(
    'create success emits Submitting → ActionSuccess → Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.create(name: '日常', color: '#b08d57'))
          .thenAnswer((_) async => const Right(_sample));
      when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
      return TagBloc(repo);
    },
    act: (b) => b.add(const CreateTagRequested('日常', '#b08d57')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<TagSubmitting>(),
      isA<TagActionSuccess>(),
      isA<TagLoading>(),
      const TagsLoaded([_sample]),
    ],
  );

  blocTest<TagBloc, TagState>(
    'loadTransactionTags emits TransactionTagsLoaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.getTransactionTags('txn1'))
          .thenAnswer((_) async => const Right([_sample]));
      return TagBloc(repo);
    },
    act: (b) => b.add(const LoadTransactionTagsRequested('txn1')),
    expect: () => [const TransactionTagsLoaded('txn1', [_sample])],
  );
}
