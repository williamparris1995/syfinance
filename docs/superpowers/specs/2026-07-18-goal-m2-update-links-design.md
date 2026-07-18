# goal M2 · UpdateGoal 关联修改 · 设计 spec

- **日期**: 2026-07-18
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans → subagent session)
- **分支**: 待定(main-driven,从 main 最新 `ed5dafd`)
- **范围**: goal M2 defer —— `UpdateGoal` 支持改关联 accounts/debts(现状只改 Name/Target/Deadline/Notes,关联不可改)。**proto 零改**(UpdateGoalRequest linked_account_ids=7/linked_debt_ids=8 已有);domain + service + handler + adapter repo.Update(加 replaceLinks)+ client form。

## 1. 背景

D-goal([2026-06-30-holding-goal-design.md](2026-06-30-holding-goal-design.md))Task 8 加多账户/多债务关联(`LinkedAccountIDs`/`LinkedDebtIDs`,CreateGoal 设)。但 **UpdateGoal 不改关联**:

- **proto** `UpdateGoalRequest` **已有** `linked_account_ids=7` + `linked_debt_ids=8`([goal.proto:72-73](../../yucai/proto/goal/v1/goal.proto#L72))—— 但 handler 不解析,service 不用。
- **service** [UpdateGoal](../../yucai/server/internal/goal/application/service.go#L97) 只改 `Name`/`TargetAmountCents`/`Deadline`/`Notes` + `IncrementVersion`;**不改 `LinkedAccountIDs`/`LinkedDebtIDs`**。
- **adapter** `GoalRepository.Update`(interface)只 update goal fields;`replaceAccountLinks`/`replaceDebtLinks`([goal_repo.go:357-400](../../yucai/server/internal/goal/adapter/driven/repository/goal_repo.go#L357),private,delete-all-then-insert)Create 用(Save 内部调),**Update 不调**。
- **domain** `Goal` 缺 `UpdateLinks` method(memory holding "domain 缺 UpdateLinks 方法")。

**用户痛点**:创建 goal 后不能加减关联账户(Investment/Savings)或债务(DebtPayoff)。需删重建。

memory `holding-asset-management-todo` goal defer M2:"UpdateGoal 关联修改(domain 缺 UpdateLinks 方法)"。

## 2. 目标

- `UpdateGoal` 支持改关联 accounts/debts(全替换,照 Create)
- domain `Goal.UpdateLinks` method
- adapter `Update` 加 `replaceLinks`(照 `Save`,interface 不变)
- handler 解析 linked(proto field 已有)
- client goal edit form 加关联 picker(照 create form)
- **proto 零改**;事务照 Create 非原子(defer)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | linked 改语义 | **全替换**(replaceLinks delete-all-then-insert) | 照 Create + 现有 replaceAccountLinks/replaceDebtLinks;简单;diff(add/remove)复杂收益小 |
| 2 | domain method | **`Goal.UpdateLinks(accountIDs, debtIDs []uuid.UUID)`**(设 + IncrementVersion) | memory "domain 缺 UpdateLinks";照 UpdateItem/UpdateName 范式 |
| 3 | adapter Update 加 replaceLinks | **`Update` 内部加 `replaceAccountLinks`+`replaceDebtLinks`**(照 `Save`) | interface `Update` 不变(service 调用不变);links 是 goal 状态的一部分,Update 应 persist links 一致(照 Save 内部调 replaceLinks) |
| 4 | interface 改动 | **`GoalRepository` interface 不变**(`Update` 已有) | adapter 内部加 replaceLinks;无 implementer 影响(约束 6) |
| 5 | proto | **零改**(linked_account_ids=7/linked_debt_ids=8 已有) | 现有 field 只需 handler 解析 |
| 6 | 事务 | **照 Create 非原子**(`Update` goal fields + replaceLinks 多 SQL,无 tx) | Create 也是 Save + replaceLinks 非事务;一致;M5(WriteSnapshot 事务)是另一处;goal update 事务可独立 follow-up |
| 7 | client form | **goal edit form 加关联 picker(照 create form)** | proto stub linked field 已 gen;create form 有 picker 范式 |
| 8 | 所有 goal type | **都可改关联**(Investment accounts / Savings accounts / DebtPayoff debts) | 用户改 goal 关联不应限 type |

## 4. 范围边界

| 在范围(M2) | 不在范围(defer / out) |
|---|---|
| domain `Goal.UpdateLinks`(accountIDs, debtIDs)+ IncrementVersion | goal update 事务(defer,照 Create 非原子) |
| adapter `GoalRepository.Update` 内部加 replaceAccountLinks/replaceDebtLinks | M5 WriteSnapshot 事务(另一 defer) |
| application `UpdateGoalRequest` +LinkedAccountIDs/LinkedDebtIDs;`UpdateGoal` 调 `goal.UpdateLinks` | edit-mode type 改(已处理 0510b7d) |
| handler 解析 req.LinkedAccountIds/LinkedDebtIds | Phase 3 Minor polish |
| client goal edit form 关联 picker(照 create) | |
| proto / ent schema / wire | **零改** |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| **domain**(goal) | `Goal` | +`UpdateLinks(accountIDs, debtIDs []uuid.UUID)`(设 LinkedAccountIDs/LinkedDebtIDs + IncrementVersion) |
| **adapter/driven**(goal) | `GoalRepository.Update`([goal_repo.go](../../yucai/server/internal/goal/adapter/driven/repository/goal_repo.go)) | Update 内部加 `replaceAccountLinks`+`replaceDebtLinks`(照 `Save`) |
| **application**(goal) | `Service.UpdateGoal`([service.go:97](../../yucai/server/internal/goal/application/service.go#L97)) | `UpdateGoalRequest` +LinkedAccountIDs/LinkedDebtIDs field;`UpdateGoal` 调 `goal.UpdateLinks` → `repo.Update` |
| **adapter/driving**(goal) | `GoalHandler.UpdateGoal`([goal_handler.go:73](../../yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go#L73)) | 解析 `req.LinkedAccountIds`/`LinkedDebtIds`(uuid.Parse each)→ service |
| **client** | goal edit form | 关联 picker(照 create form;多选 account/debt) |

**不改**:proto / ent schema / wire / interface(`GoalRepository.Update` 签名不变 → 无 implementer 影响)。

## 6. 核心改动

### 6.1 domain — Goal.UpdateLinks

[goal/domain/](../../yucai/server/internal/goal/domain/)(照 UpdateItem/UpdateName 范式):

```go
// UpdateLinks replaces the goal's linked account + debt IDs (full-replace,
// mirrors CreateGoal's link setup via replaceAccountLinks/replaceDebtLinks).
// Bumps version (links are part of the goal's mutable state — progress
// recomputation depends on them).
func (g *Goal) UpdateLinks(accountIDs, debtIDs []uuid.UUID) {
	g.LinkedAccountIDs = accountIDs
	g.LinkedDebtIDs = debtIDs
	g.IncrementVersion()
}
```

> plan 确认 `Goal` struct field 类型(`LinkedAccountIDs []uuid.UUID` / `LinkedDebtIDs []uuid.UUID`,从 networth/goal 范式推断;grep goal domain entity 确认)+ `IncrementVersion` 存在(D-goal 有)。

### 6.2 adapter — Update 加 replaceLinks

[goal_repo.go](../../yucai/server/internal/goal/adapter/driven/repository/goal_repo.go) `Update`(照 `Save` 内部调 replaceLinks 范式):

```go
// Update persists changes to a goal (optimistic lock) + replaces its linked
// accounts/debts (full-replace via replaceAccountLinks/replaceDebtLinks,
// mirroring Save). M2: previously Update only persisted goal fields, leaving
// links stale; now links follow CreateGoal's pattern.
func (r *GoalRepository) Update(ctx context.Context, g *domain.Goal) error {
	update := r.client.Goal.UpdateOneID(g.ID).
		Where(goal.Version(g.Version - 1)).
		SetName(g.Name).
		// ... existing fields (TargetAmountCents/Notes/Deadline/IsCompleted/...) ...
		SetVersion(g.Version).
		SetUpdatedAt(g.UpdatedAt)
	// ... existing deadline/completedAt/linkedAccountID(legacy) nillable sets ...
	if _, err := update.Save(ctx); err != nil {
		return fmt.Errorf("update goal: %w", err)
	}
	// M2: replace multi-account + multi-debt links (照 Save).
	if err := r.replaceAccountLinks(ctx, g); err != nil {
		return err
	}
	if err := r.replaceDebtLinks(ctx, g); err != nil {
		return err
	}
	return nil
}
```

> plan 确认:`Save` 内部确实调 `replaceAccountLinks`/`replaceDebtLinks`(grep goal_repo.go Save body 确认范式);`Update` 现有 field sets(照 line 168-206 `Update` 全文,不漏 field)。

### 6.3 application — UpdateGoalRequest + UpdateGoal

[service.go:97-119](../../yucai/server/internal/goal/application/service.go#L97):

`UpdateGoalRequest` 加 2 field(dto.go 或 service.go inline):
```go
type UpdateGoalRequest struct {
	TenantID          uuid.UUID
	ID                uuid.UUID
	Name              string
	TargetAmountCents int64
	Deadline          *time.Time
	Notes             string
	Version           int64
	LinkedAccountIDs  []uuid.UUID  // M2: full-replace linked accounts
	LinkedDebtIDs     []uuid.UUID  // M2: full-replace linked debts
}
```

`UpdateGoal` 加 `goal.UpdateLinks`:
```go
	goal.Name = req.Name
	goal.TargetAmountCents = req.TargetAmountCents
	goal.Deadline = req.Deadline
	goal.Notes = req.Notes
	goal.UpdateLinks(req.LinkedAccountIDs, req.LinkedDebtIDs) // M2: replaces links + IncrementVersion
	// (UpdateLinks 已 IncrementVersion;若 UpdateGoal 上方也有 IncrementVersion,去重 —— plan 确认 IncrementVersion 不重复)

	if err := s.repo.Update(ctx, goal); err != nil {
		return nil, fmt.Errorf("update goal: %w", err)
	}
```

> IncrementVersion:现状 `UpdateGoal` line 111 调 `goal.IncrementVersion()`。M2 改用 `goal.UpdateLinks`(内含 IncrementVersion)。**去重**:若 UpdateLinks IncrementVersion + UpdateGoal 也 IncrementVersion → version +2。改:UpdateGoal 去掉单独 IncrementVersion,用 UpdateLinks(IncrementVersion)。或 UpdateLinks 不 IncrementVersion(只设 links),UpdateGoal 保留 IncrementVersion。**plan 决定**(推荐 UpdateLinks 不 IncrementVersion,UpdateGoal 保留 IncrementVersion —— UpdateLinks 是 setter,version 由 UpdateGoal 统一)。

### 6.4 handler — 解析 linked

[goal_handler.go:73-105](../../yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go#L73):

```go
	// M2: linked accounts/debts (proto UpdateGoalRequest field 7/8).
	accountIDs := make([]uuid.UUID, 0, len(req.LinkedAccountIds))
	for i, a := range req.LinkedAccountIds {
		id, err := uuid.Parse(a)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid linked_account_ids[%d]: %v", i, err)
		}
		accountIDs = append(accountIDs, id)
	}
	debtIDs := make([]uuid.UUID, 0, len(req.LinkedDebtIds))
	for i, d := range req.LinkedDebtIds {
		id, err := uuid.Parse(d)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid linked_debt_ids[%d]: %v", i, err)
		}
		debtIDs = append(debtIDs, id)
	}

	resp, err := h.service.UpdateGoal(ctx, application.UpdateGoalRequest{
		// ... existing fields ...
		LinkedAccountIDs: accountIDs, // M2
		LinkedDebtIDs:    debtIDs,    // M2
	})
```

### 6.5 client — goal edit form 关联 picker

[client goal form](../../yucai/client/lib/goal/presentation/pages/)(照 create form 的 account/debt picker;plan 确认 create form 范式):

goal edit form 加 account multi-select(Investment/Savings goal)+ debt multi-select(DebtPayoff goal)picker。edit 时预填 goal.linkedAccountIds/linkedDebtIds;提交 UpdateGoalRequested 带 linked。proto stub linked field 已 gen(UpdateGoalRequest field 7/8)。

> plan 确认:goal create form 现有关联 picker widget(account/debt multi-select);edit form 复用 + 预填 + 提交 linked。

## 7. 数据流

- **UpdateGoal**(改关联):client edit form(选 accounts/debts)→ `UpdateGoalRequested`(linked)→ repo → RPC → handler(解析 linked)→ service(`goal.UpdateLinks` → `repo.Update` 内 replaceLinks)→ 响应。**全替换** links(delete old + insert new)。
- **IncrementVersion**:UpdateGoal 统一 IncrementVersion(UpdateLinks setter 不 IncrementVersion,plan 决定)。
- **事务**:Update goal fields + replaceAccountLinks + replaceDebtLinks 三 SQL 非原子(照 Create 非事务;defer 事务 follow-up)。

## 8. 测试

- **domain** `Goal.UpdateLinks`:设 LinkedAccountIDs/LinkedDebtIDs(全替换);plan 决定 IncrementVersion(若 UpdateLinks 含,单测验证 +1)。
- **adapter** `Update`(enttest):goal fields update + links replace(改 linked → FindByID 返新 linked,旧删)。照 Save 测范式。
- **application** `UpdateGoal`:FindByID + UpdateLinks + repo.Update → linked 持久;version 乐观锁(照现状)。
- **handler** `UpdateGoal`:解析 linked(uuid.Parse invalid → InvalidArgument);linked 传 service。
- **client** form:edit 预填 linked + 提交 UpdateGoalRequested(linked)。
- **回归**:CreateGoal linked 测不回归(Save 不动);UpdateGoal 现有测(name/target)不回归。

## 9. 风险

1. **IncrementVersion 重复**(§6.3):UpdateGoal 现状 IncrementVersion + UpdateLinks 若也 IncrementVersion → version +2。**plan 决定**:UpdateLinks 不 IncrementVersion(setter),UpdateGoal 保留 IncrementVersion(统一)。
2. **Update adapter 加 replaceLinks**(plan 确认 Save 范式):grep `Save` body 确认内部调 replaceAccountLinks/replaceDebtLinks(照加)。若 Save 不调(service separate 调),Update 应 mirror service 调用方式。
3. **interface 不变**(约束 6):`GoalRepository.Update` 签名不变 → 无 implementer 影响。adapter 内部加 replaceLinks(private method call)。
4. **事务非原子**:Update + replaceLinks 多 SQL。照 Create 非原子(defer)。若 Update goal fields 成功 + replaceLinks 失败 → links stale(旧)。罕见(edit 低频)+ 影响轻(下次 sync 重算 progress)。defer 事务。
5. **client form**(plan 确认):goal create form 现有关联 picker widget;edit form 复用。若 create form picker 不复用(edit/create form 不同),plan 适配。
6. **legacy linked_account_id=8/6**(proto 单账户 legacy,back-compat):UpdateGoalRequest linked_account_id(line 8?)—— plan 确认是否需同步 legacy 单账户 field(或只多账户 linked_account_ids=7)。

## 10. 参考

- D-goal spec:[2026-06-30-holding-goal-design.md](2026-06-30-holding-goal-design.md)(Task 8 多账户/多债务关联 + UpdateGoal MVP 不改关联)
- goal M2 现状:[UpdateGoal service:97](../../yucai/server/internal/goal/application/service.go#L97)(只改 name/target/deadline/notes)+ [replaceAccountLinks/replaceDebtLinks:357](../../yucai/server/internal/goal/adapter/driven/repository/goal_repo.go#L357)(Create 用,Update 不调)
- proto UpdateGoalRequest:[goal.proto:65-73](../../yucai/proto/goal/v1/goal.proto#L65)(linked_account_ids=7/linked_debt_ids=8 已有)
- memory:`holding-asset-management-todo`(goal defer M2 UpdateLinks)
