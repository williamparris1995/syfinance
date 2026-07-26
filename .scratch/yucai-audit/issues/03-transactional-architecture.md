# 03 · 事务一致性架构(根因:整个 server 仅 1 处真事务)

Type: grilling
Status: resolved
Blocked by: —

## Question

架构根因:整个 server 仅 1 处手写 ent Tx(`budget_repo.go:172-225`),跨模块 write port 签名只接 ctx 无 tx 传播通道。所有跨模块财务写都是 best-effort swallow,部分失败即静默财务漂移(详见 `findings.md` D7 + D1/D2/D3/D4 + S10):

- **[D7 P0 根因]** per-module ent client 架构 → 跨模块 `*sql.Tx` 当前不可能(`backup/application/service.go:109-110` 注释自认)。
- **[D1 P0]** 交易创建全程无事务(header + N entries + 余额 = N+1+M 独立写,崩溃即复式记账破缺 / Transfer split-brain)。
- **[D2 P0]** Holding 交易 5 写 fan-out(handler 注释 "trade not rolled back")。
- **[D3 P0]** Debt 还款 best-effort 吞错:债标已还但现金未扣 → 净资产虚高。
- **[D4 P0]** Template autoRecord 假幂等:recorder 成功 + NextDate 推进失败 → 重复记账。
- **[S10 P1]** JIT provisioning 跨 4 表非事务。

**决策点:**
1. 统一 tx 抽象方案:wire 注入共享 `*sql.DB` 到各模块 ent client + port 接口加 `Tx context.Context` 传播(参照 budget 范式)/ 上 outbox + saga + 对账 job / 两者结合?
2. 范围:只覆盖 P0 财务写(交易/holding/debt/template)/ 全部跨模块写?
3. template autoRecord 假幂等:DB 唯一键 `(tenant_id, template_id, last_record_date)` / `SELECT FOR UPDATE` / advisory lock?
4. 是否同步引入对账 job 作为 best-effort 写的兜底校验(如 Paid ↔ 现金流量一致)?

## Answer(resolved 2026-07-26)

grilling 决策(4 点):

1. **统一 tx 抽象(D7 根因)**:wire 注入**共享 `*sql.DB`** 到各模块 ent client(替代各自 driver)+ port 接口加 **Tx context 传播**(参照 `budget_repo.go:172-225` 范式)。同步事务,御财单 Postgres 主流。一次性架构改,之后跨模块写可事务化。
2. **范围**:只覆盖 **P0 财务写** —— 交易创建(D1)、holding 5 写 fan-out(D2)、debt 还款(D3)、template autoRecord(D4)。其余跨模块写渐进。
3. **autoRecord 假幂等(D4)**:`transaction_template` 表加 **DB 唯一键 `(tenant_id, template_id, last_record_date)`**,重复记账 INSERT 冲突拒绝(防 scheduler 并发 + crash 重复)。叠加统一 tx(recorder + NextDate 原子)。
4. **对账 job**:**不引入**(依赖统一 tx 解决根因;御财单 server + 统一 tx 后 best-effort 写不存在)。

**实施规模:大(架构重构)**,分阶段:
- 阶段 A:共享 `*sql.DB` 重构(wire + 各 ent client 构造 + TxContext port 基础设施)
- 阶段 B:P0 写事务化(交易/holding/debt/template 4 处,各包 tx + 删 handler "not rolled back"/best-effort 吞错)
- 阶段 C:autoRecord 唯一键(schema + INSERT 冲突处理)
- 阶段 D:S10 JIT provisioning 事务化(顺带,同架构)

unblocks **04**(备份恢复一致性 —— 快照隔离 + 原子 restore 依赖共享 `*sql.DB`)。**实施留专项 plan/session**(本 session 仅 resolve 锁方向)。
