import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/backup/data/backup_remote_ds.dart';
import 'package:yucai_client/backup/data/backup_repository_impl.dart';
import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRemote extends Mock implements BackupRemoteDataSource {}

const _sample = Backup(
  id: 'b1',
  filename: 'a.zip',
  sizeBytes: 1024,
  checksum: 'ck',
  encrypted: false,
  auto: false,
  createdAt: null,
);

const _settings = BackupSettings(autoBackup: true, intervalHours: 24);

void main() {
  late _MockRemote remote;

  setUp(() {
    remote = _MockRemote();
  });

  group('BackupRepositoryImpl.list', () {
    test('success returns Right(List)', () async {
      when(() => remote.list()).thenAnswer((_) async => const [_sample]);
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.list();
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('should be right'),
        (list) => expect(list, [_sample]),
      );
    });

    test('grpc unavailable maps to NetworkFailure', () async {
      when(() => remote.list()).thenThrow(GrpcError.unavailable('down'));
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.list();
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('should be left'),
      );
    });

    test('generic error maps to UnexpectedFailure', () async {
      when(() => remote.list()).thenThrow(Exception('boom'));
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.list();
      result.fold(
        (f) => expect(f, isA<UnexpectedFailure>()),
        (_) => fail('should be left'),
      );
    });
  });

  group('BackupRepositoryImpl.create', () {
    test('success returns Right(Backup)', () async {
      when(() => remote.create(encrypted: true, password: 'pw'))
          .thenAnswer((_) async => _sample);
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.create(encrypted: true, password: 'pw');
      expect(result.isRight(), true);
    });
  });

  group('BackupRepositoryImpl.restore', () {
    test('success returns Right(void)', () async {
      when(() => remote.restore(id: 'b1', password: 'pw'))
          .thenAnswer((_) async {});
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.restore(id: 'b1', password: 'pw');
      expect(result.isRight(), true);
    });
  });

  group('BackupRepositoryImpl.delete', () {
    test('success returns Right(void)', () async {
      when(() => remote.delete('b1')).thenAnswer((_) async {});
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.delete('b1');
      expect(result.isRight(), true);
    });
  });

  group('BackupRepositoryImpl.getCloudSettings', () {
    test('success returns Right(BackupSettings)', () async {
      when(() => remote.getCloudSettings()).thenAnswer((_) async => _settings);
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.getCloudSettings();
      result.fold(
        (_) => fail('should be right'),
        (s) => expect(s, _settings),
      );
    });

    test('grpc unavailable maps to NetworkFailure', () async {
      when(() => remote.getCloudSettings())
          .thenThrow(GrpcError.unavailable('down'));
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.getCloudSettings();
      result.fold(
        (f) => expect(f, isA<NetworkFailure>()),
        (_) => fail('should be left'),
      );
    });
  });

  group('BackupRepositoryImpl.saveCloudSettings', () {
    test('success returns Right(void)', () async {
      when(() => remote.saveCloudSettings(_settings)).thenAnswer((_) async {});
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.saveCloudSettings(_settings);
      expect(result.isRight(), true);
      verify(() => remote.saveCloudSettings(_settings)).called(1);
    });

    test('grpc invalidArgument maps to ValidationFailure', () async {
      when(() => remote.saveCloudSettings(_settings))
          .thenThrow(GrpcError.invalidArgument('bad'));
      final repo = BackupRepositoryImpl(remote);
      final result = await repo.saveCloudSettings(_settings);
      result.fold(
        (f) => expect(f, isA<ValidationFailure>()),
        (_) => fail('should be left'),
      );
    });
  });
}
