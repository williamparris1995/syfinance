import 'package:equatable/equatable.dart';

abstract class BackupSettingsEvent extends Equatable {
  const BackupSettingsEvent();
  @override
  List<Object?> get props => [];
}

/// 进入页面：拉取 tenant 当前 AutoBackup 配置预填表单（P1 Task 5）。
class LoadSettingsRequested extends BackupSettingsEvent {}

/// 保存：把 UI 当前值（switch + picker）发到 SaveCloudSettings。
class SaveSettingsRequested extends BackupSettingsEvent {
  const SaveSettingsRequested({
    required this.autoBackup,
    required this.intervalHours,
  });
  final bool autoBackup;
  final int intervalHours;
  @override
  List<Object?> get props => [autoBackup, intervalHours];
}
