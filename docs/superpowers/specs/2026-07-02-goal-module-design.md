# Goal 独立管理模块 · 3 type 自动 progress + 模板/复制 + 多账户聚合 + 趋势 设计

- **日期**: 2026-07-02
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: goal 完整系统(server 3 type 自动 progress 扩展 + 多账户聚合 + progress 历史 snapshot + CloneGoal/模板;Flutter 独立 lib/goal/ 模块 list/create/detail/edit;OD 原型设计先行)
- **前置**: D-goal(server goal CRUD + Investment scheduler + holding goal_link 只读)已完成
- **分 phase**: Phase 0 OD 原型 / Phase 1 核心(server 3 type + client 基础)/ Phase 2 趋势曲线 / Phase 3 模板 + 多账户 picker

## 1. 背景与目标

御财 goal 现状(Explore 确认):
- **server goal 完整**:domain(Goal{GoalType, TargetAmountCents, CurrentAmountCents, Deadline, LinkedAccountID})+ repo + application(8 RPC:Create/Get/List/Update/Delete/Complete/SyncGoalProgress/SyncInvestmentGoals/UpdateGoalProgress)+ handler + proto + scheduler
- **D-goal 只做 Investment**:scheduler SyncInvestmentGoals 算 Σ account holdings mv(经 AccountMarketValueSource port,holding 实现)写 current_amount;Savings/DebtPayoff 无自动 progress
- **Flutter 只读**:`holding/goal_view_ds`(只读 investment goals)+ `holding/goal_link_page`(holding detail 关联只读)。**无独立 lib/goal/ 模块,无 /goals 顶级路由**
- goal 类型:Savings / DebtPayoff / Investment(int+String(),DB varchar)
- account 余额源:`account.CurrentBalanceCents`(domain 字段);debt 已还源:`DebtDetails.RemainingPrincipal()`(domain)+ OriginalPrincipal

goal 模块目标:
1. **3 type 自动 progress**:Savings 算多账户余额 / DebtPayoff 算多债务已还 / Investment 算多账户 mv — scheduler 每日跑
2. **多账户聚合**:goal 关联多 account/debt(不只单账户),scheduler Σ
3. **progress 历史趋势**:每日 snapshot,详情页画曲线
4. **模板/复制**:CloneGoal + 常用目标模板(应急基金/买房首付/教育金)
5. **Flutter 独立管理 UI**:list/create/detail/edit + OD 原型设计先行

## 2. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| 3 type 自动 progress(scheduler 扩展) | goal 共享/家庭目标 |
| 多账户聚合(linked_account_ids + linked_debt_ids) | AI 目标建议 |
| progress 历史 snapshot + 趋势曲线 | goal 导出/报表 |
| CloneGoal + 模板(client seed) | server 模板表(client 常量 YAGNI) |
| Flutter lib/goal/ 4 页 + OD 原型 | holding goal_link 重构(保留,数据层复用) |
| sidebar 导航 | bottom nav(避免拥挤) |

## 3. 架构总览

```
Flutter goal UI(GoalListPage / GoalFormPage / GoalDetailPage / GoalEditPage)
   ↳ proto goal/v1 RPC
goal handler → application.Service
   ↳ CRUD + CompleteGoal + UpdateGoalProgress(手动) + CloneGoal(新)
goal scheduler(每日, 扩 D-goal)
   ├─ Investment: Σ linked_account_ids mv(AccountMarketValueSource, D-goal port 扩多账户)
   ├─ Savings:    Σ linked_account_ids 余额(新 AccountBalanceSource port)
   └─ DebtPayoff: Σ linked_debt_ids 已还(新 DebtProgressSource port)
   ↳ 写 current_amount + goal_progress_snapshot(趋势)
```

**3 个跨模块 port**(goal domain 本地接口,结构实现,goal 不 import account/debt/holding — 照 D-goal/D-currency/D-budget 模式):
- `AccountMarketValueSource.GetAccountsMarketValue(ctx, tenantID, accountIDs) (int64, error)`(D-goal 单账户 → 扩多账户)
- `AccountBalanceSource.GetAccountsBalance(ctx, tenantID, accountIDs) (int64, error)`(新,Σ CurrentBalanceCents)
- `DebtProgressSource.GetDebtsPaid(ctx, tenantID, debtIDs) (int64, error)`(新,Σ original − remaining)

## 4. server 改动

### 4.1 schema(migration `20260702_goal_multi_account_snapshot.sql`)
- **多账户关联**(替换单字段):新表 `goal_account_links(goal_id, account_id)`(Investment + Savings 共用;goal_type 区分算 mv 还是余额)+ `goal_debt_links(goal_id, debt_id)`(DebtPayoff)。无需 link_type 字段(goal_type 已区分语义)。旧 `goals.linked_account_id` 单字段迁移到 goal_account_links 后移除(或保留兼容期,Task 0 定)
- **新表 `goal_progress_snapshot`**(id, tenant_id, goal_id, snapshot_date, current_amount_cents, created_at)— 照 holding_snapshot 模式,唯一约束 (goal_id, snapshot_date)
- domain:Goal 加 `LinkedAccountIDs []uuid.UUID` + `LinkedDebtIDs []uuid.UUID`(替换单 LinkedAccountID)

### 4.2 domain 多账户
- `NewGoal(..., goalType, accountIDs []uuid.UUID, debtIDs []uuid.UUID)` 改签名
- 创建校验(按 type):Investment/Savings → accountIDs 非空且 account type 匹配(investment/asset);DebtPayoff → debtIDs 非空
- progress 派生方法不变(CurrentAmountCents/TargetAmountCents/IsCompleted)

### 4.3 scheduler 3 type + snapshot(扩 D-goal scheduler)
- `SyncAllGoals(ctx, tenantID)`:逐 goal 按 type 分支调对应 port 算 progress → SetCurrentAmount + 写 snapshot
- 复用 D-goal scheduler 骨架(MinIntervalHours + TenantLister 跨 tenant fan-out)
- best-effort(单 goal/port fail 跳过 + 日志)
- snapshot 写:upsert(照 holding_snapshot,(goal_id, snapshot_date) 唯一)

### 4.4 RPC + 创建校验
- `CloneGoal(CloneGoalRequest{source_goal_id, target_amount_cents?, deadline?, name?})`:复制 source(可改字段),reset current=0,新 linked_links 关联(深拷)
- CreateGoal/UpdateGoal 加多账户/多债务字段 + 按 type 校验关联
- UpdateGoalProgress(手动,现有)— Savings/DebtPayoff 兜底(用户记一笔贡献,加到 current;即使自动也可手动补)

### 4.5 proto
- `GoalDTO` 加 `repeated string linked_account_ids` + `repeated string linked_debt_ids`(保留单 linked_account_id 向后兼容)
- `CreateGoalRequest`/`UpdateGoalRequest` 加多账户/多债务 repeated 字段
- 新 `CloneGoalRequest` + `CloneGoalResponse`
- 新 `GetGoalProgressHistory(goal_id, from, to)` RPC → 趋势曲线(Phase 2)

## 5. client 改动(新建 `lib/goal/` DDD 四层,照 budget/holding 范式)

### 5.1 数据层
- `GoalRemoteDataSource`(GrpcClient + AuthRetryCaller → GoalServiceClient)+ mapper(GoalDTO → GoalView)
- `GoalRepositoryImpl` + abstract `GoalRepository`
- `GoalView` entity(id/name/type/target/current/deadline/linked_account_ids/linked_debt_ids/progress_pct/is_completed + 趋势 snapshots list)

### 5.2 bloc
- `GoalBloc`:LoadList / LoadDetail / Create / Update / Delete / Complete / RecordContribution(手动)/ Clone

### 5.3 四页面
1. **GoalListPage** `/goals` — 全部 goals(3 type 混合卡片 + 进度环 + 类型徽章 + deadline 倒计时 + 完成/进行中分组)+ AppBar 新建(从模板快捷)+ 卡片 → detail
2. **GoalFormPage** `/goals/new` + `/goals/:id/edit` — type picker → 动态字段(Investment/Savings 选多账户 / DebtPayoff 选多债务)+ target + deadline + "从模板"快捷(应急基金/买房/教育金)+ 关联 picker 多选
3. **GoalDetailPage** `/goals/:id` — 进度环 + **趋势曲线**(fl_chart,Phase 2)+ 关联账户/债务列表 + 手动记贡献(Savings/DebtPayoff)+ 完成/删除/编辑/复制(CloneGoal)
4. (编辑复用 GoalFormPage)

### 5.4 导航 + 复用
- router 加 `/goals` branch 7(照 budget branch 6,静态 /new /:id/edit 在 /:id 前)
- app_shell sidebar 加"目标"(lucide target/wallet icon, **仅 sidebar 不进 bottom nav**)
- holding/goal_link_page 保留(holding 视角只读投资 goal),数据层复用 lib/goal/ 的 ds/repo(或保留独立 goal_view_ds,defer 统一)

## 6. OD 原型(Phase 0,设计先行)

用 **Open Design**(MCP open-design)设计 goal UI,作 Flutter 实现的设计源(照 transaction/debt/receivables/holding 的 OD 范式):
- 4 界面(list/form/detail/edit)× desktop/tablet/mobile
- 御财设计语言(金 #b08d57 / 衬线 / 米白 / lucide icons,同 holding UI)
- mock 数据 + API 标注
- OD 项目命名:`yucai-goal-prototype`
- 若 OD agent 不可用(会话污染/上游过载),fallback 直写 HTML 原型(照 holding 原型 fallback,memory `od-prototype-to-flutter`)

## 7. 失败/降级策略
| 场景 | 处理 |
|---|---|
| port fail(单 goal) | 跳过该 goal + 日志(best-effort,照 D-goal) |
| 关联账户/债务已删 | 跳过 + 日志(snapshot 不写或写上次值) |
| snapshot 唯一冲突(同日重跑) | upsert(照 holding_snapshot) |
| CloneGoal source 不存在 | InvalidArgument |
| 手动 progress 超 target | 自动 IsCompleted(domain 已处理) |
| 多账户 picker 空 | 创建禁用(校验) |

## 8. 测试策略(全程 TDD)
- **server domain**:多账户 NewGoal 校验(type 匹配)+ CloneGoal 深拷 + progress 派生
- **server scheduler**:SyncAllGoals 3 type 分支(mock 3 port)+ snapshot upsert + best-effort skip + 跨 tenant fan-out
- **server application**:CloneGoal + CreateGoal 多账户校验 + GetGoalProgressHistory(Phase 2)
- **server e2e**:grpcurl CreateGoal(Savings 多账户)→ scheduler → GetGoal 验 current=Σ 余额;DebtPayoff 同理;Investment 多账户 Σ mv
- **Flutter**:GoalListPage(3 type 卡片/分组/倒计时)+ GoalFormPage(type picker 动态字段 + 多账户 picker + 模板)+ GoalDetailPage(进度环 + Phase 2 曲线 + 手动贡献)+ bloc(ds/repo mapper)

## 9. 前置验证(Task 0,各 Phase 起)
- Read goal domain NewGoal 完整签名 + LinkedAccountID 用法
- Read D-goal scheduler(scheduler.go)+ AccountMarketValueSource port + holding 实现
- Read account application(单/多账户余额查询:CurrentBalanceCents + 是否有 GetAccounts(ids))
- Read debt application(单/多债务 RemainingPrincipal + OriginalPrincipal + 查询)
- Read holding_snapshot 表/migration(作 goal_progress_snapshot 模板)
- Read goal proto 现有 DTO 字段(确认 linked_account_ids/CloneGoal 新增)

## 10. 实施分 phase(供 writing-plans)

### Phase 0: OD 原型(2-3 task)
OD 设计 4 界面 × 三端 + 御财设计语言;`yucai-goal-prototype` 项目;fallback 直写 HTML。

### Phase 1: 核心(server 3 type + client 基础,~10-12 task)
1. server migration(multi-account links + linked_debt + goal_progress_snapshot 表)
2. server domain(NewGoal 多账户 + 校验 + CloneGoal domain)+ 单测
3. server 3 port(AccountMarketValueSource 扩多账户 + AccountBalanceSource 新 + DebtProgressSource 新)
4. account/holding/debt 实现 3 port 结构
5. server scheduler SyncAllGoals(3 type 分支 + snapshot 写 + best-effort)+ 单测
6. server proto(GoalDTO/CreateGoal/UpdateGoal 多账户 + CloneGoal RPC)+ stub regen
7. server wire + main(3 port 注入 goal service via setter,照 D-goal)+ e2e
8. Flutter data 层(GoalRemoteDataSource + Repo + GoalView + 多账户 mapper)
9. Flutter GoalBloc + events/states
10. Flutter GoalListPage + GoalFormPage(type picker + 单账户 picker,多账户 Phase 3)
11. Flutter GoalDetailPage(进度 + 手动贡献 + 完成/删/复制)+ GoalEditPage
12. router /goals branch 7 + sidebar + e2e + final review

### Phase 2: 趋势曲线(~3 task)
1. server GetGoalProgressHistory RPC(读 snapshot 范围)+ proto
2. Flutter GoalDetailPage 趋势曲线(fl_chart,照 holding perf curve)
3. e2e + review

### Phase 3: 模板 + 多账户 picker(~3 task)
1. Flutter 模板 picker(应急基金/买房/教育金 client 常量 + 创建"从模板")
2. Flutter 关联 picker 升级多账户/多债务(单选→多选)
3. CloneGoal UI(详情页"复制")+ e2e + review

## 11. 决策记录(用户拍板)
| # | 决策 | 选定 |
|---|---|---|
| goal 范围 | MVP / 完整 CRUD + 手动 progress | **完整 CRUD + 手动 progress** |
| ① Savings/DebtPayoff progress | 纯手动 / 关联自动 / 关联手动同步 | **全关联自动算**(Savings Σ 账户余额 / DebtPayoff Σ 债务已还 / Investment Σ mv) |
| ② 关联粒度 | 单账户 / 多账户聚合 | **多账户聚合**(linked_account_ids + linked_debt_ids) |
| ③ 历史 | 仅当前 progress / snapshot 趋势 | **progress snapshot + 趋势曲线** |
| ④ 模板/复制 | defer / CloneGoal + client 模板 | **CloneGoal RPC + client 常量模板** |
| ⑤ 导航 | sidebar / sidebar+bottom nav | **仅 sidebar**(照 budget) |
| ⑥ OD 原型 | 跳过 / OD 设计先行 | **OD 原型先行**(Phase 0,照 transaction/debt 范式) |
| ⑦ holding/goal_link | 废弃 / 保留 | **保留**(holding 视角只读,数据层 defer 统一) |
| ⑧ DebtPayoff 关联 | 复用 linked_account / 新 linked_debt_id | **新 linked_debt_id**(直接关联 debt,语义清晰) |

## 12. 风险清单(plan 需显式处理)
1. **多账户 schema 改动**(linked_account_id 单 → 多关联表)— 向后兼容 + 迁移现有单账户 goal
2. **scheduler 3 type 分支复杂度**(D-goal 单 Investment → 3 type × 多账户 Σ)— 充分单测 + best-effort
3. **3 个跨模块 port**(account 余额 / debt 已还 / holding mv 多账户)— 结构实现,goal 不 import 三者(照 D-goal 模式)
4. **snapshot 表 + scheduler 写**(照 holding_snapshot,upsert,唯一约束)
5. **goal_progress_snapshot migration** dated SQL(`20260702_...sql`)
6. **wire 手改**(goal service 注入 3 port via setter,照 D-goal SetAccountMarketValueSource;见 [[yucai-wire-handmaintained]])
7. **proto regen**(多账户 repeated 字段 + CloneGoal RPC + GetGoalProgressHistory;protoc_plugin 25.0.0)
8. **OD 原型 agent 可能不可用**(会话污染,holding 原型时遇过)— fallback 直写 HTML
9. **fl_chart 趋势曲线**(Phase 2,照 holding perf curve 模式,fl_chart 1.x API)
10. **多账户 picker UI**(Phase 3,单选→多选升级,AccountType filter by goal type)

## 13. 参考
- D-goal:[goal scheduler](../../yucai/server/internal/goal/scheduler/scheduler.go)(AccountMarketValueSource + TenantLister fan-out 模式)
- account 余额:[CurrentBalanceCents](../../yucai/server/internal/account/domain/entity.go) + SumBalancesByCurrency(D-currency)
- debt 已还:[RemainingPrincipal](../../yucai/server/internal/debt/domain/entity.go#L119) + OriginalPrincipal
- holding_snapshot(C):migration + upsert 模式(goal_progress_snapshot 模板)
- budget D-budget:[port 模式](../../yucai/server/internal/budget/application/service.go)(函数注入,entryFunc)+ Flutter DDD 四层 + sidebar 导航
- 相关:[[yucai-wire-handmaintained]] [[yucai-dev-env]] [[od-prototype-to-flutter]]
