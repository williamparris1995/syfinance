# budget repo.Update 原子性 + conflict mapping · 设计 spec

- **日期**: 2026-07-17
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans → subagent session)
- **分支**: 待定(main-driven,从 main 最新 `e77c564`)
- **范围**: budget M1 final review follow-up —— `BudgetRepository.Update` **包 ent 事务**(delete items + insert items + budget UPDATE 原子)+ **optimistic lock 冲突 → `codes.Aborted`**(现落 NotFound/Internal)。零 proto / 零 client / 零 ent schema。`repo.Update` 签名不变 → 4 个 caller 自动受益。

## 1. 背景

budget M1([2026-07-17-budget-m1-edit-update-design.md](2026-07-17-budget-m1-edit-update-design.md),merged main `e77c564`)的 final whole-branch review(opus)标 2 个 pre-existing Minor,bundle 成本 follow-up:

1. **`repo.Update` 非事务**([budget_repo.go:165-199](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165)):`delete items` + `insert items` + `budget UPDATE` 三条独立 SQL,无事务包装。若 budget UPDATE 因乐观锁 `WHERE Version(v-1)` 不匹配失败,items 变动(delete + insert)**已提交**,budget 字段/version 未更新 → DB 状态不一致(items 反映新状态,budget 行旧)。罕见(并发 edit)+ 轻影响(显示不一致,刷新重试),但 pre-existing(AddBudgetItem/RemoveBudgetItem 同路径同问题)。
2. **optimistic lock → `codes.Internal`/`NotFound` 非 `Aborted`**:budget [mapError:283-295](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go#L283) **有** `contains(msg, "optimistic lock") → codes.Aborted` 分支(line 290),但 `repo.Update` 失败时 `fmt.Errorf("update budget: %w", err)` 包装的 ent error 是 `*ent.NotFoundError`(WHERE 0 行),msg 含 "not found" → mapError **先匹配** `contains(msg, "not found") → codes.NotFound`(line 286,"not found" 在 "optimistic lock" 之前)→ 落 `codes.NotFound`(或 default `Internal`),**永远不到** "optimistic lock" 分支(dead)。client 收 404/500,无法区分"刷新重试"(retryable conflict)vs 通用错误。

memory `holding-asset-management-todo` D-budget M1 follow-up recommendation。

**关键约束**:budget mapError switch 顺序 `not found → invalid/must → optimistic lock → default`。optimistic lock err msg **绝不能含 "not found"**(否则被先匹配 NotFound)。

## 2. 目标

- `repo.Update` **原子**(ent tx:items delete+insert + budget update 同事务,失败回滚)
- optimistic lock 冲突 → **`codes.Aborted`**(可重试 conflict,client 提示"刷新重试")
- 4 caller(AddBudgetItem/RemoveBudgetItem/UpdateBudget/ComputeActuals)自动受益(签名不变)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | tx 范围 | **`repo.Update` 内部包 tx** | 签名不变 → 4 caller 自动受益;最小改动;ent 标准 `r.client.Tx(ctx)` |
| 2 | optimistic lock 检测 | **`budgetent.IsNotFound(err)`**(repo 阶段 NotFound = 乐观锁) | caller 先 FindByID 确认 budget 存在 → repo 阶段 NotFound 必是 version 不匹配(并发改);ent UpdateOneID WHERE 0 行返 NotFound |
| 3 | optimistic lock err 措辞 | **纯措辞 `"optimistic lock: budget X concurrently modified, refresh and retry"`,不 `%w` ent err** | 避免 msg 含 "not found" 被 mapError 先匹配 NotFound;不 `%w` ent NotFound 避免其 "not found" 渗入 msg |
| 4 | 其他 err(非 NotFound) | **`fmt.Errorf("update budget: %w", err)`** 照旧 | 保留上下文;非冲突的 DB/transport err 走 mapError default/Internal(合理) |
| 5 | mapError 改动 | **不改**(已有 "optimistic lock" → Aborted 分支) | repo 措辞修后 mapError 自动路由 Aborted;mapError switch 顺序不动 |
| 6 | tenant-scoped item delete | **defer** | `Where(budgetitem.BudgetID(b.ID))` 无 tenant predicate,但 budget ID 全局唯一 uuid,冗余;backup DeleteByTenant 也 budget-scoped;防御性价值低,单独审计 task |
| 7 | 范围 | **仅 `repo.Update` + 测试** | 零 proto/client/wire/schema;M1 final review bundle ① 非事务 + ② gRPC code |

## 4. 范围边界

| 在范围(follow-up) | 不在范围(defer / out) |
|---|---|
| `BudgetRepository.Update` 包 ent tx(delete+insert+update 原子) | tenant-scoped item delete(决策 6 defer) |
| `repo.Update` optimistic lock → "optimistic lock" 措辞 → mapError Aborted | AddBudgetItem/RemoveBudgetItem/UpdateBudget/ComputeActuals 调用方(签名不变,自动受益,无需改) |
| `repo.Update` 测试(tx 原子性 + optimistic lock Aborted mapping) | mapError 改动(已有分支)|
| | proto / client / wire / ent schema(零改)|

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| **adapter/driven**(budget) | `BudgetRepository.Update`([budget_repo.go:165](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165)) | 包 `r.client.Tx(ctx)`(delete items + insert items + budget update 同 tx,Rollback on err);budget update 失败 `budgetent.IsNotFound` → `"optimistic lock: ..."` 纯措辞;其他 err `"update budget: %w"` |
| **测试** | [tests/budget_integration_test.go](../../yucai/server/tests/budget_integration_test.go) | +tx 原子性测试(update 失败 → items 未改)+ optimistic lock → Aborted-mappable err 测试(经 mapError 断言 `codes.Aborted`) |

**不改**:domain / application / handler / proto / client / wire / ent schema。

## 6. 核心改动

### 6.1 repo.Update — ent tx + optimistic lock mapping

[budget_repo.go:165-199](../../yucai/server/internal/budget/adapter/driven/repository/budget_repo.go#L165) 整段替换。M1 Task 1 已补 `SetCurrencyCode` + delete err,本 follow-up 在其上**加 tx 包裹 + optimistic lock 检测**:

```go
// Update persists changes to a budget atomically (ent tx: delete old items +
// insert new items + update budget) with optimistic locking. A version
// conflict (concurrent edit since the caller's FindByID) returns an
// "optimistic lock: ..." error with NO "not found" substring, so budget
// mapError routes it to codes.Aborted (not codes.NotFound — the switch checks
// "not found" before "optimistic lock"). All callers (AddBudgetItem /
// RemoveBudgetItem / UpdateBudget / ComputeActuals) share this path, so all
// inherit atomicity + correct conflict mapping.
func (r *BudgetRepository) Update(ctx context.Context, b *domain.Budget) error {
	tx, err := r.client.Tx(ctx)
	if err != nil {
		return fmt.Errorf("begin budget tx: %w", err)
	}

	// Delete old items (tx-scoped).
	if _, err := tx.BudgetItem.Delete().
		Where(budgetitem.BudgetID(b.ID)).
		Exec(ctx); err != nil {
		_ = tx.Rollback()
		return fmt.Errorf("delete old budget items: %w", err)
	}

	// Insert new items (tx-scoped, full replace — item IDs change, budget ID stable).
	for _, item := range b.Items {
		if _, err := tx.BudgetItem.Create().
			SetID(item.ID).
			SetBudgetID(item.BudgetID).
			SetAccountID(item.AccountID).
			SetPlannedAmountCents(item.PlannedAmountCents).
			SetActualAmountCents(item.ActualAmountCents).
			SetNotes(item.Notes).
			Save(ctx); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("insert budget item: %w", err)
		}
	}

	// Update budget (tx-scoped, optimistic lock WHERE version = v-1).
	if _, err := tx.Budget.UpdateOneID(b.ID).
		Where(budget.Version(b.Version - 1)).
		SetName(b.Name).
		SetCurrencyCode(b.CurrencyCode).
		SetTotalAmountCents(b.TotalAmountCents).
		SetIsActive(b.IsActive).
		SetVersion(b.Version).
		SetUpdatedAt(b.UpdatedAt).
		Save(ctx); err != nil {
		_ = tx.Rollback()
		if budgetent.IsNotFound(err) {
			// WHERE matched 0 rows — budget was modified concurrently since
			// FindByID (caller confirmed existence). Pure phrasing, no "not
			// found", so mapError -> codes.Aborted (refresh-and-retry signal).
			return fmt.Errorf("optimistic lock: budget %s was modified concurrently, refresh and retry", b.ID)
		}
		return fmt.Errorf("update budget: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit budget tx: %w", err)
	}
	return nil
}
```

> ent API(plan 确认):`r.client.Tx(ctx) → *budgetent.Tx`(含 `tx.Budget` / `tx.BudgetItem` sub-clients,同 `*Client` 结构 —— account/auth/sync ent 的 `Tx` 范式);`budgetent.IsNotFound(err)`(budget ent 包生成的 `IsNotFound`,同其他 ent 包)。`tx.Rollback()` / `tx.Commit()` 标准。

### 6.2 mapError — 不改

[budget_handler.go:283-295](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go#L283) `mapError` 已有 `contains(msg, "optimistic lock") → codes.Aborted`(line 290)。repo 措辞修后自动路由。**switch 顺序不动**(`not found` 在前 —— 由 repo 措辞不含 "not found" 保证 optimistic lock 能到 line 290)。

## 7. 数据流

- **正常 update**:`service.X` → FindByID(version v)→ `budget.Update`(IncrementVersion v+1)→ `repo.Update`:`Tx` → delete old items + insert new + budget UPDATE `WHERE Version(v)`(=(v+1)-1,匹配 DB v)→ Commit。原子成功。
- **optimistic lock 冲突**(并发:FindByID 后另一 edit 让 DB v+1):budget UPDATE `WHERE Version(v)` 不匹配 DB v+1 → 0 行 → ent `NotFound` → `tx.Rollback()`(items 变动回滚,**原子**)→ `budgetent.IsNotFound(err)` → 返 `"optimistic lock: budget X concurrently modified, refresh and retry"`(不含 "not found")→ service propagate → handler `mapError` → `codes.Aborted`。client 提示"刷新重试"。
- **其他 err**(非 NotFound,如 DB down):Rollback → `"update budget: %w"` → mapError default → `codes.Internal`(合理,非冲突)。

## 8. 测试

- **tx 原子性**(`tests/budget_integration_test.go`):构造 budget update 让 budget UPDATE 失败(乐观锁,version 不匹配)+ 断言 **items 未改**(FindByID 后 items 仍是原 set,delete+insert 回滚)。这是 M1 Task 1 `TestBudgetRepoUpdate_OptimisticLock` 的强化版(M1 只断言 err,本 follow-up 加 items-unchanged 断言验证回滚)。
- **optimistic lock → Aborted**(`tests/`):integration test 经 service.UpdateBudget(或新 helper)触发乐观锁冲突 + 经 budget `mapError` 断言 `codes.Aborted`(非 NotFound/Internal)。验证 err 措辞不含 "not found"(否则 mapError 走 NotFound)。
- **正常 update 不回归**:现有 `TestBudgetRepoUpdate`(M1 Task 1)+ `TestBudgetUpdate`(M1 Task 2)+ `TestBudgetCRUD`(AddBudgetItem/RemoveBudgetItem 路径)全过 —— tx 包裹不影响正常路径。

## 9. 风险

1. **ent Tx API**(plan 确认):`r.client.Tx(ctx)` 返 `*budgetent.Tx`(Budget/BudgetItem sub-clients)。若 budget ent 未生成 Tx(plan Task 0 确认 ent client.go 有 Tx 方法 —— 标准 ent 生成,account/auth/sync 都有,budget 同构)。`budgetent.IsNotFound` 同理(plan 确认 budget ent 包有 IsNotFound)。
2. **mapError switch 顺序不变**:repo optimistic lock 措辞**必须不含 "not found"**(否则 mapError 先匹配 NotFound)。代码评审重点(err msg 措辞)。
3. **tx 性能**:每次 repo.Update 开 tx(3 SQL 原子)。正常路径开销小(单连接 tx)。AddBudgetItem/RemoveBudgetItem 也开 tx(它们调 repo.Update)。可接受(budget 操作低频)。
4. **Rollback err 忽略**:`_ = tx.Rollback()`(Rollback 失败通常是 tx 已自动回滚或连接问题,log 即可,不 propagate)。照 ent 惯例。
5. **caller 不需改**:`repo.Update` 签名不变(`Update(ctx, *domain.Budget) error`)→ AddBudgetItem/RemoveBudgetItem/UpdateBudget/ComputeActuals 调用方零改。约束 6 无 implementer 影响(interface 方法签名不变)。
6. **ComputeActuals persist 路径**:`ComputeActuals` 也调 repo.Update(ComputeActualsForItem + IncrementVersion + Update)。tx 包裹后 ComputeActuals 也原子受益(无需改)。

## 10. 参考

- budget M1 spec:[2026-07-17-budget-m1-edit-update-design.md](2026-07-17-budget-m1-edit-update-design.md)(repo.Update 非事务 + optimistic lock → Internal/NotFound 问题暴露)
- budget M1 final review recommendation(M1 progress ledger `.superpowers/sdd/progress-budget-m2.md` 或 M1 ledger):bundle ① 非事务 + ② gRPC code 到本 follow-up
- ent Tx 范式:[account ent client.go Tx:123](../../yucai/server/internal/account/ent/client.go#L123)(`c.Tx(ctx) → *Tx` sub-clients)
- optimistic lock 措辞范式对照:[account_repo.go:231-233](../../yucai/server/internal/account/adapter/driven/repository/account_repo.go#L231)(`fmt.Errorf("optimistic lock: version mismatch after update")`,但 account 用 n.Version 检查 dead,budget 用 ent.IsNotFound 检测正确)
- mapError:[budget_handler.go:283-295](../../yucai/server/internal/budget/adapter/driving/grpc/budget_handler.go#L283)("optimistic lock" → Aborted 分支已有)
- memory:`holding-asset-management-todo`(D-budget M1 follow-up recommendation)
