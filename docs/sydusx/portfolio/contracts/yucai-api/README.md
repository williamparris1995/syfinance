# Contract: yucai-api

> 跨产品契约:yucai-server **produces** / yucai-client **consumes**。
> 由 `/sydusx-portfolio` 建立(2026-08-05)。单 codebase monorepo,契约 = proto/gRPC API。

## 权威源(single source)

proto 定义在 [`yucai/proto/`](../../../../../yucai/proto/)(toolchain:Buf Go + `make gen-dart`)。本目录是**契约元数据**(producer/consumer/版本指针),**不复制 proto 内容**(one source of truth)。

- 当前版本:`v1`(见 [CURRENT](CURRENT))。
- gen stub:Go `yucai/server/` + Dart `yucai/client/`(proto 改后双端 regen)。

## Producer / Consumer

| 角色 | 产品 | 说明 |
|---|---|---|
| producer | [yucai-server](../../../products/yucai-server/) | 定义 + 实现 gRPC service;proto 改动经其 `sydusx-design` bump |
| consumer | [yucai-client](../../../products/yucai-client/) | `depends on yucai-api`;消费 gen Dart stub;浮于 CURRENT |

## Bump 规则

server 的 `sydusx-design` 在 proto 破坏性改动时:写新 `vN` + 移动 CURRENT + 扫描所有产品 `spec.md`/`design.md` 的 `depends on yucai-api` 通知 consumer(harness advisory)。当前 `proto/` 单版本未切片,待首次破坏性改动时建立 vN 目录。

## 变更记录

**2026-09-03(R10 F16,向后兼容)**:sync/v1 增强——GetSyncStatusRequest 加 `device_id`(空=租户聚合视角);ConflictDTO 加 `conflict_type`(值 `version_conflict`);PullChanges 落实 `page_size`(默认 500/上限 1000)+`has_more` 语义(按 version ASC 排序,续拉 since_version=页尾 change.version);PushChanges 对 UPDATE 型变更做版本比对冲突检测(落后版本跳过落库、记 conflicts、随响应返回;CREATE/DELETE 不检测)。server 恒 `device_id required`(单设备 client 'bound' 字面量→uuid.Nil 过渡容忍,F17 真实化)。**消费方 defer**:yucai-client F17 起消费 device_id/conflict_type/pull 分页。

- **2026-09-03(R9 F11,向后兼容)**:`sync/v1 PushChanges` 首次实装——payload bytes=各模块 domain JSON(backup envelope 行同构:PascalCase 键/int 枚举/RFC3339 时间戳),`entity_type`∈8 模块名(account/transaction/debt/budget/goal/holding/tag/template),CREATE/UPDATE=upsert 单设备语义(信任 client version),DELETE=硬删;批次原子(业务表+sync_log 同一事务,任一失败整体回滚);零 proto 改动。消费方 yucai-client F10 OfflineSyncPort 对接(T3)。
- **2026-08-29(R5 feature H,向后兼容)**:`PortfolioPerformanceResponse` 新增 `ReturnMetric`/`CagrScope` enum + optional 字段 `primary_return_metric=15` / `cagr_scope=16`(server 恒填 XIRR / CURRENT_HOLDINGS_COST_TO_MV)。纯新增 optional,旧 client 无感;**消费方 defer**:client 线收益本地化时随行 `gen-dart` regen 并消费(重命名/tooltip/头部指标切换)。
