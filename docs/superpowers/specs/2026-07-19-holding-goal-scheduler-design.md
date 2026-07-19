# holding-backed goal scheduler e2e · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `4b3a143`)
- **范围**: 补 holding-backed goal scheduler **cross-module integration** test(goal ↔ holding)。**纯 test 新增**,零 proto/schema/production 改。

## 1. 背景

holding e2e 套件系列:performance ✅(`8694afa..3d34548`)+ CreatedAt fix ✅(`ebd4e2a`)+ sell 双写 ✅(`29d207f..0080325`)+ price+snapshot ✅(`4245d34..4b3a143`)。本 spec 是第 4 spec(goal scheduler,holding-backed investment goal)。

goal scheduler 现有 test:
- **goal**:6 个单测(repo/handler/domain×2/scheduler/application)
- **holding GetAccountsMarketValue port** 单测(`goal_port_multi_test.go`)
- **networth**:2 个单测(非本范围)

**缺 cross-module integration**:goal scheduler → holding `GetAccountsMarketValue` port → `goal.current_amount` 更新(端到端 cross-module)。

## 2. 目标

补 holding-backed goal scheduler cross-module integration:seed investment goal(linked to holding account)→ `SyncAllGoals` → holding port(mv)→ `goal.current_amount` = Σ holdings mv。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | scope | goal scheduler(holding-backed investment) | holding 套件系列(holding-backed goal);networth 跨模块独立非 range;savings/debt goal 非 holding-backed |
| 2 | 入口 | `svc.SyncAllGoals(ctx, tenantID)`(service 核心,单 tenant) | 验核心 holding-backed current_amount 更新;scheduler `SyncNow` 是 thin cross-tenant wrapper,可选 |
| 3 | cross-module harness | 单 sqlite + account/holding/goal ent client shared driver | 照 holding_doublewrite 范式(多 client shared driver);cross-module 数据互见 |
| 4 | AccountMarketValueSource 注入 | `goalSvc.SetAccountMarketValueSource(holdSvc)`(structural) | holding Service structural 实现 goal/domain port;无 adapter |
| 5 | mv 原币不折算 | 是 | service.go:1660 `accountMarketValue` 返原币;期望值按原币 Σ qty×price |
| 6 | LinkedAccountIDs 真 accountID | 是 | goal link 到 harness 真 investment account(非随机 uuid.New),否则 mv=0 |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| TestGoalScheduler_HoldingBackedCurrentAmount | networth 多币种聚合(独立) |
| cross-module harness(account+holding+goal ent shared driver) | savings/debt goal(非 holding-backed) |
| SyncAllGoals(service 核心) | scheduler SyncNow cross-tenant wrapper(可选,plan 决定) |
| mv 原币 + LinkedAccountIDs 真 accountID | range-period 覆盖(performance future) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| harness(新) | `setupGoalHoldingHarness` | 单 sqlite + account/holding/goal ent client shared driver + 真 service + `goalSvc.SetAccountMarketValueSource(holdSvc)` |
| test | `TestGoalScheduler_HoldingBackedCurrentAmount` | seed investment account + holding + security + goal → SyncAllGoals → 验 current_amount |
| 文件 | `yucai/server/tests/goal_holding_scheduler_integration_test.go`(新) | +harness + 1 test |

## 6. 核心改动

### 6.1 setupGoalHoldingHarness

照 [holding_doublewrite_integration_test.go:33-66](../../yucai/server/tests/holding_doublewrite_integration_test.go) `setupHoldingDoubleWriteTestDB` 范式(多 client shared driver):
- 单 in-memory sqlite(`file:goal_hold_<TestName>?mode=memory` + `SetMaxOpenConns(1)` + `PRAGMA foreign_keys=ON`)
- **account + holding + goal ent client 共享 driver**(各自 `Schema.Create`)
- wire 真 service:account(`accountRepo`/`chartRepo`)+ holding(`secRepo`/`holdRepo`/`tradeRepo`)+ goal(`goalRepo`)
- `goalSvc.SetAccountMarketValueSource(holdSvc)`(structural,holding Service 满足 `goal/domain.AccountMarketValueSource`)
- 返 `goalSvc` + `goalRepo` + `holdSvc` + `tenantID`/`accountID`

### 6.2 TestGoalScheduler_HoldingBackedCurrentAmount

- seed **investment account**(account 模块,`AccountTypeAsset`/`CategoryInvestment`)
- seed **security**(holding,`CurrentPrice=13000` via `UpdateSecurityPrice`)
- seed **holding**(100 qty,`AccountID=investment account`,`TenantID`)
- seed **investment goal**(`LinkedAccountIDs=[investment account]`,`TargetAmountCents=2000000`,`CurrentAmountCents=0` 初始)
- `goalSvc.SyncAllGoals(ctx, tenantID)`
- 验:`goal.CurrentAmountCents == 100×13000 = 1,300,000`

## 7. 数据流

```
seed investment account + security(price 13000) + holding(100 qty, accountID) + goal(LinkedAccountIDs=[accountID], target 2000000, current 0)
→ goalSvc.SyncAllGoals(ctx, tenantID)
→ repo.FindAll goals → investment goal: computeGoalProgress
→ mvSrc.GetAccountsMarketValue(tenantID, [accountID]) = Σ holdings mv = 100×13000 = 1,300,000
→ g.SetCurrentAmount(1300000) + IncrementVersion + repo.Update
→ 验 goal.CurrentAmountCents == 1,300,000
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestGoalScheduler_HoldingBackedCurrentAmount | cross-module goal scheduler(holding-backed) | `goal.CurrentAmountCents = Σ holdings mv = 1,300,000` |

零回归:全量 server 测 pass + build green(performance S1-S4 + sell 双写 + price+snapshot + buy doublewrite 不破)。

## 9. 风险

1. **cross-module harness**:account + holding + goal ent shared driver(3 client)。照 holding_doublewrite 范式。各自 `Schema.Create`。
2. **LinkedAccountIDs 真 accountID**:goal link 到 harness 真 investment account(非随机 `uuid.New`),否则 `GetAccountsMarketValue` 找不到 → mv=0。
3. **mv 原币不折算**:service.go:1660;期望值按原币 Σ qty×price(单币 CNY 简化)。
4. **IncrementVersion**:SyncAllGoals 已做(L255-257);e2e 只调 SyncAllGoals,不直接 `repo.Update`。
5. **per-tenant 错误不传播**(GoalScheduler):本 test 用 `SyncAllGoals`(service 单 tenant),不经 scheduler SyncNow。若用 SyncNow,per-tenant err log+continue。
6. **goal_repo.Update optimistic lock**:`Where(Version-1)`;SyncAllGoals IncrementVersion 后 Update。
7. 零 proto/schema/production 改(纯 test)。

## 10. 参考

- goal scheduler:[goal/scheduler/scheduler.go](../../yucai/server/internal/goal/scheduler/scheduler.go)(`Scheduler`/`GoalSyncer`/`SyncNow`)
- `AccountMarketValueSource` port:[goal/domain/repository.go:54](../../yucai/server/internal/goal/domain/repository.go)(接口在 goal/domain)
- holding `GetAccountsMarketValue`:[holding/application/service.go:1702](../../yucai/server/internal/holding/application/service.go)(structural 实现)
- goal `SyncAllGoals`:[goal/application/service.go:231](../../yucai/server/internal/goal/application/service.go)(`computeGoalProgress` → `SetCurrentAmount` → `Update`)
- cross-module harness 范式:[holding_doublewrite_integration_test.go:33-66](../../yucai/server/tests/holding_doublewrite_integration_test.go)(多 client shared driver)
- holding e2e 套件:performance/sell/price+snapshot spec
