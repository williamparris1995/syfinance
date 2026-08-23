import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/backup/data/backup_remote_ds.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// Binding wizard state machine (R6 feature G, design ADR-5):
/// idle → guarding → blocked | uploading → success | failed(retryable).
/// Guard + post-upload verification ride the DUAL-SOURCE repos — after login
/// the session tracker already routes them to the remote path.
@injectable
class BindingBloc extends Bloc<BindingEvent, BindingState> {
  BindingBloc(
    this._accounts,
    this._transactions,
    this._holdings,
    this._exporter,
    this._backupRemote,
    this._database,
    this._boundMarker,
  ) : super(const BindingState()) {
    on<BindingStarted>(_onStarted);
    on<BindingUploadConfirmed>(_onUploadConfirmed);
    on<BindingRetryRequested>(_onStarted);
  }

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  final HoldingRepository _holdings;
  final LocalSnapshotExporter _exporter;
  final BackupRemoteDataSource _backupRemote;
  final db.AppDatabase _database;
  final BoundMarker _boundMarker;

  Future<void> _onStarted(
      BindingEvent event, Emitter<BindingState> emit) async {
    emit(state.copyWith(status: BindingStatus.guarding));
    final accounts = await _accounts.list();
    final transactions =
        await _transactions.list(const ListTransactionsParams(pageSize: 1));
    final holdings = await _holdings.listHoldings();
    // Fail-closed: any guard facet erroring means we CANNOT prove the
    // account empty — block the upload rather than risk a silent overwrite
    // of a non-empty account (review G-J2).
    for (final result in [accounts, transactions, holdings]) {
      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        emit(state.copyWith(
            status: BindingStatus.failed,
            failureMessage: '无法确认账号状态（${failure.displayMessage}），已阻止上传'));
        return;
      }
    }
    final nonEmpty =
        accounts.fold((_) => false, (a) => a.isNotEmpty);
    final hasTxns =
        transactions.fold((_) => false, (t) => t.totalCount > 0);
    final hasHoldings =
        holdings.fold((_) => false, (h) => h.isNotEmpty);
    if (nonEmpty || hasTxns || hasHoldings) {
      emit(state.copyWith(
          status: BindingStatus.blocked,
          blockedReason: '该账号已有服务端数据（合并暂不支持），请换一个账号或放弃绑定'));
      return;
    }
    emit(state.copyWith(status: BindingStatus.readyToUpload));
  }

  Future<void> _onUploadConfirmed(
      BindingEvent event, Emitter<BindingState> emit) async {
    emit(state.copyWith(status: BindingStatus.uploading));
    try {
      final snapshot = await _exporter.exportAll();
      await _backupRemote.uploadBackup(snapshot);
      // Verification: remote facet counts vs local (design FR-3).
      final remoteAccounts = await _accounts.list();
      final localAccounts =
          await _database.accountDao.getAllAccounts();
      final accountCount = remoteAccounts.fold(
          (_) => -1, (a) => a.length);
      if (accountCount != localAccounts.length) {
        emit(state.copyWith(
            status: BindingStatus.failed,
            failureMessage: '上传后校验不一致（本地 ${localAccounts.length} vs 服务端 $accountCount），请重试或联系支持'));
        return;
      }
      // Persist the bound marker so future logins skip the wizard
      // (re-login idempotency, R6 H FR-3).
      await _boundMarker.markBound('bound');
      emit(state.copyWith(
        status: BindingStatus.success,
        uploadedEntities: localAccounts.length,
        verifiedRemoteCount: accountCount,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: BindingStatus.failed, failureMessage: e.toString()));
    }
  }
}

abstract class BindingEvent {}

class BindingStarted extends BindingEvent {}

class BindingUploadConfirmed extends BindingEvent {}

class BindingRetryRequested extends BindingEvent {}

enum BindingStatus {
  idle,
  guarding,
  blocked,
  readyToUpload,
  uploading,
  success,
  failed,
}

class BindingState {
  const BindingState({
    this.status = BindingStatus.idle,
    this.blockedReason,
    this.failureMessage,
    this.uploadedEntities = 0,
    this.verifiedRemoteCount = -1,
  });

  final BindingStatus status;
  final String? blockedReason;
  final String? failureMessage;
  final int uploadedEntities;
  final int verifiedRemoteCount;

  BindingState copyWith({
    BindingStatus? status,
    String? blockedReason,
    String? failureMessage,
    int? uploadedEntities,
    int? verifiedRemoteCount,
  }) =>
      BindingState(
        status: status ?? this.status,
        blockedReason: blockedReason ?? this.blockedReason,
        failureMessage: failureMessage ?? this.failureMessage,
        uploadedEntities: uploadedEntities ?? this.uploadedEntities,
        verifiedRemoteCount:
            verifiedRemoteCount ?? this.verifiedRemoteCount,
      );
}
