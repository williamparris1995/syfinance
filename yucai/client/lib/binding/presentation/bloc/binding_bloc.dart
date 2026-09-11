import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/sync_batch_splitter.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;
import 'package:yucai_client/core/session_mode/bound_marker.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// F19-T1 绑定向导状态机(spec FR-1,design ADR-1/ADR-3):
/// idle → guarding → readyToMerge(非空摘要)| readyToUpload(空)
/// → uploading(批进度)→ success(上行/冲突摘要)| failed(可重试)。
///
/// **统一合并路径(ADR-1)**:空与非空账号同走合并链
/// (markAllPending → collect → 拆批 push → 回写 → refreshAll → markBound →
/// registerDevice),空时合并 = 纯上传(语义等价);uploadBackup/envelope
/// 导出路径退出向导(类保留在 lib 中作 F20 cloud 恢复通道评估,不再被
/// 调用)。守卫从「空校验」改为「数据摘要采集」(三面计数),非空不再
/// blocked 而是进入 readyToMerge 合并确认(FR-1)。
///
/// 守卫与收尾仍骑双源 repo(登录后 session tracker 已切远端路径);
/// 合并链在 bloc 内联(ADR-3,不动 SyncCoordinatorBloc —— 其回网触发/
/// in-flight 语义与向导流程不同)。
class BindingBloc extends Bloc<BindingEvent, BindingState> {
  BindingBloc(
    this._accounts,
    this._transactions,
    this._holdings,
    this._database,
    this._boundMarker,
    this._syncPort,
    this._collector,
  ) : super(const BindingState()) {
    on<BindingStarted>(_onStarted);
    on<BindingMergeConfirmed>(_onMergeConfirmed);
    on<BindingUploadConfirmed>(_onUploadConfirmed);
    on<BindingRetryRequested>(_onRetryRequested);
  }

  final AccountRepository _accounts;
  final TransactionRepository _transactions;
  final HoldingRepository _holdings;
  final db.AppDatabase _database;
  final BoundMarker _boundMarker;

  /// F17-T1(FR-2/ADR-1):合并链上行通道 + 绑定后设备注册
  /// (RegisterDevice 走同一 port;deviceId=clientId 由 port 自取)。
  final OfflineSyncPort _syncPort;

  /// F19-T1(ADR-3):合并链收集器(与协调器共用生产注册的同一实例)。
  final PendingCollector _collector;

  /// 合并批大小(spec Grill record 定案 200/批):grpc 默认 4MB 接收上限 +
  /// server 单事务的平衡点;常量可调(个人量级几千笔 → 十几批,分钟级)。
  static const int mergeBatchSize = 200;

  Future<void> _onStarted(
      BindingEvent event, Emitter<BindingState> emit) async {
    emit(const BindingState(status: BindingStatus.guarding));
    final accounts = await _accounts.list();
    final transactions =
        await _transactions.list(const ListTransactionsParams(pageSize: 1));
    final holdings = await _holdings.listHoldings();
    // Fail-closed: any guard facet erroring means we CANNOT prove the
    // account's data summary — stop the wizard rather than pushing blind
    // (merge is safe, but the confirm card needs truthful counts; retry
    // re-runs the guard, review G-J2 语义延续).
    for (final result in [accounts, transactions, holdings]) {
      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) {
        emit(BindingState(
            status: BindingStatus.failed,
            failureMessage: '无法确认账号状态（${failure.displayMessage}），请稍后重试'));
        return;
      }
    }
    // F19-T1:守卫采集摘要(FR-1)—— 计数而非布尔;非空 → readyToMerge
    // (合并语义),空 → readyToUpload(纯上传文案,内部同链)。
    final summary = BindingServerSummary(
      accountCount:
          accounts.fold((_) => 0, (a) => a.length),
      transactionCount:
          transactions.fold((_) => 0, (t) => t.totalCount),
      holdingCount:
          holdings.fold((_) => 0, (h) => h.length),
    );
    emit(BindingState(
      status: summary.isEmpty
          ? BindingStatus.readyToUpload
          : BindingStatus.readyToMerge,
      serverSummary: summary,
    ));
  }

  /// readyToMerge 确认(服务端非空)→ 合并链(FR-2/FR-3)。
  Future<void> _onMergeConfirmed(
      BindingEvent event, Emitter<BindingState> emit) async {
    if (state.status != BindingStatus.readyToMerge) return;
    await _runMergeChain(emit, markAll: true);
  }

  /// readyToUpload 确认(服务端为空)→ 同一合并链(空时合并 = 纯上传,
  /// ADR-1 统一路径;两态仅文案区分,代码路径合一)。
  Future<void> _onUploadConfirmed(
      BindingEvent event, Emitter<BindingState> emit) async {
    if (state.status != BindingStatus.readyToUpload) return;
    await _runMergeChain(emit, markAll: true);
  }

  /// 失败重试:链内失败(canResume)→ 断点续传(**跳过全量标记** —— 已推批
  /// 已回写 synced,collect 只收剩余 pending,自然断点续传,ADR-3);守卫面
  /// 失败 → 重走守卫。
  Future<void> _onRetryRequested(
      BindingEvent event, Emitter<BindingState> emit) async {
    if (state.status != BindingStatus.failed) return;
    if (state.canResume) {
      await _runMergeChain(emit, markAll: false);
    } else {
      await _onStarted(event, emit);
    }
  }

  /// 合并执行链(ADR-3,binding 层内联):
  /// 1. markAllPendingForSync×8(事务外逐表,幂等;仅首次确认执行,重试跳过);
  /// 2. 循环 collect → null(剩余全空)收敛;非空 → 拆 200/批 → 逐批 push →
  ///    每批成功即回写 synced(断点粒度=批)+ 进度发射;批失败 → failed
  ///    (已推批已 synced,重试只推剩余);
  /// 3. 收敛后 mirror.refreshAll(本地=两端并集)→ markBound → fire-and-forget
  ///    registerDevice → success(上行总数/冲突数摘要)。
  Future<void> _runMergeChain(Emitter<BindingState> emit,
      {required bool markAll}) async {
    // 全新状态(非 copyWith):清掉上一轮的 progress/failed 残留。
    emit(BindingState(
      status: BindingStatus.uploading,
      serverSummary: state.serverSummary,
    ));
    try {
      if (markAll) {
        // ADR-2 全量标记:guest 期 synced 行进入收集通路(幂等,重复调用
        // 只影响仍是 synced 的行);guest 无墓碑,墓碑表无此面。
        await _database.accountDao.markAllPendingForSync();
        await _database.transactionDao.markAllPendingForSync();
        await _database.debtDao.markAllPendingForSync();
        await _database.budgetDao.markAllPendingForSync();
        await _database.goalDao.markAllPendingForSync();
        await _database.holdingDao.markAllPendingForSync();
        await _database.tagDao.markAllPendingForSync();
        await _database.templateDao.markAllPendingForSync();
      }

      var uploaded = 0;
      var conflictTotal = 0;
      while (true) {
        final batch = await _collector.collect();
        // 全空(空库直通/上轮已推完)→ 收敛收尾。
        if (batch == null) break;
        final subBatches = splitSyncBatch(batch, mergeBatchSize);
        for (var i = 0; i < subBatches.length; i++) {
          final sub = subBatches[i];
          final result = await _syncPort.push(sub);
          if (!result.ok) {
            emit(state.copyWith(
                status: BindingStatus.failed,
                failureMessage: result.reason ?? '上传失败',
                canResume: true));
            return;
          }
          // 批成功回写(版本守卫 + 冲突实体一并标记,见 _writeBack)。
          await _writeBack(sub, result.conflicts);
          uploaded += sub.changeCount;
          conflictTotal += result.conflictCount;
          emit(state.copyWith(
            status: BindingStatus.uploading,
            progress: BindingProgress(
                batchIndex: i + 1,
                totalBatches: subBatches.length,
                uploadedChanges: uploaded),
          ));
        }
        // 本轮批次全部推完;循环再 collect 一次确认为空(在途 FR-1b 降级
        // 行重收时以新版本快照再推,版本守卫自洽无死循环)。
      }

      // First-binding's own mirror refresh (replaces the login-triggered
      // refresh that only fires for already-bound devices, review H-W4):
      // push 后镜像拉回,本地收敛到两端并集(FR-3 终态)。Resolve lazily —
      // BoundMirror depends on the same repos this bloc holds, eager
      // injection would cycle.
      getIt.isRegistered<BoundMirror>()
          ? await getIt<BoundMirror>().refreshAll()
          : null;
      // 'bound' 为纯绑定标记值(F17-T1 语义收敛:tenant 标记与设备身份
      // 分离 —— deviceId 独立取 clientId,见 GrpcOfflineSyncPort doc)。
      await _boundMarker.markBound('bound');
      // F17-T1(FR-2/ADR-1):markBound 后 fire-and-forget 注册设备行
      // (deviceId=clientId 由 port 自取;deviceName 取 Platform 简单值)。
      // 失败 log warn 不阻断绑定:server 按非空 device_id 幂等,下次绑定
      // 或 F17-T2 拉取前重试一次即可,无须在此重试。
      unawaited(_registerDevice());
      emit(BindingState(
        status: BindingStatus.success,
        uploadedEntities: uploaded,
        conflictCount: conflictTotal,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: BindingStatus.failed,
          failureMessage: e.toString(),
          canResume: true));
    }
  }

  /// 批成功回写(协调器 _writeBack 的 binding 层简化版,ADR-3):批内实体
  /// pending → synced(版本守卫 markXSynced)+ 批内墓碑清除,单事务。
  ///
  /// **冲突确认语义(F18-T2 同款)**:[conflicts] 命中的实体必然 ⊆ 本批
  /// 实体 —— 与正常落库实体走同一 versionsById、同一版本守卫标记 synced
  /// (server 冲突记录已保存内容,不标记则每轮重推堆冲突);失败批不回写
  /// (pending 保留重推)。holding_ledger 无 syncState(append-only),无
  /// 回写面。
  Future<void> _writeBack(
      SyncBatch sub, List<SyncConflictInfo> conflicts) async {
    if (conflicts.isNotEmpty) {
      // 确认面观测日志(English 结构化,无 CJK):解决前的可观测锚点。
      debugPrint('[binding] conflict acknowledged: '
          '${conflicts.length} entities recorded server-side '
          '(content preserved in conflict rows, resolution pending)');
    }
    await _database.transaction(() async {
      for (final entry in sub.entitiesByModule.entries) {
        // 版本守卫输入:entityId → 批次快照版本。
        final versionsById = {
          for (final e in entry.value) e.entityId: e.version,
        };
        switch (entry.key) {
          case SyncModule.account:
            await _database.accountDao.markAccountsSynced(versionsById);
          case SyncModule.transaction:
            await _database.transactionDao.markTransactionsSynced(versionsById);
          case SyncModule.debt:
            await _database.debtDao.markDebtsSynced(versionsById);
          case SyncModule.budget:
            await _database.budgetDao.markBudgetsSynced(versionsById);
          case SyncModule.goal:
            await _database.goalDao.markGoalsSynced(versionsById);
          case SyncModule.holding:
            await _database.holdingDao.markHoldingsSynced(versionsById);
          case SyncModule.tag:
            await _database.tagDao.markTagsSynced(versionsById);
          case SyncModule.template:
            await _database.templateDao.markTemplatesSynced(versionsById);
          case SyncModule.holdingLedger:
            // 台账行无 syncState(append-only)—— 无回写面;头行 pending
            // 期间台账全量重收的幂等语义见 collector 注释(F17-T2)。
            break;
          default:
            break; // 值域外模块防御(不应到达)。
        }
      }
      for (final t in sub.tombstones) {
        await _database.syncTombstoneDao.clearTombstone(t.module, t.entityId);
      }
    });
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

/// F19-T1(FR-1):readyToMerge 态的合并确认(非空账号)。
class BindingMergeConfirmed extends BindingEvent {}

class BindingUploadConfirmed extends BindingEvent {}

class BindingRetryRequested extends BindingEvent {}

enum BindingStatus {
  idle,
  guarding,

  /// F19-T1:服务端已有数据(摘要非空)→ 合并确认卡。
  readyToMerge,

  /// 服务端为空(摘要全 0)→ 上传确认卡(内部与 readyToMerge 同链)。
  readyToUpload,
  uploading,
  success,
  failed,
}

/// F19-T1(FR-1):守卫采集的服务端数据摘要(三面计数;缺省全 0 = 空账号)。
class BindingServerSummary {
  const BindingServerSummary({
    this.accountCount = 0,
    this.transactionCount = 0,
    this.holdingCount = 0,
  });

  final int accountCount;
  final int transactionCount;
  final int holdingCount;

  /// 三面全 0(空账号 → readyToUpload)。
  bool get isEmpty =>
      accountCount == 0 && transactionCount == 0 && holdingCount == 0;
}

/// F19-T1(FR-5/ADR-4):合并上传批进度(uploading 态携带)。
class BindingProgress {
  const BindingProgress({
    required this.batchIndex,
    required this.totalBatches,
    required this.uploadedChanges,
  });

  /// 当前批序号(1 基)。
  final int batchIndex;

  /// 本轮收集拆出的总批数。
  final int totalBatches;

  /// 截至当前批的累计上行条数(实体 + 墓碑)。
  final int uploadedChanges;
}

class BindingState {
  const BindingState({
    this.status = BindingStatus.idle,
    this.serverSummary,
    this.failureMessage,
    this.progress,
    this.uploadedEntities = 0,
    this.conflictCount = 0,
    this.canResume = false,
  });

  final BindingStatus status;

  /// F19-T1:守卫摘要(readyToMerge/readyToUpload/uploading 态携带;
  /// UI 摘要卡与空/非空文案区分的唯一数据源)。
  final BindingServerSummary? serverSummary;

  final String? failureMessage;

  /// F19-T1:uploading 态的批进度(null = 尚未完成任何一批)。
  final BindingProgress? progress;

  /// success 摘要:累计上行条数(实体 + 墓碑;断点续传后为末轮计数)。
  final int uploadedEntities;

  /// success 摘要:push 命中的冲突条数(>0 提示进冲突面板;F18 面板零接线,
  /// badge 读取协调器/面板自己的计数源)。
  final int conflictCount;

  /// F19-T1 fix round 1:failed 态的重试语义 —— true = 失败发生在合并链内
  /// (重试续传:跳过全量标记,只推剩余 pending);false = 守卫面失败
  /// (重试 = 重新走守卫)。UI 按此区分按钮/提示文案。
  final bool canResume;

  BindingState copyWith({
    BindingStatus? status,
    BindingServerSummary? serverSummary,
    String? failureMessage,
    BindingProgress? progress,
    int? uploadedEntities,
    int? conflictCount,
    bool? canResume,
  }) =>
      BindingState(
        status: status ?? this.status,
        serverSummary: serverSummary ?? this.serverSummary,
        failureMessage: failureMessage ?? this.failureMessage,
        progress: progress ?? this.progress,
        uploadedEntities: uploadedEntities ?? this.uploadedEntities,
        conflictCount: conflictCount ?? this.conflictCount,
        canResume: canResume ?? this.canResume,
      );
}
