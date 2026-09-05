# Task Brief F12-T1 — 计数聚合 + 构造补扫

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f12`,客户端 `yucai/client/`。**TDD。**

## 先读(必读)

1. `docs/.../2026-09-03-sync-status-conflict/{spec.md FR-2/3,design.md ADR-2/3}`
2. `lib/binding/presentation/bloc/sync_coordinator_bloc.dart`(F10 交付:状态机/幂等/TODO-F12 锚点;**行为语义零破坏**)
3. `lib/core/localdb/daos/` 8 个 `watchPending*` 流 + `sync_tombstone_dao.dart`(**检查有无 watch 流,缺则补**)
4. `lib/core/session_mode/session_mode_tracker.dart`(isGuest 判定;guest↔bound 切换信号——auth bloc 态变化时 tracker 布尔翻转,但无流;设计 ADR-2 授权"登录/登出事件驱动订阅重建或轮询——TDD 定,注释")

## 交付物

### 1. PendingCountWatcher(`lib/binding/data/pending_count_watcher.dart`)

- 聚合 8 模块 `watchPending*` + 墓碑 watch 流 → `Stream<int>`(sum;每次任一源发射重算);手写 merge(无 rxdart 依赖——StreamController+9 订阅);`dispose()` 统一 cancel;中文注释(墓碑计入理由:删除也是待同步变更)。
- DI 注册(lazySingleton;bloc 构造注入或 bloc 内自建——选一,注释理由)。

### 2. bloc 扩展(零破坏)

- `SyncCoordinatorState` 增 `pendingCount`(全态携带,props 更新,既有构造兼容默认值)。
- 订阅 watcher → emit 同 status 的计数更新(不触发同步动作,纯状态)。
- **guest 处理**:bloc 构造时 isGuest→不订阅/计数 0;guest↔bound 切换的订阅重建——最小实现:构造时判定+`SyncRetryRequested`/事件路径上惰性重订?或 tracker 增变更通知?**最小侵入**:构造时判定一次+bloc 长生命周期内登录态翻转由补扫/重试事件路径自然携带(计数流对 guest 库本来也无 pending——guest 写入恒 synced!)。想清楚后选最小正确路径,注释论证(guest 写不置 pending 是 F10 语义,所以 guest 订阅无害——可能根本不需要切换重建;论证它)。
- **构造补扫**(ADR-3):构造尾部 `if (!isGuest)`:collect 一次→计数更新;若 online 且非空→触发一次同步(照既有触发路径);offline→仅计数。TODO-F12 锚点注释更新为已闭环。

### 3. TDD 测试

- watcher:多源求和/任一源发射触发重算/dispose 后无泄漏(用 fake 流手控)。
- bloc:计数全态携带;构造补扫 online(触发 push)/offline(仅计数)两分支;guest 构造(不订阅不补扫);既有 7 测零回归(语义零破坏守门)。

## 验证

1. 新单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1397)
3. `flutter analyze` 新文件 0 条

## 约束

F10 协调器行为/pending 语义零破坏(既有测试不改不红);不动 UI(T2);中文注释;不 commit。完成后报告(含 guest 订阅策略论证)。
