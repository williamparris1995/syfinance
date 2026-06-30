# Holding 子项目 D-goal · holding-backed 投资目标 设计

- **日期**: 2026-06-30
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: D 首批(holding-backed investment goal:account 级关联 + scheduler 每日算市值进度 + Flutter goal_link 接真)
- **上游全景设计**: [2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md) §7.2
- **前置**: A(holding 基础 + 双写)+ B(价格 sync)+ C(收益 snapshot)已完成
- **D 分解**: D-goal 首批;D-currency(realized 折算/net-worth)/ D-budget(actuals/排除/UI)后续独立 spec

## 1. 背景与目标

goal 模块**现有且完整**(server `internal/goal/`:domain/application/ent/handler + Flutter proto 已生成),`GoalType` 含 `investment`(枚举存在但 domain 无特化逻辑)。Flutter [goal_link_page.dart](../../yucai/client/lib/holding/presentation/pages/goal_link_page.dart)(A-flutter Task 10)**⏳D 全空态** —— holding 模块根本没消费 goal(点关联只弹 SnackBar「⏳D 待 goal.proto」)。

D-goal 目标:让 **investment goal 接通 holding** —— investment goal 关联 investment account(复用 `linked_account_id`),scheduler 每日算该账户 Σ holdings 市值写 `goal.current_amount`,Flutter goal_link 接真显示进度。

**行业最佳实践**(用户拍板):投资目标 = **账户/组合级**(非单持仓),因目标长期(年)vs 持仓短期(可卖出)。御财 goal 已有 `linked_account_id` + `Account.category="investment"`,复用最自然(不加新字段)。

## 2. 范围边界

| 在范围(D-goal 首批) | 不在范围(D-currency/D-budget/后续) |
|---|---|
| investment goal 关联 investment account(复用 linked_account_id) | D-currency(realized 多币种折算 / net-worth) |
| goal scheduler 每日算 Σ account holdings mv → goal.current_amount | D-budget(budget actuals 接通 / 排除 investment / Flutter UI) |
| holding `GetAccountMarketValue` port(暴露给 goal) | ETA 推算(首批 defer,需 progress 历史速率) |
| GoalType=investment 特化(进度从 holding mv) | 单 holding / security 级 goal(首批 account 级) |
| Flutter goal_link 接真(progress% + current/target + 贡献占比) | goal 创建/编辑 UI(走现有 goal 模块) |
| proto `SyncInvestmentGoals` RPC(手动,可选) | budget 关联(D-budget) |

## 3. 架构总览

```
B SyncPrices(每日)→ security.current_price 更新(已存在)
                        ↓ (价格已是最新)
goal scheduler(每日,独立,复用 B/currency/SnapshotScheduler 模式 + IntervalSource 门控)
  → goal.SyncInvestmentGoals(ctx)
    → 遍历 GoalType=investment 的 goals
    → 对每个 goal.LinkedAccountID(investment account)
       → holding port.GetAccountMarketValue(accountID) = Σ holdings(qty × current_price)
       → goal.SetCurrentAmount(mv); progress% = mv / target; 达 target → MarkCompleted
    → goal_repo.Save

Flutter goal_link_page(/holdings/goals,填 A-flutter ⏳D 空态)
  → ListGoals(filter linked_account=holding.account_id, type=investment)
  → goal 列表 + progress% + current/target + 该 holding 贡献占比
```

**复用(D-goal 零新表)**:
- `goal.linked_account_id`(现有,[entity.go:21](../../yucai/server/internal/goal/domain/entity.go#L21))+ `Account.category="investment"`(现有)+ `GoalType.investment`(现有)
- scheduler 模式(B/currency/SnapshotScheduler 同款,goal 是第 4 个 scheduler)
- holding port(类似 C 的 `RateHistoryRepository` 结构 port —— goal 定义本地接口,holding 结构实现)

**跨模块依赖**:**goal → holding port**(`GetAccountMarketValue`)。holding application 加方法(按 account 聚合 holdings × current_price),goal 定义本地 `AccountMarketValueSource` port 结构消费。**反向不依赖**(holding 不知 goal)。

**特化**:`GoalType.investment` 进度从 holding mv;savings/debt_payoff 走 account balance(现有逻辑不动)。

## 4. server 改动

### 4.1 domain(goal)
- `Goal` 加 `SetCurrentAmount(amt int64)`(investment 进度从 mv 设;触发 `ProgressPct`/`MarkCompleted`)
- 现有 `AddProgress`/`MarkCompleted`/`ProgressPct` 不动(savings/debt_payoff 走手动 `AddProgress`)

### 4.2 holding application(暴露 port)
- 加 `GetAccountMarketValue(ctx, accountID uuid.UUID) (int64, error)` = Σ holdings(qty × current_price)under account(分页聚合,复用 `ListHoldings` 逻辑)
- 结构满足 goal 的 `AccountMarketValueSource` port

### 4.3 goal application
- `domain.AccountMarketValueSource` 接口(goal 本地,`GetAccountMarketValue(ctx, accountID)(int64, error)`,holding 结构实现,goal 不 import holding)
- `Service` 加 `accountMarketValueSource` 字段 + `SetAccountMarketValueSource` setter(对齐 B/C setter 模式,`NewService` 签名不变)
- `SyncInvestmentGoals(ctx) (int, error)`:遍历 `GoalType=investment` goals → 对 `linked_account` 调 port → mv → `goal.SetCurrentAmount(mv)` → repo.Save。best-effort(单 goal fail 不中断)

### 4.4 goal scheduler(第 4 个 scheduler)
- `goal/scheduler/scheduler.go`(照 B/currency/SnapshotScheduler 模式)
- `GoalSyncer` 接口 = `SyncInvestmentGoals(ctx)(int, error)`(goal application.Service 实现)
- `NewScheduler/Start/SyncNow/doSync/IntervalSource` 门控(复用同一 IntervalSource)

### 4.5 proto(goal)
- ⚠️ **goal.proto 现有 RPC 待 plan 阶段 Read 确认**(Explore 确认 client proto 已生成,goal.proto 存在,但 RPC 清单未详)
- 预期:加 `SyncInvestmentGoals` RPC(手动触发,可选,调试/补数据)+ `ListGoals`/`GetGoal` DTO 含 `current_amount` + `target_amount`(progress% Flutter 算 current/target,或 DTO 加 `progress_pct`)
- **若 ListGoals 已返 current + target,零 proto 改**(仅 scheduler + holding port + Flutter)

### 4.6 wire + main
- providers:goal scheduler + goal service `SetAccountMarketValueSource(holdingSvc)`(holding application.Service 结构实现 port)
- `wire_gen.go` 手改(镜像 B/C,见 [[yucai-wire-handmaintained]])
- main:`go goalScheduler.Start(schedCtx)`

## 5. schema 改动

**零新表/字段**。复用 `goal.linked_account_id` + `Account.category="investment"` + `GoalType.investment`(均现有)。

## 6. Flutter 改动

### 6.1 goal_link 接真(填 ⏳D)
`goal_link_page` 从 holding 详情进(传 `holding.account_id`):
- 调 `ListGoals`(filter `linked_account=holding.account_id`, `type=investment`)
- **goal 列表**:名 / 关联 investment account / 当前 mv(=progress current)/ 目标 / 进度条 %
- **概览头**:该 account 的 goals 统计(总数 / 超前 / 持平 / 落后,按 progress% 分组)
- **该 holding 贡献**:holding.mv / account.mv 占比(对账户目标的贡献)
- **关联选择**:account 级下 goal 已关联 account;首批 goal_link **只读**(显示 account goals + holding 贡献),创建/编辑 goal 走 goal 模块(现有)。原型 holding picker → 改为"该 holding 所属 account 的 goals 列表"
- **ETA ⏳**(defer,占位)

### 6.2 数据层
holding 模块调 goal gRPC:新建 `GoalView` data source(holding import goal proto + 调 `ListGoals`)或扩展 holding_repo。

### 6.3 降级(沿用 A-flutter `isPendingBackend` 惯例)
- investment account 无 holdings → mv=0,progress=0(显示 0%)
- goal RPC fail → ⏳ 空态(非崩溃)
- holding 无 account → 空态

## 7. 失败/降级策略(server)
| 场景 | 处理 |
|---|---|
| `GetAccountMarketValue` fail(account 无 holdings / holding 服务错) | 该 goal 跳过 + 日志,best-effort 不中断 |
| goal scheduler 单轮 error | logged 不退出循环(对齐 B/currency) |
| 无 investment goal | `SyncInvestmentGoals` 返 0(无操作) |
| goal 已 IsCompleted | 跳过(不再更新)或继续(幂等)—— 首批跳过 |

## 8. 测试策略(全程 TDD)
- **server domain**:goal `SetCurrentAmount` + investment progress 特化(达 target MarkCompleted)
- **server application**:`SyncInvestmentGoals`(mock `AccountMarketValueSource`,验证 mv→current_amount + best-effort)+ holding `GetAccountMarketValue`(分页聚合多 holding)
- **server scheduler**:照 [B scheduler_test.go](../../yucai/server/internal/holding/scheduler/scheduler_test.go) 模式
- **server handler**:`SyncInvestmentGoals` RPC 映射(若加)
- **Flutter**:goal_link widget test(真 goals 渲染 + progress% 计算 + 空态/降级)+ GoalView data source

## 9. 前置验证(Task 0)
- **Read goal.proto 确认现有 RPC + DTO**(Explore 说 client proto 已生成,但 RPC 清单未详;确认 ListGoals 是否已返 current+target → 决定 proto 改动量)
- 确认 goal ent 表 + GoalType.investment 现有
- 工作区干净

## 10. 实施顺序建议(供 writing-plans,~9-10 task)
```
1. domain:goal SetCurrentAmount + holding GetAccountMarketValue 聚合
2. goal application:SyncInvestmentGoals + AccountMarketValueSource port setter
3. goal scheduler(照 B/currency/SnapshotScheduler 模式)
4. proto:Read goal.proto 确认 + 加 SyncInvestmentGoals(手动,可选)
5. wire + main:goal scheduler 接线 + holding→goal port 注入(wire_gen 手改)
6. server 端到端:scheduler 算 mv 写 goal.current_amount
7. Flutter data/domain:GoalView data source + entity
8. Flutter presentation:goal_link_page 接真填 ⏳D + widget test
9. 全链路 + final review
```

## 11. 决策记录(用户拍板)
| # | 决策 | 选定 |
|---|---|---|
| D 分解 | D-goal / D-currency / D-budget 独立 spec | **D-goal 首批**(最有价值,原型+空态待填) |
| ① goal 关联粒度 | account 级 / 单 holding / portfolio | **account 级**(复用 linked_account_id,行业最佳实践:目标长期 vs 持仓短期) |
| ② 进度触发 | scheduler 每日 / 手动 RPC / 两者 | **scheduler 每日**(B price sync 后,行业实践,持久化 current_amount) |
| ③ ETA | defer / 简单线性 / 精确(snapshot 速率) | **defer**(首批 progress% + current/target,ETA 需历史) |
| ④ Flutter goal_link | 只读 / 创建编辑 | **首批只读**(account goals + holding 贡献;创建走 goal 模块) |

## 12. 风险清单(plan 需显式处理)
1. **goal.proto 现有 RPC 未详**(Task 0 Read 确认;若 ListGoals 已返 current+target,零 proto 改)
2. **跨模块 goal→holding port**(结构 port,类似 C RateHistoryRepository;goal 不 import holding)
3. **goal scheduler 第 4 个**(复用 IntervalSource;wire 手改镜像 B/C)
4. **holding GetAccountMarketValue 分页聚合**(复用 ListHoldings;account 下多 holding,Σ qty×current_price)
5. **goal service 现有 SyncGoalProgress stub**(Explore 发现 service.go:118-137 stub;D-goal SyncInvestmentGoals 是新方法,不依赖 stub,但需确认不冲突)

## 13. 参考
- goal 现状:[entity.go:11-27](../../yucai/server/internal/goal/domain/entity.go#L11)(LinkedAccountID)/ valueobject.go(GoalType.investment)/ application SyncGoalProgress stub
- holding GetAccountMarketValue:复用 ListHoldings 聚合 + security.CurrentPriceCents
- C 模式:RateHistoryRepository 结构 port(holding 本地,currency 实现)
- scheduler 模式:B/currency/SnapshotScheduler(照搬)
