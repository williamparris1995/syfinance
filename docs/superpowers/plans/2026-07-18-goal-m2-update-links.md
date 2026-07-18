# goal M2 · UpdateGoal 关联修改 · Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `UpdateGoal` 支持改关联 accounts/debts(现状 service 不设 linked → repo.Update replaceLinks 旧值无变化)。

**Architecture:** domain `Goal.UpdateLinks` setter(设 LinkedAccountIDs/LinkedDebtIDs)+ service `UpdateGoalRequest` +2 field + `UpdateGoal` 调 `goal.UpdateLinks` + handler 解析 proto linked(已有 field 7/8)+ client edit form picker。**零 proto / 零 adapter**(adapter `Update` 已调 `replaceAccountLinks`/`replaceDebtLinks` + legacy,spec §6.2 勘误)/ 零 schema / 零 wire。全替换语义(照 Create)。

**Tech Stack:** Go ent + DDD · Flutter flutter_bloc · TDD

---

## Global Constraints

(每个 task 隐含;从 spec §3/§9 + CLAUDE.md)

1. **英文 slog**(无 CJK)。
2. **proto 零改**:`UpdateGoalRequest` `linked_account_ids=7`/`linked_debt_ids=8` 已有(handler 不用 → M2 接上)。
3. **adapter 零改**(spec §6.2 勘误):[goal_repo.go `Update`](../../yucai/server/internal/goal/adapter/driven/repository/goal_repo.go#L168)(line 168-206)**已调** `replaceAccountLinks`+`replaceDebtLinks`(line 199-204)+ legacy `SetLinkedAccountID`(line 185-189),照 `Save`。M2 gap 只在 service 不设 `goal.LinkedAccountIDs/LinkedDebtIDs`。
4. **`Goal.UpdateLinks` setter**(spec §6.3 决策):设 LinkedAccountIDs/LinkedDebtIDs,**不 IncrementVersion**(UpdateGoal 统一 IncrementVersion,避免 version+2)。
5. **全替换语义**(replaceLinks delete-all-then-insert,照 Create)。
6. **照 Create 非原子**(Update + replaceLinks 多 SQL 无 tx;defer 事务 follow-up)。
7. **interface 不变**(`GoalRepository.Update` 签名不变 → 无 implementer 影响,约束 6)。
8. **commit multi `-m`**,TDD。

---

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| [goal/domain/entity.go](../../yucai/server/internal/goal/domain/entity.go) | `Goal` | +`UpdateLinks(accountIDs, debtIDs []uuid.UUID)` setter(设 LinkedAccountIDs/LinkedDebtIDs,**不 IncrementVersion**) |
| [goal/application/service.go](../../yucai/server/internal/goal/application/service.go) | `Service` | `UpdateGoalRequest` +`LinkedAccountIDs`/`LinkedDebtIDs` field;`UpdateGoal` 调 `goal.UpdateLinks` → IncrementVersion → `repo.Update`(已 replaceLinks) |
| [goal/application/dto.go](../../yucai/server/internal/goal/application/dto.go)(或 service.go inline) | DTO | `UpdateGoalRequest` +2 field |
| [goal/adapter/driving/grpc/goal_handler.go](../../yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go) | handler | `UpdateGoal` 解析 `req.LinkedAccountIds`/`LinkedDebtIds`(uuid.Parse each)→ service |
| [goal/domain/entity_test.go](../../yucai/server/internal/goal/domain/entity_test.go) | domain test | +`TestGoal_UpdateLinks` |
| [goal/application/service_test.go](../../yucai/server/internal/goal/application/service_test.go) | app test | +UpdateGoal linked 测 |
| client goal edit form | page | 关联 picker(照 create form;预填 + 提交 linked) |
| client goal test | test | edit form linked 测 |

**不改**:proto / ent schema / adapter repo(`Update` 已 replaceLinks)/ wire / `GoalRepository` interface。

---

## Task 1: server — domain setter + service 设 linked + handler 解析

domain + application + handler + test。零 adapter / 零 proto。

**Files:**
- Modify: [goal/domain/entity.go](../../yucai/server/internal/goal/domain/entity.go)
- Modify: [goal/application/service.go](../../yucai/server/internal/goal/application/service.go) (+ dto.go inline)
- Modify: [goal/adapter/driving/grpc/goal_handler.go](../../yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go)
- Modify: domain test + application test

**Interfaces:**
- Consumes: 现有 `Goal.LinkedAccountIDs`/`LinkedDebtIDs`([]uuid.UUID);`IncrementVersion`;`repo.Update`(已 replaceLinks);proto `req.LinkedAccountIds`/`LinkedDebtIds`(field 7/8)
- Produces: `Goal.UpdateLinks` + service UpdateGoal 设 linked + handler 解析

- [ ] **Step 1: 写 domain 测(失败态)**

[entity_test.go](../../yucai/server/internal/goal/domain/entity_test.go)(照现有 Goal 测范式):
```go
func TestGoal_UpdateLinks(t *testing.T) {
	g := newTestGoal(t) // 现有 helper or construct
	acc1, acc2, debt1 := uuid.New(), uuid.New(), uuid.New()
	g.UpdateLinks([]uuid.UUID{acc1, acc2}, []uuid.UUID{debt1})
	if len(g.LinkedAccountIDs) != 2 || g.LinkedAccountIDs[0] != acc1 || g.LinkedAccountIDs[1] != acc2 {
		t.Errorf("LinkedAccountIDs: got %v, want [%s %s]", g.LinkedAccountIDs, acc1, acc2)
	}
	if len(g.LinkedDebtIDs) != 1 || g.LinkedDebtIDs[0] != debt1 {
		t.Errorf("LinkedDebtIDs: got %v, want [%s]", g.LinkedDebtIDs, debt1)
	}
	// full-replace: second call clears old
	g.UpdateLinks(nil, nil)
	if len(g.LinkedAccountIDs) != 0 || len(g.LinkedDebtIDs) != 0 {
		t.Errorf("clear: got accounts=%v debts=%v, want empty", g.LinkedAccountIDs, g.LinkedDebtIDs)
	}
	// UpdateLinks does NOT IncrementVersion (UpdateGoal owns version bump)
	// (verify version unchanged across UpdateLinks calls — 照 spec §6.3 决策)
}
```

- [ ] **Step 2: 跑测看失败**

Run: `cd yucai/server && go test ./internal/goal/domain/... -run TestGoal_UpdateLinks -count=1`
Expected: FAIL(`g.UpdateLinks undefined`)

- [ ] **Step 3: 加 domain Goal.UpdateLinks setter**

[entity.go](../../yucai/server/internal/goal/domain/entity.go)(照现有 setter 范式):
```go
// UpdateLinks replaces the goal's linked account + debt IDs (full-replace,
// mirrors CreateGoal's link setup). Does NOT bump version — UpdateGoal owns
// the version bump so a single UpdateGoal call = single IncrementVersion.
func (g *Goal) UpdateLinks(accountIDs, debtIDs []uuid.UUID) {
	g.LinkedAccountIDs = accountIDs
	g.LinkedDebtIDs = debtIDs
}
```

- [ ] **Step 4: 跑 domain 测通过**

Run: `cd yucai/server && go test ./internal/goal/domain/... -run TestGoal_UpdateLinks -count=1`
Expected: PASS

- [ ] **Step 5: 改 service UpdateGoalRequest + UpdateGoal 设 linked**

[service.go:97-119](../../yucai/server/internal/goal/application/service.go#L97):

`UpdateGoalRequest` 加 2 field(dto.go 或 service.go inline,grep `UpdateGoalRequest struct`):
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
	goal.UpdateLinks(req.LinkedAccountIDs, req.LinkedDebtIDs) // M2: set links (setter, no version bump)
	goal.IncrementVersion()                                    // 统一 version bump (现状已有,保留)

	if err := s.repo.Update(ctx, goal); err != nil {
		return nil, fmt.Errorf("update goal: %w", err)
	}
```

> `goal.IncrementVersion()` 现状 line 111 已有(保留);UpdateLinks setter 不 IncrementVersion → 单次 +1(避免 +2)。

- [ ] **Step 6: 改 handler 解析 linked**

[goal_handler.go:73-105](../../yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go#L73) `UpdateGoal`:

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
		TenantID:          tenantID,
		ID:                id,
		Name:              req.Name,
		TargetAmountCents: req.TargetAmountCents,
		Deadline:          deadline,
		Notes:             req.Notes,
		Version:           req.Version,
		LinkedAccountIDs:  accountIDs, // M2
		LinkedDebtIDs:     debtIDs,    // M2
	})
```

- [ ] **Step 7: 写 application 测(UpdateGoal linked)**

[service_test.go](../../yucai/server/internal/goal/application/service_test.go)(照现有 UpdateGoal 测范式 + fakeGoalRepo):
```go
// TestUpdateGoal_ChangesLinks verifies UpdateGoal persists new linked
// accounts/debts (full-replace). The repo fake records the goal passed to
// Update so the test asserts links reached the repo (which replaceLinks them).
func TestUpdateGoal_ChangesLinks(t *testing.T) {
	acc1, acc2, debt1 := uuid.New(), uuid.New(), uuid.New()
	repo := &fakeGoalRepo{goal: &domain.Goal{ID: uuid.New(), Version: 1, LinkedAccountIDs: []uuid.UUID{uuid.New()}}}
	svc := NewService(repo, nil, nil, nil) // 照现有 NewService 签名
	_, err := svc.UpdateGoal(ctx, UpdateGoalRequest{
		ID: repo.goal.ID, Version: 1,
		LinkedAccountIDs: []uuid.UUID{acc1, acc2},
		LinkedDebtIDs:    []uuid.UUID{debt1},
	})
	if err != nil { t.Fatalf("UpdateGoal: %v", err) }
	// repo.Update received goal with new links (full-replace).
	got := repo.updatedGoal // fake records last Update arg
	if len(got.LinkedAccountIDs) != 2 || got.LinkedAccountIDs[0] != acc1 { t.Errorf("...") }
	if len(got.LinkedDebtIDs) != 1 || got.LinkedDebtIDs[0] != debt1 { t.Errorf("...") }
}
```

> plan 确认:`fakeGoalRepo` 现有(Update 记录)+ `NewService` 签名(grep service_test 现有 setup)。

- [ ] **Step 8: 跑测 + build + 全量**

Run: `cd yucai/server && go test ./internal/goal/... -count=1`(domain + application UpdateLinks/UpdateGoal + 现有不回归)
Run: `cd yucai/server && go build ./...`
Run: `cd yucai/server && go test ./... -count=1`

- [ ] **Step 9: Commit**

```bash
cd e:/projects/syfinance
git add yucai/server/internal/goal/domain/entity.go \
  yucai/server/internal/goal/domain/entity_test.go \
  yucai/server/internal/goal/application/service.go \
  yucai/server/internal/goal/application/service_test.go \
  yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go
git commit -m "feat(goal): UpdateGoal linked accounts/debts (M2 Task 1)" -m "domain Goal.UpdateLinks setter + service UpdateGoalRequest +LinkedAccountIDs/LinkedDebtIDs + UpdateGoal 调 goal.UpdateLinks (repo.Update 已 replaceLinks 照 Save, adapter 不动) + handler parse req.LinkedAccountIds/LinkedDebtIds (proto field 7/8 已有). full-replace (照 Create). UpdateLinks setter 不 IncrementVersion (UpdateGoal 统一). zero proto/adapter/schema/wire."
```

---

## Task 2: client — goal edit form 关联 picker

client goal edit form 加关联 picker(照 create form;预填 + 提交 linked)。

**Files:**
- Modify: client goal edit form(grep `goal.*form` / `goal_edit` / `GoalFormPage`)
- Modify: client goal test

**Interfaces:**
- Consumes: Task 1 proto linked field(已有 stub);goal create form 关联 picker 范式
- Produces: edit form 改 linked

- [ ] **Step 1: 定位 goal create form 关联 picker**

Grep client goal form(`goal_form_page` / `GoalFormPage` / `account.*picker` / `debt.*picker`)找 create form 的关联 picker widget(account multi-select + debt multi-select for DebtPayoff)。确认 edit 模式(`_isEdit` / `goalId != null`)现状 + 是否复用 create 的 picker。

- [ ] **Step 2: edit form 加关联 picker(预填 + 提交)**

edit 模式:预填 `goal.linkedAccountIds`/`linkedDebtIds` → picker 选 → 提交 `UpdateGoalRequested`(带 linked_account_ids/linked_debt_ids)。proto stub `UpdateGoalRequest` linked field 已有(field 7/8,Dart gen)。

照 create form picker 范式(account multi-select filter by goal type:Investment/Savings → asset accounts;DebtPayoff → debts)。

> plan 确认:create form 关联 picker widget(`AccountMultiSelect` / `DebtMultiSelect` 或 inline);edit form 复用;goal bloc `UpdateGoalRequested` event 是否已有 linked field(若否,加)。

- [ ] **Step 3: client 测**

widget test:edit 模式预填 linked + 提交 UpdateGoalRequested(linked)。(基线 4 fail CLAUDE.md,不引入新。)

- [ ] **Step 4: analyze + test + build**

Run: `cd yucai/client && flutter analyze`(22 基线无新增)
Run: `cd yucai/client && flutter test test/goal/`(新测过)
Run: `cd yucai/client && flutter build windows --debug`

- [ ] **Step 5: Commit**

```bash
cd e:/projects/syfinance
git add yucai/client/lib/goal/... yucai/client/test/goal/...
git commit -m "feat(goal/client): edit form linked accounts/debts picker (M2 Task 2)" -m "goal edit form 加关联 picker (照 create, 预填 goal.linkedAccountIds/linkedDebtIds + 提交 UpdateGoalRequested linked). proto stub field 7/8 已有."
```

---

## Spec coverage 矩阵 + §6.2 勘误

**spec §6.2 勘误**:spec 假设 "adapter `Update` 加 replaceLinks" —— **错误**。[goal_repo.go Update:168-206](../../yucai/server/internal/goal/adapter/driven/repository/goal_repo.go#L168) **已调** `replaceAccountLinks`+`replaceDebtLinks`(line 199-204)+ legacy(line 185-189),照 `Save`。**M2 不动 adapter**。真 gap:service 不设 `goal.LinkedAccountIDs/LinkedDebtIDs`(Task 1 Step 5)+ handler 不解析(Task 1 Step 6)。

| spec 决策/章节 | 落地 task | 备注 |
|---|---|---|
| §3 #1 全替换 | Task 1 UpdateLinks setter + adapter(已 replaceLinks) | |
| §3 #2 Goal.UpdateLinks | Task 1 Step 3 | setter 不 IncrementVersion(§6.3) |
| §3 #3 adapter Update replaceLinks | **不改**(已调,line 199-204) | §6.2 勘误 |
| §3 #4 interface 不变 | Task 1(adapter 不动) | |
| §3 #5 proto 零改 | 全 plan | field 7/8 已有 |
| §3 #6 非原子 | 全 plan(照 Create) | defer 事务 |
| §3 #7 client form | Task 2 | 照 create picker |
| §6.1 Goal.UpdateLinks | Task 1 Step 3 | |
| §6.2 adapter Update | **勘误:不改** | Update 已 replaceLinks |
| §6.3 service UpdateGoal | Task 1 Step 5 | |
| §6.4 handler | Task 1 Step 6 | |
| §6.5 client form | Task 2 | |
| §9 风险 1 IncrementVersion | Task 1 Step 5(UpdateLinks 不 IncrementVersion,UpdateGoal 统一) | |
| §9 风险 2 Save 范式 | 确认 Save 调 replaceLinks(goal_repo.go:67-72) | Update 同(199-204) |
