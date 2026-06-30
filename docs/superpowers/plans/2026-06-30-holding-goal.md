# Holding 子项目 D-goal · holding-backed 投资目标 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 investment goal 接通 holding —— investment goal 关联 investment account(复用 `linked_account_id`),goal scheduler 每日算该账户 Σ holdings 市值写 `goal.current_amount`,Flutter goal_link 接真显示进度。零新表/字段。

**Architecture:** server 端 goal domain 加 `SetCurrentAmount` + `GoalRepository.FindAll` type filter + goal application `SyncInvestmentGoals`(调 holding `GetAccountMarketValue` port)+ goal scheduler(第 4 个,照 B 模式)+ proto `ListGoals` 加 `goal_type` filter + `SyncInvestmentGoals` RPC;holding application 暴露 `GetAccountMarketValue(tenantID, accountID)` 结构满足 goal 的 `AccountMarketValueSource` port(跨模块,goal 不 import holding);Flutter goal_link 调 `ListGoals(type=investment)` 填 ⏳D 空态。

**Tech Stack:** Go(ent + grpc + slog)+ proto3 + Flutter(flutter_bloc + injectable + grpc stub + equatable)

**Spec:** [docs/superpowers/specs/2026-06-30-holding-goal-design.md](../specs/2026-06-30-holding-goal-design.md)

## Global Constraints

- **分支**:`holding-asset-management`(A/B/C 已合并,C 续做 D-goal)
- **零新表/字段**:复用 `goal.linked_account_id` + `Account.category="investment"` + `GoalType.investment`(均现有)。不加 ent schema,不跑 ent 生成
- **goal.proto 现状(已 Read 确认)**:`GoalDTO` **已有** `current_amount_cents`/`target_amount_cents`/`progress_pct`/`remaining_cents`/`linked_account_id`/`goal_type`(D-goal **零 DTO 改**,Flutter 直接用);`ListGoalsRequest` 现有 `page`+`completed`(**无 goal_type filter**,D-goal 加);`SyncGoalProgress` RPC 已有(savings stub,D-goal **新增 `SyncInvestmentGoals`** 批量 investment)
- **GoalRepository.FindAll 现状**:`FindAll(ctx, tenantID, completed*, page)` **无 type filter**,D-goal 加 `goalType*` 参数(nil=全部,向后兼容现有 ListGoals 调用)
- **Goal domain 现有**:`AddProgress(amount)`/`MarkCompleted`/`ProgressPct`/`RemainingAmount`(D-goal **加 `SetCurrentAmount(amt)`**,investment 进度从 mv 设)
- **holding GetAccountMarketValue(tenantID, accountID)**:**tenant-scoped**(用具体 tenantID,避免 C concern 3 的 `FindAll(Nil)` ent 返空问题),Σ holdings(qty × current_price)under account
- **AccountMarketValueSource port**:goal domain 本地接口(`GetAccountMarketValue(ctx, tenantID, accountID)(int64, error)`),holding application.Service 结构实现(**goal 不 import holding**,类似 C 的 RateHistoryRepository 结构 port)
- **goal scheduler 第 4 个**:照搬 [B holding/scheduler/scheduler.go](../../yucai/server/internal/holding/scheduler/scheduler.go) 模式(SnapshotScheduler 改名),复用同一 IntervalSource(auth.TenantRepository)
- **wire 工具链坏**:`wire_gen.go` 手改镜像 B/C,不跑 wire CLI(见 [[yucai-wire-handmaintained]])
- **Dart stub 重生成**:`cd yucai/proto && bash gen-dart.sh`(make 不在 Bash PATH;protoc_plugin 25.0.0)。Go stub:`cd yucai/proto && buf generate --template buf.gen.go.yaml`
- **English 结构化日志**(CLAUDE.md AI 约束#2);CJK 只在用户可见 Dart UI(御财 Flutter 无强制 i18n)
- **复用第一**:goal scheduler 严格对齐 B `holding/scheduler/scheduler.go`;跨模块 port 对齐 C `RateHistoryRepository`
- **失败策略**:SyncInvestmentGoals best-effort(单 goal/holding mv fail 不中断);scheduler errors logged 不退出循环
- **每 task 末尾 commit**:conventional commit 中文 header(对齐 git log),如 `feat(holding-d-goal-server): ...`
- **flutter analyze 基线 = 22 error**(全 `*.pbserver.dart`,客户端未用);fl_chart 1.x(holding 模块已知)

## File Structure

### server 新建
- `yucai/server/internal/goal/scheduler/scheduler.go` — GoalScheduler(照 B 模式)
- `yucai/server/internal/goal/scheduler/scheduler_test.go` — scheduler 单测

### server 修改
- `yucai/server/internal/goal/domain/entity.go` — Goal 加 `SetCurrentAmount`
- `yucai/server/internal/goal/domain/repository.go` — `GoalRepository.FindAll` 加 `goalType*` 参数 + 新增 `AccountMarketValueSource` port
- `yucai/server/internal/goal/adapter/driven/repository/goal_repo.go` — FindAll type filter 实现
- `yucai/server/internal/goal/application/service.go` — `SyncInvestmentGoals` + `ListGoals` 传 type + `SetAccountMarketValueSource` setter
- `yucai/server/internal/goal/application/dto.go` — `ListGoalsRequest` 加 `GoalType *GoalType`
- `yucai/server/internal/goal/application/service_test.go` — SyncInvestmentGoals 单测
- `yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go` — `SyncInvestmentGoals` handler + `ListGoals` type 映射
- `yucai/server/internal/holding/application/service.go` — 加 `GetAccountMarketValue(ctx, tenantID, accountID)`
- `yucai/proto/goal/v1/goal.proto` — `ListGoalsRequest` 加 `goal_type` + `SyncInvestmentGoals` RPC + message
- `yucai/server/wire/providers.go` — goal scheduler + goal service SetAccountMarketValueSource(holdingSvc)
- `yucai/server/wire/wire_gen.go` — **手改**(镜像 B/C)
- `yucai/server/wire/app.go` — App.GoalScheduler
- `yucai/server/cmd/server/main.go` — go GoalScheduler.Start

### Flutter 修改
- `yucai/client/lib/holding/data/goal_view_ds.dart` — 新建,调 goal ListGoals(type=investment)
- `yucai/client/lib/holding/domain/entities/goal_view_entity.dart` — 新建 GoalView entity
- `yucai/client/lib/holding/data/holding_repository_impl.dart` — 加 listInvestmentGoals(accountId)
- `yucai/client/lib/holding/domain/repositories/holding_repository.dart` — 加抽象
- `yucai/client/lib/holding/presentation/pages/goal_link_page.dart` — 接真填 ⏳D

---

## Task 0: 前置(确认 + 清工作区)

**Files:** 无改动(验证 task)

- [ ] **Step 1: 确认 goal ent 表 + GoalType.investment 现有**

```bash
"/c/Users/andy/AppData/Local/Programs/Podman/podman.exe" exec yucai-pg psql -U yucai -d yucai -c "\d goals" 2>&1 | head -20
```
Expected:`goals` 表存在,含 `goal_type`/`linked_account_id`/`current_amount_cents`/`target_amount_cents` 列。若无表,goal 模块未 migrate(检查 server 启动)。

- [ ] **Step 2: 确认工作区干净(C 完成后)**

```bash
git -C /e/projects/syfinance status
```
Expected:干净(除 docs/ 若有新文件)。记 HEAD 为 D-goal 起点。

- [ ] **Step 3: 验证 server + flutter 当前编译绿(D-goal 起点)**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:**PASS**(C 已合并)。记 ledger "D-goal 起点 HEAD + server build 绿"。

(本 task 无 commit —— 纯验证)

---

## Task 1: goal domain(SetCurrentAmount + FindAll type filter + AccountMarketValueSource port)

**Files:**
- Modify: `yucai/server/internal/goal/domain/entity.go`(加 SetCurrentAmount)
- Modify: `yucai/server/internal/goal/domain/repository.go`(FindAll 加 goalType* + AccountMarketValueSource port)
- Test: `yucai/server/internal/goal/domain/domain_test.go`(若存在,追加;否则新建 entity 行为测)

**Interfaces:**
- Produces:
  - `domain.Goal.SetCurrentAmount(amtCents int64)` — 设 CurrentAmountCents(vestment 用),触发 MarkCompleted 若达 target
  - `domain.GoalRepository.FindAll(ctx, tenantID uuid.UUID, completed *bool, goalType *GoalType, page PageRequest)` — 加 goalType filter(nil=全部)
  - `domain.AccountMarketValueSource` 接口 `GetAccountMarketValue(ctx, tenantID, accountID uuid.UUID)(int64, error)`
- Task 3(SyncInvestmentGoals)、Task 4(repo)依赖

**背景**:Goal 现有 AddProgress(手动加)/SyncGoalProgress stub(直接设)。D-goal 加 SetCurrentAmount(investment mv 设,封装 + MarkCompleted)。FindAll 加 type filter(scheduler 遍历 investment)。

- [ ] **Step 1: 写失败测试(domain_test.go 追加 SetCurrentAmount)**

先确认 domain_test.go 是否存在:
```bash
ls /e/projects/syfinance/yucai/server/internal/goal/domain/*_test.go 2>/dev/null && echo EXISTS || echo NEW
```

在 `domain_test.go`(新建或追加)加:
```go
package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestGoalSetCurrentAmountAndAutoComplete(t *testing.T) {
	g := &Goal{
		ID:                uuid.New(),
		TargetAmountCents: 100000,
		CurrentAmountCents: 0,
	}
	// Set mv below target → progress 60%, not completed.
	g.SetCurrentAmount(60000)
	if g.CurrentAmountCents != 60000 {
		t.Fatalf("current = %d, want 60000", g.CurrentAmountCents)
	}
	if g.IsCompleted {
		t.Fatal("should not be completed below target")
	}
	// Set mv at/above target → auto-complete.
	g.SetCurrentAmount(100000)
	if !g.IsCompleted {
		t.Fatal("should auto-complete at target")
	}
	if g.CompletedAt == nil {
		t.Fatal("CompletedAt should be set")
	}
}

func TestGoalSetCurrentAmountDoesNotUncomplete(t *testing.T) {
	// Re-setting a lower mv after completion must not un-complete.
	g := &Goal{TargetAmountCents: 100000, IsCompleted: true, CompletedAt: ptrTime(time.Now())}
	g.SetCurrentAmount(10000)
	if !g.IsCompleted {
		t.Fatal("completed goal must stay completed even if mv drops")
	}
}

func ptrTime(t time.Time) *time.Time { return &t }
```

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/domain/ -run SetCurrentAmount -v -count=1
```
Expected:FAIL / 编译错误(`SetCurrentAmount` 未定义)。

- [ ] **Step 3: 实现 SetCurrentAmount(entity.go)**

在 `entity.go` 的 `AddProgress` 之后加:
```go
// SetCurrentAmount sets the current progress from a market-value snapshot
// (used by investment goals whose progress = Σ holdings mv). Auto-completes
// when reaching target; never un-completes a completed goal (mv may fluctuate).
func (g *Goal) SetCurrentAmount(amtCents int64) {
	g.CurrentAmountCents = amtCents
	if g.CurrentAmountCents < 0 {
		g.CurrentAmountCents = 0
	}
	g.UpdatedAt = time.Now()
	if g.CurrentAmountCents >= g.TargetAmountCents && !g.IsCompleted {
		g.MarkCompleted()
	}
}
```

- [ ] **Step 4: 改 GoalRepository.FindAll 加 goalType filter(repository.go)**

把 `GoalRepository.FindAll` 签名改:
```go
type GoalRepository interface {
	Save(ctx context.Context, goal *Goal) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Goal, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, completed *bool, goalType *GoalType, page PageRequest) (*PaginatedResult[Goal], error)
	Update(ctx context.Context, goal *Goal) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
}

// AccountMarketValueSource reports the market value of an account's holdings
// (Σ qty × current price). Implemented by holding/application.Service
// (structural type — goal does not import holding).
type AccountMarketValueSource interface {
	GetAccountMarketValue(ctx context.Context, tenantID, accountID uuid.UUID) (int64, error)
}
```

- [ ] **Step 5: 修复 FindAll 签名变更引发的编译错误**

`FindAll` 加了 `goalType*` 参数,现有调用方需补 nil:
- `goal/application/service.go:141` `ListGoals`:`s.repo.FindAll(ctx, req.TenantID, req.Completed, nil, req.Page)`(nil type = 全部,向后兼容;Task 3 改为 req.GoalType)
- `goal/adapter/driven/repository/goal_repo.go`:`FindAll` 实现签名加 `goalType *GoalType`(Task 4 实现 filter;本 step 先加参数不用,nil = 现有行为)
- 其他调用方 grep 确认:`grep -rn "FindAll" /e/projects/syfinance/yucai/server/internal/goal/`

- [ ] **Step 6: 跑测试验证 PASS + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/domain/ -run SetCurrentAmount -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:domain 测 PASS;build 绿(FindAll 调用方已补 nil)。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/goal/domain/
git commit -m "feat(holding-d-goal-server): goal domain SetCurrentAmount + FindAll type filter + AccountMarketValueSource port

Goal.SetCurrentAmount(investment mv 设,达 target 自动 complete,不 uncomplete)。
GoalRepository.FindAll 加 goalType* filter(nil=全部向后兼容)。新增
AccountMarketValueSource port(goal 本地,holding 结构实现,类似 C RateHistoryRepository)。"
```

---

## Task 2: holding application GetAccountMarketValue(暴露 port)

**Files:**
- Modify: `yucai/server/internal/holding/application/service.go`(加 GetAccountMarketValue)
- Test: `yucai/server/internal/holding/application/service_test.go`(追加)

**Interfaces:**
- Consumes:`holdingRepo.FindAll(ctx, tenantID, &accountID, page)`(现有)、`securityRepo.FindByID`(现有)
- Produces:`Service.GetAccountMarketValue(ctx, tenantID, accountID uuid.UUID)(int64, error)` — 结构满足 goal `AccountMarketValueSource` port。Task 3(wire 注入)依赖

**背景**:holding application 加方法,Σ 该 tenant+account 下所有 holdings 的市值(qty × current_price)。tenant-scoped(避免 FindAll Nil concern)。

- [ ] **Step 1: 写失败测试(service_test.go 追加)**

复用 C 的 `newTestServiceWithSecurities` 模式(或 holding application 现有 test helper),加 fake holdings under account:
```go
func TestGetAccountMarketValueSumsHoldings(t *testing.T) {
	// seed: account A has 2 holdings (qty×price), account B has 1.
	// security price set. GetAccountMarketValue(tenant, A) = Σ A holdings mv.
	// 需 fake holdingRepo.FindAll(tenant, &accountID, page) 返回该 account holdings。
	// 实现 fakeHoldingRepo(若 C 的 fake 不支持 account filter,扩展)。
	// 期望:account A mv = h1.qty×price1 + h2.qty×price2;account B mv = h3.qty×price3。
	t.Skip("Step 3 实现具体:照 C fakeHoldingRepo 模式,扩展 account filter + 多 holding")
}
```
> ⚠️ holding application 现有 fake repo(C 的 fakeSecurityRepo/fakeHoldingRepo)需支持 account filter + 多 holding。**Step 3 前先 Read C 的 fakeHoldingRepo 确认其 FindAll 是否支持 accountID filter**,若不支持则扩展(加 accountID 过滤逻辑)。本测核心:多 holding Σ mv + account 隔离(B account holdings 不计入 A)。

- [ ] **Step 2: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -run GetAccountMarketValue -v -count=1
```
Expected:FAIL / 编译错误(`GetAccountMarketValue` 未定义)。

- [ ] **Step 3: 实现 GetAccountMarketValue(service.go)**

在 `service.go` 末尾(`SnapshotHoldings`/`GetHoldingPerformance` 附近,C 已建)加:
```go
// GetAccountMarketValue returns the total market value (original currency,
// NOT CNY-converted — investment goal tracks raw mv) of all holdings under
// an account: Σ holding.MarketValue(security.CurrentPriceCents). Tenant-scoped.
// Implements goal/domain.AccountMarketValueSource (structural).
func (s *Service) GetAccountMarketValue(ctx context.Context, tenantID, accountID uuid.UUID) (int64, error) {
	var total int64
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.holdingRepo.FindAll(ctx, tenantID, &accountID, page)
		if err != nil {
			return 0, fmt.Errorf("account market value: list holdings: %w", err)
		}
		for _, h := range result.Items {
			if err := ctx.Err(); err != nil {
				return total, err
			}
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				slog.Warn("account market value: security missing, skip",
					slog.String("security_id", h.SecurityID.String()),
					slog.String("operation", "GetAccountMarketValue"))
				continue
			}
			total += h.MarketValue(sec.CurrentPriceCents)
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return total, nil
}
```
> `domain.PageRequest`/`Holding.MarketValue` 已存在(C 用过)。`slog`/`fmt`/`uuid` 已 import。

- [ ] **Step 4: 补全 fakeHoldingRepo account filter(若 Step 1 确认需)**

Read C 的 fakeHoldingRepo,确认 `FindAll(ctx, tenantID, accountID*, page)` 是否按 accountID 过滤。若否,扩展(加 `if accountID != nil && h.AccountID != *accountID { continue }`)。补全 `TestGetAccountMarketValueSumsHoldings` 实测(去掉 t.Skip,seed 2 account holdings,断言 Σ + 隔离)。

- [ ] **Step 5: 跑测试验证 PASS + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/holding/application/ -run GetAccountMarketValue -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:PASS + build 绿。**确认 `*holdingapp.Service` 结构满足 `goal/domain.AccountMarketValueSource`**(编译时 Task 3 wire 注入会验证)。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/holding/application/
git commit -m "feat(holding-d-goal-server): holding GetAccountMarketValue(Σ account holdings mv)

GetAccountMarketValue(ctx, tenantID, accountID) = Σ holdings(qty×current_price)
under tenant+account。tenant-scoped(避免 FindAll Nil)。原币市值(不 CNY 折算,
investment goal track 原始 mv)。结构满足 goal/domain.AccountMarketValueSource port。
分页聚合。fakeHoldingRepo account filter 扩展。"
```

---

## Task 3: goal application SyncInvestmentGoals + ListGoals type + setter

**Files:**
- Modify: `yucai/server/internal/goal/application/service.go`(SyncInvestmentGoals + ListGoals type + SetAccountMarketValueSource)
- Modify: `yucai/server/internal/goal/application/dto.go`(ListGoalsRequest 加 GoalType)
- Test: `yucai/server/internal/goal/application/service_test.go`

**Interfaces:**
- Consumes:`domain.GoalRepository.FindAll(...goalType*...)`(Task 1)、`domain.AccountMarketValueSource`(Task 1 port,Task 2 holding 实现)、`Goal.SetCurrentAmount`(Task 1)
- Produces:
  - `Service.SyncInvestmentGoals(ctx, tenantID uuid.UUID) (int, error)` — 遍历 investment goals,调 port 算 mv,SetCurrentAmount,Save。best-effort。实现 `GoalSyncer` 接口(Task 5 scheduler)
  - `Service.SetAccountMarketValueSource(src domain.AccountMarketValueSource)`
  - `ListGoalsRequest` 加 `GoalType *domain.GoalType`(DTO)
- Task 5(scheduler)、Task 6(proto/handler)、Task 8(wire)依赖

**背景**:goal service 加 mv source setter(NewService 签名不变,对齐 B/C setter 模式)。SyncInvestmentGoals 遍历 investment goals(Task 1 FindAll type filter),对 linked_account 调 port 算 mv,SetCurrentAmount。best-effort(单 goal fail 不中断)。

- [ ] **Step 1: dto.go ListGoalsRequest 加 GoalType**

`yucai/server/internal/goal/application/dto.go` 的 `ListGoalsRequest` 加字段:
```go
type ListGoalsRequest struct {
	TenantID  uuid.UUID
	Completed *bool
	GoalType  *domain.GoalType  // D-goal: nil=全部,investment=scheduler/Flutter filter
	Page      domain.PageRequest
}
```

- [ ] **Step 2: 写失败测试(service_test.go 追加 SyncInvestmentGoals)**

```go
type fakeAccountMarketValueSource struct {
	// mv maps accountID → market value cents to return.
	mv map[uuid.UUID]int64
	// errOn accountID → error (simulate holding service failure).
	errOn map[uuid.UUID]error
}

func (f *fakeAccountMarketValueSource) GetAccountMarketValue(_ context.Context, _, accountID uuid.UUID) (int64, error) {
	if f.errOn != nil {
		if e, ok := f.errOn[accountID]; ok {
			return 0, e
		}
	}
	return f.mv[accountID], nil
}

func TestSyncInvestmentGoalsUpdatesMvAndCompletes(t *testing.T) {
	// seed goals: g1 investment linked_account=acct1 target=100000,
	//             g2 investment linked_account=acct2 target=200000,
	//             g3 savings (not investment, must be skipped).
	// fakeAccountMarketValueSource.mv: acct1=60000, acct2=200000.
	// SyncInvestmentGoals → g1.current=60000 (not completed), g2.current=200000 (auto-completed),
	//                      g3 untouched (savings). returns synced=2.
	investment := domain.GoalTypeInvestment
	repo, svc := newTestServiceWithGoals(t, []seedGoal{
		{Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct1), Target: 100000},
		{Type: domain.GoalTypeInvestment, LinkedAccount: ptrUUID(acct2), Target: 200000},
		{Type: domain.GoalTypeSavings, LinkedAccount: ptrUUID(acct1), Target: 50000},
	})
	svc.SetAccountMarketValueSource(&fakeAccountMarketValueSource{
		mv: map[uuid.UUID]int64{acct1: 60000, acct2: 200000},
	})
	count, err := svc.SyncInvestmentGoals(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if count != 2 {
		t.Fatalf("synced = %d, want 2 (g1+g2 investment, g3 savings skipped)", count)
	}
	if got := repo.currentFor("g1"); got != 60000 {
		t.Fatalf("g1 current = %d, want 60000", got)
	}
	if !repo.isCompleted("g2") {
		t.Fatal("g2 should auto-complete at target 200000")
	}
	if got := repo.currentFor("g3"); got != 0 {
		t.Fatalf("g3 (savings) must be untouched, got current %d", got)
	}
}

func TestSyncInvestmentGoalsContinuesPastHoldingError(t *testing.T) {
	// acct1 holding service fails, acct2 ok. g1 skipped (logged), g2 synced. count=1.
	// ... 照上面模式,errOn: acct1 → error
}

func TestSyncInvestmentGoalsSkipsCompleted(t *testing.T) {
	// already-completed investment goal → skipped (no re-update). count excludes it.
}
```
> `newTestServiceWithGoals`/`seedGoal`/`fakeGoalRepo`(currentFor/isCompleted helpers)照 C fakeSecurityRepo 模式实现(domain 接口全实现,未用方法 panic)。`domain.GoalTypeInvestment`/`GoalTypeSavings` 以 valueobject.go 实际枚举为准(Read 确认)。

- [ ] **Step 3: 跑测试验证 FAIL**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/application/ -run SyncInvestmentGoals -v -count=1
```
Expected:FAIL / 编译错误(`SyncInvestmentGoals`/`SetAccountMarketValueSource` 未定义)。

- [ ] **Step 4: 实现 — service.go struct 加字段 + setter + SyncInvestmentGoals**

改 `Service` struct(line 12-14)加字段:
```go
type Service struct {
	repo          domain.GoalRepository
	mvSource      domain.AccountMarketValueSource // D-goal: injected via setter; nil = SyncInvestmentGoals errors
}
```
`NewService(repo)` 不变。

在 service.go 末尾加:
```go
// SetAccountMarketValueSource injects the holding market-value source used by
// SyncInvestmentGoals. Called by wire after construction (NewService signature
// unchanged). *holding/application.Service implements this port structurally.
func (s *Service) SetAccountMarketValueSource(src domain.AccountMarketValueSource) {
	s.mvSource = src
}

// SyncInvestmentGoals recomputes current_amount for every investment goal from
// its linked investment account's Σ holdings market value. Best-effort: a goal
// whose mv lookup fails is logged and skipped without aborting the batch.
// Already-completed goals are skipped (mv may fluctuate; we don't un-complete).
// Implements goal/scheduler.GoalSyncer.
func (s *Service) SyncInvestmentGoals(ctx context.Context, tenantID uuid.UUID) (int, error) {
	if s.mvSource == nil {
		return 0, fmt.Errorf("sync investment goals: market value source not configured")
	}
	investment := domain.GoalTypeInvestment
	synced := 0
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.repo.FindAll(ctx, tenantID, nil, &investment, page)
		if err != nil {
			return synced, fmt.Errorf("sync investment goals: list: %w", err)
		}
		for _, g := range result.Items {
			if err := ctx.Err(); err != nil {
				return synced, err
			}
			if g.IsCompleted || g.GoalType != domain.GoalTypeInvestment || g.LinkedAccountID == nil {
				continue
			}
			mv, err := s.mvSource.GetAccountMarketValue(ctx, tenantID, *g.LinkedAccountID)
			if err != nil {
				slog.Warn("goal sync: holding mv failed, skip goal",
					slog.String("goal_id", g.ID.String()),
					slog.String("account_id", g.LinkedAccountID.String()),
					slog.String("error", err.Error()),
					slog.String("operation", "SyncInvestmentGoals"))
				continue
			}
			g.SetCurrentAmount(mv)
			g.IncrementVersion()
			if err := s.repo.Update(ctx, &g); err != nil {
				slog.Warn("goal sync: update failed",
					slog.String("goal_id", g.ID.String()),
					slog.String("error", err.Error()),
					slog.String("operation", "SyncInvestmentGoals"))
				continue
			}
			synced++
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return synced, nil
}
```
> import 加 `"log/slog"`(若未有)。`domain.GoalTypeInvestment` 以 valueobject.go 枚举为准(Read 确认确切名)。

- [ ] **Step 5: 改 ListGoals 传 GoalType(service.go ListGoals)**

`ListGoals`(line 140-154)的 `FindAll` 调用从 `nil` 改为 `req.GoalType`:
```go
result, err := s.repo.FindAll(ctx, req.TenantID, req.Completed, req.GoalType, req.Page)
```

- [ ] **Step 6: 跑测试验证 PASS + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/application/ -run SyncInvestmentGoals -v -count=1
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/... -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:PASS(3 SyncInvestmentGoals 测)+ goal 全包回归 + build 绿。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/goal/application/
git commit -m "feat(holding-d-goal-server): goal SyncInvestmentGoals + ListGoals type + mv source setter

Service 加 mvSource 字段 + SetAccountMarketValueSource setter(NewService 签名不变)。
SyncInvestmentGoals(ctx,tenantID):遍历 investment goals,调 mvSource.GetAccountMarketValue
→ SetCurrentAmount → Update。best-effort(mv fail 跳过+日志,不中断)。skip 已完成。
ListGoalsRequest 加 GoalType*(DTO),ListGoals 传 type。实现 GoalSyncer(scheduler)。
3 单测(更新+auto-complete/holding 错误/skip completed)。"
```

---

## Task 4: goal ent repo FindAll type filter 实现

**Files:**
- Modify: `yucai/server/internal/goal/adapter/driven/repository/goal_repo.go`(FindAll 加 goalType where)
- Test: `yucai/server/internal/goal/adapter/driven/repository/goal_repo_test.go`(若存在,追加;否则新建)

**Interfaces:**
- Consumes:`domain.GoalRepository.FindAll(...goalType*...)`(Task 1 接口)
- Produces:ent-backed FindAll 支持 goalType filter。Task 3(SyncInvestmentGoals FindAll investment)、handler(ListGoals type)依赖

**背景**:FindAll 现有(tenantID + completed* + page)。加 goalType*(nil=全部)。参照现有 budget/holding repo 的 ent where 模式。

- [ ] **Step 1: Read goal_repo.go FindAll 现有实现**

```bash
grep -n "func.*FindAll" /e/projects/syfinance/yucai/server/internal/goal/adapter/driven/repository/goal_repo.go
```
Read 该函数,记下 ent 查询模式(`client.Goal.Query().Where(goal.TenantIDEQ(tenantID)...)`)+ ent→domain mapping。

- [ ] **Step 2: 改 FindAll 签名加 goalType + where**

把 FindAll(从 Task 1 已加 `goalType *GoalType` 参数签名,本 step 实现 filter):
```go
func (r *GoalRepository) FindAll(ctx context.Context, tenantID uuid.UUID, completed *bool, goalType *domain.GoalType, page domain.PageRequest) (*domain.PaginatedResult[domain.Goal], error) {
	q := r.client.Goal.Query().Where(goal.TenantIDEQ(tenantID))
	if completed != nil {
		q = q.Where(goal.IsCompletedEQ(*completed))
	}
	if goalType != nil {
		q = q.Where(goal.GoalTypeEQ(int(*goalType))) // ⚠️ goal_type ent 存储 int;Read 生成的 where.go 确认 GoalTypeEQ 签名
	}
	// ... 保留现有分页 + Order + ent→domain mapping
}
```
> ⚠️ `goal.GoalTypeEQ` 的参数类型(int vs enum)以生成的 `ent/goal/where.go` 为准 —— Read 确认。`domain.GoalType` 底层 int(Read valueobject.go 确认)。

- [ ] **Step 3: 写/追加 repo 集成测(enttest)**

```go
func TestGoalRepoFindAllFiltersByType(t *testing.T) {
	client := openTestClient(t) // 照现有 goal repo test 的 enttest helper
	defer client.Close()
	ctx := context.Background()
	tenant := uuid.New()
	// seed 2 investment + 1 savings goal
	// FindAll(tenant, nil, &investment, page) → 2 investment
	// FindAll(tenant, nil, nil, page) → 3 全部
}
```
(照现有 goal repo test 的 enttest 模式;若无,参照 holding repo test Task 3 的 enttest helper。)

- [ ] **Step 4: 跑测试 + build**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/adapter/driven/repository/ -v -count=1
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:PASS + build 绿。

- [ ] **Step 5: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/goal/adapter/driven/repository/
git commit -m "feat(holding-d-goal-server): goal_repo FindAll type filter 实现

ent where goal_type filter(nil=全部)。enttest 集成测验证 investment/全部 filter。"
```

---

## Task 5: goal scheduler(照 B 模式 + TenantLister 遍历)

**Files:**
- Create: `yucai/server/internal/goal/scheduler/scheduler.go`
- Create: `yucai/server/internal/goal/scheduler/scheduler_test.go`

**Interfaces:**
- Consumes:`IntervalSource`(`MinIntervalHours(ctx) int`,auth.TenantRepository 结构实现,复用 B/C 同源)+ `TenantLister`(`FindAllIDs(ctx)([]uuid.UUID, error)`,auth.TenantRepository 结构实现)
- Produces:
  - `scheduler.GoalSyncer` 接口 `SyncInvestmentGoals(ctx, tenantID uuid.UUID)(int, error)`(goal application.Service 实现)
  - `scheduler.TenantLister` 接口 `FindAllIDs(ctx)([]uuid.UUID, error)`
  - `scheduler.Scheduler` + `NewScheduler(syncer GoalSyncer, lister TenantLister, src IntervalSource, tick, log)` + `Start(ctx)` + `SyncNow(ctx)(int, error)`
- Task 8(wire)依赖

**背景**:照 B [holding/scheduler/scheduler.go](../../yucai/server/internal/holding/scheduler/scheduler.go) 模式,**加 TenantLister 跨 tenant 遍历**(每个 tenant 的 investment goals 独立 sync)。scheduler 包定义 GoalSyncer + TenantLister 接口(不 import auth/goal application)。wire 注入 auth.TenantRepository(满足 IntervalSource + TenantLister)+ goalSvc(GoalSyncer)。

- [ ] **Step 1: 写 scheduler.go(照 B holding/scheduler/scheduler.go + TenantLister)**

`yucai/server/internal/goal/scheduler/scheduler.go`:
```go
// Package scheduler runs periodic investment-goal progress sync (Σ holdings mv
// → goal.current_amount) as a background task. Mirrors holding/scheduler +
// currency/scheduler; fans out across tenants via TenantLister.
package scheduler

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
)

// IntervalSource reports the minimum hours between automatic syncs.
// Reused from B/C (same auth.TenantRepository provider).
type IntervalSource interface {
	MinIntervalHours(ctx context.Context) int
}

// TenantLister enumerates tenant IDs to fan out the sync. Implemented by
// auth.TenantRepository (structural — scheduler does not import auth).
type TenantLister interface {
	FindAllIDs(ctx context.Context) ([]uuid.UUID, error)
}

// GoalSyncer recomputes investment-goal progress for one tenant. Implemented
// by goal/application.Service.SyncInvestmentGoals.
type GoalSyncer interface {
	SyncInvestmentGoals(ctx context.Context, tenantID uuid.UUID) (int, error)
}

// Scheduler periodically fans out GoalSyncer across all tenants, gated by
// IntervalSource. Mirrors B holding/scheduler 1:1 + tenant fan-out.
type Scheduler struct {
	syncer GoalSyncer
	lister TenantLister
	src    IntervalSource
	tick   time.Duration
	log    *slog.Logger

	mu       sync.Mutex
	lastSync time.Time
}

func NewScheduler(syncer GoalSyncer, lister TenantLister, src IntervalSource, tick time.Duration, log *slog.Logger) *Scheduler {
	if log == nil {
		log = slog.Default()
	}
	return &Scheduler{syncer: syncer, lister: lister, src: src, tick: tick, log: log}
}

// Start runs the scheduler loop until ctx is cancelled. Immediate doSync on
// start, then on each tick re-syncs only if MinIntervalHours elapsed.
func (s *Scheduler) Start(ctx context.Context) {
	if _, err := s.doSync(ctx); err != nil {
		s.log.Error("goal sync failed", "error", err, "operation", "GoalScheduler.Start")
	}
	ticker := time.NewTicker(s.tick)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			interval := time.Duration(s.src.MinIntervalHours(ctx)) * time.Hour
			s.mu.Lock()
			elapsed := time.Since(s.lastSync)
			s.mu.Unlock()
			if elapsed >= interval {
				if _, err := s.doSync(ctx); err != nil {
					s.log.Error("goal sync failed", "error", err, "operation", "GoalScheduler.Start")
				}
			}
		}
	}
}

func (s *Scheduler) SyncNow(ctx context.Context) (int, error) { return s.doSync(ctx) }

// doSync fans out across all tenants: Σ per-tenant synced counts. Per-tenant
// errors logged, not fatal (other tenants still sync). ctx cancel short-circuits.
func (s *Scheduler) doSync(ctx context.Context) (int, error) {
	if err := ctx.Err(); err != nil {
		return 0, err
	}
	tenants, err := s.lister.FindAllIDs(ctx)
	if err != nil {
		s.log.Error("goal sync: list tenants failed", "error", err, "operation", "GoalScheduler")
		s.mu.Lock()
		s.lastSync = time.Now()
		s.mu.Unlock()
		return 0, err
	}
	total := 0
	for _, tid := range tenants {
		if err := ctx.Err(); err != nil {
			return total, err
		}
		count, err := s.syncer.SyncInvestmentGoals(ctx, tid)
		if err != nil {
			s.log.Error("goal sync: tenant failed, continue", "tenant_id", tid.String(), "error", err, "operation", "GoalScheduler")
			continue
		}
		total += count
	}
	s.log.Info("goal sync completed", "count", total, "tenants", len(tenants), "operation", "GoalScheduler")
	s.mu.Lock()
	s.lastSync = time.Now()
	s.mu.Unlock()
	return total, nil
}
```

- [ ] **Step 2: 写 scheduler_test.go(照 B scheduler_test.go + mockTenantLister)**

照 [B scheduler_test.go](../../yucai/server/internal/holding/scheduler/scheduler_test.go) 5 测(immediate/interval-gate/ctx-cancel/SyncNow-error/SyncNow-cancelled),加 `mockTenantLister`(返固定 tenant 列表)+ `mockGoalSyncer`(Σ calls):
```go
type mockTenantLister struct{ ids []uuid.UUID }
func (m *mockTenantLister) FindAllIDs(_ context.Context) ([]uuid.UUID, error) { return m.ids, nil }

type mockGoalSyncer struct {
	calls atomic.Int64
	perTenant int // 返回固定 count
	errOn map[uuid.UUID]error // 模拟单 tenant 错误
}
func (m *mockGoalSyncer) SyncInvestmentGoals(_ context.Context, tenantID uuid.UUID) (int, error) {
	m.calls.Add(1)
	if m.errOn != nil { if e, ok := m.errOn[tenantID]; ok { return 0, e } }
	return m.perTenant, nil
}
// 5 测照 B scheduler_test 结构:Start immediate doSync / interval gate / ctx cancel / SyncNow error / per-tenant 错误继续
```

- [ ] **Step 3: 跑测试**

```bash
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/scheduler/ -v -count=1
```
Expected:PASS(5 测)。

- [ ] **Step 4: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/goal/scheduler/
git commit -m "feat(holding-d-goal-server): goal scheduler(照 B 模式 + TenantLister 跨 tenant 遍历)

GoalSyncer(SyncInvestmentGoals per-tenant)+ TenantLister(FindAllIDs)+ IntervalSource。
Scheduler 照 B holding/scheduler 1:1 + doSync 跨 tenant fan-out(Σ count,per-tenant 错误
继续)。scheduler 包不 import auth/goal application。5 单测对齐 B scheduler_test。"
```

---

## Task 6: proto(ListGoals type filter + SyncInvestmentGoals RPC)+ 重生成 stub

**Files:**
- Modify: `yucai/proto/goal/v1/goal.proto`(ListGoalsRequest 加 goal_type + service 加 SyncInvestmentGoals RPC + message)
- Regenerate: `yucai/server/internal/proto/goal/v1/goal.pb.go`、`goal_grpc.pb.go`、`yucai/client/lib/proto/goal/v1/*.dart`

**Interfaces:**
- Produces:proto `ListGoalsRequest.goal_type`(filter)+ `SyncInvestmentGoals(SyncInvestmentGoalsRequest) returns (SyncInvestmentGoalsResponse)` RPC;Go `GoalServiceServer.SyncInvestmentGoals` + Dart `GoalServiceClient.syncInvestmentGoals`。Task 7(handler)、Task 10(Flutter ds)依赖

**背景**:setup task(proto 契约)。ListGoalsRequest 加 goal_type(filter investment)。新增 SyncInvestmentGoals RPC(手动触发 + 测试用;scheduler 内部用 service 方法)。

- [ ] **Step 1: 改 goal.proto — ListGoalsRequest 加 goal_type**

`ListGoalsRequest`(proto line 77-80)加 `goal_type`:
```proto
message ListGoalsRequest {
  yucai.common.v1.PageRequest page = 1;
  bool completed = 2;
  GoalType goal_type = 3;  // D-goal: filter by type (UNSPECIFIED=all)
}
```

- [ ] **Step 2: 改 goal.proto — service 加 SyncInvestmentGoals RPC**

service 块(`ListGoals` 之后)加:
```proto
  rpc SyncInvestmentGoals(SyncInvestmentGoalsRequest) returns (SyncInvestmentGoalsResponse);
```

文件末尾加 message:
```proto
message SyncInvestmentGoalsRequest {}

message SyncInvestmentGoalsResponse {
  int32 synced_count = 1;
  google.protobuf.Timestamp synced_at = 2;
}
```

- [ ] **Step 3: 重生成 Go stub**

```bash
cd /e/projects/syfinance/yucai/proto && buf generate --template buf.gen.go.yaml
```
Expected:`goal.pb.go` 出现 `SyncInvestmentGoalsRequest/Response`;`goal_grpc.pb.go` 的 `GoalServiceServer` 加 `SyncInvestmentGoals` 方法。**此时 GoalHandler 未实现 → server 编译红,Task 7 修**。

- [ ] **Step 4: 重生成 Dart stub(protoc_plugin 25.0.0)**

```bash
dart pub global activate protoc_plugin 25.0.0
cd /e/projects/syfinance/yucai/proto && bash gen-dart.sh
```
Expected:`goal.pb.dart` 出现 `SyncInvestmentGoalsRequest/Response` + `ListGoalsRequest.goalType`;`goal.pbgrpc.dart` 的 `GoalServiceClient` 加 `syncInvestmentGoals`。

- [ ] **Step 5: 验证 Go server 编译红(预期,Task 7 转 green)**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
```
Expected:**FAIL** —— `GoalHandler` 未实现 `SyncInvestmentGoals`(GoalServiceServer 接口新方法)。记错误,Task 7 修。

- [ ] **Step 6: Commit proto + 重生成产物**

```bash
cd /e/projects/syfinance
git add yucai/proto/goal/v1/goal.proto yucai/server/internal/proto/goal/v1/ yucai/client/lib/proto/goal/v1/
git commit -m "feat(holding-d-goal-proto): ListGoals goal_type filter + SyncInvestmentGoals RPC

ListGoalsRequest 加 goal_type(filter investment)。新增 SyncInvestmentGoals RPC
(手动触发,返回 synced_count+synced_at)。Go/Dart stub 重生成。GoalHandler 待 Task 7
实现 SyncInvestmentGoals(server 编译红,预期)。"
```

---

## Task 7: goal handler(SyncInvestmentGoals + ListGoals type 映射)

**Files:**
- Modify: `yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go`(SyncInvestmentGoals handler + ListGoals type 映射)
- Modify: `yucai/server/internal/goal/application/dto.go`(若 ListGoals 映射需)
- Test: `yucai/server/internal/goal/adapter/driving/grpc/goal_handler_test.go`(若存在,追加)

**Interfaces:**
- Consumes:`service.SyncInvestmentGoals(ctx, tenantID)`(Task 3)、`pb.SyncInvestmentGoalsRequest/Response`、`getTenantID`(现有 helper)
- Produces:`GoalHandler` 满足 `GoalServiceServer`(Task 6 red 转 green)

**背景**:handler 调 service.SyncInvestmentGoals(跨 tenant,scheduler 同方法?或 handler 调单 tenant?)。

⚠️ **关键决策**:service.SyncInvestmentGoals(ctx, **tenantID**)(per-tenant,Task 3)。handler 拿 tenantID(getTenantID)→ 调 SyncInvestmentGoals(tenantID)单 tenant。但 scheduler(Task 5)跨 tenant 逐个调。

handler SyncInvestmentGoals RPC:**单 tenant**(当前登录 tenant)。手动触发当前 tenant 的 goal sync。

- [ ] **Step 1: Read goal_handler.go 现有 + handler 测模式**

```bash
grep -n "func.*Handler.*Goal\|getTenantID\|mapError" /e/projects/syfinance/yucai/server/internal/goal/adapter/driving/grpc/goal_handler.go
```
记下:handler struct、getTenantID/mapError helper、ListGoals 现有映射(goalType 从 proto → service DTO)。

- [ ] **Step 2: 实现 SyncInvestmentGoals handler(在 ListGoals 之后)**

```go
// SyncInvestmentGoals recomputes current_amount for the caller's investment
// goals from Σ holdings mv (manual trigger; the scheduler does this for all
// tenants automatically). Returns synced count + timestamp.
func (h *GoalHandler) SyncInvestmentGoals(ctx context.Context, _ *pb.SyncInvestmentGoalsRequest) (*pb.SyncInvestmentGoalsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	count, err := h.service.SyncInvestmentGoals(ctx, tenantID)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.SyncInvestmentGoalsResponse{
		SyncedCount: int32(count),
		SyncedAt:    timestamppb.Now(),
	}, nil
}
```
> 确认 `timestamppb`/`codes`/`status` import(goal_handler 现有 ListGoals 用)。

- [ ] **Step 3: 改 ListGoals 映射传 goal_type(handler + dto)**

`ListGoals` handler 把 `req.GoalType`(proto enum)→ service DTO `GoalType *domain.GoalType`。Read 现有 ListGoals handler 的 DTO 构造,加:
```go
var goalType *domain.GoalType
if req.GetGoalType() != pb.GoalType_GOAL_TYPE_UNSPECIFIED {
	gt := goalTypeFromProto(req.GetGoalType()) // proto enum → domain.GoalType
	goalType = &gt
}
// ListGoalsRequest{..., GoalType: goalType}
```
`goalTypeFromProto`(NAME 映射,对齐 holding 现有 enum 映射惯例):
```go
func goalTypeFromProto(t pb.GoalType) domain.GoalType {
	switch t {
	case pb.GoalType_GOAL_TYPE_SAVINGS:
		return domain.GoalTypeSavings
	case pb.GoalType_GOAL_TYPE_DEBT_PAYOFF:
		return domain.GoalTypeDebtPayoff
	case pb.GoalType_GOAL_TYPE_INVESTMENT:
		return domain.GoalTypeInvestment
	default:
		return domain.GoalTypeSavings // UNSPECIFIED 不应到这(filter 时已 nil)
	}
}
```
> `domain.GoalTypeSavings`/`DebtPayoff`/`Investment` 以 valueobject.go 实际枚举名为准(Read 确认)。

- [ ] **Step 4: 跑 build + handler 测**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
cd /e/projects/syfinance/yucai/server && go test ./internal/goal/adapter/driving/grpc/ -v -count=1
```
Expected:**build PASS**(Task 6 red 转 green);handler 测 PASS。新增测(照现有 handler test stub service 模式):
```go
func TestSyncInvestmentGoalsReturnsCount(t *testing.T) {
	// stub service.SyncInvestmentGoals 返 3 → response.SyncedCount==3 + SyncedAt 非 nil
}
func TestListGoalsFiltersByType(t *testing.T) {
	// req.GoalType=INVESTMENT → service 收到 GoalType=Investment(verify mock)
}
```

- [ ] **Step 5: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/internal/goal/adapter/driving/grpc/ yucai/server/internal/goal/application/dto.go
git commit -m "feat(holding-d-goal-server): goal handler SyncInvestmentGoals + ListGoals type 映射

SyncInvestmentGoals(单 tenant 手动触发,映射 synced_count+synced_at)。ListGoals
传 goal_type(proto enum→domain.GoalType NAME 映射,UNSPECIFIED→nil=全部)。
GoalHandler 满足 Task6 新接口,server 编译绿。handler 单测。"
```

---

## Task 8: wire + main(goal scheduler 接线 + holding→goal port 注入)

**Files:**
- Modify: `yucai/server/wire/providers.go`(goal scheduler provider + 改 provideGoalService 注入 SetAccountMarketValueSource)
- Modify: `yucai/server/wire/wire_gen.go`(**手改**,镜像 B/C)
- Modify: `yucai/server/wire/app.go`(App.GoalScheduler)
- Modify: `yucai/server/cmd/server/main.go`(go GoalScheduler.Start)

**Interfaces:**
- Consumes:Tasks 1-7 全部产物
- Produces:完整 server 可启动(goal scheduler 随 main 启动 + holding→goal port 注入)

**背景**:wire 工具链坏(见 [[yucai-wire-handmaintained]]),wire_gen.go 手改镜像 B/C。goal service 用 setter 注入 mvSource(NewService 签名不变)。goal scheduler 注入 GoalSyncer(goalSvc)+ TenantLister(authTenantRepo)+ IntervalSource(authTenantRepo)。

- [ ] **Step 1: providers.go — goal scheduler provider + 改 provideGoalService**

Read 现有 `provideGoalService` + `provideCurrencyScheduler`/`provideSnapshotScheduler`(B/C)模式。

改 `provideGoalService` 加 mvSource 注入(对齐 B provideHoldingService setter 模式):
```go
func provideGoalService(repo goaldomain.GoalRepository, mvSource goaldomain.AccountMarketValueSource) *goalapp.Service {
	svc := goalapp.NewService(repo)
	svc.SetAccountMarketValueSource(mvSource) // *holdingapp.Service 结构实现 AccountMarketValueSource
	return svc
}
```
> `*holdingapp.Service` 结构满足 `goaldomain.AccountMarketValueSource`(Task 2 GetAccountMarketValue)。wire 注入 holdingSvc 作 mvSource。

加 goal scheduler provider(在 provideSnapshotScheduler 附近):
```go
import (
	goalscheduler "github.com/yucai/server/internal/goal/scheduler"
	// ... 现有 import
)

// provideGoalScheduler: goalSvc implements GoalSyncer; authTenantRepo satisfies
// both TenantLister (FindAllIDs) and IntervalSource (MinIntervalHours) structurally.
func provideGoalScheduler(svc *goalapp.Service, tenantRepo *auth.TenantRepository) *goalscheduler.Scheduler {
	return goalscheduler.NewScheduler(svc, tenantRepo, tenantRepo, 1*time.Hour, nil)
}
```
> ⚠️ `*auth.TenantRepository` 同时满足 `goalscheduler.TenantLister`(FindAllIDs,C 已确认存在)+ `goalscheduler.IntervalSource`(MinIntervalHours,B/C 复用)。确认 auth.TenantRepository 有 FindAllIDs(C Task 7 已确认)。

- [ ] **Step 2: 手改 wire_gen.go(镜像 B/C 的 scheduler 行)**

Read `wire_gen.go`,定位:
- `goalService := provideGoalService(...)`(现有)
- `holdingService := provideHoldingService(...)`(B/C 已加)
- `snapshotScheduler := provideSnapshotScheduler(...)`(C 加)
- `NewApp(...)`(含 snapshotScheduler)

手改:
```go
// 改 goalService 构造行,加 holdingService 作 mvSource 实参(镜像 B provideHoldingService 加 priceRouter):
goalService := provideGoalService(goalRepo, holdingService) // holdingService 作 AccountMarketValueSource
// ⚠️ 以实际 provideGoalService 原参数为准,追加 holdingService

// 在 snapshotScheduler 行(C 加)之后加:
goalScheduler := provideGoalScheduler(goalService, tenantRepo)

// 改 NewApp 调用末尾加 goalScheduler 实参(在 snapshotScheduler 之后):
app := NewApp(..., snapshotScheduler, goalScheduler)
```
> 关键:**先 Read wire_gen.go** 把 goalService/holdingService/NewApp 原参数抄下,只追加(holdingService 作 mvSource + goalScheduler 变量 + NewApp 实参)。不跑 wire CLI。

- [ ] **Step 3: app.go — App.GoalScheduler**

App struct 加字段(在 `SnapshotScheduler` 之后):
```go
GoalScheduler *goalscheduler.Scheduler
```
加 import:`goalscheduler "github.com/yucai/server/internal/goal/scheduler"`
NewApp 签名加参数(在 `snapshotScheduler` 之后)+ struct literal 加 `GoalScheduler: goalScheduler,`。

- [ ] **Step 4: main.go — go GoalScheduler.Start**

Read `cmd/server/main.go`(C 加的 `go app.SnapshotScheduler.Start(schedCtx)` 附近)。在它之后加:
```go
// Start goal progress scheduler (daily investment-goal mv sync).
go app.GoalScheduler.Start(schedCtx)
```

- [ ] **Step 5: go build 全量绿 + 全量 test**

```bash
cd /e/projects/syfinance/yucai/server && go build ./...
cd /e/projects/syfinance/yucai/server && go test ./... -count=1
```
Expected:**PASS**。若报错:wire_gen 参数个数/类型 → 检查 Step 2(provideGoalService 实参 + NewApp);mvSource 类型 → 确认 holdingService 满足 AccountMarketValueSource;auth.TenantRepository 满足 TenantLister+IntervalSource。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/server/wire/ yucai/server/cmd/server/main.go
git commit -m "feat(holding-d-goal-server): wire+main 接线 goal scheduler + holding→goal port

providers.go:provideGoalScheduler(goalSvc+tenantRepo 作 GoalSyncer+TenantLister+
IntervalSource)+ provideGoalService 注入 SetAccountMarketValueSource(holdingSvc 作
AccountMarketValueSource)。wire_gen.go 手改(镜像 B/C,goalService 加 holdingService
实参 + goalScheduler 变量 + NewApp)。app.go+main:App.GoalScheduler + Start。
go build 绿 + 全量 test 过。"
```

---

## Task 9: server 端到端验证(scheduler 算 mv 写 goal.current_amount)

**Files:** 无改动(验证 task,我自做)

**背景**:验证 goal scheduler 启动跑 + investment goal.current_amount = Σ account holdings mv。

- [ ] **Step 1: 重建 server + 起 podman DB**

```bash
cd /e/projects/syfinance/yucai/server && go build -o bin/server.exe ./cmd/server
"C:\Users\andy\AppData\Local\Programs\Podman\podman.exe" ps --filter name=yucai-pg --format '{{.Names}} {{.Status}}'
```

- [ ] **Step 2: 起 server background(memory yucai-dev-env env,绝对路径 cwd)**

```bash
cd /e/projects/syfinance/yucai/server && \
export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable' && \
export JWT_SECRET='dev-secret-change-me-32chars-minimum-aaaa' && \
export GRPC_PORT=9090 && export LOG_LEVEL=debug && \
./bin/server.exe
```
监听日志:`goal sync completed count:N tenants:M operation=GoalScheduler`(scheduler 跑)。

- [ ] **Step 3: 创建 investment goal + 验证 current_amount 更新**

若 DB 无 investment goal,scheduler count=0(无操作,正常)。验证路径二选一:
- **A(有 investment goal)**:DB 查 `SELECT name, target_amount_cents, current_amount_cents FROM goals WHERE goal_type=3;` → current_amount_cents = Σ linked_account holdings mv(若 account 有 holdings)
- **B(无 investment goal,grpcurl 创建)**:登录(test@yucai.local/test1234)拿 token,grpcurl CreateGoal(investment, linked_account=<investment account id>),再 grpcurl SyncInvestmentGoals → DB 查 current_amount 更新

```bash
"/c/Users/andy/AppData/Local/Programs/Podman/podman.exe" exec yucai-pg psql -U yucai -d yucai -c "SELECT g.name, g.target_amount_cents, g.current_amount_cents, a.category FROM goals g LEFT JOIN accounts a ON a.id=g.linked_account_id WHERE g.goal_type=3;"
```
Expected:investment goals(current_amount 反映 Σ holdings mv,或 0 若 account 无 holdings)。记实际值。

- [ ] **Step 4: TaskStop server,记录证据**

停 background server。ledger 记 "Task 9:goal scheduler 跑 count=N,investment goal current_amount 反映 Σ holdings mv"。(无 commit)

---

## Task 10: Flutter data/domain(GoalView ds + entity + repo)+ 单测

**Files:**
- Create: `yucai/client/lib/holding/data/goal_view_ds.dart`(调 goal ListGoals type=investment)
- Create: `yucai/client/lib/holding/domain/entities/goal_view_entity.dart`(GoalView entity)
- Create: `yucai/client/lib/holding/data/goal_view_mapper.dart`(proto→entity)
- Modify: `yucai/client/lib/holding/domain/repositories/holding_repository.dart`(加 listInvestmentGoals 抽象)
- Modify: `yucai/client/lib/holding/data/holding_repository_impl.dart`(加实现)
- Test: `yucai/client/test/holding/data/goal_view_test.dart`

**Interfaces:**
- Consumes:Dart stub `GoalServiceClient.listGoals` + `ListGoalsRequest.goalType`(Task 6)+ `GoalDTO`(current/target/progress_pct/linked_account_id/is_completed)
- Produces:
  - `GoalView` entity(`{id, name, targetCents, currentCents, progressPct, linkedAccountId, isCompleted, deadline}`)
  - `HoldingRemoteDataSource.listInvestmentGoals() → Future<List<GoalView>>`(调 goal ListGoals type=INVESTMENT)
  - `HoldingRepository.listInvestmentGoals() → Future<Either<Failure, List<GoalView>>>`
- Task 11(presentation)依赖

**背景**:holding 模块调 goal gRPC(跨模块 client,holding import goal proto)。首批**客户端 filter linked_account**(investment goals 数量少,取全部 investment + client filter by holding.accountId;避免 proto/repo 加 linked_account filter)。goal.proto `GoalDTO` 已有 current/target/progress_pct/linked_account_id(D-goal 零 DTO 改)。

- [ ] **Step 1: 写 GoalView entity(goal_view_entity.dart)**

```dart
import 'package:equatable/equatable.dart';

class GoalView extends Equatable {
  const GoalView({
    required this.id,
    required this.name,
    required this.targetCents,
    required this.currentCents,
    required this.progressPct,
    this.linkedAccountId,
    this.isCompleted = false,
  });
  final String id;
  final String name;
  final int targetCents;
  final int currentCents;
  final double progressPct;
  final String? linkedAccountId;
  final bool isCompleted;

  @override
  List<Object?> get props => [id, name, targetCents, currentCents, progressPct, linkedAccountId, isCompleted];
}
```

- [ ] **Step 2: 写 goal_view_mapper.dart(proto→entity)**

```dart
import 'package:yucai_client/proto/goal/v1/goal.pb.dart' as goalpb;
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';

GoalView goalDtoToView(goalpb.GoalDTO dto) {
  return GoalView(
    id: dto.id,
    name: dto.name,
    targetCents: dto.targetAmountCents.toInt(),
    currentCents: dto.currentAmountCents.toInt(),
    progressPct: dto.progressPct,
    linkedAccountId: dto.linkedAccountId.isEmpty ? null : dto.linkedAccountId,
    isCompleted: dto.isCompleted,
  );
}
```
> `targetAmountCents`/`currentAmountCents` 是 protobuf Int64(getter),用 `.toInt()`(对齐 C Task 12 holding_mapper Int64 模式)。

- [ ] **Step 3: 写 goal_view_ds.dart(listInvestmentGoals)**

```dart
import 'package:yucai_client/proto/goal/v1/goal.pb.dart' as goalpb;
import 'package:yucai_client/proto/goal/v1/goal.pbgrpc.dart' as goalgrpc;
import 'package:yucai_client/holding/data/goal_view_mapper.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';

class GoalViewDataSource {
  GoalViewDataSource(this._client);
  final goalgrpc.GoalServiceClient _client;

  /// 取所有 investment goals(server 按 type=INVESTMENT filter)。
  /// 调用方(holding_repository)按 linked_account 客户端 filter。
  Future<List<GoalView>> listInvestmentGoals() async {
    final resp = await _client.listGoals(goalpb.ListGoalsRequest(
      goalType: goalpb.GoalType.GOAL_TYPE_INVESTMENT,
    ));
    return resp.goals.map(goalDtoToView).toList();
  }
}
```
> ⚠️ 确认 `GoalServiceClient.listGoals` + `ListGoalsRequest.goalType` 在 Dart stub(Task 6 gen-dart 生成)。若 holding 模块未注入 GoalServiceClient,getIt 注册 GoalViewDataSource(注入 GoalServiceClient)。

- [ ] **Step 4: holding_repository 抽象 + impl 加 listInvestmentGoals**

`holding_repository.dart` 加:
```dart
Future<Either<Failure, List<GoalView>>> listInvestmentGoals();
```
`holding_repository_impl.dart` 加(注入 GoalViewDataSource):
```dart
@override
Future<Either<Failure, List<GoalView>>> listInvestmentGoals() =>
    _guard(() => _goalViewDs.listInvestmentGoals());
```
> `_goalViewDs` 是新注入字段(`@LazySingleton()` GoalViewDataSource)。DI 注册(build_runner)。

- [ ] **Step 5: 单测(mapper + ds response-wiring)**

`goal_view_test.dart`:mapper(Int64→int + linkedAccountId 空处理)+ ds(mock GoalServiceClient.listGoals 返 2 investment goals → 断言 ds 返 2 GoalView)。

- [ ] **Step 6: build_runner + analyze + test**

```bash
cd /e/projects/syfinance/yucai && dart run build_runner build --delete-conflicting-output  # 注册 GoalViewDataSource
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/data/goal_view_ds.dart lib/holding/domain/entities/goal_view_entity.dart lib/holding/data/holding_repository_impl.dart
cd /e/projects/syfinance/yucai/client && flutter test test/holding/
```
Expected:build_runner 注册 GoalViewDataSource;analyze 0 新 error(22 基线);test PASS。

- [ ] **Step 7: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/holding/
git commit -m "feat(holding-d-goal-flutter): data/domain GoalView(listInvestmentGoals)

GoalView entity + mapper(proto GoalDTO Int64→int)+ GoalViewDataSource(调 goal
ListGoals type=INVESTMENT)+ holding_repository listInvestmentGoals。客户端 filter
linked_account(首批,investment goals 少)。DI 注册 GoalViewDataSource。mapper+ds 测。"
```

---

## Task 11: Flutter presentation(goal_link 接真填 ⏳D)+ widget test

**Files:**
- Modify: `yucai/client/lib/holding/presentation/pages/goal_link_page.dart`(接真,删 ⏳D 空态)
- Test: `yucai/client/test/holding/presentation/pages/goal_link_page_test.dart`

**Interfaces:**
- Consumes:`HoldingRepository.listInvestmentGoals`(Task 10)+ `holding.accountId`(从 holding 详情传)

**背景**:goal_link_page 从 holding 详情进(传 holding.accountId)。用 `FutureBuilder`(调 listInvestmentGoals + client filter linked_account=holding.accountId,无需新 bloc)。删 A-flutter Task 10 的 ⏳D 空态(`_pendingGoalEmpty`/`_overviewCard` 的 '—' / SnackBar「⏳D」)。

- [ ] **Step 1: Read goal_link_page.dart 现有(A-flutter Task 10 ⏳D 结构)**

```bash
grep -n "⏳D\|_pendingGoalEmpty\|_overviewCard\|_tapHolding\|_apiNote\|hourglass" /e/projects/syfinance/yucai/client/lib/holding/presentation/pages/goal_link_page.dart
```
记下:概览头(总数/超中/落后,现 '—')、goal 列表区(⏳ 空态)、holding picker、API note。

- [ ] **Step 2: goal_link_page 接真(FutureBuilder)**

改 goal_link_page:从构造接收 `holding`(含 accountId)+ `repo`(HoldingRepository)。用 FutureBuilder:
```dart
// initState 或 FutureBuilder:
final future = repo.listInvestmentGoals();
FutureBuilder<Either<Failure, List<GoalView>>>(
  future: future,
  builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const CircularProgressIndicator();
    }
    return snapshot.data!.fold(
      (f) => _errorState(f.displayMessage),
      (allInvestmentGoals) {
        // 客户端 filter linked_account = holding.accountId
        final goals = allInvestmentGoals
            .where((g) => g.linkedAccountId == holding.accountId)
            .toList();
        if (goals.isEmpty) return _emptyState('该账户暂无投资目标');
        return _goalsList(goals, holding);  // 概览头 + goal 卡片 + 贡献占比
      },
    );
  },
)
```
**填 6 个 ⏳D 区**:
- 概览头:总数(goals.length)/ 超前(progress≥100)/ 持平(80-100)/ 落后(<80)—— 替换 '—'
- goal 卡片:名 / current/target(元,cents/100)/ progress%(进度条)
- 该 holding 贡献:holding.marketValueCents / account.mv(或 / goal.target)占比
- 删 `_pendingGoalEmpty`(⏳ 空态)、`_tapHolding` SnackBar「⏳D」、API note 的 ⏳ 标注(改为实现说明)

- [ ] **Step 3: 删过时 ⏳ 注释 + API note 更新**

清 goal_link_page 文件头注释(line 10-24 的 "⏳D 待 goal.proto")+ `_apiNote` 的 "goal.backing_holding_id ⏳ D" → 改为"D-goal account 级:goal.linked_account_id 关联 investment account,progress = Σ holdings mv"(实现说明)。

- [ ] **Step 4: widget test**

`goal_link_page_test.dart`:mock repo.listInvestmentGoals → Right([2 goals,1 linked to holding.accountId,1 other])→ 渲染 1 goal + progress% + 贡献;Right([])→ 空态;Left → 错误态。

- [ ] **Step 5: build_runner + analyze + test**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/presentation/pages/goal_link_page.dart
cd /e/projects/syfinance/yucai/client && flutter test test/holding/
```
Expected:analyze 0 新 error;test PASS(现有 118 + 新增)。

- [ ] **Step 6: Commit**

```bash
cd /e/projects/syfinance
git add yucai/client/lib/holding/presentation/pages/goal_link_page.dart yucai/client/test/holding/presentation/pages/
git commit -m "feat(holding-d-goal-flutter): goal_link 接真填 ⏳D(account 级 goal + 贡献)

goal_link_page FutureBuilder 调 listInvestmentGoals + 客户端 filter
linked_account=holding.accountId。填概览头(总数/超前/持平/落后)+ goal 卡片
(progress%+current/target+进度条)+ 该 holding 贡献占比。删 A-flutter Task10
⏳D 空态(_pendingGoalEmpty/SnackBar/API note)。widget test(真数据+空态+错误)。"
```

---

## Task 12: 全链路验证 + final whole-branch review

**Files:** 无改动(验证 task)

- [ ] **Step 1: server 全量绿**

```bash
cd /e/projects/syfinance/yucai/server && go build ./... && go test ./... -count=1
```
Expected:PASS。

- [ ] **Step 2: flutter 全量绿**

```bash
cd /e/projects/syfinance/yucai/client && flutter analyze lib/holding/ lib/goal/ && flutter test test/holding/
```
Expected:analyze 0 新 error(22 基线 *.pbserver);test PASS(现有 118 + D-goal 新增)。

- [ ] **Step 3: 端到端(flutter run,见 [[yucai-dev-env]] debug 模式)**

```bash
cd /e/projects/syfinance/yucai/client && flutter run -d windows
```
验证:
1. holding 详情 → goal_link → 显示该 holding 所属 investment account 的 goals + progress% + current/target + 贡献占比
2. 概览头(总数/超前/持平/落后)真数据
3. 无 investment goal → 空态(非 ⏳D)
4. RPC fail → 错误态(非崩溃)

- [ ] **Step 4: final whole-branch review**

MERGE_BASE = `e801097`(C 终点,D-goal commits 从 `f7376a2` spec 起)。用 opus 广审 D-goal commits:
- correctness:SetCurrentAmount(auto-complete 不 uncomplete)/ SyncInvestmentGoals best-effort / GetAccountMarketValue tenant-scoped 聚合 / scheduler 跨 tenant fan-out / ListGoals type filter / 不破坏 goal 现有(savings/debt_payoff)
- 测试覆盖(domain/application/scheduler/repo/handler + Flutter data/presentation)
- 无 Critical/Important

---

## Self-Review(plan 自查)

**1. Spec coverage**(对照 spec 各节):
- §1 目标(investment goal 接 holding)→ Tasks 1-12 ✅
- §2 范围边界 → 全 task 在 D-goal 范围,无 D-currency/D-budget 越界 ✅
- §3 架构(scheduler + holding port + Flutter)→ Tasks 2/3/5/8/10/11 ✅
- §4.1 domain SetCurrentAmount → Task 1 ✅
- §4.2 holding GetAccountMarketValue → Task 2 ✅
- §4.3 goal application SyncInvestmentGoals + port → Task 3 ✅
- §4.4 goal scheduler → Task 5 ✅(加 TenantLister 跨 tenant,refine spec:scheduler 持 lister 非 service)
- §4.5 proto → Task 6 ✅(refine:加 ListGoals goal_type + SyncInvestmentGoals RPC;GoalDTO 零改)
- §4.6 wire+main → Task 8 ✅
- §5 schema 零新表 → 全 plan 无 ent schema 改 ✅
- §6 Flutter goal_link → Tasks 10/11 ✅(refine:客户端 filter linked_account,无 proto linked_account filter)
- §7 失败/降级 → Task 3 best-effort + Task 5 scheduler per-tenant 继续 + Task 11 空态/错误 ✅
- §8 测试 → 每 task TDD ✅
- §9 前置 → Task 0 ✅
- §10 实施顺序 → Tasks 0-12 ✅
- §11 决策记录 → Global Constraints 反映 ✅
- §12 风险 → Task 0 确认 / Task 1 FindAll type filter / Task 2 tenant-scoped / Task 5 scheduler 跨 tenant / Task 8 wire 手改 ✅

**2. Placeholder scan**:
- Task 2/3 的 fake repo 实现(fakeHoldingRepo account filter / fakeGoalRepo + newTestServiceWithGoals)→ 给了"照 C fakeSecurityRepo 模式 + 实现接口全方法"的明确路径(非 placeholder,必要的 test helper 发现,因接口方法多 plan 不凭记忆写全)
- Task 4 ent where `goal.GoalTypeEQ` 签名 → "Read 生成的 where.go 确认"(必要的接口发现)
- Task 8 wire 手改 → "Read wire_gen.go 镜像"(B/C 惯例)
- Task 11 goal_link 6 区填 → 给了 FutureBuilder 模式 + 每区映射(删 ⏳ + 真数据),Read 现有 goal_link_page 后实现
- 这些是"对现有代码精确对齐 + 照模式补全",非内容缺失

**3. Type consistency**:
- `Goal.SetCurrentAmount(amtCents int64)`:Task 1 定义 → Task 3 SyncInvestmentGoals 调用 → 一致 ✅
- `GoalRepository.FindAll(...goalType *GoalType...)`:Task 1 接口 → Task 3 调用(&investment)→ Task 4 实现 → 一致 ✅
- `AccountMarketValueSource.GetAccountMarketValue(ctx, tenantID, accountID)(int64, error)`:Task 1 port → Task 2 holding 实现 → Task 3 调用 → 一致 ✅
- `SyncInvestmentGoals(ctx, tenantID)(int, error)`:Task 3 per-tenant → Task 5 GoalSyncer 接口 → Task 7 handler(单 tenant)→ 一致 ✅
- `scheduler.TenantLister.FindAllIDs(ctx)([]uuid.UUID, error)`:Task 5 → Task 8 wire(auth.TenantRepository)→ 一致 ✅
- proto `ListGoalsRequest.goal_type` + `SyncInvestmentGoals` RPC:Task 6 → Task 7 handler(goalTypeFromProto)→ Task 10 Dart stub → 一致 ✅
- `GoalView` entity:Task 10 定义 → Task 11 用 → 一致 ✅

**4. Refine 记录(plan 对 spec 的合理细化)**:
- §4.4 scheduler 持 TenantLister(plan Task 5)vs spec 隐含 service 持 —— plan 选 scheduler 持(对齐 B scheduler 自包含 + 避免 goal service 跨模块 TenantLister)
- §4.5 proto 加 ListGoals goal_type filter + SyncInvestmentGoals RPC(plan Task 6)—— spec 说"零 proto 改"基于 ListGoals 已返 current+target(对),但 ListGoals 无 type filter(D-goal 需 filter investment)+ 加手动 RPC
- §6 Flutter 客户端 filter linked_account(plan Task 10)vs spec "ListGoals filter linked_account" —— plan 客户端 filter(首批简化,investment goals 少,避免 proto/repo linked_account 改)

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-06-30-holding-goal.md`. 执行方式见下方对话。
