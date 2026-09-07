import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/backup/data/backup_remote_ds.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/di/injection.dart';
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
    this._syncPort,
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

  /// F17-T1(FR-2/ADR-1):绑定成功后的设备注册通道(RegisterDevice 走
  /// GrpcOfflineSyncPort;deviceId=clientId 由 port 自取)。
  final OfflineSyncPort _syncPort;

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
      // First-binding's own mirror refresh (replaces the login-triggered
      // refresh that only fires for already-bound devices, review H-W4),
      // then persist the marker so future logins skip the wizard (FR-3).
      // Resolve lazily — BoundMirror depends on the same repos this bloc
      // holds, eager injection would cycle.
      getIt.isRegistered<BoundMirror>()
          ? await getIt<BoundMirror>().refreshAll()
          : null;
      // 'bound' 为纯绑定标记值(F17-T1 语义收敛:tenant 标记与设备身份
      // 分离 —— deviceId 独立取 clientId,见 GrpcOfflineSyncPort doc)。
      await _boundMarker.markBound('bound');
      // F17-T1(FR-2/ADR-1):markBound 后 fire-and-forget 注册设备行
      // (deviceId=clientId 由 port 自取;deviceName 取 Platform 简单值
      // —— 平台名,足够多设备列表区分,不引设备型号采集)。失败 log warn
      // 不阻断绑定:server 按非空 device_id 幂等,下次绑定或 F17-T2 拉取
      // 前重试一次即可,无须在此重试。
      unawaited(_registerDevice());
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

  /// F17-T1:设备注册的 fire-and-forget 容错壳 —— 异常吞掉并 log warn
  /// (英文结构化日志,无 CJK),绑定流程绝不因注册失败回滚/阻断。
  Future<void> _registerDevice() async {
    try {
      await _syncPort.registerDevice(Platform.operatingSystem);
    } catch (e) {
      debugPrint(
          '[binding] register device failed (idempotent, retried on next '
          'binding or pull): $e');
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
