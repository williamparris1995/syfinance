# Code Plan — F10 离线写语义与缓冲

> execute 分解。约束:TDD;回归门全绿;在线路径行为逐位不变。

## Tasks

- [ ] **T1 三态路由+降级+OfflineAuthenticated 修复**:DataRoute/tracker 扩展/8 repo 统一改造+共享写降级 helper/auth_bloc 修复。验证:单测(路由矩阵/降级/其他失败不降级)+全量不回归。
- [ ] **T2 schema v3+pending+镜像协调**:syncState 列+墓碑表+迁移;local DS route 感知置 pending/写墓碑;bound_mirror pending 保护。验证:单测(标记/保护/迁移兼容)+在线路径逐位不变断言。
- [ ] **T3 同步管线**:OfflineSyncPort+SyncBatch+SyncCoordinator(状态流)+Connectivity 接线+fake。验证:单测+集成断言(断网写→pending→fake 上行→synced→mirror 不抹)。
- [ ] **T4 全量回归门**:flutter test/analyze/make client-e2e(在线 guest 全链路不回归)+提交。

## 执行方式

T1→T2→T3→T4 串行派发,每任务两轴 review,修复循环 ≤5。
