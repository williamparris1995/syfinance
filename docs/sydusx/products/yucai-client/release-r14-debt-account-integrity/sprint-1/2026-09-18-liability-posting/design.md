# Design: F36 负债记账治本·方案 A

prototype: none （纯记账语义/迁移/server,零 UI 面变化;hero 展示语义已在 F35 热修落地）

## Context

spec（[./spec.md](./spec.md)）已确认(用户 2026-09-19「按推荐」拍板 3 决策点)。侦察结论:增量记账语义已自洽(创建贷 P[有到账]/还款借 T/标记已还借 T 贷权益),缺口=①创建无到账账户不入账 ②改总额无调整 ③删除零分录 ④存量同步债无历史分录 ⑤server 借入创建不入账。既有设施:`_ensureSettlementAccount`(权益户「历史还款结转」幂等兜底,WIP)、server 事务管道(service.go AccountLookup port + WithTx,还款入账已存在)、repairs.dart 修复例程先例。

## Goals / NonGoals

**Goals**:不变式「负债账户余额 = −Σ名下借入债 remaining」在任意操作序列+存量数据上成立;client/server 双侧分录补齐;存量 repair 幂等迁移。
**NonGoals**:borrowedOut 对称改造(后续小票)、利息拆分科目化(ADR-2)、hero 展示层(F35 热修已做)、server 存量独立重算(经调整分录同步收敛)。

## Decisions(ADR)

- **ADR-1 删除=终止清账**:删除时若剩余>0,借 负债 −剩余 / 贷 权益;历史现金流分录不动。
  *Rationale*:钱真实收付过,冲回会凭空改资产;清账把「负债消失」入权益是期初调整惯例。*Alternatives*:全冲回(用户否决——资产回退与删除语义纠缠)。
- **ADR-2 利息不拆分**:期次全额 T(本金+利息)冲减负债/剩余,与 server 及全部既有数字口径一致。*Alternatives*:利息拆支出科目(改剩余语义+新科目+全量重述,否决)。**推论**:不变式中的「剩余」= total − ΣpaidCents(含息),与现行 `remainingPrincipalCents` 定义相同,零口径迁移。
- **ADR-3 存量修复=权益户一次性调整**:以账户为单位 delta=target−current 单笔调整分录(对方=「历史还款结转」),app_meta 标记幂等,不伪造历史流水。*Alternatives*:逐笔回填历史分录(伪造数据,否决)。
- **ADR-4 创建无到账账户**:借 权益 +P / 贷 负债 +P(债「从历史而来」语义);有到账维持现行为。server 同规则(source_account_id 空 → 权益)。
- **ADR-5 改总额调整**:update 中 totalPrincipalCents 变化 Δ≠0 → 同事务 负债 ±Δ / 权益 ∓Δ(Δ=新−旧);server 同。schedule 重生成路径不改(frozen/重排语义照旧)。
- **ADR-6 幂等与触发**:repair 以 app_meta 键 `f36_liability_balance_repair_v1` + 调整分录固定描述前缀「F36 余额修复」;挂启动 repair 管道(repairs.dart 惯例),先于首屏数据读取执行一次。
- **ADR-7 server 创建/改额/删除入账**:复用 service.go 既有事务管道与 AccountLookup;借入创建有 source_account_id → 借 资产+P/贷 负债+P(与客户端镜像),无 → 权益;改额/删除同 ADR-5/1。多设备下客户端 repair 调整分录经 sync 上行,server 余额自然收敛(不重复修复)。

## HLD

```
client: debt_local_ds{create✓/update+调整/delete+清账/无到账→权益}
        repairs.dart: f36Repair(db, txns) — app_meta 幂等,启动管道触发
server: debt/application/service.go{create 入账/update Δ调整/delete 清账}
        (既有 AccountLookup + WithTx 管道)
sync:   调整/清账分录=普通交易,markPending 语义随操作既有路由
```

## LLD(关键规则)

- **清账金额**:delete 时 remaining = totalPrincipal − Σentry.paidCents(与 _toEntity 同式);remaining=0(已还清)删除 → 无分录。
- **调整金额**:update ΔP = newTotal − oldTotal;ΔP>0 → 贷 负债 ΔP/借 权益;ΔP<0 → 借 负债 |ΔP|/贷 权益。仅当 ΔP≠0。
- **repair**:对每个 liability 账户(含 cat=7/9 且有借入债者):target=−Σremaining;delta=target−balance;|delta|>0 → 借(delta<0)负债 |delta|/贷 权益 或 贷(delta>0)负债 delta/借 权益。borrowedOut 应收账户本票不动。
- **不变式测试矩阵**:创建(有/无到账)→还款→标记已还→改额±→删除→混合序列;每步断言 balance == −Σremaining。

## Risks / Trade-offs

- 存量 repair 在绑定设备先跑会把调整分录置 pending 上行,server 端若同账本已正确会重复入账 → 调整分录描述前缀固定 + server 端不实现补偿(概率极低;多设备同库场景首版接受,ledger 记录)。
- update 改额与 schedule 重生成同事务,失败回滚需同 WithTx(client 已同 _database.transaction)。
- 权益户复用「历史还款结转」一名,报表上归集所有期初调整 —— 语义可接受(会计惯例)。

## Migration Plan

repair 例程(ADR-6)随新版首次启动执行一次;dev 库手工触发验证 5 户 target=−剩余;回滚=无(调整分录为真实账务,不做反向)。

## Open Questions

无(三决策点已拍板;server 侧实现细节随 T3 集成测试钉)。
