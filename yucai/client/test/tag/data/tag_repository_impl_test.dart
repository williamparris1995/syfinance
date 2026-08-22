import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Tag;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRemote extends Mock implements TagRemoteDataSource {}

TagRepositoryImpl _guestOffRepo(_MockRemote remote) {
  final tracker = SessionModeTracker()..isGuest = false;
  return TagRepositoryImpl(remote, TagLocalDataSource(AppDatabase(NativeDatabase.memory())), tracker);
}

const _sample = Tag(id: 't1', name: '日常', color: '#b08d57', version: 1);

void main() {
  late _MockRemote remote;

  setUp(() {
    remote = _MockRemote();
  });

  group('TagRepositoryImpl.list', () {
    test('success returns Right(List)', () async {
      when(() => remote.list()).thenAnswer((_) async => const [_sample]);
      final repo = _guestOffRepo(remote);
      final result = await repo.list();
      expect(result.isRight(), true);
      result.fold((_) => fail('should be right'), (list) => expect(list, [_sample]));
    });

    test('grpc unavailable maps to NetworkFailure', () async {
      when(() => remote.list()).thenThrow(const GrpcError.unavailable('down'));
      final repo = _guestOffRepo(remote);
      final result = await repo.list();
      result.fold((f) => expect(f, isA<NetworkFailure>()), (_) => fail('should be left'));
    });
  });

  group('TagRepositoryImpl.create', () {
    test('success returns Right(Tag)', () async {
      when(() => remote.create(name: '日常', color: '#b08d57'))
          .thenAnswer((_) async => _sample);
      final repo = _guestOffRepo(remote);
      final result = await repo.create(name: '日常', color: '#b08d57');
      expect(result.isRight(), true);
    });
  });

  group('TagRepositoryImpl.getTransactionTags', () {
    test('success returns Right(List)', () async {
      when(() => remote.getTransactionTags('txn1'))
          .thenAnswer((_) async => const [_sample]);
      final repo = _guestOffRepo(remote);
      final result = await repo.getTransactionTags('txn1');
      expect(result.isRight(), true);
    });
  });
}
