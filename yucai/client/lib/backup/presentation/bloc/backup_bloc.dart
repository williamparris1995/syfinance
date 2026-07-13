import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/domain/repositories/backup_repository.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_state.dart';

@injectable
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  BackupBloc(this._repo) : super(BackupInitial()) {
    on<LoadBackupsRequested>(_onLoad);
    on<CreateBackupRequested>(_onCreate);
    on<DeleteBackupRequested>(_onDelete);
    on<RestoreBackupRequested>(_onRestore);
  }

  final BackupRepository _repo;

  List<Backup> _last = const [];

  Future<void> _onLoad(LoadBackupsRequested event, Emitter<BackupState> emit) async {
    emit(BackupLoading(_last));
    final result = await _repo.list();
    result.fold(
      (failure) => emit(BackupError(failure.displayMessage, last: _last)),
      (backups) {
        _last = backups;
        emit(BackupsLoaded(backups));
      },
    );
  }

  Future<void> _onCreate(
    CreateBackupRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(BackupSubmitting(_last));
    final result = await _repo.create(encrypted: event.encrypted);
    result.fold(
      (failure) => emit(BackupError(failure.displayMessage, last: _last)),
      (_) {
        emit(BackupActionSuccess('备份已创建', _last));
        add(LoadBackupsRequested());
      },
    );
  }

  Future<void> _onDelete(
    DeleteBackupRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(BackupSubmitting(_last));
    final result = await _repo.delete(event.id);
    result.fold(
      (failure) => emit(BackupError(failure.displayMessage, last: _last)),
      (_) {
        emit(BackupActionSuccess('备份已删除', _last));
        add(LoadBackupsRequested());
      },
    );
  }

  Future<void> _onRestore(
    RestoreBackupRequested event,
    Emitter<BackupState> emit,
  ) async {
    emit(BackupSubmitting(_last));
    final result = await _repo.restore(id: event.id, password: event.password);
    result.fold(
      (failure) => emit(BackupError(failure.displayMessage, last: _last)),
      (_) {
        emit(BackupActionSuccess('恢复成功,请重启应用', _last));
        add(LoadBackupsRequested());
      },
    );
  }
}
