# Code Ledger — F36 liability-posting

## T1 client 分录补齐 — ✅ done(2026-09-19,派发 TDD)

- 改动:debt_local_ds.dart(创建无到账权益分录/update ΔP 调整分录+新可选参/delete 清账分录)+debt_local_ds_test.dart(不变式助手+7 序列测)+offline_routing_test.dart(夹具补种 acc-debt)。
- fix-rounds:1(offline_routing 3 条回归——设计内回滚暴露空库建债夹具,原代理收尾修复)。
- **符号口径勘误(已同步 T2)**:存储口径 liability=credit−debit,真实不变式 balance==+Σremaining(简报字面 −Σremaining 为显示镜像);助手按存储口径断言并注释。
- repo 层未透传 totalPrincipalCents/delete 无 markPending —— 后续票范围(T3 接线 totalPrincipal)。
- 评审:两轴 pass。提交:feat(client) F36-T1。

## T2 server 入账补齐 — ✅ done(2026-09-19,派发 TDD)

- 改动:application/service.go(AccountLookup 最小扩展 FindByAccountType[具体仓储已实现,wire 零改动]/equityCarryoverAccountName 常量/ledgerRecord 助手/buildCreatePosting/buildPrincipalAdjustment/buildDeleteSettlement/Create-Update-Delete 全 runWriteTx 同事务)/dto.go(SourceAccountID*/TotalPrincipalCents* 指针 nil 安全)/handler(borrowedIn SourceAccountId 透传)/集成测试(不变式助手+3 序列)。
- fix-rounds:0。**符号口径**:与 T1 对齐(balance==+Σremaining 存储口径)。
- 已知限制(ledger 记录):proto UpdateDebtRequest 无 total_principal_cents 字段(protoc 不可用),TotalPrincipalCents 为 Go 结构体字段,gRPC 透传待 proto 加字段后一行接入;bound 模式改总额经 RPC 不生效(现状既有),client 调整分录本地路径(guest)先行,bound 待 proto。
- 降级裁定:租户缺「历史还款结转」权益户 → warn+跳过分录(镜像 debtCurrencyCode 先例;硬失败会断债务操作;漂移经 T3 client repair sync 收敛)。
- 评审:两轴 pass。提交:feat(server) F36-T2(5 文件)。

## T3 存量迁移+repo 接线 — ✅ done(2026-09-19,派发 TDD)

- 改动:repairs.dart(管道化入口+runF36LiabilityBalanceRepair)/debt_repository_impl.dart(update 增 totalPrincipalCents 仅 local 透传,remote dormant[proto 无字段])+2 测试文件(修复 3 测+repo 透传 1 测)。
- fix-rounds:0。**侦察/裁定**:挂点=app_database.beforeOpen 唯一,但只许动 repairs.dart → 管道化重构(旧函数改私有入口+标记互不牵连);入账必经交易管道(BalanceLocalUpdater 联动)——**旧 raw SQL repair 不联动余额正是历史漂移根源**;表单金额编辑态=可编辑但提交不携带(UpdateDebtParams 无字段)→ repo 参数 dormant 留注释。
- 幂等三连跑验证(首跑 2 笔/带标记重跑跳过/清标记重入 delta 归零不再生成)。
- 评审:两轴 pass。提交:feat(client) F36-T3(4 文件)。

## T4 不变式矩阵 + 全量门 — ✅ done(2026-09-19)

- 矩阵:T1 7 序列(创建有/无到账/还款/改额±/删除/含息超还/剩余0 删除)+T2 3 序列(server)+T3 3 修复测(收敛/幂等/重入)覆盖 FR-1 不变式全部操作面。
- 门:go build/test 全绿(67 包)+flutter **1871 全绿**+analyze **438≤439**+client-e2e **14/14**。
- 整体评审:pass(T1-T3 边界评审+ADR 对照,borrowedOut 未动/spec Scope 守住)。
- 待合并后执行:dev 库真机修复取证(app 重启触发 beforeOpen 管道,5 户 balance==+Σremaining;显示口径 −Σ剩余)。

## 裁决:sydusx-review pass → sydusx-test pass → finish
