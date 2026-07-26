# 01 · 跨租户数据隔离与授权(IDOR + 防御纵深)

Type: grilling
Status: resolved
Blocked by: —

## Question

审计确认 1 处 P0 跨租户读 IDOR + 多处授权防御纵深缺口(详见 `findings.md` S1/S5/S7/S11/D9):

- **[S1 P0]** `GetHoldingPerformance` 链:`holding_handler.go:322-346` 丢弃 tenantID,`holding_repo.go:67-78` `FindByID` 无 tenant 过滤(注释自承 "caller's responsibility" 但无 caller 过滤)→ 任意认证用户传他人 `holding_id` 即可读其收益/成本/价格曲线。
- **[S5 P1]** `RecordTransaction` 不校验 entries.account_id 归属 → cross-tenant entry 落库,经 `SumEntryTotalsByAccount`(`transaction_repo.go:890-914` 无 tenant_id 过滤)污染受害者 budget actuals。
- **[S7 P1]** 全局 securities 写操作(CreateSecurity/UpdateSecurityPrice/SyncPrices/BackfillPriceHistory)无 admin/role 控制 → 任何用户可改任意 security 价格污染所有租户市值/收益。
- **[S11 P1]** `Holding.SaveOrUpdate/FindByAccountAndSecurity` 查重缺 tenantID 过滤(防御纵深)。
- **[D9 P1]** 4 子表(TransactionEntry/BudgetItem/PaymentSchedule/TransactionTag)无 tenant_id 列,隔离纯靠 parent join。

**决策点:**
1. S1 IDOR 立即修(tenantID 透传 FindByID + `holding.TenantID(tenantID)` 过滤,照 `GetPortfolioPerformance` 范式 + 跨租户拒绝测试)?
2. 授权防御纵深做到哪层:仅补 handler/service ownership 校验,还是同时反规范化子表 tenant_id + DB 级兜底?
3. securities 全局写操作:限运维 CLI / 加 role claim / 维护模式?
4. 是否建立一套**跨租户拒绝矩阵**端到端测试(每个 RPC × 他人资源 → PermissionDenied)作为授权回归门?

## Answer(resolved 2026-07-26)

grilling 决策(4 点):

1. **S1 IDOR 修复(无分歧,直接做)**:`GetHoldingPerformance` handler 透传 tenantID → service 签名加 tenantID → `HoldingRepo.FindByID` 加 `holding.TenantID(tenantID)` 过滤。照 `GetPortfolioPerformance` 范式。补跨租户拒绝测试(用户 A 传用户 B holding_id → PermissionDenied)。同步排查 `holdingXIRR/holdingTWR/holdingCAGR/tradesForHolding/aggregateRealizedForSecurity` 全链 tenant 透传。

2. **防御纵深 = 应用层 + repo 层**(不反规范化子表 schema):
   - handler/service 层:每个 ownership-sensitive RPC 校验 caller 对资源 ownership(补 Holding/securities/entries 漏点)。
   - repo 层:所有 query 强制 `tenant_id` Where(含 `SumEntryTotalsByAccount` 补 tenant 过滤)。
   - 子表(TransactionEntry/BudgetItem/PaymentSchedule/TransactionTag)保持靠 parent join —— DB 级约束(FK/CHECK/反规范化 tenant_id)归 **05**。

3. **securities 全局写 = admin role claim**:JWT 加 `role` claim,`CreateSecurity`/`UpdateSecurityPrice`/`SyncPrices`/`BackfillPriceHistory` 校验 `role=admin`。admin 来源:`first-user-is-admin`(JIT provisioning 创建 tenant 的首个 user 标记 admin;可叠加环境变量指定 admin subject)。读操作保持全员可用。完整 role 模型在 **14** 落地后复用此 claim。

4. **授权测试 = 全量拒绝矩阵**:建授权测试框架,覆盖所有 ownership-sensitive RPC(Get/Update/Delete/Transfer × 他人 tenant 资源 → 断言 PermissionDenied),接入 CI 作回归门。参照 holding e2e 套件范式。

**实施范围与协同**:
- S5 entries 归属校验(RecordTransaction/UpdateTransaction 在 Save 前对每 entry 跑 `accountRepo.FindByID(tenantID, accountID)`,NotFound 即 InvalidArgument)纳入本 ticket。
- admin role 的 JIT provisioning 标记与 **S10**(JIT 非事务)协同 —— 标记 admin 时一并纳入事务(依赖 **03**)。
- 子表 tenant_id 反规范化 + DB FK/CHECK 留 **05**。
- IDOR 修法作为独立 hotfix,不阻塞其他 ticket。

## Implementation(2026-07-26)

4 commits 本地 main(未 push),分阶段独立提交:
- `fdf39ee` 阶段 1 — IDOR:GetHoldingPerformance 全链透传 tenantID + `FindByID` tenant 谓词 + `SaveOrUpdate` 加固 + `TestGetHoldingPerformance_RejectsCrossTenant`
- `50a14f8` 阶段 2 — entries 归属校验(Record/Update)+ `SumEntryTotalsByAccount` tenant 过滤 + budget `EntryTotalsFunc` port 透传 + wire 闭包;修了 `TestSimpleTransfer` 被 lazy fixture 掩盖的真 bug
- `06972cf` 阶段 3 — `is_admin` bool(ent regen)+ first-user-is-admin JIT + JWT claim + `RequireAdmin` interceptor(fail-closed)+ wire 拦截器链 Logging→Auth→RequireAdmin
- `642897d` 阶段 4 — 全量授权拒绝矩阵(bufconn,14 子测试:跨租户 IDOR / securities 写 × admin / fail-closed 旧 token / 无 token / 非 guarded 不误伤)

全测试绿(59 包),`go vet` 干净。验证:跨租户 holding 访问→NotFound、securities 写非 admin→PermissionDenied、旧 token fail-closed。proto UserDTO 加 `is_admin`(client UI 暴露)留 follow-up。
