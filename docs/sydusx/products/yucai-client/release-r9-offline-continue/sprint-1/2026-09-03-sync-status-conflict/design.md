# Design — F12 同步状态 UI

> R9 sprint-1 · 2026-09-03。spec 四决策在案;F10 件全复用。

## Decisions (ADRs)

- **ADR-1 挂载与形态**:app_shell 顶栏 `OfflineBadge` 旁 `SyncStatusBadge`(StatelessWidget,`BlocBuilder<SyncCoordinatorBloc>`);仅 `!isGuest` 渲染(SessionModeTracker 判定,非 bloc 态——bloc 对 guest 本就 idle);四态渲染表:syncing→spinner+「同步中」;failed→negative 色 chip+原因+onTap 重试;pendingN>0→muted chip「待同步 N」;clean→SizedBox.shrink。语义令牌 context.yucai。
- **ADR-2 计数聚合**:`PendingCountWatcher`(binding/data)——8 个 `watchPending*` 流 `CombineLatest`(用 Rx?无 rxdart 依赖则手写:聚合 StreamController+8 订阅 merge 求和+墓碑表 watch[SyncTombstoneDao 补 watchAllTombstones 流,若缺则加];实现形态 TDD 时定,注释理由)+去抖不需要。bloc 订阅→`SyncCoordinatorState.pendingCount` 全态携带(状态类增字段,props 更新);guest 退订/清零。
- **ADR-3 构造补扫**:bloc 构造尾部:`if (!isGuest) add(SyncRetryRequested 命名待定——或内部 _kick)`——online 时即走同步;offline 时 collect 结果仅体现为计数(不 push,grpc 会立刻失败→failed?不——**补扫仅收集+更新计数;若 online 才触发 push**)。语义注释钉死。
- **ADR-4 手动重试**:badge onTap failed→`SyncRetryRequested`(既有事件);点击防抖由 bloc 幂等兜底。
- **ADR-5 测试策略 TDD**:bloc(聚合流 fake/计数/补扫 online/offline 两分支/guest)→widget(四态/tap/令牌)→e2e guest 零回归。

## HLD 改动面

- `lib/binding/data/pending_count_watcher.dart`(新)
- `lib/binding/presentation/bloc/sync_coordinator_bloc.dart`(计数+补扫+状态类)
- `lib/binding/presentation/widgets/sync_status_badge.dart`(新)+ `lib/app/widgets/app_shell.dart`(挂载)
- `core/localdb/daos/sync_tombstone_dao.dart`(补 watch 流,若缺)
- injection(bloc 已注册;watcher 注册或 bloc 内构造——TDD 定)

## LLD 要点

- 聚合实现最小:StreamGroup 不在 SDK?手写 merge(8+1 订阅 → 每发射重算 sum → sink);close 语义随 bloc dispose。
- 补扫事件命名照 `...Requested` 惯例。
- badge 尺寸/样式对齐 OfflineBadge 现有规格(读其实现照抄尺寸节奏)。

## Risks

| 风险 | 缓解 |
|---|---|
| 9 流聚合泄漏 | bloc dispose 统一 cancel;单测钉 |
| guest↔bound 切换订阅错乱 | 登录/登出事件驱动订阅重建(或 tracker 态轮询——TDD 定,注释);单测钉 |
| e2e guest 回归 | badge 仅绑定态渲染;全量门 |

## Open Questions

无(实现自由度均已在 ADR 内授权+注释要求)。
