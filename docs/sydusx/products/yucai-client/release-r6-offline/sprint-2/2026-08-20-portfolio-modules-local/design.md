---
feature: 2026-08-20-portfolio-modules-local
status: drafted
---

# Design — 资产类模块本地化

> 消费 [spec.md](spec.md)(confirmed)。**server 语义锚点(research + design 补充提取)**:
> ① holding 复式:buy=credit from(现金−)/debit holding.account(投资+),sell 反向;fee 不进现金腿(资本化进 lot);校验:from 存在/asset/≠holding 账户/同币种/buy 余额充足;成本:buy lot 每股=(price×qty+fee)/qty,sell FIFO 消耗+realizedPnl 扣 sell fee+avgCost 从余 lot 重算。
> ② budget actuals(budget/domain/repository.go:45-59):**actual = max(Σdebit, Σcredit)**(取较大方向),月窗口 [月初, 月末−1ns];**读时计算**(server read-time compute,非持久)。
> ③ goal 三源(application/service.go:215-300):Investment=Σ linked accounts 持仓市值 / Savings=Σ linked accounts 余额 / DebtPayoff=Σ linked debts paid(schedule paidCents);无 links→0。
> ④ debt 复式:还入 borrowedIn=credit from+debit debt 账户;收款 borrowedOut=debit from+credit debt 账户;borrowedOut create=credit source(现金−)+debit receivable+。
> ⑤ networth 三源:assets=Σ asset 账户余额+Σ 持仓市值;liabilities=Σ liability 账户余额+Σ borrowedIn remaining;base 折算。

## Context

范式第 3 轮复制(C/D 验证);本 feature 的增量 = 复式引擎复用 + FIFO 成本引擎 + 五处聚合移入 client + 两个降级面。

## Goals / NonGoals

- **Goals**:五面(holding/budget/goal/debt+receivables/networth)双源化;行情/收益显式降级;report 零改动记录。
- **NonGoals**:XIRR/TWR 移植 / 快照 scheduler 模拟 / 行情缓存 / 镜像(H)。

## Decisions(ADRs)

### ADR-1 holding local ds = 单 drift 事务四件套 + FIFO 引擎 + 读时合成
- **Decision**:
  - **buy/sell**:一个 `db.transaction` 内:①Holdings upsert(quantity/avgCost);②buy 建 HoldingLot(每股=(price×qty+fee)/qty)/sell **FIFO 消耗**(从最老 lot 扣,realizedPnl=(price−lot成本)×数量−fee,余量为 0 删 lot;avgCost=余 lot 加权);③HoldingTransactions 流水;④**本地复式交易**(复用 D 的 transaction 写入语义,entries 按方向表,fromAccountId 必填+四校验)。dividend/split:流水+持仓数量调整(split 按 ratio);dividend **不复式**(server recordDividend 无 incomeAccount——记 accepted 差异,资金入账由用户自行记账)。
  - **展示合成**:listHoldings 读时 join securities(name/symbol/type/currency)+ 现价(currentPriceCents 列);marketValue=quantity×现价,无现价→按 avgCost 并置 pnl=0(陈旧);无 security 行→unknown 兜底。
  - syncPrices/performance → 见 ADR-6。
- **Rationale**:与 server 单 RPC 事务语义原子对齐;FIFO 照抄 ConsumeLotsFIFO 可观察行为。
- **Alternatives**:复式走 repo 层拼两个 ds——破坏事务性,reject。

### ADR-2 聚合器归属 = 各 local ds 内聚,不建 core 共享层
- **Decision**:budget actuals 在 budget local ds;goal 三源在 goal local ds(跨表读 holdings/accounts/debts 经各自 DAO——data 层读 core/localdb 合法);networth 独立 `NetWorthLocalDataSource`;receivables summary 在 debt local ds。
- **Rationale**:五处口径异构(max 方向/三源/三源/14 字段),共享层是假抽象;DAO 是共享边界已存在。
- **Alternatives**:core/aggregator 服务——过度设计。

### ADR-3 budget:读时 actuals(口径照抄)+ 隐式乐观锁可观察一致
- **Decision**:get/list 读时对每 item 计算 actual=max(Σdebit,Σcredit)(月窗口扫 transaction_entries,经 accounts 类型无关——server 即如此,不区分);update 整包替换 items+version+1(远端无 version 参数,隐式锁的可观察差异不暴露)。
- **Rationale**:口径逐字照抄(budget/domain/repository.go:53-57 的 max 简化口径,含其怪异但一致)。

### ADR-4 goal:读时三源 + progress history 空
- **Decision**:list/get 读时算 currentAmount(无 links→0;Investment 用 ADR-1 同款市值合成);recordContribution/complete/clone 后直接返回读时重算实体;getProgressHistory → `[]`(accepted)。

### ADR-5 debt:复式四方向 + schedule 同事务;receivables summary 本地聚合
- **Decision**:recordPayment 单事务:复式(④方向表)+schedule 行 paid=true/paidCents/transactionId;borrowedOut create 单事务:债务+首期 schedule+复式④;receivables summary:遍历 borrowedOut debts+schedule 聚合 14 字段(口径以 server GetReceivablesSummary 字段名逐一对齐,oracle 钉核心三项:借出本金/已收/待收)。

### ADR-6 行情与收益:显式降级
- **Decision**:guest 下 syncPrices/getPortfolioPerformance/getHoldingPerformance/getHoldingCurve(若有)→ `ServerFailure('离线暂不支持行情同步/收益分析')`;updateSecurityPrice guest 允许(本地写,用户手工调价——快照价值);searchSecurities guest=本地 symbol/name 前缀匹配。
- **Rationale**:诚实降级优于假数据;手工调价是离线编辑面的一部分。

### ADR-7 networth ds 双源化
- **Decision**:`NetWorthLocalDataSource`(三源⑤口径+本地汇率折算标注陈旧);`NetWorthDataSource` 改造为双源路由(构造 +local +tracker;它不走 repo,自带 guard 同款)。
- **Alternatives**:并入 holding repo——职责错位(其消费方是 home 直连)。

## HLD

```
新增 local ds:holding/data/holding_local_ds.dart(最大:FIFO+复式+合成)
              budget/data/budget_local_ds.dart
              goal/data/goal_local_ds.dart
              debt/data/debt_local_ds.dart(含 receivables summary 聚合)
              holding/data/networth_local_ds.dart
改 repo/ds:holding/budget/goal/debt 四个 repository_impl(+local+tracker 路由)
           holding/data/networth_ds.dart(双源化)
           (transaction/account local ds 被复用——零改动)
零改动:report 全链/各 bloc/pages/securities 表
```

## LLD 要点

### FIFO 伪码(sell)
```
remaining=sellQty; realized=0
for lot in lots(按 acquiredDate ASC):
  take=min(lot.remainingQuantity, remaining)
  realized += (price−lot.priceCents)×take
  lot.remainingQuantity−=take; remaining−=take
  if lot.remaining==0: 删 lot
  if remaining==0: break
realized −= fee  (sell fee 从 proceeds 扣,照抄 server)
avgCost = Σ(余lot price×qty)/Σ余qty (无余 lot→0)
```

### 聚合口径表(oracle 锚)

| 聚合 | 口径 | server 锚 |
|---|---|---|
| budget actual | max(Σdebit,Σcredit) @month 窗口,按 item.accountId | budget/domain/repository.go:53 |
| goal Investment | Σ linked accounts 的 Σ holdings(qty×现价∨avgCost) | goal/application/service.go:287 |
| goal Savings | Σ linked accounts currentBalance | :292 |
| goal DebtPayoff | Σ linked debts Σ schedule paidCents | :224 |
| networth | assets=Σ asset 余额+Σ 持仓市值;liab=Σ liability 余额+Σ borrowedIn remaining | networth/domain 三 port |
| receivables summary | borrowedOut 债务+schedule 全量聚合(14 字段) | GetReceivablesSummary |

### 映射特例

- Holding 实体的展示字段(securityName/marketValue/…)drift 无列→读时合成;写路径只落核心列。
- HoldingTransaction.tradeDate/debt 日期=String(yyyy-MM-dd)↔drift DateTime UTC 互转。
- budget month=String 直存;goal links 联结表聚合。
- debt DebtType{borrowedIn,borrowedOut} domain index+1=契约 int(1/2;server 从 1 起✓);AmortizationMethod 同(server 从 1)。

### 测试计划

- holding:buy 复式 oracle(现金腿=price×qty 不含 fee)/fee 资本化(avgCost)/FIFO 多 lot 消耗+realizedPnl/余额不足回滚/split 数量/dividend 不复式/合成(无价降级)。
- budget:actuals oracle(max 口径两方向)/整包替换/月窗口边界。
- goal:三源 oracle(各 type)/links patch/乐观锁/recordContribution 后 current 重算/history 空。
- debt:还入/收款复式方向/borrowedOut create 双写/schedule 更新同事务/summary 核心三项。
- networth:三源 oracle+折算标注。
- 路由测试 ×5(guest 本地/远端零调用/切换)。

## Risks

- **R1 receivables summary 14 字段逐一对齐工作量**——oracle 只钉核心三项,长尾字段 execute 时对照 server 逐个核(记 checklist)。
- **R2 goal Investment 市值与 holding 页合成口径一致性**——同一合成 helper 抽在 holding local ds 供 goal 复用(data 层依赖,合法)。
- **R3 FIFO 边界(部分成交/零余 lot/浮点数量)**——golden 测试钉多 lot 场景;quantity 用 double(契约如此)。

## Migration

纯新增;injectable 重新生成(4 repo + networth ds 构造扩展)。

## Open Questions

1. receivables summary 长尾字段口径(执行时逐字段核,不足处记 accepted 差异)。
2. getHoldingCurve 是否在 repo 面(research 未列——执行时按实际面补降级)。
