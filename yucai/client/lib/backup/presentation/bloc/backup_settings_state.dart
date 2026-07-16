import 'package:equatable/equatable.dart';

import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';

abstract class BackupSettingsState extends Equatable {
  const BackupSettingsState();
  @override
  List<Object?> get props => [];
}

class BackupSettingsInitial extends BackupSettingsState {}

/// 加载中（首载 spinner；UI 在 Loading + settings=null 时显示 progress）。
class BackupSettingsLoading extends BackupSettingsState {}

/// 配置已加载 —— UI 预填 switch + picker。
class BackupSettingsLoaded extends BackupSettingsState {
  const BackupSettingsLoaded(this.settings);
  final BackupSettings settings;
  @override
  List<Object?> get props => [settings];
}

/// 保存中 —— UI 禁用控件、显示 spinner（保留当前 settings 供控件继续渲染）。
class BackupSettingsSaving extends BackupSettingsState {
  const BackupSettingsSaving(this.settings);
  final BackupSettings settings;
  @override
  List<Object?> get props => [settings];
}

/// 保存成功反馈（一次性）—— BlocListener 捕获 message 显示 SnackBar；
/// 同时携带最新 settings 供 UI 继续显示（与 BackupActionSuccess 模式一致）。
class BackupSettingsSaved extends BackupSettingsState {
  const BackupSettingsSaved(this.settings, {this.message = '自动备份设置已保存'});
  final BackupSettings settings;
  final String message;
  @override
  List<Object?> get props => [settings, message];
}

class BackupSettingsError extends BackupSettingsState {
  const BackupSettingsError(this.message, {this.settings});
  final String message;
  /// 保留上次已知 settings —— UI 在错误态仍可继续显示控件（避免空白）。
  final BackupSettings? settings;
  @override
  List<Object?> get props => [message, settings];
}
