# Task Brief F10-T1 — 三态数据路由 + 写降级 + OfflineAuthenticated 修复

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r9-f10`,客户端 `yucai/client/`。**TDD。** 查证事实(spec「事实基线」+ 下述)为本任务地图。

## 先读(必读)

1. `docs/sydusx/products/yucai-client/release-r9-offline-continue/sprint-1/2026-09-03-offline-write-buffer/{spec.md,design.md}`(FR-1/1b/2 + ADR-1)
2. `lib/core/session_mode/session_mode_tracker.dart`(现状:单 bool isGuest)
3. `lib/auth/presentation/bloc/auth_bloc.dart:44-69`(**潜伏 bug:OfflineAuthenticated 设 isGuest=false → 全远端;注释宣称本地读**)
4. `lib/core/connectivity/connectivity_gateway.dart`(current + online 流)
5. 代表性 repo:`lib/transaction/data/transaction_repository_impl.dart`(全 8 个同构:account/transaction/tag/budget/debt/goal/holding/template 的 *_repository_impl,`_useLocal` + `_guard` + `_mirrored` 三件套)
6. `lib/core/network/auth_retry.dart`(只重试 401;unavailable 直抛)+ repo `_mapGrpcError`(unavailable→NetworkFailure)

## 交付物

### 1. DataRoute 三态(core/session_mode/)

- `enum DataRoute { guestLocal, boundRemote, boundOfflineLocal }`(中文 dartdoc:三态语义)。
- SessionModeTracker 扩展:持 isGuest(现字段)+ authOffline(bool,OfflineAuthenticated 时 true)+ online(bool,ConnectivityGateway 快照);`DataRoute resolveDataRoute()`:guest→guestLocal;bound+(!online || authOffline)→boundOfflineLocal;否则 boundRemote。**接线**:AuthBloc 的 onChange 置 isGuest/authOffline(修 bug:OfflineAuthenticated 置 authOffline=true);ConnectivityGateway.online 流订阅更新 online 快照(初值 current;插件失败乐观 true——现状语义)。tracker 自订阅还是外部推——实现定,注释理由(DI 生命周期注意 lazySingleton 时序)。

### 2. 8 repo 统一改造

- `_useLocal` getter 替换为 `_useLocalDs => route == guestLocal || route == boundOfflineLocal` 语义(命名自定,注释三态)。
- **写降级 helper**(core 共享,如 `core/session_mode/bound_write_fallback.dart` 或更合适处):`Future<Either<Failure,T>> writeWithFallback(Future<Either<Failure,T>> Function() remote, Future<Either<Failure,T>> Function() local)`——先 remote;**Right 直接返回;Left 且 failure 是 NetworkFailure → 走 local 返回**(注释:FR-1b 双保险,connectivity 误报兜底;其他失败不降级)。8 repo 的**写方法**(create/update/delete/record 等)在 boundRemote 时包此 helper;读方法不降级(bound-offline 由路由直接本地)。
- 每 repo 改造模式统一(照 transaction 范式),中文注释标注 F10/FR-1。

### 3. OfflineAuthenticated 修复

- auth_bloc:OfflineAuthenticated → authOffline=true(数据路由本地);**修注释与代码矛盾**;Authenticated → authOffline=false。注意 62-68 行镜像触发逻辑保持(仅 Authenticated)。
- 路由层/登录语义零改动(hasSession 不变)。

### 4. TDD 测试

- tracker 路由矩阵单测(guest/bound×online/offline×authOffline 六组合)。
- 写降级 helper 单测(Right 直返/NetworkFailure 降级/其他 Failure 不降级/双 Left)。
- 代表性 repo 单测 ×2 个模块(transaction+tag,照既有 repo 测试模式):boundRemote+NetworkFailure→落本地;guest 行为不变;boundOfflineLocal→本地。其余 6 repo 用同构轻测(路由分支各 1 条,mockito/mocktail 照库内惯例)。
- auth_bloc 单测:OfflineAuthenticated 事件→tracker 态断言(修 bug 的回归钉)。

## 验证(全部执行并贴证据)

1. 新单测绿(先红后绿)
2. `flutter test` 全量不回归(≥1277)
3. `flutter analyze` 新文件 0 条

## 约束

- **在线路径行为逐位不变**(guest 与 bound-online 在 connectivity=true 时输出与现状一致——既有测试即守门)。
- 本任务不动 schema/mirror/同步管线(T2/T3)。
- pending 标记本任务不做(降级写 local 的 pending 置位在 T2;本任务注释 TODO-F10T2 锚点)。
- 中文注释;不 commit。完成后报告。
