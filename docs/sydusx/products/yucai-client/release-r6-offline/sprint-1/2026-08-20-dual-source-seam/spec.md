---
feature: 2026-08-20-dual-source-seam
status: confirmed
---

# Spec — repository 双源 seam + account 模块试点

> R6 sprint-1 feature C(sprint-1 收口;依赖 A✓ drift/AccountDao + B✓ Guest 态)。G2(seam 在哪层)是本 feature 的 design 级决策——本 spec 定**行为**,ADR 落 design.md。
> 现状:`AccountRepositoryImpl` 是 remote ds 上的 thin `_guard`;domain `AccountRepository` port 5 方法(list/create/delete/getById/update);5 usecases → bloc → pages。

## ADDED Requirements

### Requirement: FR-1 数据源按会话模式路由
- [ ] account repository 的每次调用 SHALL 按当前会话模式选择数据源:**Guest → 本地 drift**;其余会话态(Authenticated/OfflineAuthenticated 等)→ 现有远端 gRPC 路径(含 401-refresh-retry,原样)。会话中切换(登录/登出)后,后续新调用按新态生效。

#### Scenario: 游客列表读本地
- GIVEN app 处于 Guest,本地库有一行账户
- WHEN 调用 list()
- THEN 返回本地行的映射实体,零网络调用

#### Scenario: 绑定用户列表走远端(零回归)
- GIVEN app 处于 Authenticated
- WHEN 调用 list()
- THEN 走现有 remote ds gRPC 路径,行为与本 feature 之前完全一致

#### Scenario: 登出后新调用切本地
- GIVEN Authenticated 下调用走远端;用户登出(Guest)
- WHEN 再次调用 list()
- THEN 读本地(不发起 gRPC)

### Requirement: FR-2 游客 account 全链路 CRUD
- [ ] Guest 态下 account 的 list/create/getById/update/delete SHALL 全部对本地 drift 生效:新建行由 client 生成 UUID(ADR-1 ID 策略),version 初始 1,时间戳取本地时钟,currentBalance 初始 = initialBalance,status 初始 active;update 为 patch 语义(仅变更提供的字段,version +1);**删除前校验余额非零拒绝**(与远端「non-zero balance」行为对齐)。

#### Scenario: 断网全新记账(成功判据①首块拼图)
- GIVEN Guest,无网络
- WHEN 创建账户(name=现金,initialBalance=10000)→ 列表 → 详情 → 改名 → 再列表
- THEN 全链路成功:列表含该行(余额 10000),详情为改名后值,全程零网络依赖

#### Scenario: 余额非零不可删
- GIVEN Guest 本地账户 currentBalanceCents = 5000
- WHEN delete(id)
- THEN 返回与远端同语义的失败(余额非零),行仍在

#### Scenario: patch 更新与版本递增
- GIVEN Guest 本地账户 version=1
- WHEN update(仅改 name)
- THEN 仅 name 变化,version=2,其余字段原值

### Requirement: FR-3 绑定路径零回归
- [ ] 非 Guest 会话态下,account 全部操作 SHALL 与本 feature 之前的实现行为一致(远端路径、错误映射、乐观锁语义);本 feature SHALL NOT 改动 domain `AccountRepository` 接口签名与 `AccountRemoteDataSource`。

### Requirement: FR-4 bloc/presentation 无感
- [ ] account 的 bloc/usecases/pages SHALL 零改动(现有 account 测试不修改仍全绿);数据源切换对上层完全透明。

### Requirement: FR-5 seam 范式文档化
- [ ] design.md SHALL 落「模块接入双源」的接线步骤清单(供 sprint-2 各模块机械复制):需要新建什么、改哪里、测什么。

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;分层不倒置(data 层不 import presentation 层——会话态读取经注入抽象,design 定形态)。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server;`go test ./...` 保持全绿。

## scope boundary

- **IN**:account 模块双源 + seam 范式定型 + 游客全链路(含 UUID 生成/默认值/patch 语义/余额删除校验)+ 范式文档。
- **OUT**:其余模块双源(sprint-2 按范式复制)/绑定后镜像写穿透(H)/OfflineAuthenticated 的本地降级读(远端失败即现状错误条,H 镜像后再评估)/绑定上传(G)/引用数据 seed 机制(open question,游客 currency 下拉等场景由现有 CurrencySettings 本地默认兜底,首连拉取 defer)。
- **已知张力(accepted)**:OfflineAuthenticated(离线已绑定)读远端必失败 → 错误条;镜像(H)落地前不改善。
- **依赖**:A(drift + AccountDao)、B(Guest 态)均已 merged。

## 可行性

- **technical**:可行——remote_ds 已是既有 seam 形态,镜像加一路 local ds + repo 内路由是同构扩展;实体映射(drift 行 ↔ domain 实体)是主要工作量。
- **economic**:可行——单模块试点定型,sprint-2 复制摊薄。
- **operational**:可行——纯 client,游客态零网络面。
