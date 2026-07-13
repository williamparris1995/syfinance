import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/domain/repositories/backup_repository.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_bloc.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_state.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRepo extends Mock implements BackupRepository {}

const _sample = Backup(
  id: 'b1',
  filename: 'a.zip',
  sizeBytes: 1024,
  checksum: 'ck',
  encrypted: false,
  auto: false,
  createdAt: null,
);

void main() {
  blocTest<BackupBloc, BackupState>(
    'load success emits Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
      return BackupBloc(repo);
    },
    act: (b) => b.add(LoadBackupsRequested()),
    expect: () => [isA<BackupLoading>(), const BackupsLoaded([_sample])],
  );

  blocTest<BackupBloc, BackupState>(
    'load failure emits Loading → Error',
    build: () {
      final repo = _MockRepo();
      when(() => repo.list())
          .thenAnswer((_) async => const Left(ServerFailure('boom')));
      return BackupBloc(repo);
    },
    act: (b) => b.add(LoadBackupsRequested()),
    expect: () => [
      isA<BackupLoading>(),
      isA<BackupError>().having((s) => s.message, 'message', 'boom'),
    ],
  );

  blocTest<BackupBloc, BackupState>(
    'create success emits Submitting → ActionSuccess → Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.create(encrypted: true))
          .thenAnswer((_) async => const Right(_sample));
      when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
      return BackupBloc(repo);
    },
    act: (b) => b.add(const CreateBackupRequested(true)),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<BackupSubmitting>(),
      isA<BackupActionSuccess>(),
      isA<BackupLoading>(),
      const BackupsLoaded([_sample]),
    ],
  );

  blocTest<BackupBloc, BackupState>(
    'delete success emits Submitting → ActionSuccess → Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.delete('b1')).thenAnswer((_) async => const Right(null));
      when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
      return BackupBloc(repo);
    },
    act: (b) => b.add(const DeleteBackupRequested('b1')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<BackupSubmitting>(),
      isA<BackupActionSuccess>(),
      isA<BackupLoading>(),
      const BackupsLoaded([_sample]),
    ],
  );

  blocTest<BackupBloc, BackupState>(
    'restore success emits Submitting → ActionSuccess(请重启) → Loading → Loaded',
    build: () {
      final repo = _MockRepo();
      when(() => repo.restore(id: 'b1', password: 'pw'))
          .thenAnswer((_) async => const Right(null));
      when(() => repo.list()).thenAnswer((_) async => const Right([_sample]));
      return BackupBloc(repo);
    },
    act: (b) => b.add(const RestoreBackupRequested(id: 'b1', password: 'pw')),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<BackupSubmitting>(),
      isA<BackupActionSuccess>()
          .having((s) => s.message, 'message', '恢复成功,请重启应用'),
      isA<BackupLoading>(),
      const BackupsLoaded([_sample]),
    ],
  );

  blocTest<BackupBloc, BackupState>(
    'create failure emits Submitting → Error',
    build: () {
      final repo = _MockRepo();
      when(() => repo.create(encrypted: true))
          .thenAnswer((_) async => const Left(ServerFailure('创建失败')));
      return BackupBloc(repo);
    },
    act: (b) => b.add(const CreateBackupRequested(true)),
    expect: () => [
      isA<BackupSubmitting>(),
      isA<BackupError>().having((s) => s.message, 'message', '创建失败'),
    ],
  );
}
