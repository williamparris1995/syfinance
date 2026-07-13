import 'package:equatable/equatable.dart';

abstract class BackupEvent extends Equatable {
  const BackupEvent();
  @override
  List<Object?> get props => [];
}

class LoadBackupsRequested extends BackupEvent {}

class CreateBackupRequested extends BackupEvent {
  const CreateBackupRequested(this.encrypted);
  final bool encrypted;
  @override
  List<Object?> get props => [encrypted];
}

class DeleteBackupRequested extends BackupEvent {
  const DeleteBackupRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class RestoreBackupRequested extends BackupEvent {
  const RestoreBackupRequested({required this.id, required this.password});
  final String id;
  final String password;
  @override
  List<Object?> get props => [id, password];
}
