import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/binding/data/pending_collector.dart';
import 'package:yucai_client/binding/data/pending_count_watcher.dart';
import 'package:yucai_client/binding/data/pull_applier.dart';
import 'package:yucai_client/binding/domain/offline_sync_port.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/sync_state.dart' show SyncModule;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

/// F10 T3(spec FR-5,design ADR-5/LLD):回网同步协调器 —— 以 bloc 形态供
/// F12 UI 消费(design Open Question 定案:倾向 bloc)。
///
/// 触发:ConnectivityGateway.online 流的 true 边沿(照 notifications_bootstrap
/// 回网订阅先例)+ 手动 retry 事件(F12「立即同步」)+ 构造补扫触发
/// (F12 T1,见 [_bootstrapScan])。进行中幂等:flight 期间到达的触发直接
/// 丢弃(见 [_transform])。
///
/// 流程:collect → 空批次 → clean;非空 → syncing(n) → port.push →
/// 成功:回写 synced + 清墓碑 + 按模块刷新镜像 → clean;失败:failed(reason)
/// + pending 保留(下次触发重试)。
///
/// 仅 bound 态生效:guest 写全 synced 无上行语义,触发为无操作(下行拉取
/// 同门控 —— guest 无 server 侧多设备语义,[_pullAndApply] 不可达)。
///
/// F12 T1(spec FR-2/FR-3,design ADR-2/ADR-3)零破坏增量:
/// - 计数订阅:构造时(bound)订阅 [PendingCountWatcher] 聚合流,计数变化经
///   [SyncPendingCountChanged] 专属管道更新状态(同 status 纯计数更新,
///   不触发同步动作)→ pendingCount 全态携带;
/// - 构造补扫(**闭环原 TODO-F12 观察点 3**):迟构造(如 F12 UI 首次消费
///   才 resolve)不补发构造前的回网边沿 → 构造时即 collect 一次兜底,
///   online 且非空则触发一次同步,offline 仅计数(见 [_bootstrapScan])。
///
/// F18-T2(spec FR-2,design ADR-2)确认语义:push 成功响应命中的冲突实体
/// 在回写阶段一并标 synced(内容已在 server 冲突记录,防反复重推堆冲突);
/// 冲突完整列表随 clean 态携带(权威计数归 ListConflicts/面板,协调器不
/// 重复拉)。解决流(面板)是 T3 的面。
class SyncCoordinatorBloc
    extends Bloc<SyncCoordinatorEvent, SyncCoordinatorState> {
  /// [onlineStream] 不落字段(构造期订阅即弃);照库内先例(如
  /// AccountRepositoryImpl)用位置初始化形参。
  ///
  /// [pendingWatcher] F12 T1:计数聚合器注入缝(测试用 fake 流手控);
  /// 生产不注入 → bloc 自建(见 [_ensurePendingWatch] 的接线/归属注释)。
  ///
  /// [applier]/[clientIdProvider] F17-T2:下行应用器 + 自设备身份缝
  /// (own-echo 过滤,见 [_pullAndApply]);生产 DI 注入,缺省 null =
  /// 拉取编排不生效(上行语义与 F10-F13 逐位一致)。
  SyncCoordinatorBloc(
    this._port,
    this._collector,
    this._session,
    this._db, [
    Stream<bool>? onlineStream,
    this._mirror,
    this._pendingWatcher,
    this._applier,
    this._clientIdProvider,
  ]) : super(const SyncCoordinatorState()) {
    // 计数更新专属管道(**先于**基类触发管道注册):不经 [_transform] 的
    // in-flight 闸门(计数是纯状态信号,flight 中也须实时更新;且绝不能
    // 占用闸门挤掉真实触发 —— 见 [_transform] 内的对应跳过)。
    on<SyncPendingCountChanged>(_onCountChanged);
    // 基类订阅:触发事件共用一条处理管道(单一 in-flight 闸门)。
    on<SyncCoordinatorEvent>(_onTriggered, transformer: _transform);
    // 回网订阅:gateway.online 本身 distinct 且无重放,每个 true 事件即
    // 一次回网边沿(测试注入普通流,同语义)。
    _onlineSub = onlineStream?.listen((online) {
      if (online) add(SyncOnlineRestored());
    });
    // F12 T1 guest 策略(论证;design ADR-2 授权 TDD 定):
    // - spec FR-2 钉「guest 计数归零不订阅」→ 构造按 isGuest 门控一次;
    //   guest 期订阅虽「无害」(F10 语义:guest 写入恒 synced、删除不落
    //   墓碑 → guest 库 pending 计数恒 0,订阅只是 9 条 drift 流空转),
    //   但按规格不做无意义工作。
    // - guest↔bound 翻转**无需订阅重建 machinery**(tracker 无变更流,为其
    //   加通知属过度设计):bloc 为 lazySingleton,生产首个 resolve 来自
    //   F12 badge(仅绑定态渲染)→ 现实中构造时几乎必为 bound;即便在
    //   guest 期被构造,guest 期计数恒 0 与状态自洽,翻转后**首个触发事件**
    //   (回网边沿/手动重试)经 _onTriggered 顶部的 _ensurePendingWatch
    //   惰性重订,计数随下一次同步活动自然对齐 —— 即简报定的「最小侵入」
    //   路径:构造时判定一次 + 事件路径自然携带。
    if (!_session.isGuest) {
      _ensurePendingWatch();
      _bootstrapScan();
    }
  }

  final OfflineSyncPort _port;
  final PendingCollector _collector;
  final SessionModeTracker _session;
  final db.AppDatabase _db;
  final BoundMirror? _mirror;

  /// F12 T1:注入的计数聚合器(测试缝);生产为 null → 自建。
  final PendingCountWatcher? _pendingWatcher;

  /// F17-T2:下行应用器(缺省 null → 拉取编排不生效,见类 doc)。
  final PullApplier? _applier;

  /// F17-T2:自设备身份缝(own-echo 过滤;与 GrpcOfflineSyncPort 同一
  /// 注入源 TokenStorage.readClientId)。
  final ClientIdProvider? _clientIdProvider;

  /// 实际生效的计数聚合器(注入或自建);bloc 是其唯一消费者与生命周期
  /// 属主 —— 不走 DI 单独注册(避免 lazySingleton 无人 dispose 的悬挂流,
  /// 见 pending_count_watcher.dart 类 doc 的归属论证)。
  PendingCountWatcher? _watcher;

  StreamSubscription<bool>? _onlineSub;
  StreamSubscription<int>? _countSub;

  /// 最新已知待同步计数(watcher/补扫维护,成功收敛/异常态发射时携带)。
  int _liveCount = 0;

  /// watcher 是否已上报过计数 —— 补扫的事务快照在构造上不晚于任何 watcher
  /// 发射,一旦 watcher 上报过,补扫的陈旧计数不得覆盖(见 [_bootstrapScan])。
  bool _watcherCounted = false;

  Future<void> _onTriggered(
    SyncCoordinatorEvent event,
    Emitter<SyncCoordinatorState> emit,
  ) async {
    // guest 不触发(语义见类 doc):状态保持不变、不收集不 push、不拉取。
    if (_session.isGuest) return;
    // F12 T1:guest 期构造后翻转为 bound 的首触发 → 惰性重订计数流
    // (guest 策略论证见构造尾部注释)。
    _ensurePendingWatch();

    try {
      // F17-T2(ADR-3):**pull 先于 push**(收最新再发 —— 他设备变更先进
      // 本地,再决定上行内容;失败容忍,见 [_pullAndApply])。构造补扫的
      // online 分支走同一管道,同样先拉。
      await _pullAndApply();
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
        // 成功:回写 synced(含 F18-T2 冲突确认标记)→ 清墓碑 → 按模块刷新
        // 镜像(T2 保护语义闭环:上行后的行靠 server 回读存活,不再依赖
        // pending 保护)。
        await _writeBack(batch, result.conflicts);
        await _refreshMirror(batch.modules);
        // F17-T2(ADR-3):push 成功后再拉一次(他设备变更感知 —— 本批
        // push 期间 server 可能已追加他设备条目);失败容忍同前。
        await _pullAndApply();
        // clean 携带实时计数:回写后库内 pending 通常为 0,但 push 在途的
        // FR-1b 降级更新行(版本守卫放行)仍 pending —— 计数须如实携带
        //(spec FR-2 全态携带);watcher 重算异步,_liveCount 可能短暂滞后,
        // 下一次源发射即收敛。
        emit(SyncCoordinatorState(
          status: SyncStatus.clean,
          pendingCount: _liveCount,
          // F17-T1(FR-5/ADR-5):冲突计数透传(clean 态携带;失败态无冲突
          // ——失败结果不含 conflicts)。F12 badge 组件**不改**(仅状态
          // 携带,冲突面板/解决流是 F18 的面)。
          conflictCount: result.conflictCount,
          // F18-T2(FR-2/ADR-2):冲突**完整列表**随 clean 携带(字段级:
          // conflictId/双 payload/createdAt,面板消费;与 conflictCount 同
          // 生命周期)。不可变视图防外部 mutate;权威计数归 ListConflicts
          // —— 协调器 clean 后不异步重拉,面板 bloc 自己拉(分工见 state doc)。
          conflicts: UnmodifiableListView(result.conflicts),
        ));
      } else {
        // 失败:pending 保留(不动库),下次回网/手动触发重试。
        emit(SyncCoordinatorState(
          status: SyncStatus.failed,
          pendingCount: batch.changeCount,
          failureReason: result.reason ?? '同步失败',
        ));
      }
    } catch (e) {
      // 收集/回写/镜像刷新异常同样收敛为 failed(pending 保留可重试);
      // 计数携带 watcher 最新值(收集中途抛出时批次计数不可得)。
      emit(SyncCoordinatorState(
        status: SyncStatus.failed,
        pendingCount: _liveCount,
        failureReason: e.toString(),
      ));
    }
  }

  /// F12 T1:计数更新(非触发)—— 同 status 纯计数发射,保留 failed 态
  /// 原因;等值状态由 bloc 的 == 去重(Equatable props),不产生冗余发射。
  void _onCountChanged(
    SyncPendingCountChanged event,
    Emitter<SyncCoordinatorState> emit,
  ) {
    _liveCount = event.count;
    emit(SyncCoordinatorState(
      status: state.status,
      pendingCount: event.count,
      // F17-T1:计数纯更新不冲掉冲突计数(同 failureReason 的保留语义);
      // F18-T2:完整列表同理保留(「最近一次成功 push」携带面)。
      conflictCount: state.conflictCount,
      conflicts: state.conflicts,
      failureReason: state.failureReason,
    ));
  }

  /// F12 T1:订阅计数聚合流(幂等)。生产自建 watcher(接线/归属选择理由
  /// 见构造与字段注释);测试可注入 fake。
  void _ensurePendingWatch() {
    if (_countSub != null) return;
    final watcher = _pendingWatcher ?? PendingCountWatcher.forDatabase(_db);
    _watcher = watcher;
    _countSub = watcher.stream.listen(
      (count) {
        _watcherCounted = true; // 先置旗再入队:补扫据此让位(时序论证见 _bootstrapScan)。
        add(SyncPendingCountChanged(count));
      },
      // 计数流异常不阻断协调器(watcher 内部已吞源错误,此处兜底)。
      onError: (_, __) {},
    );
  }

  /// F12 T1 构造补扫(spec FR-3,design ADR-3;闭环原 TODO-F12「迟构造不
  /// 补发构造前回网边沿」):构造时 collect 一次 —— 非空且 online → 走既有
  /// 触发管道同步一次([SyncBootstrapSyncRequested],受 in-flight 幂等
  /// 保护);offline → 仅计数(不 push:gRPC 会立刻失败徒增 failed 噪音)。
  ///
  /// 事务快照:collect 包在 `_db.transaction` 内 —— 保证补扫读到**构造
  /// 时刻**的一致库状态,不受构造后并发写影响(与 [_writeBack] 同一事务
  /// 工具),语义即「补构造前错过的边沿」。
  ///
  /// 计数时序:补扫的快照不晚于任何 watcher 发射(watcher 订阅在构造期、
  /// drift 首发射与补扫 collect 并发)——若 watcher 已上报过计数(旗标
  /// [_watcherCounted],置旗与入队同处于监听回调的同步段,无交错窗口),
  /// 补扫的陈旧快照计数**让位不覆盖**;watcher 尚未上报(如测试注入无发射
  /// fake、或首发射未到)时补扫计数兜底生效。两类事件按入队序处理,终值
  /// 恒收敛到最新者。
  Future<void> _bootstrapScan() async {
    try {
      final batch = await _db.transaction(() => _collector.collect());
      if (!_watcherCounted) {
        add(SyncPendingCountChanged(batch?.changeCount ?? 0));
      }
      if (batch != null && _session.online) {
        add(SyncBootstrapSyncRequested());
      }
    } catch (_) {
      // 补扫失败静默:不阻断 bloc,首回网/手动重试路径自会收敛。
    }
  }

  /// F17-T2(spec FR-3,design ADR-3)拉取编排:分页循环拉尽并应用下行。
  ///
  /// - 游标:drift `sync_cursor` 单行(since=上次页尾;缺省 0=全量重拉,
  ///   应用路径幂等[upsert 按 id / delete 幂等],重装/清库无一致性风险)。
  /// - 分页:since=游标 → 应用 → 游标=**页尾条目 logVersion**(非 frontier
  ///   —— server ADR-3:frontier 可能仍在后续页在途)→ hasMore 续拉。
  /// - own-echo 过滤:deviceId=自设备的条目跳过应用(server PullChanges
  ///   无设备过滤,自设备的推送回声必然返流)—— 本地已是这些行的权威态
  ///   (pending 行有更强保护,synced 行内容等同),回灌纯属浪费;**游标
  ///   仍按原始页推进**(含被过滤条目),否则会永远重拉同一窗口。
  /// - 失败容忍:任一页失败(port.pull 抛出 / applier 抛出)→ log 后返回,
  ///   **不 emit**(push 流与状态机不破),游标停在最后成功页尾 → 下次
  ///   触发以同游标幂等重拉重放。
  /// - 应用后不刷新镜像:增量条目即 server 终态(spec FR-3「窄幅镜像刷新
  ///   不需要」);镜像仍是全量重建场景(登录/绑定/推送后)的面。
  /// - 未注入 applier(旧测试/降级):整段 no-op(上行语义零回归)。
  ///
  /// 破坏性 server 防御:页非空但页尾版本未前进(病态 server/fake 死循环
  /// 面具)→ 中断本轮,余量留给下次触发。
  Future<void> _pullAndApply() async {
    final applier = _applier;
    if (applier == null) return;
    try {
      final own = await _clientIdProvider?.call();
      var since = await _db.syncCursorDao.readLastPulledVersion();
      while (true) {
        final page = await _port.pull(since);
        if (page.changes.isEmpty) {
          // 空页:游标推进到 frontier(此后无 >since 条目;防 frontier
          // 停留导致每次触发重复空拉)。
          await _db.syncCursorDao.writeLastPulledVersion(page.latestVersion);
          return;
        }
        // own-echo 过滤(游标按原始页推进,理由见 doc)。
        final foreign = own == null
            ? page.changes
            : page.changes.where((c) => c.deviceId != own).toList();
        if (foreign.isNotEmpty) {
          await applier.apply(foreign);
        }
        if (page.changes.last.logVersion <= since) {
          // 页尾未前进:病态分页面具,中断防死循环(见 doc)。
          debugPrint('[sync-coordinator] pull page not advancing '
              '(since=$since); aborting pull loop');
          return;
        }
        since = page.changes.last.logVersion;
        await _db.syncCursorDao.writeLastPulledVersion(since);
        if (!page.hasMore) return;
      }
    } catch (e) {
      // 拉失败容忍:不阻断 push 流、不破状态;游标停在最后成功页尾。
      debugPrint('[sync-coordinator] pull failed (tolerated): $e');
    }
  }

  /// 成功回写:批内实体 pending → synced(单事务,带**版本守卫**——仅当
  /// 行当前版本仍等于批次快照版本才回写,push 在途的 FR-1b 降级更新行保持
  /// pending 留下次上行)+ 清批内墓碑(墓碑无版本概念,批内即清)。
  ///
  /// F18-T2(FR-2/ADR-2)**冲突确认语义**:[conflicts] 命中的实体(必然 ⊆
  /// 本批实体 —— 冲突仅由本次 push 的条目触发)与正常落库实体走**同一
  /// versionsById、同一版本守卫**标记 synced:server 冲突记录已保存其内容
  /// (client_payload,面板解决时裁决),不标记则该行每轮重推、堆一条新
  /// 冲突记录。守卫同款意味着 push 在途的降级行(版本已推进)**不**被陈旧
  /// 确认 —— 新内容未进冲突记录,保持 pending 下次上行是正确行为。
  Future<void> _writeBack(
      SyncBatch batch, List<SyncConflictInfo> conflicts) async {
    if (conflicts.isNotEmpty) {
      // 确认面观测日志(English 结构化,无 CJK):解决前的可观测锚点。
      debugPrint('[sync-coordinator] conflict acknowledged: '
          '${conflicts.length} entities recorded server-side '
          '(content preserved in conflict rows, resolution pending)');
    }
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
          case SyncModule.holdingLedger:
            // 台账行无 syncState(append-only)—— 无回写面;头行 pending
            // 期间台账全量重收的幂等语义见 collector 注释(F17-T2)。
            break;
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
      // SyncModule 前 8 常量与 MirrorModule 枚举名逐字一致(sync_state.dart
      // 契约);holding_ledger 非 MirrorModule 成员(第 9 个 entityType,
      // append-only 台账)—— 其镜像刷新随 holding 模块整体走
      // (BoundMirror._refreshHoldings 含 holdings+transactions+securities)。
      final mirrorModule = module == SyncModule.holdingLedger
          ? MirrorModule.holding
          : MirrorModule.values.byName(module);
      await mirror.refreshModule(mirrorModule);
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
        // F12 T1:bloc 8.x 的 on<E> 按 `event is E` 匹配**子类型** → 计数
        // 事件也会流入本触发管道(它同时已被专属 handler 处理);在此跳过:
        // 既避免二次处理,更避免计数事件占用 in-flight 闸门挤掉真实触发。
        if (event is SyncPendingCountChanged) return;
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
    // F12 T1:计数订阅与聚合器随 bloc 释放(归属论证见 _watcher 字段)。
    _countSub?.cancel();
    _watcher?.dispose();
    return super.close();
  }
}

/// 触发事件(三路:回网边沿 / 手动重试 / 构造补扫),共用一条处理管道。
abstract class SyncCoordinatorEvent {}

/// 回网 true 边沿(协调器内部由 online 订阅转发,外部不直接添加)。
class SyncOnlineRestored extends SyncCoordinatorEvent {}

/// 手动重试(F12 UI「立即同步」入口;失败后的用户主动触发)。
class SyncRetryRequested extends SyncCoordinatorEvent {}

/// F12 T1(ADR-3):构造补扫发现非空批次且在线 → 请求一次同步(走既有
/// 触发管道,受 in-flight 幂等保护;仅由 [_bootstrapScan] 内部添加)。
class SyncBootstrapSyncRequested extends SyncCoordinatorEvent {}

/// F12 T1 内部事件:计数聚合流 / 构造补扫的计数更新(**非触发**;由
/// [_onCountChanged] 专属管道处理,不进 in-flight 闸门)。
class SyncPendingCountChanged extends SyncCoordinatorEvent {
  SyncPendingCountChanged(this.count);

  /// 最新待同步计数(8 头表 pending 行数 + 墓碑数)。
  final int count;
}

/// 同步状态(spec FR-5 的 SyncStatus;F12 T1 起计数全态携带)。
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
///
/// F12 T1(spec FR-2):pendingCount **全态携带实时待同步计数**(实体 +
/// 墓碑)—— idle/clean 亦有值(badge「待同步 N」即读它);Equatable 让
/// bloc 在 emit 层去重等值状态(纯计数更新的噪声发射被吞)。
///
/// F17-T1(FR-5/ADR-5 最小面):[conflictCount] 携带最近一次成功 push 的
/// 冲突条数(clean 态写入,计数更新不冲掉;0=无冲突)。仅状态携带 ——
/// F12 badge 组件不改,「冲突 N 待处理」展示与解决流是 F18 的面。
/// F18-T2(FR-2/ADR-2)增 [conflicts] 完整列表(clean 态随 conflictCount
/// 一并携带;权威计数归 ListConflicts/面板,见字段 doc 分工注释)。
class SyncCoordinatorState extends Equatable {
  const SyncCoordinatorState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.failureReason,
    this.conflictCount = 0,
    this.conflicts = const [],
  });

  final SyncStatus status;

  /// 实时待同步计数(watcher 流权威;syncing 中亦随实时覆盖)—— idle/clean
  /// 由计数聚合流维护(构造补扫亦发初值)。
  final int pendingCount;

  /// failed 态原因。
  final String? failureReason;

  /// F17-T1:最近一次成功 push 的冲突条数(默认 0;F18 冲突面板消费)。
  final int conflictCount;

  /// F18-T2(FR-2/ADR-2):最近一次成功 push 命中的冲突**完整列表**(clean
  /// 态携带,UnmodifiableListView 防外部 mutate;与 [conflictCount] 同生命
  /// 周期 —— 空批次/失败态清零)。
  ///
  /// 分工注释(最小面):此处仅携带 push 响应信息;**权威计数与最新列表 =
  /// ListConflicts**,由 F18 冲突面板 bloc 自己拉取/解决后重取 —— 协调器
  /// clean 后**不**异步 listConflicts 刷新(两消费方各取所需,不重复拉)。
  final List<SyncConflictInfo> conflicts;

  @override
  List<Object?> get props =>
      [status, pendingCount, failureReason, conflictCount, conflicts];
}
