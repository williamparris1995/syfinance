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

**2026-09-06(R10 F17-T2,向后兼容)**:PushChanges `entity_type` 第 9 值 `holding_ledger` 上 wire——持仓台账行(append-only trade ledger;payload=envelope 台账行同构:PascalCase 键、`TradeType` int 枚举 buy=1/sell=2/dividend=3/split=4、无 Version/TenantID 键)。server 注册第 9 个 writer(entitywriter/holding_ledger.go,台账查证裁决=实施:ent HoldingTransaction 表+Service 直接 RPC 写入路径现成);upsert 按 id 幂等重推、tenant 注入覆盖;**客户端恒 CREATE**(台账无乐观版本,server 对 CREATE 不做冲突检测;CurrentState 恒 v1 保接口完备);上行口径:台账行随 pending 持仓头行批次整批上行(同 (account,security) pair 全收,server 按 id 幂等吸收重收)。PullChanges **消费方落地**(yucai-client F17-T2):游标本地区语义(drift `sync_cursors` 单行,since=页尾 change.version 分页续拉[F16 既有 wire 契约],自设备回声 client 侧过滤不回灌);下行 DELETE 本地硬删不写墓碑(源头即 server log,回声乒乓论证见 client pull_applier.dart 类 doc)。零 proto 改动。

**2026-09-06(R10 F17,向后兼容)**:sync/v1 RegisterDeviceRequest 加 `device_id = 2`(空串=legacy server-generated;非空=幂等键,重注册返回既有行含 last_sync_version;畸形=InvalidArgument)。client push 侧 deviceId 从 'bound' 字面量迁移为安装级 clientId(TokenStorage 'yucai.client_id'),server 对 'bound' 的 Nil 容忍保留至旧客户端退役。holding/v1 client stub 同步补齐 R5-H 遗留(ReturnMetric/CagrScope/字段 15-16,server 侧自 cd3677c7 已有)。

**2026-09-03(R10 F16,向后兼容)**:sync/v1 增强——GetSyncStatusRequest 加 `device_id`(空=租户聚合视角);ConflictDTO 加 `conflict_type`(值 `version_conflict`);PullChanges 落实 `page_size`(默认 500/上限 1000)+`has_more` 语义(按 version ASC 排序,续拉 since_version=页尾 change.version);PushChanges 对 UPDATE 型变更做版本比对冲突检测(落后版本跳过落库、记 conflicts、随响应返回;CREATE/DELETE 不检测)。server 恒 `device_id required`(单设备 client 'bound' 字面量→uuid.Nil 过渡容忍,F17 真实化)。**消费方 defer**:yucai-client F17 起消费 device_id/conflict_type/pull 分页。

- **2026-09-03(R9 F11,向后兼容)**:`sync/v1 PushChanges` 首次实装——payload bytes=各模块 domain JSON(backup envelope 行同构:PascalCase 键/int 枚举/RFC3339 时间戳),`entity_type`∈8 模块名(account/transaction/debt/budget/goal/holding/tag/template),CREATE/UPDATE=upsert 单设备语义(信任 client version),DELETE=硬删;批次原子(业务表+sync_log 同一事务,任一失败整体回滚);零 proto 改动。消费方 yucai-client F10 OfflineSyncPort 对接(T3)。
- **2026-08-29(R5 feature H,向后兼容)**:`PortfolioPerformanceResponse` 新增 `ReturnMetric`/`CagrScope` enum + optional 字段 `primary_return_metric=15` / `cagr_scope=16`(server 恒填 XIRR / CURRENT_HOLDINGS_COST_TO_MV)。纯新增 optional,旧 client 无感;**消费方 defer**:client 线收益本地化时随行 `gen-dart` regen 并消费(重命名/tooltip/头部指标切换)。
