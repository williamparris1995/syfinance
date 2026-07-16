import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/backup/domain/repositories/backup_repository.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_settings_state.dart';

/// 自动备份配置页 bloc（P1 Task 5）。
///
/// - [LoadSettingsRequested] → repo.getCloudSettings → BackupSettingsLoaded
///   预填表单。
/// - [SaveSettingsRequested] → repo.saveCloudSettings → BackupSettingsSaved
///   （SnackBar 反馈）。
///
/// 对齐 BackupBloc / TagBloc 模式：`@injectable`（factory 注册，路由层
/// 每次进入新实例）；失败 emit BackupSettingsError(message, settings:)。
@injectable
class BackupSettingsBloc
    extends Bloc<BackupSettingsEvent, BackupSettingsState> {
  BackupSettingsBloc(this._repo) : super(BackupSettingsInitial()) {
    on<LoadSettingsRequested>(_onLoad);
    on<SaveSettingsRequested>(_onSave);
  }

  final BackupRepository _repo;

  Future<void> _onLoad(
    LoadSettingsRequested event,
    Emitter<BackupSettingsState> emit,
  ) async {
    emit(BackupSettingsLoading());
    final result = await _repo.getCloudSettings();
    result.fold(
      (failure) => emit(BackupSettingsError(failure.displayMessage)),
      (settings) => emit(BackupSettingsLoaded(settings)),
    );
  }

  Future<void> _onSave(
    SaveSettingsRequested event,
    Emitter<BackupSettingsState> emit,
  ) async {
    final current = state.settings ?? BackupSettings.disabled;
    final next = BackupSettings(
      autoBackup: event.autoBackup,
      intervalHours: event.intervalHours,
    );
    emit(BackupSettingsSaving(next));
    final result = await _repo.saveCloudSettings(next);
    result.fold(
      (failure) => emit(BackupSettingsError(failure.displayMessage, settings: current)),
      (_) => emit(BackupSettingsSaved(next)),
    );
  }
}

/// 从任意 state 提取最近一次已知的 settings（Loaded/Saving/Saved/Error 都可能携带；
/// Initial/Loading 为 null）。UI 用它决定是显示 progress 还是表单。
extension BackupSettingsStateX on BackupSettingsState {
  BackupSettings? get settings {
    switch (this) {
      case BackupSettingsLoaded(:final settings):
        return settings;
      case BackupSettingsSaving(:final settings):
        return settings;
      case BackupSettingsSaved(:final settings):
        return settings;
      case BackupSettingsError(:final settings):
        return settings;
      default:
        return null;
    }
  }
}
