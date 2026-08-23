---
feature: 2026-08-20-bound-mirror-logout
status: confirmed
---

# Spec — 绑定后镜像写穿透 + 登出回本地

> R6 sprint-3 feature H(依赖 G)。M2 决策落地:「绑/不绑是用户自由选择」的完全体。
> 事实基础:双源 seam 中绑定态走远端;G 上传后本地保留导出时点数据;登出→Guest→seam 自动切本地——**镜像机制是唯一缺口**。远端写返回值不含完整副作用(debt 排期/holding FIFO/budget items 生成在 server),逐调用点写穿透抓不全 → 本 spec 采用**模块级刷新镜像**。

## ADDED Requirements

### Requirement: FR-1 绑定态写后镜像(模块级刷新)
- [ ] 绑定态下,任一模块的写操作成功后,该模块的本地 drift 镜像 SHALL 被刷新(远端最新数据整表替换本地):刷新为 fire-and-forget(不阻塞写路径返回),失败静默记录(下次写再试);刷新覆盖该模块全部关联表(budget 含 items[per-budget detail]/debt 含 schedule[per-debt detail]/holding 含 transactions+securities;goal 含 links)。**首次登录后(已有数据的账号)SHALL 全模块刷新一次**(登入即镜像,不等首次写)。

#### Scenario: 绑定态记账后本地同步
- GIVEN Authenticated,镜像在位
- WHEN 远端 recordExpense 成功
- THEN 稍后本地 drift 的 transactions/accounts 表含该笔(含余额联动效果)

#### Scenario: 登入即镜像
- GIVEN 账号已有服务端数据,本地 drift 为空/旧
- WHEN 登录成功(Authenticated)
- THEN 全模块镜像刷新(登出后立刻可用,无需先做一次写)

### Requirement: FR-2 登出回本地(最后镜像)
- [ ] 登出 SHALL 使 app 回到 Guest 模式(B 已实现)且本地数据可用:业务页面读到的数据 = 最后镜像(**登出前在线写过的数据都在**);离线登出同样可用(镜像已在本地,登出零网络)。登出时若在线 SHALL best-effort 全模块终刷(抓住漏网刷新);离线则直接用现有镜像。

#### Scenario: 绑定期间记账→登出→数据可见(成功判据③完全体)
- GIVEN Authenticated,远端记 3 笔账(镜像已刷新)
- WHEN 登出(断网状态)
- THEN Guest 模式下列表含这 3 笔,零网络

### Requirement: FR-3 再登录幂等
- [ ] 已绑定过(上传或镜像在位)的设备再登录 SHALL **不触发绑定向导**(G 的进程级 one-shot 闸不够——重启即失效,且 guard 会误报「账号已有数据」blocked):绑定完成时 SHALL 持久化本地标记(secure storage `bound_tenant`);登录成功时标记存在且账号非空 → 跳过向导直接在线。

#### Scenario: 绑定→登出→重启 app→再登录
- GIVEN 曾绑定(标记已持久化),重启 app 后登录同一账号
- THEN 不出现绑定向导,直接进入在线模式

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;分层不倒置;镜像刷新不阻塞写路径(写返回时延无可测退化)。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server;`go test ./...` 保持全绿。

## scope boundary

- **IN**:模块级刷新镜像服务(8 模块+reference securities)/登出终刷+离线登出/再登录标记/G one-shot 闸升级为持久标记。
- **OUT**:绑定态离线续写(outbox,ticket 16)/镜像的读路径使用(绑定态仍读远端;镜像仅供登出后——M1 维持)/冲突解决(单向拉取无冲突)/镜像失败的用户可见提示(静默重试,accepted)。
- **依赖**:G(绑定完成点/向导触发点)/D/E(全部 local ds 与 DAO——镜像的写入面)。

## 可行性

- **technical**:可行——刷新=现有 repo list(绑定态自动远端)+整表替换 DAO +实体→行 mapper(8 个,与 D/E 逆向)。
- **economic**:可行——代码集中一个服务+8 mapper,复制面小。
- **operational**:可行——个人数据量小,N+1 detail 拉取(budget/debt)毫秒级;fire-and-forget 无 UX 影响。
