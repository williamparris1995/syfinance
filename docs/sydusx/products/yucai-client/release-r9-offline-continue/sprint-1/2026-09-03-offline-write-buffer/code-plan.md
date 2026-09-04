# Code Plan — F10 离线写语义与缓冲

> execute 分解。约束:TDD;回归门全绿;在线路径行为逐位不变。

## Tasks

- [x] **T1 三态路由+降级+OfflineAuthenticated 修复**:DataRoute/tracker 扩展/8 repo 统一改造+共享写降级 helper/auth_bloc 修复。验证:单测(路由矩阵/降级/其他失败不降级)+全量不回归。
- [x] **T2 schema v3+pending+镜像协调**:syncState 列+墓碑表+迁移;local DS route 感知置 pending/写墓碑;bound_mirror pending 保护。验证:单测(标记/保护/迁移兼容)+在线路径逐位不变断言。
- [x] **T3 同步管线**:OfflineSyncPort+SyncBatch+SyncCoordinator(状态流)+Connectivity 接线+fake。验证:单测+集成断言(断网写→pending→fake 上行→synced→mirror 不抹)。
- [x] **T4 全量回归门**:flutter test/analyze/make client-e2e(在线 guest 全链路不回归)+提交。

## 执行方式

T1→T2→T3→T4 串行派发,每任务两轴 review,修复循环 ≤5。


## Ledger 记账

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 三态路由 | ✅ | 1(3 派生读源补三态+2 NIT) | OfflineAuthenticated 潜伏 bug 修复;debt/budget/goal 补 _mapGrpcError(否则降级永不触发) |
| T2 schema v3+镜像 | ✅ | 1(holding 证券/台账 rebuild PK 冲突→upsert,reviewer 实证复现) | 复合写头行 pending 齐(还款=交易+债务双 pending);迁移 v2→3 无损 |
| T3 同步管线 | ✅ | 1(markXSynced 版本守卫防在途更新误标) | noop port 恒失败防未上行被标 synced;集成断言 5 步闭环 |
| T4 全量门 | ✅ | 1(ui_collect 测试修:tap 前滚入) | **F9 暴露的漏网**:F9 债权页加 DebtSearchSortBar 推卡片出首屏,而 F9 门只单跑新 UI 文件未跑全量——ui_collect tap 落空;修 ensureVisible+全量 UI 门 12 文件绿 |

## 教训(promote 候选)

- **UI 门必须全量跑**:F9 收官只单跑新增 UI 文件(client-e2e-ui F=),漏掉 DebtSearchSortBar 对既有 ui_collect 的布局冲击。此后任何触碰 UI 的 feature 收官门 = `make client-e2e-ui` 全量(或至少声明受影响文件清单)。候选 PROMOTE 进 ai-harness 提示。
