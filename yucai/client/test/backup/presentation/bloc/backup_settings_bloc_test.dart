import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/backup/domain/repositories/backup_repository.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_bloc.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_state.dart';
import 'package:yucai_client/core/error/failures.dart';

class _MockRepo extends Mock implements BackupRepository {}

class _SettingsFake extends Fake implements BackupSettings {}

const _loaded = BackupSettings(autoBackup: false, intervalHours: 24);

void main() {
  setUpAll(() {
    registerFallbackValue(_SettingsFake());
  });

  group('load', () {
    blocTest<BackupSettingsBloc, BackupSettingsState>(
      'success emits Loading → Loaded',
      build: () {
        final repo = _MockRepo();
        when(() => repo.getCloudSettings())
            .thenAnswer((_) async => const Right(_loaded));
        return BackupSettingsBloc(repo);
      },
      act: (b) => b.add(LoadSettingsRequested()),
      expect: () => [
        isA<BackupSettingsLoading>(),
        const BackupSettingsLoaded(_loaded),
      ],
    );

    blocTest<BackupSettingsBloc, BackupSettingsState>(
      'failure emits Loading → Error',
      build: () {
        final repo = _MockRepo();
        when(() => repo.getCloudSettings())
            .thenAnswer((_) async => const Left(ServerFailure('boom')));
        return BackupSettingsBloc(repo);
      },
      act: (b) => b.add(LoadSettingsRequested()),
      expect: () => [
        isA<BackupSettingsLoading>(),
        isA<BackupSettingsError>().having((s) => s.message, 'message', 'boom'),
      ],
    );
  });

  group('save', () {
    late _MockRepo repo;

    setUp(() {
      repo = _MockRepo();
      when(() => repo.saveCloudSettings(any()))
          .thenAnswer((_) async => const Right(null));
    });

    blocTest<BackupSettingsBloc, BackupSettingsState>(
      'success emits Saving → Saved，repo 收到正确参数',
      build: () => BackupSettingsBloc(repo),
      act: (b) => b.add(
        const SaveSettingsRequested(autoBackup: true, intervalHours: 48),
      ),
      expect: () => [
        isA<BackupSettingsSaving>()
            .having((s) => s.settings.autoBackup, 'auto', true)
            .having((s) => s.settings.intervalHours, 'interval', 48),
        isA<BackupSettingsSaved>()
            .having((s) => s.settings.autoBackup, 'auto', true)
            .having((s) => s.settings.intervalHours, 'interval', 48)
            .having((s) => s.message, 'message', '自动备份设置已保存'),
      ],
      verify: (_) async {
        final captured =
            verify(() => repo.saveCloudSettings(captureAny())).captured;
        final s = captured.single as BackupSettings;
        expect(s.autoBackup, true);
        expect(s.intervalHours, 48);
      },
    );

    blocTest<BackupSettingsBloc, BackupSettingsState>(
      'failure emits Saving → Error（保留上次 settings）',
      build: () {
        when(() => repo.saveCloudSettings(any()))
            .thenAnswer((_) async => const Left(ServerFailure('保存失败')));
        // 预填上次 settings → 失败时 Error.settings 能携带 previous。
        when(() => repo.getCloudSettings())
            .thenAnswer((_) async => const Right(_loaded));
        return BackupSettingsBloc(repo);
      },
      act: (b) => b
        ..add(LoadSettingsRequested())
        ..add(const SaveSettingsRequested(autoBackup: true, intervalHours: 12)),
      // 顺序：Loading → Loaded → Saving → Error
      expect: () => [
        isA<BackupSettingsLoading>(),
        const BackupSettingsLoaded(_loaded),
        isA<BackupSettingsSaving>(),
        isA<BackupSettingsError>()
            .having((s) => s.message, 'message', '保存失败')
            .having((s) => s.settings?.autoBackup, 'prev.auto', false)
            .having((s) => s.settings?.intervalHours, 'prev.interval', 24),
      ],
    );
  });

  test('BackupSettingsStateX.settings 提取各 state 携带的 settings', () {
    expect(BackupSettingsInitial().settings, isNull);
    expect(BackupSettingsLoading().settings, isNull);
    expect(BackupSettingsLoaded(_loaded).settings, _loaded);
    expect(BackupSettingsSaving(_loaded).settings, _loaded);
    expect(BackupSettingsSaved(_loaded).settings, _loaded);
    expect(BackupSettingsError('x', settings: _loaded).settings, _loaded);
    expect(BackupSettingsError('x').settings, isNull);
  });
}
