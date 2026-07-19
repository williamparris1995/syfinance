# savings+debt goal 分支 e2e · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `2149700`)
- **范围**: 补 **Savings + DebtPayoff** goal scheduler e2e(现只 Investment)。**纯 test 新增**,零 proto/schema/production 改。

## 1. 背景

goal scheduler e2e 套件(`afced1e..a02175d`)只覆盖 **Investment goal**(`mvSrc.GetAccountsMarketValue`)。`computeGoalProgress` Savings/DebtPayoff 分支未 e2e:
- **Savings**:`balSrc.GetAccountsBalance`(Σ account `CurrentBalanceCents`)
- **DebtPayoff**:`debtSrc.GetDebtsPaid`(Σ `TotalPrincipal − RemainingPrincipal`)

单元层 `service_test.go` L208-242 stub 覆盖三类型分派;**e2e 层缺 Savings/DebtPayoff 真实 ent-backed account/debt**。

## 2. 目标

补 Savings + DebtPayoff goal scheduler cross-module e2e(照 Investment 范式)。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 扩展 setupGoalHoldingHarness | 是 | 现成 harness;加 debt client/schema + debtSvc + `SetAccountBalanceSource` + `SetDebtProgressSource` |
| 2 | 2 test(Savings + DebtPayoff) | 是 | 两分支独立;照 Investment 范式 |
| 3 | Savings fixture(account balance) | 是 | savings account `InitialBalance 800000` + savings goal target 1000000 → current=800000 |
| 4 | DebtPayoff fixture(debt paid) | 是 | debt total 600000 EqualPrincipal 3月 + mark Schedule[0] paid 200000 + debt payoff goal target 600000 → current=200000 |
| 5 | 干净数字 | 是 | savings 800000 / debt paid 200000(整除) |
| 6 | target > paid(避 auto-complete) | 是 | savings 1000000>800000 / debt 600000>200000 |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| TestGoalScheduler_SavingsBackedCurrentAmount | Investment(已覆盖) |
| TestGoalScheduler_DebtPayoffBackedCurrentAmount | SyncNow cross-tenant(future) |
| harness 扩展(debt client + SetAccountBalanceSource/DebtProgressSource) | account balance 变化后 sync(静态 InitialBalance) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| harness | `setupGoalHoldingHarness`(扩展) | +debt client/schema + debtSvc + `SetAccountBalanceSource(acctSvc)` + `SetDebtProgressSource(debtSvc)` + 返 debtSvc |
| test | `TestGoalScheduler_SavingsBackedCurrentAmount` | savings account 800000 + savings goal → current=800000 |
| test | `TestGoalScheduler_DebtPayoffBackedCurrentAmount` | debt 600000(EqualPrincipal 3月 mark paid 200000)+ debt payoff goal → current=200000 |
| 文件 | `goal_holding_scheduler_integration_test.go`(改) | harness 扩展 + 2 test + 现有 holding test 改解构 |

## 6. 核心改动

### 6.1 harness 扩展

`setupGoalHoldingHarness` 加:
- debt client(`debtent.NewClient(debtent.Driver(drv))`)+ `Schema.Create`(**FK 顺序:debt 先于 goal**,`goal_debt_links` 引用 debt)
- debtSvc(`debtrepo.NewDebtRepository(debtClient)` + `debtapp.NewService(debtRepo)`)
- `goalSvc.SetAccountBalanceSource(acctSvc)`(acctSvc 已在 harness L69)
- `goalSvc.SetDebtProgressSource(debtSvc)`
- 返值加 `debtSvc`

现有 `TestGoalScheduler_HoldingBackedCurrentAmount` 改解构(`, _` 接住 debtSvc)。

### 6.2 TestGoalScheduler_SavingsBackedCurrentAmount

- seed savings account(`Category=Savings, AccountType=Asset, InitialBalance=800000`)
- seed savings goal(`GoalTypeSavings, LinkedAccountIDs=[accountID], target=1000000`)
- `SyncAllGoals(ctx, tenantID)`
- 验:`goal.CurrentAmountCents == 800000`

### 6.3 TestGoalScheduler_DebtPayoffBackedCurrentAmount

- seed debt(`total=600000, EqualPrincipal, term=3月` → 月 200000;`mark Schedule[0] paid` → paid=200000, remaining=400000)
- seed debt payoff goal(`GoalTypeDebtPayoff, LinkedDebtIDs=[debtID], target=600000`)
- `SyncAllGoals(ctx, tenantID)`
- 验:`goal.CurrentAmountCents == 200000`(600000 − 400000)

## 7. 数据流

**Savings**:
```
seed savings account(InitialBalance 800000)+ savings goal(LinkedAccountIDs=[accountID], target 1000000)
→ SyncAllGoals → computeGoalProgress(Savings)
→ balSrc.GetAccountsBalance([accountID]) = CurrentBalanceCents = 800000
→ goal.CurrentAmountCents = 800000
```

**DebtPayoff**:
```
seed debt(total 600000 EqualPrincipal 3月)+ mark Schedule[0] paid(paid 200000, remaining 400000)+ debt payoff goal(LinkedDebtIDs=[debtID], target 600000)
→ SyncAllGoals → computeGoalProgress(DebtPayoff)
→ debtSrc.GetDebtsPaid([debtID]) = TotalPrincipal − RemainingPrincipal = 600000 − 400000 = 200000
→ goal.CurrentAmountCents = 200000
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestGoalScheduler_SavingsBackedCurrentAmount | Savings goal(account balance) | current=800000 |
| TestGoalScheduler_DebtPayoffBackedCurrentAmount | DebtPayoff goal(debt paid) | current=200000 |

零回归:全量 server 测 pass + build green。

## 9. 风险

1. **harness 签名扩展**(加 debtSvc;现有 holding test 改 `_`)。
2. **goal_debt_links FK**(debt schema 先 Create + seed debt 先于 goal link)。
3. **MarkPaid 全量付**(EqualPrincipal 多期 + mark Schedule[0];total=600000 月 200000 整除)。
4. **auto-complete**(current >= target → MarkCompleted;target > paid 避歧义)。
5. **GetDebtsPaid 不需 SetAccountLookup**(debt NewService(repo) 即满足)。
6. **debt EqualPrincipal term**(StartDate/DueDate 间隔 = term months;选 3 月)。
7. 零 proto/schema(纯 test)。

## 10. 参考

- computeGoalProgress:[goal/application/service.go:283-303](../../yucai/server/internal/goal/application/service.go)(Savings/DebtPayoff 分支)
- port:[goal/domain/repository.go:51-68](../../yucai/server/internal/goal/domain/repository.go)(AccountBalanceSource/DebtProgressSource)
- 实现:[account/application/service.go:343-367](../../yucai/server/internal/account/application/service.go)(GetAccountsBalance)+ [debt/application/service.go:187-211](../../yucai/server/internal/debt/application/service.go)(GetDebtsPaid)
- goal scheduler 套件:[2026-07-19-holding-goal-scheduler-design.md](2026-07-19-holding-goal-scheduler-design.md)(Investment e2e 范式)
