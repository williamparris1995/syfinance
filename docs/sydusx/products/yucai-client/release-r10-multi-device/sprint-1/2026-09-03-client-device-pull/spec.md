# Spec — F17 client 设备身份与拉取

> R10 sprint-1 · 2026-09-03 · analysis 产出(client 侧查证;顶层"多设备"为用户 R10 确认)。

## 查证事实基线

- 设备身份现成:`TokenStorage.clientId`(uuid v4 安装级,SecureStorage `yucai.client_id`,启动生成)——且经 `x-client-id` metadata 已随每 RPC 上送;BoundMarker 'bound' 字面量为 deviceId 现值(F16 过渡容忍)。
- Dart stub 落后 proto 2 字段(GetSyncStatusRequest.device_id / ConflictDTO.conflict_type)——**gen-dart 前置**(protoc_plugin 实测未装,需 activate;AGENTS.md:10 声明失实)。
- PullChanges client 零实现;增量应用底料=archive_importer(envelope 行→drift 写入,PullChanges payload 同构);mirror 全量路径成熟(pending 保护)。
- 拉取触发点已有挂点:回网边沿/push 成功后/手动重试/构造补扫;无轮询。
- 孤儿台账:合成头行已上行可拉,但**台账行本身不出 origin 设备**(collector 不收/server 无 holding_ledger writer)——第二设备拉到 qty=0 空头行。
- conflicts 响应 client 完全丢弃(port 连 PushResponse 都不接)。

## Requirements

- **FR-1 gen-dart 前置**:`dart pub global activate protoc_plugin` → `make gen-dart` → diff 面恰为 2 message(验证)+ AGENTS.md 声明修正。
- **FR-2 设备身份真实化**:`GrpcOfflineSyncPort._deviceId()` 改用 `TokenStorage.clientId`(构造注入);**绑定流程 RegisterDevice**(`binding_bloc` 上传成功后调,幂等——server 传非 Nil id 即幂等);'bound' 字面量与 `markBound('bound')` 语义收敛(tenant 标记与设备身份分离——BoundMarker 保持绑定标记职责,deviceId 独立取 clientId;注释钉死);push payload 的 deviceId=clientId。
- **FR-3 PullChanges 消费**:新 `PullApplier`(binding/data)——payload(envelope 行)→ drift upsert / DELETE→本地硬删+**墓碑**(与上行对称),**pending 行保护**(本地 pending 不被下行覆盖——照 mirror ADR-3 语义);cursor=server 设备行 last_sync_version(server 维护)或本地存(设计定,推荐 server 设备行[pull 请求带 since=上次响应 latest,幂等重拉无害]);触发:push 成功后 + 回网时(push 前拉)——各一次,分页循环拉尽(has_more);应用后窄幅镜像刷新不需要(增量已是终态;但**冲突跳过的变更不在 log**——本地拉到的是 server 现行,一致)。
- **FR-4 孤儿台账闭环**:server 注册 `holding_ledger` writer(台账行 payload,envelope `holdingTxnRowToEnvelope` 形态;upsert=按 id 插/替,delete 同);client collector 收 pending 头行**关联的台账行**(同一 (account,security) pair 的离线台账随头行上行——查证口径:recordDividend 同事务产物;server CurrentState for ledger=按 id find);pull 侧 applier 支持台账行应用(第二设备补齐分红记录);F10 T3 的"已知缺口"注释更新为闭环。
- **FR-5 conflicts 最小消费**:port 接 PushResponse——conflicts 非空时 SyncResult 扩展携带 count+详情(F18 做解决流);协调器状态扩展(conflicted 态或 failureReason 附信息——设计定最小面);F12 badge 显示"冲突 N 待处理"(点击→F18 UI 立占位)。
- **FR-6 测试与门**:port/applier/collector 单测;e2e fake 补 RegisterDevice/PullChanges 实现+bridge 注册——**双设备模拟场景**(设备 A push→fake server 落库→设备 B[第二 client 实例或同进程第二 DB]pull→数据一致);F10-F13/F16 全部门零回归。

## NFR

单设备语义零回归('bound' 退役后 Nil 过渡删除——client 全量换 clientId,server 兼容任何 uuid);pending/墓碑保护下行同样成立;中文注释(client 侧)。

## Scope boundary

| 排除 | 理由 |
|---|---|
| 冲突解决 UI/ResolveConflict 调用 | F18 |
| 轮询/定时拉取 | 触发点驱动够用,YAGNI |
| 第二设备登录初始拉取优化(mirror 全量已是) | 已覆盖 |
| GetSyncStatus client 消费 | F18(冲突面板需要时) |

## Grill record

| 决策 | 定案 |
|---|---|
| 设备身份源 | clientId 复用(现成+已在 wire)——技术推荐,零争议 |
| 拉取应用路径 | 增量 applier(底料=archive_importer 同构)——技术推荐 |
| cursor 归属 | server 设备行(server 已维护,幂等重拉无害)——技术推荐 |

## Feasibility

technical ✓(查证:身份/底料/触发点/测试 harness 全现成);economic ✓;operational ✓(fake e2e 可模拟双设备)。
