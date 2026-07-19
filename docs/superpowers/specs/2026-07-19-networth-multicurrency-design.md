# networth 多币种 e2e · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `15d6410`)
- **范围**: 补 networth 多币种 **cross-module integration**(account/holding/debt + currency rate → GetNetWorth base CNY 聚合)。**纯 test 新增**,零 proto/schema/production 改。

## 1. 背景

holding e2e 套件系列 + future(performance/sell/price+snapshot/goal/lot/range-period)+ 3 production fix(CreatedAt + Source + lot ID)。本 spec 是 future(**networth 多币种,跨模块独立**)。

networth 现有 test:
- networth application/handler 单测(**fake port** + fake rateRepo)
- account/holding/debt `SumByCurrency` 单测(单模块)
- currency rate_history 单测

**缺 cross-module integration**:真 ent-backed account/holding/debt + 真 currency rate history → GetNetWorth 多币种聚合 端到端(三 source 真实现 + 真 FindRate forward-fill + ConvertToBase 链路从未同时驱动)。

## 2. 目标

补 networth 多币种 cross-module integration:seed account CNY + holding USD + debt CNY + rate → GetNetWorth base CNY 聚合(assets/liab/net)。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | base CNY | 是 | 简单(rate USD=7,数字干净 10000+7000=17000);base USD 逐条 round 噪声 defer |
| 2 | 4 ent shared driver | 是 | networth 无 ent(纯聚合);account+holding+debt+currency 共享 sqlite;照 holding_doublewrite/goal_holding 范式 |
| 3 | debt `SetAccountLookup` | 是 | debt currency 默认 CNY(accountLookup nil);production wire 注入;harness 必须(USD debt 归 USD) |
| 4 | rate 过去日期 seed | 是 | GetNetWorth `FindRate(code, time.Now())` 硬编码不可注入;fixture seed `<= now` 过去日期,否则 1.0 fallback |
| 5 | 逐条 round | 是 | ConvertToBase 每条 round;base CNY 数字干净(无 round 噪声) |
| 6 | handler 不测 | 是 | networth_handler_test 已覆盖透传;focus application 真链路 |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| TestNetWorth_MultiCurrency(4 ent + GetNetWorth base CNY) | base USD(逐条 round 噪声,future) |
| setupNetWorthHarness(4 ent shared driver) | handler 透传(已覆盖) |
| debt SetAccountLookup + rate 过去日期 | rate 缺失 fallback(单测覆盖) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| harness(新) | `setupNetWorthHarness` | 4 ent shared driver(account/holding/debt/currency)+ 真 service + `networthapp.NewService` + `debtSvc.SetAccountLookup(accountRepo)` |
| test | `TestNetWorth_MultiCurrency` | seed account CNY + security USD + holding USD + debt CNY + rate USD=7 → GetNetWorth base CNY |
| 文件 | `yucai/server/tests/networth_multicurrency_integration_test.go`(新) | +harness + 1 test |

## 6. 核心改动

### 6.1 setupNetWorthHarness

照 [goal_holding_scheduler_integration_test.go](../../yucai/server/tests/goal_holding_scheduler_integration_test.go) / [holding_doublewrite_integration_test.go:33](../../yucai/server/tests/holding_doublewrite_integration_test.go) 范式(多 ent shared driver):
- 单 sqlite(`file:net_worth_dw?mode=memory` + `SetMaxOpenCns(1)` + `PRAGMA foreign_keys=ON`)
- **4 ent client**(account/holding/debt/currency)shared driver + 各自 `Schema.Create`
- 真 service:account(`accountRepo`/`chartRepo`)+ holding(`sec/hold/trade`)+ debt(`debtRepo` + **`SetAccountLookup(accountRepo)`**)+ rateRepo(currency)
- `networthapp.NewService(acctSvc, holdSvc, debtSvc, rateRepo, nil)`
- 返 `networthSvc` + `tenantID`

### 6.2 TestNetWorth_MultiCurrency

- seed **account CNY savings 10000**(asset,`CreateAccount CurrencyCode:"CNY" + AccountTypeAsset + InitialBalanceCents:10000`)
- seed **security USD** + `UpdateSecurityPrice(10 cents)` + `BuyHolding(100 qty)` → mv=100×10=1000 cents USD
- seed **debt CNY 5000**(remaining)
- seed **rate USD=7**(过去日期 `<= time.Now()`)
- `networthSvc.GetNetWorth(ctx, tenantID, "CNY")`
- 验:
  - `TotalAssetsCents == 17000`(account CNY 10000 + holding USD 1000×7=7000)
  - `TotalLiabilitiesCents == 5000`(debt CNY 5000)
  - `NetWorthCents == 12000`(17000 − 5000)
  - `Currency == "CNY"`

## 7. 数据流

```
seed account CNY 10000 + security USD price 10 + holding 100 qty(mv=1000 USD)+ debt CNY 5000 + rate USD=7(过去日期)
→ networthSvc.GetNetWorth(tenantID, "CNY")
→ accounts.SumBalancesByCurrency → {CNY:10000}; toBase(CNY, rate=1, base=1) = 10000
→ holdings.SumMarketValueByCurrency → {USD:1000}; toBase(USD, rate=7, base=1) = 7000
→ debts.SumRemainingByCurrency → {CNY:5000}; toBase(CNY) = 5000
→ assets = 17000, liab = 5000, net = 12000
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestNetWorth_MultiCurrency | cross-module networth 多币种 | TotalAssets=17000 / Liab=5000 / Net=12000 / Currency=CNY |

零回归:全量 server 测 pass + build green(holding e2e 套件 + future 全不破)。

## 9. 风险

1. **rate 过去日期 seed**:GetNetWorth `FindRate(code, time.Now())` 硬编码;fixture seed `<= now` 过去日期(如 2025-01-02),否则 forward-fill miss → 1.0 fallback(USD 不折算)。
2. **debt `SetAccountLookup`**:debt currency 默认 CNY(accountLookup nil);harness 必须 `SetAccountLookup(accountRepo)`(USD debt 归 USD)。
3. **holding currency from security**:`CreateSecurity(CurrencyCode:"USD")` + `UpdateSecurityPrice`(mv = qty × price)。
4. **account CurrencyCode + Asset type**:`SumBalancesByCurrency` 过滤(`CreateAccount CurrencyCode + AccountTypeAsset`)。
5. **逐条 round**:base CNY 数字干净(10000+7000=17000,无 round 噪声)。
6. **4 ent shared driver**(account/holding/debt/currency;networth 无 ent)。
7. 零 proto/schema(纯 test)。

## 10. 参考

- GetNetWorth:[networth/application/service.go:56](../../yucai/server/internal/networth/application/service.go)(跨 account/holding/debt 聚合 + toBase)
- networth port:[networth/domain/repository.go](../../yucai/server/internal/networth/domain/repository.go)(AccountBalanceSource/HoldingMarketValueSource/DebtSource)
- rate 折算:[currency/domain/convert.go:9](../../yucai/server/internal/currency/domain/convert.go)(ConvertToBase)+ [rate_history_repo.go:27](../../yucai/server/internal/currency/adapter/driven/repository/rate_history_repo.go)(FindRate forward-fill)
- cross-module harness 范式:[holding_doublewrite_integration_test.go:33](../../yucai/server/tests/holding_doublewrite_integration_test.go) / [goal_holding_scheduler_integration_test.go](../../yucai/server/tests/goal_holding_scheduler_integration_test.go)(多 ent shared driver)
- networth 单测:[networth/application/service_test.go](../../yucai/server/internal/networth/application/service_test.go)(fake port 期望值参考)
