# holding CreatedAt bug fix · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `3d34548`)
- **范围**: 修 production `Holding.CreatedAt` bug —— `BuyHolding` 创建 holding 时 `CreatedAt=zero` → `portfolioCAGR` 对所有用户 silently nil。方案 B(adapter `SaveOrUpdate` Create `IsZero` fallback)。**小 fix**:1 处 production 改 + 1 unit test + S4 注释更新。

## 1. 背景

holding performance e2e 套件(2026-07-19,commits `8694afa..3d34548`)Task 5 S4 发现 production bug,reviewer 完整诊断:

- `BuyHolding::ApplyBuy`([entity.go:64-73](../../yucai/server/internal/holding/domain/entity.go))只 bump `UpdatedAt`,不设 `CreatedAt`
- [service.go:96-100](../../yucai/server/internal/holding/application/service.go) BuyHolding 新 holding struct literal omit `CreatedAt`(zero)
- [holding_repo.go:35](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo.go) `SaveOrUpdate` Create 分支 `SetCreatedAt(h.CreatedAt)` **无条件透传** zero → 覆盖 ent schema `Default(time.Now).Immutable()`([holding.go:44-46](../../yucai/server/internal/holding/ent/schema/holding.go))
- → `earliestHoldingCreated`([service.go:1623](../../yucai/server/internal/holding/application/service.go))返 zero → `portfolioCAGR`([service.go:1554](../../yucai/server/internal/holding/application/service.go))`!earliest.IsZero()` guard skip → **production portfolioCAGR 对所有用户 silently nil**

S4 test 用预创 holding `SetCreatedAt` 绕过验数学(诚实 flag 非 mask;见 holding e2e 套件 Task 5 报告 `.superpowers/sdd/task-5-report.md`)。

## 2. 目标

`BuyHolding` 创 holding → `CreatedAt` 非 zero → `portfolioCAGR` 对所有用户正常显示。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | fix 层 | **adapter**(`SaveOrUpdate` Create `IsZero` fallback) | 兜底所有创建路径(防御,不依赖 application 记得设);修正"ent default 被 SetCreatedAt(zero) 错误覆盖"根因本身;最小改动(1 处条件) |
| 2 | 不用 application 层(BuyHolding 设 `CreatedAt`) | 否 | 只覆盖 BuyHolding 单点;未来新创建路径需各自设;依赖 application 记得 |
| 3 | ent `Default(time.Now)` 保留 | 是 | schema 已定义 default,本应生效;被 `SetCreatedAt(zero)` 错误覆盖;fix = zero 时不 SetCreatedAt → default 生效 |
| 4 | regression 用 unit test(adapter 层) | 是 | production `portfolioCAGR!=nil` 难 test(`days>=1` guard,刚 BuyHolding days≈0);unit test 锁 adapter `CreatedAt!=zero`(根因)+ 逻辑链(earliest!=zero → guard 通过 → CAGR!=nil) |
| 5 | S4 注释更新 | 是 | 顺修 M1(deferred misleading "mirrors production");fix 后 production CreatedAt=ent time.Now,S4 预创模拟"过去买"是独立 test 设计 |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| `holding_repo.go` SaveOrUpdate Create `IsZero` fallback | Trade/Snapshot CreatedAt(portfolioCAGR 不依赖;另有机制) |
| `holding_repo_test.go` unit test(锁 fallback) | 其他 trade type(sell/dividend/split 不创 holding) |
| S4 注释更新(M1) | S4 改用 BuyHolding(`ent time.Now`≠`SetNow` eval,独立 test 设计) |
| | production portfolioCAGR!=nil integration test(`days>=1` 难 test) |

## 5. 架构

| 层 | 改动 |
|---|---|
| adapter([holding_repo.go](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo.go)) | `SaveOrUpdate` Create 分支:`IsZero` fallback(zero 时不 SetCreatedAt → ent `Default(time.Now)`) |
| test([holding_repo_test.go](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo_test.go)) | 新 `TestSaveOrUpdate_CreateFillsDefaultCreatedAt` |
| test([holding_performance_integration_test.go](../../yucai/server/tests/holding_performance_integration_test.go)) | S4 注释更新(M1) |

## 6. 核心改动

### 6.1 holding_repo.go SaveOrUpdate Create 分支

[holding_repo.go:30-36](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo.go)(Create 分支),改条件 SetCreatedAt:

```go
// Create new
create := r.client.Holding.Create().
    SetID(h.ID).SetTenantID(h.TenantID).
    SetAccountID(h.AccountID).SetSecurityID(h.SecurityID).
    SetQuantity(h.Quantity).SetAvgCostCents(h.AvgCostCents).
    SetVersion(h.Version).SetUpdatedAt(h.UpdatedAt)
// CreatedAt: 显式值透传;zero 时不 SetCreatedAt -> ent Default(time.Now) 生效
// (修 BuyHolding omit CreatedAt 致 portfolioCAGR nil bug)。
if !h.CreatedAt.IsZero() {
    create = create.SetCreatedAt(h.CreatedAt)
}
if _, err := create.Save(ctx); err != nil {
    return fmt.Errorf("create holding: %w", err)
}
```

Update 分支([:42-51](../../yucai/server/internal/holding/adapter/driven/repository/holding_repo.go))不动(已不 SetCreatedAt)。

### 6.2 unit test(holding_repo_test.go 新)

```go
func TestSaveOrUpdate_CreateFillsDefaultCreatedAt(t *testing.T) {
    client := setupHoldingTestDB(t) // 现有 helper(testdb_test.go)
    repo := NewHoldingRepository(client)
    ctx := context.Background()

    // seed holding with CreatedAt zero(模拟 BuyHolding omit)
    h := &domain.Holding{
        ID: uuid.New(), TenantID: uuid.New(),
        AccountID: uuid.New(), SecurityID: uuid.New(),
        // CreatedAt zero(模拟 BuyHolding)
    }
    if err := repo.SaveOrUpdate(ctx, h); err != nil {
        t.Fatalf("SaveOrUpdate: %v", err)
    }

    // 查回 CreatedAt 非 zero(ent Default time.Now 生效)
    got, err := repo.FindByAccountAndSecurity(ctx, h.TenantID, h.AccountID, h.SecurityID)
    if err != nil || got == nil {
        t.Fatalf("find: %v", err)
    }
    if got.CreatedAt.IsZero() {
        t.Error("CreatedAt zero after SaveOrUpdate(Create with zero); want ent Default(time.Now) via IsZero fallback")
    }
}
```

### 6.3 S4 注释更新(holding_performance_integration_test.go)

TestS4 预创 holding 注释(M1 misleading "mirrors production")改为:production `BuyHolding` 现设 `CreatedAt=ent time.Now`(本 fix 后);S4 预创 `SetCreatedAt` 模拟"过去买"场景验 CAGR 数学(`ent time.Now`≠`SetNow` eval 2021,独立 test 设计,非 bug 绕过)。

## 7. 测试

- **unit**(holding_repo_test.go):`SaveOrUpdate` Create `CreatedAt=zero` → 持久化非 zero(IsZero fallback 生效)。显式非 zero → 透传照 set(不影响 test seed / Task 5 S4 预创)。
- **S4 注释更新**(非行为改)。
- **零回归**:全量 server 测 pass(套件 S1-S4 仍 pass —— S4 预创 `SetCreatedAt` 非零 → `IsZero=false` → 照 SetCreatedAt,不变)。

## 8. 风险

1. **ent Default(time.Now) vs SetNow 注入**:ent Create 用真实 `time.Now`(不受 `SetNow`)。production `CreatedAt=持久化时间`(正确语义)。test S4 用预创 `SetCreatedAt`(模拟过去买,独立)。无冲突。
2. **IsZero fallback 影响现有 test seed**:test 显式 `SetCreatedAt`(Task 5 预创 / 其他 seed)→ `IsZero=false` → 照 SetCreatedAt(不变)。仅 zero(BuyHolding omit)→ fallback。零回归。
3. **Update 分支**:不动(已不 SetCreatedAt)。无影响。

## 9. 参考

- holding e2e 套件:[2026-07-19-holding-e2e-design.md](2026-07-19-holding-e2e-design.md)(Task 5 发现 bug)+ plan + ledger `.superpowers/sdd/progress-holding-e2e.md`
- reviewer 诊断:entity.go:64-73 ApplyBuy + service.go:96-100 + holding_repo.go:35 + service.go:1554/1623 + schema/holding.go:44-46
- memory:`holding-performance-e2e-suite` + `holding-asset-management-todo`(follow-up 记录)
