# budget M2 · ListBudgets N×M query 批量化 · 设计 spec

- **日期**: 2026-07-17
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans,**plan/subagent 下 session**)
- **分支**: 待定(main-driven,从 main 最新)
- **范围**: budget M2 defer —— `ListBudgets`/`GetBudget`/`GetBudgetByMonth` read-time actuals 的 **N×M query → month 聚合 batch**(一次 query per month,所有 account totals)。零 proto / 零 ent schema。

## 1. 背景

D-budget([2026-07-01-holding-budget-design.md](2026-07-01-holding-budget-design.md))引入 budget actuals **读时算**(`computeActualsReadTime`,[budget/application/service.go:200-217](../../yucai/server/internal/budget/application/service.go#L200-L217))。currents 流程:

- `ListBudgets`([service.go:74-89](../../yucai/server/internal/budget/application/service.go#L74-L89)):`FindAll`(N budget)→ 每个 budget `computeActualsReadTime` → 每个 item `entryFunc(ctx, item.AccountID, from, to)`
- `entryFunc` = wire 闭包 over `transaction.SpendingByAccount`([txn service.go:117](../../yucai/server/internal/transaction/application/service.go#L117))→ `txnRepo.SumEntryTotalsByAccount`([txn_repo.go:890-914](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go#L890-L914),**单 account** raw SQL)

**N×M 问题**:总 DB query = Σ(all items across all budgets)。budget 多时(12 月 × 多 expense item)几十~上百 query。`GetBudget`/`GetBudgetByMonth` 单 budget 同样 per-item query(M query)。

memory `holding-asset-management-todo` D-budget defer M2:"ListBudgets N×M query"。

**关键洞察**:budget item = `(accountID = expense account, budget.Month)`。`SumEntryTotalsByAccount` 单 account + 单 date range → 可改 month 聚合(一次 query per month,所有 account totals via `GROUP BY account_id`)。

## 2. 目标

read-time actuals query 数:
- `ListBudgets`:**N×M → distinct months**(通常 1-12)
- `GetBudget`/`GetBudgetByMonth`:**M → 1**

通过 transaction repo 新 `SumEntryTotalsByMonth`(GROUP BY account_id)+ budget batch entryFunc。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 优化方案 | **A month 聚合 batch** | query N×M → distinct months(最彻底);B 去重 cache 仍 unique (account,month) pairs,效果次;C cache actuals 实时性差 + invalidation 复杂 |
| 2 | 范围 | **all read-time actuals**(ListBudgets + GetBudget + GetBudgetByMonth) | 三者共享 `computeActualsReadTime`,batch 统一受益 |
| 3 | ComputeActuals(persist RPC)| **保持单 entryFunc,不改** | 用户显式触发频率低;persist 逻辑(per-item IncrementVersion)与 read-time 不同;范围外 |
| 4 | batch 接口位置 | **transaction.SpendingByAccountByMonth service 方法 + wire 闭包注入 budget** | 对齐现有 SpendingByAccount 单 account 模式;budget 不 import transaction(port 模式,照 D-budget entryFunc 闭包) |
| 5 | repo 返回类型 | `map[uuid.UUID]AccountTotals{Debit,Credit}` | month range 内所有有活动 account 的 totals;budget item 按 accountID 查 map 算 net(debit−credit) |
| 6 | ListBudgets batch 策略 | **按 budget.Month 分组,每 month 1 query + 内存 cache** | distinct months 通常 1-12,远小于 N×M;同 month 多 budget 共享一次 query |
| 7 | AccountTotals type 归属 | **transaction domain**(repo 返)+ budget 自定义 `EntryTotals` type(budget 不 import transaction domain) | DDD 边界:budget application 用自己 type,wire 闭包转换 |

## 4. 范围边界

| 在范围 | 不在范围(defer / out) |
|---|---|
| transaction domain `TransactionRepository` +`SumEntryTotalsByMonth` | `ComputeActuals` persist RPC(保持单 entryFunc) |
| transaction ent impl(raw SQL GROUP BY account_id) | client / proto(零改) |
| transaction application +`SpendingByAccountByMonth` | D-budget 其他 defer(M1 edit delete+recreate / M3 多币种原币相加) |
| budget application +`EntryTotalsMonthFunc` + `entryMonthFunc` field + `NewService` 加参数 | `GetBudget`/`GetBudgetByMonth` 单 budget 仍走 `computeActualsReadTime`(内改 batch,签名不变) |
| budget `computeActualsReadTime` 改 batch + `ListBudgets` `computeActualsReadTimeBatch`(按 month 分组) | transaction repo 其他方法(SpendingByAccount 单 account 保留供 ComputeActuals persist) |
| wire `providers.go` budget `entryMonthFunc` 闭包 + `wire_gen.go` 镜像 | |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| **domain**(transaction)| `TransactionRepository` interface + `AccountTotals` type | +`SumEntryTotalsByMonth(ctx, tenantID, from, to) (map[uuid.UUID]AccountTotals, error)` |
| **adapter/driven**(transaction)| `TransactionRepository` ent impl | raw SQL `GROUP BY account_id WHERE tenant + date range`(rebindPlaceholders sqlite/postgres,对齐 `SumEntryTotalsByAccount`) |
| **application**(transaction)| `Service` | +`SpendingByAccountByMonth`(薄包装 repo,对齐 `SpendingByAccount`) |
| **application**(budget)| `Service` | +`EntryTotals` type + `EntryTotalsMonthFunc` type + `entryMonthFunc` field;`NewService` 加参数;`computeActualsReadTime` 改 batch;`ListBudgets` 改 `computeActualsReadTimeBatch`(按 month 分组) |
| **wire** | `providers.go` + `wire_gen.go` | budget `entryMonthFunc` 闭包 over `txnSvc.SpendingByAccountByMonth`(转换 AccountTotals→EntryTotals)+ 注入 |

## 6. 核心改动

### 6.1 transaction domain — repo interface + AccountTotals

[transaction/domain/repository.go](../../yucai/server/internal/transaction/domain/repository.go) `TransactionRepository` interface 加方法 + 新 type:

```go
// AccountTotals is one account's debit/credit totals over a period (used by
// budget batch actuals — SumEntryTotalsByMonth groups by account_id).
type AccountTotals struct {
    DebitCents  int64
    CreditCents int64
}

// SumEntryTotalsByMonth returns debit/credit totals grouped by account_id for
// entries whose transaction_date is in [from, to], tenant-scoped. One map entry
// per account with activity in the range. Used by budget batch actuals
// (replaces N×M per-item SumEntryTotalsByAccount calls with one query per month).
SumEntryTotalsByMonth(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]AccountTotals, error)
```

### 6.2 transaction ent impl — raw SQL

[transaction_repo.go](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go)(对齐 `SumEntryTotalsByAccount:890-914`):

```go
func (r *TransactionRepository) SumEntryTotalsByMonth(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
    if r.rawDB == nil {
        return nil, fmt.Errorf("sum entry totals by month requires the underlying *sql.DB (rawDB is nil)")
    }
    q := `
        SELECT e.account_id, COALESCE(SUM(e.debit_cents), 0), COALESCE(SUM(e.credit_cents), 0)
        FROM ` + transactionEntryTable + ` e
        JOIN ` + transactionTable + ` t ON t.id = e.transaction_id
        WHERE t.tenant_id = ?
          AND t.deleted_at IS NULL
          AND t.transaction_date >= ?
          AND t.transaction_date <= ?
        GROUP BY e.account_id
    `
    q = rebindPlaceholders(q, r.rawDialect)
    rows, err := r.rawDB.QueryContext(ctx, q, tenantID, from, to)
    if err != nil {
        return nil, fmt.Errorf("sum entry totals by month: %w", err)
    }
    defer rows.Close()
    out := make(map[uuid.UUID]domain.AccountTotals)
    for rows.Next() {
        var accID uuid.UUID
        var debit, credit int64
        if err := rows.Scan(&accID, &debit, &credit); err != nil {
            return nil, fmt.Errorf("scan entry totals by month: %w", err)
        }
        out[accID] = domain.AccountTotals{DebitCents: debit, CreditCents: credit}
    }
    return out, rows.Err()
}
```

### 6.3 transaction application — SpendingByAccountByMonth

[transaction/application/service.go](../../yucai/server/internal/transaction/application/service.go)(对齐 `SpendingByAccount:117-123`):

```go
// SpendingByAccountByMonth returns debit/credit totals grouped by account_id
// for [from, to], tenant-scoped. Budget batch actuals port: one query replaces
// N×M per-item SpendingByAccount calls. Thin wrapper over the repository.
func (s *Service) SpendingByAccountByMonth(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]domain.AccountTotals, error) {
    totals, err := s.txnRepo.SumEntryTotalsByMonth(ctx, tenantID, from, to)
    if err != nil {
        return nil, fmt.Errorf("spending by account by month: %w", err)
    }
    return totals, nil
}
```

### 6.4 budget application — batch entryFunc + computeActualsReadTime 改 batch

[budget/application/service.go](../../yucai/server/internal/budget/application/service.go):

```go
// EntryTotals is one account's debit/credit over a period (budget-local copy
// of transaction.AccountTotals — budget does not import transaction domain).
type EntryTotals struct {
    DebitCents  int64
    CreditCents int64
}

// EntryTotalsMonthFunc returns debit/credit totals grouped by account_id for
// [from, to], tenant-scoped. Batch port for read-time actuals (replaces
// per-item EntryTotalsFunc for ListBudgets/GetBudget*). nil → actuals stay 0.
type EntryTotalsMonthFunc func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]EntryTotals, error)

type Service struct {
    repo           domain.BudgetRepository
    entryFunc      EntryTotalsFunc       // 单 account(ComputeActuals persist 用,保持)
    entryMonthFunc EntryTotalsMonthFunc  // batch(read-time actuals 用,新)
}

func NewService(repo domain.BudgetRepository, entryFunc EntryTotalsFunc, entryMonthFunc EntryTotalsMonthFunc) *Service {
    return &Service{repo: repo, entryFunc: entryFunc, entryMonthFunc: entryMonthFunc}
}
```

`computeActualsReadTime` 改 batch(单 budget:1 month query 替代 M;GetBudget/GetBudgetByMonth 受益):

```go
// computeActualsReadTime fills each item's ActualAmountCents via one batch
// month query (entryMonthFunc), not per-item. nil entryMonthFunc → actuals 0.
// err → all items 0 + slog (best-effort, 不 propagate)。
func (s *Service) computeActualsReadTime(ctx context.Context, b *domain.Budget) {
    if s.entryMonthFunc == nil {
        return
    }
    from, to := monthRange(b.Month)
    totals, err := s.entryMonthFunc(ctx, b.TenantID, from, to)
    if err != nil {
        slog.Error("budget actuals: entryMonthFunc failed",
            "operation", "budget.computeActualsReadTime",
            "budget_id", b.ID.String(), "error", err.Error())
        for i := range b.Items { b.Items[i].ActualAmountCents = 0 }
        return
    }
    for i := range b.Items {
        if t, ok := totals[b.Items[i].AccountID]; ok {
            b.Items[i].ActualAmountCents = t.DebitCents - t.CreditCents
        } else {
            b.Items[i].ActualAmountCents = 0
        }
    }
}
```

`ListBudgets` 改 `computeActualsReadTimeBatch`(按 month 分组,每 month 1 query):

```go
func (s *Service) ListBudgets(ctx context.Context, req ListBudgetsRequest) (*ListBudgetsResult, error) {
    result, err := s.repo.FindAll(ctx, req.TenantID, req.ActiveOnly, req.Page)
    if err != nil {
        return nil, fmt.Errorf("list budgets: %w", err)
    }
    s.computeActualsReadTimeBatch(ctx, req.TenantID, result.Items)
    dtos := make([]BudgetDTO, len(result.Items))
    for i, b := range result.Items {
        dtos[i] = BudgetToDTO(&b)
    }
    return &ListBudgetsResult{Budgets: dtos, NextPageToken: result.NextPageToken, TotalCount: result.TotalCount}, nil
}

// computeActualsReadTimeBatch fills actuals for many budgets with one query
// per distinct month (vs N×M per-item). nil entryMonthFunc → no-op。
func (s *Service) computeActualsReadTimeBatch(ctx context.Context, tenantID uuid.UUID, budgets []domain.Budget) {
    if s.entryMonthFunc == nil {
        return
    }
    monthCache := map[string]map[uuid.UUID]EntryTotals{}
    for i := range budgets {
        month := budgets[i].Month
        if _, cached := monthCache[month]; cached {
            continue
        }
        from, to := monthRange(month)
        totals, err := s.entryMonthFunc(ctx, tenantID, from, to)
        if err != nil {
            slog.Error("budget actuals batch: entryMonthFunc failed",
                "operation", "budget.computeActualsReadTimeBatch",
                "month", month, "error", err.Error())
            monthCache[month] = nil // 标记已尝试(失败,item 留 0)
            continue
        }
        monthCache[month] = totals
    }
    for i := range budgets {
        totals := monthCache[budgets[i].Month]
        for j := range budgets[i].Items {
            if totals != nil {
                if t, ok := totals[budgets[i].Items[j].AccountID]; ok {
                    budgets[i].Items[j].ActualAmountCents = t.DebitCents - t.CreditCents
                    continue
                }
            }
            budgets[i].Items[j].ActualAmountCents = 0
        }
    }
}
```

### 6.5 wire — budget entryMonthFunc 闭包注入

`providers.go` `provideBudgetService`(加 entryMonthFunc 参数)+ `wire_gen.go` 镜像:

```go
func provideBudgetService(repo *budgetrepo.BudgetRepository, txnSvc *transactionapp.Service) *budgetapp.Service {
    entryFunc := func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
        d, c, err := txnSvc.SpendingByAccount(ctx, accountID, from, to)
        return d, c, err
    }
    entryMonthFunc := func(ctx context.Context, tenantID uuid.UUID, from, to time.Time) (map[uuid.UUID]budgetapp.EntryTotals, error) {
        totals, err := txnSvc.SpendingByAccountByMonth(ctx, tenantID, from, to)
        if err != nil {
            return nil, err
        }
        out := make(map[uuid.UUID]budgetapp.EntryTotals, len(totals))
        for acc, t := range totals {
            out[acc] = budgetapp.EntryTotals{DebitCents: t.DebitCents, CreditCents: t.CreditCents}
        }
        return out, nil
    }
    return budgetapp.NewService(repo, entryFunc, entryMonthFunc)
}
```

(`provideBudgetService` 签名 + `wire_gen.go` provider 声明顺序手改,memory `yucai-wire-handmaintained`。)

## 7. 数据流

- **GetBudget / GetBudgetByMonth**:`FindByID`/`FindByMonth` → `computeActualsReadTime`(1 `entryMonthFunc` query = `SpendingByAccountByMonth`)→ map 填 item(**M query → 1**)
- **ListBudgets**:`FindAll` → `computeActualsReadTimeBatch`(按 month 分组,每 month 1 query + 内存 cache)→ 填所有 budget item(**N×M → distinct months**)
- **ComputeActuals(persist)**:保持 `entryFunc` 单 account per-item(范围外)

## 8. 测试

- **transaction domain/impl** `SumEntryTotalsByMonth`(enttest SQLite):多 account entries → map 正确(accountID → debit/credit);tenant 隔离;date range 过滤;空 range → 空 map;soft-deleted 排除
- **transaction application** `SpendingByAccountByMonth`:wrapper 委托 repo(mock)
- **budget application**:
  - `computeActualsReadTime` batch:单 budget,1 query,map 填 item(actual = debit−credit);nil entryMonthFunc → actuals 0;err → actuals 0 + 不 panic
  - `ListBudgets` `computeActualsReadTimeBatch`:多 budget 多 month,query 数 = distinct months(用 fake counter 验,非 items);同 month 多 budget 共享;actuals 正确
- **interface 加方法**:`TransactionRepository` 加 `SumEntryTotalsByMonth` → grep 全 implementer(real repo + `_FakeTxnRepo` / `_MockTxnRepo` / 其他 test fake),补 stub(memory 教训 + CLAUDE.md 约束 6:**implementer 跑全量 suite 非 scoped**)

## 9. 风险

1. **interface 加方法**(CLAUDE.md 约束 6):`TransactionRepository` +`SumEntryTotalsByMonth` → 全 implementer(real + test fakes)需实现。grep 独有方法名(SumEntryTotalsByMonth)定位 implementer。implementer 跑**全量 suite** 非 scoped(否则跨包 fake 漏改致 build fail)。
2. **wire 手改**(memory `yucai-wire-handmaintained`):`provideBudgetService` 签名加 `txnSvc`(或 entryMonthFunc 闭包)+ `wire_gen.go` provider 声明顺序镜像。不跑 wire CLI。
3. **raw SQL dialect**:`SumEntryTotalsByMonth` 用 `rebindPlaceholders`(sqlite `?` vs postgres `$N`),对齐 `SumEntryTotalsByAccount`。enttest SQLite + prod postgres 都覆盖。
4. **`ComputeActuals`(persist)保留单 entryFunc**:范围外。但 `NewService` 加 `entryMonthFunc` 参数 → ComputeActuals 调用方不变(它用 `entryFunc`)。确认 `entryFunc` 仍注入(wire 双闭包)。
5. **monthCache nil 标记**:失败 month 标 nil(避免重试 + item 留 0)。map[key]nil vs 不存在 —— 代码用 `totals != nil` 区分(见 6.4)。
6. **budget.TenantID**:确认 `domain.Budget` 有 `TenantID` field(computeActualsReadTime/ Batch 用)。若跨 budget tenant 混(不应,ListBudgets 已 tenant-scoped),用 req.TenantID 而非 budget.TenantID(6.4 用 tenantID 参数)。

## 10. 参考

- D-budget spec:[2026-07-01-holding-budget-design.md](2026-07-01-holding-budget-design.md)(actuals 读时算 + entryFunc 闭包 port 模式)
- transaction repo 单 account 范式:[transaction_repo.go SumEntryTotalsByAccount:890-914](../../yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go#L890-L914)
- memory:`holding-asset-management-todo`(D-budget M2 defer)、`yucai-wire-handmaintained`(wire 手改)、CLAUDE.md 约束 6(interface 加方法 grep 全 implementer)
