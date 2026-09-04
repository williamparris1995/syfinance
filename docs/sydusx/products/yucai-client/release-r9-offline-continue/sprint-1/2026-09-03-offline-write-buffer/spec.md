# Spec — F10 离线写语义与缓冲

> R9 sprint-1 · 2026-09-03 · analysis 产出(写路径代码级查证 + 两决策经用户确认)。

## Goal

绑定态断网时完整记账走 R6 本地管道(零功能降级),未同步写可跟踪(pending),回网自动收集增量批次交同步通路;一并修复查证发现的 OfflineAuthenticated 路由潜伏 bug。

## 查证事实基线(设计输入)

- 写分叉:8 repo 同构 `_useLocal => tracker.isGuest` 单布尔,无第三态。
- 绑定态在线写=远端权威 + fire-and-forget 全量镜像刷新(delete-all+rebuild,**会抹掉未上行本地行**)。
- 绑定态断网写现状=NetworkFailure 直接失败,**数据丢失零排队**(仅 autoRecord 有回网重推导)。
- 8 头表有 version+updatedAt;无 dirty 列/游标/outbox;drift schemaVersion=2。
- UploadBackup 全量无幂等;**休眠 sync proto(lastSyncVersion/lastSyncAt)零使用**。
- **潜伏 bug**:OfflineAuthenticated 代码路由远端(auth_bloc.dart:54-56),与注释/commit 04c48910 宣称"本地读"不符——绑定+离线冷启动读写全失败。

## Requirements

- **FR-1 三态数据路由**:`SessionModeTracker` 扩展数据路由策略(guest 本地 / bound-online 远端 / **bound-offline 本地+pending**);8 repo 的 `_useLocal` 分叉统一改用策略;断网判定=ConnectivityGateway.online 流(插件失败乐观在线——远端失败兜底见 FR-1b)。
- **FR-1b 远端失败降级**:bound-online 态写远端遇 NetworkFailure(grpc unavailable)时**降级落本地并置 pending**(不只依赖 connectivity 探测,双保险);读侧 bound-offline 走本地镜像。
- **FR-2 OfflineAuthenticated 修复**:绑定+离线冷启动读走本地镜像、写走本地+pending(消除现状全红);修注释与代码矛盾。
- **FR-3 pending 跟踪**:drift schemaVersion 3 迁移,8 头表加同步状态列(语义:guest 行=无需上行;绑定后镜像行=synced;离线/降级写=pending;上行成功回 synced);**镜像刷新永不抹掉 pending 行**(协调语义钉死:refreshModule 对 pending 行跳过 delete/rebuild,或 rebuild 后回插——设计定形态)。
- **FR-4 离线删除墓碑**:离线删除若本地硬删,下次镜像 delete-all+rebuild 会**复活该行**(正确性缺陷);加轻量墓碑表(模块+实体 id+时间),上行时随批次传 server 删除,上行成功清除墓碑。
- **FR-5 回网同步管线**:`ConnectivityGateway.online` → 收集各模块 pending 行+墓碑 → 映射为增量 sync 批次 DTO → 经**同步 port 接口**上行(F11 落 RPC;F10 定义 port + 本地 fake 可测)→ 成功回写 synced/清墓碑;失败保留 pending 待下次触发;同步状态流(待同步计数/进行中/失败)对外暴露(供 F12 UI)。
- **FR-6 回归门**:guest 模式全链路不回归(make client-e2e/ui/test 全绿);离线续写单测+集成断言(断网写→pending→回网收集→fake 上行→synced→镜像刷新不抹)。

## NFR

- 离线写与 guest 同管道同语义(uuid/乐观锁/余额联动),零功能降级。
- schema 迁移向后兼容(既有 guest 库/绑定镜像库升级无损)。
- 同步 port 为跨模块抽象(F11 的 gRPC 实现可替换 fake),遵守依赖方向。

## Scope boundary

| 排除 | 理由 |
|---|---|
| 多设备冲突合并(server 端他源变更) | ticket 16;本 release 单设备语义(server 无其他写者) |
| 离线**实时行情**/收益引擎 | R6 语义不变(最后快照) |
| sync engine 全量(8 硬伤修复) | ticket 16 |
| 解绑(unbind)功能 | 不在本 feature(R6 亦无) |

## Grill record

| 决策 | 定案 |
|---|---|
| 回网补同步形态 | 用户选**增量 dirty 上传**(激活休眠 sync proto,新 RPC;为 ticket 16 铺路)——非控制器推荐(全量重传),用户取远期架构价值 |
| OfflineAuthenticated 路由 bug | 用户确认一并修(离线续写依赖:断网冷启动) |
| 离线删除 | 控制器推荐墓碑表(正确性必需:无墓碑则镜像刷新复活已删行);替代=断网禁删(功能洞),按推荐入 FR-4,**spec 确认时用户可推翻** |

## Feasibility

technical ✓(本地管道自足;sync proto 契约面现成;connectivity 触发有 autoRecord 先例);economic ✓(客户端改造集中 session/routing/mirror 协调/迁移;F11 承担 server 侧);operational ✓(回归门齐备)。
