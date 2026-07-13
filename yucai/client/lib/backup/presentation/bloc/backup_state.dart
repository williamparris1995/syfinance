import 'package:equatable/equatable.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';

abstract class BackupState extends Equatable {
  const BackupState();
  @override
  List<Object?> get props => [];
}

class BackupInitial extends BackupState {}

/// 列表刷新中 —— 保留 last list 供 UI 继续显示（避免操作成功触发 LoadBackupsRequested
/// 时，全屏 spinner 闪烁、列表消失）。首载 last 为空 → UI 走 isFirstLoad spinner。
class BackupLoading extends BackupState {
  const BackupLoading([this.last = const []]);
  final List<Backup> last;
  @override
  List<Object?> get props => [last];
}

class BackupsLoaded extends BackupState {
  const BackupsLoaded(this.backups);
  final List<Backup> backups;
  @override
  List<Object?> get props => [backups];
}

/// 创建/删除/恢复进行中 —— 保留 last list 供 UI 继续显示（列表不闪）。
class BackupSubmitting extends BackupState {
  const BackupSubmitting(this.last);
  final List<Backup> last;
  @override
  List<Object?> get props => [last];
}

/// 一次性成功反馈（create/delete/restore）—— UI BlocListener 捕获 message
/// 显示 SnackBar；随后 bloc add(LoadBackupsRequested) 刷新回到 BackupsLoaded。
class BackupActionSuccess extends BackupState {
  const BackupActionSuccess(this.message, this.last);
  final String message;
  final List<Backup> last;
  @override
  List<Object?> get props => [message, last];
}

class BackupError extends BackupState {
  const BackupError(this.message, {this.last = const []});
  final String message;
  final List<Backup> last;
  @override
  List<Object?> get props => [message, last];
}
