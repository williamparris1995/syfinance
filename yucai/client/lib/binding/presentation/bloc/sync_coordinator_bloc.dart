import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

/// F10 T3(spec FR-5,design ADR-5/LLD):回网同步协调器 —— 以 bloc 形态供
/// F12 UI 消费(design Open Question 定案:倾向 bloc)。
///
/// 触发:ConnectivityGateway.online 流的 true 边沿(照 notifications_bootstrap
/// 回网订阅先例)+ 手动 retry 事件(F12「立即同步」)。进行中幂等:flight
/// 期间到达的触发直接丢弃(见 [_transform])。
///
/// 流程:collect → 空批次 → clean;非空 → syncing(n) → port.push →
/// 成功:回写 synced + 清墓碑 + 按模块刷新镜像 → clean;失败:failed(reason)
/// + pending 保留(下次触发重试)。
///
/// 仅 bound 态生效:guest 写全 synced 无上行语义,触发为无操作。
///
/// TODO-F12(观察 3,UX 决策点):bloc 为 lazySingleton —— 迟构造(如 F12
/// UI 首次消费时才 resolve)不补发构造前的回网边沿;是否改为构造即扫一次
/// (collect 空/非空自判)由 F12 UX 定,本任务不修。
class SyncCoordinatorBloc
    extends Bloc<SyncCoordinatorEvent, SyncCoordinatorState> {
  /// [onlineStream] 不落字段(构造期订阅即弃);照库内先例(如
  /// AccountRepositoryImpl)用位置初始化形参。
  SyncCoordinatorBloc(
    this._port,
    this._collector,
    this._session,
    this._db, [
    Stream<bool>? onlineStream,
    this._mirror,
  ]) : super(const SyncCoordinatorState()) {
    // 基类订阅:两个触发事件共用一条处理管道(单一 in-flight 闸门)。
    on<SyncCoordinatorEvent>(_onTriggered, transformer: _transform);
    // 回网订阅:gateway.online 本身 distinct 且无重放,每个 true 事件即
    // 一次回网边沿(测试注入普通流,同语义)。
    _onlineSub = onlineStream?.listen((online) {
      if (online) add(SyncOnlineRestored());
    });
  }

  final OfflineSyncPort _port;
  final PendingCollector _collector;
  final SessionModeTracker _session;
  final db.AppDatabase _db;
  final BoundMirror? _mirror;

  StreamSubscription<bool>? _onlineSub;

  Future<void> _onTriggered(
    SyncCoordinatorEvent event,
    Emitter<SyncCoordinatorState> emit,
  ) async {
    // guest 不触发(语义见类 doc):状态保持不变、不收集不 push。
    if (_session.isGuest) return;

    try {
      final batch = await _collector.collect();
      if (batch == null) {
        // 空批次(无 pending 无墓碑)→ clean。
        emit(const SyncCoordinatorState(status: SyncStatus.clean));
        return;
      }
      emit(SyncCoordinatorState(
        status: SyncStatus.syncing,
        pendingCount: batch.changeCount,
      ));
      final result = await _port.push(batch);
      if (result.ok) {
        // 成功:回写 synced → 清墓碑 → 按模块刷新镜像(T2 保护语义闭环:
        // 上行后的行靠 server 回读存活,不再依赖 pending 保护)。
        await _writeBack(batch);
        await _refreshMirror(batch.modules);
        emit(const SyncCoordinatorState(status: SyncStatus.clean));
      } else {
        // 失败:pending 保留(不动库),下次回网/手动触发重试。
        emit(SyncCoordinatorState(
          status: SyncStatus.failed,
          pendingCount: batch.changeCount,
          failureReason: result.reason ?? '同步失败',
        ));
      }
    } catch (e) {
      // 收集/回写/镜像刷新异常同样收敛为 failed(pending 保留可重试)。
      emit(SyncCoordinatorState(
        status: SyncStatus.failed,
        failureReason: e.toString(),
      ));
    }
  }

  /// 成功回写:批内实体 pending → synced(单事务,带**版本守卫**——仅当
  /// 行当前版本仍等于批次快照版本才回写,push 在途的 FR-1b 降级更新行保持
  /// pending 留下次上行)+ 清批内墓碑(墓碑无版本概念,批内即清)。
  Future<void> _writeBack(SyncBatch batch) async {
    await _db.transaction(() async {
      for (final entry in batch.entitiesByModule.entries) {
        // 版本守卫输入:entityId → 批次快照版本。
        final versionsById = {
          for (final e in entry.value) e.entityId: e.version,
        };
        switch (entry.key) {
          case SyncModule.account:
            await _db.accountDao.markAccountsSynced(versionsById);
          case SyncModule.transaction:
            await _db.transactionDao.markTransactionsSynced(versionsById);
          case SyncModule.debt:
            await _db.debtDao.markDebtsSynced(versionsById);
          case SyncModule.budget:
            await _db.budgetDao.markBudgetsSynced(versionsById);
          case SyncModule.goal:
            await _db.goalDao.markGoalsSynced(versionsById);
          case SyncModule.holding:
            await _db.holdingDao.markHoldingsSynced(versionsById);
          case SyncModule.tag:
            await _db.tagDao.markTagsSynced(versionsById);
          case SyncModule.template:
            await _db.templateDao.markTemplatesSynced(versionsById);
          default:
            break; // 值域外模块防御(不应到达)。
        }
      }
      for (final t in batch.tombstones) {
        await _db.syncTombstoneDao.clearTombstone(t.module, t.entityId);
      }
    });
  }

  /// 按批次涉及模块刷新镜像(窄幅,非 refreshAll);镜像内部失败自吞
  /// (debugPrint),不阻断 clean 收敛 —— 自愈发生在下一次**非空** push 或
  /// 其他刷新触发(登录/写后刷新;空批次路径不刷新镜像)。
  Future<void> _refreshMirror(Set<String> modules) async {
    final mirror = _mirror;
    if (mirror == null) return;
    for (final module in modules) {
      // SyncModule 常量与 MirrorModule 枚举名逐字一致(sync_state.dart 契约)。
      await mirror.refreshModule(MirrorModule.values.byName(module));
    }
  }

  /// 简版 droppable 事件变换(未引入 bloc_concurrency):任一触发处理期间
  /// 到达的新触发**直接丢弃**(到达时刻判定,不排队)—— 即 design LLD
  /// 「进行中幂等(忽略重入)」。mapper 流完成 = 处理结束,放行下一触发;
  /// 状态发射在 handler 内经 bloc emit 走 onChange,不经此变换。
  Stream<SyncCoordinatorEvent> _transform(
    Stream<SyncCoordinatorEvent> events,
    EventMapper<SyncCoordinatorEvent> mapper,
  ) {
    final driver = StreamController<SyncCoordinatorEvent>();
    var processing = false;
    events.listen(
      (event) {
        if (processing) return; // flight 中:忽略重入。
        processing = true;
        mapper(event)
            .drain<void>()
            .whenComplete(() => processing = false);
      },
      onError: driver.addError,
      onDone: driver.close,
    );
    return driver.stream;
  }

  @override
  Future<void> close() {
    _onlineSub?.cancel();
    return super.close();
  }
}

/// 触发事件(两路:回网边沿 / 手动重试),共用一条处理管道。
abstract class SyncCoordinatorEvent {}

/// 回网 true 边沿(协调器内部由 online 订阅转发,外部不直接添加)。
class SyncOnlineRestored extends SyncCoordinatorEvent {}

/// 手动重试(F12 UI「立即同步」入口;失败后的用户主动触发)。
class SyncRetryRequested extends SyncCoordinatorEvent {}

/// 同步状态(spec FR-5 的 SyncStatus;待同步计数在 syncing 态携带)。
enum SyncStatus {
  /// 初始态(未触发过)。
  idle,

  /// 无待上行变更(空批次收敛点 / 上行成功后)。
  clean,

  /// 上行进行中(携带本批变更数 n = 实体 + 墓碑)。
  syncing,

  /// 上行失败(携带原因;pending 保留待重试)。
  failed,
}

/// 协调器对外状态流(bloc state;F12 UI 消费)。
class SyncCoordinatorState {
  const SyncCoordinatorState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.failureReason,
  });

  final SyncStatus status;

  /// syncing/failed 态的本批变更数(clean/idle 为 0)。
  final int pendingCount;

  /// failed 态原因。
  final String? failureReason;
}
