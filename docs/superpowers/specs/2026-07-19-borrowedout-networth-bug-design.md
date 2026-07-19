# BorrowedOut networth bug fix · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `a5c5369`)
- **范围**: 修 production bug #4(networth `SumRemainingByCurrency` 不 filter DebtType → BorrowedOut receivable principal 落 liability)。**最小 fix liab filter**(1 行)+ comment 同步 + test。

## 1. 背景

networth 多币种 e2e 套件(`9377bd8..a5c5369`)Task 2 out-of-scope note:networth `SumRemainingByCurrency`([debt/application/service.go:162-183](../../yucai/server/internal/debt/application/service.go))`FindAll(ctx, tenantID, page, nil)` typeFilter=nil → BorrowedOut(receivable)principal 计 liab(错)。

**调研纠正 reviewer 判断**:
- reviewer"networth asset 未 mirror receivable" **误判**。BorrowedOut double-write → receivable **asset** account(`AccountTypeAsset` + `AccountCategoryOtherAsset`;[debt_handler.go:135-141](../../yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go) + 486-500)→ receivable principal **已在 networth asset**(`SumBalancesByCurrency` filter `AccountTypeAsset`,含 receivable;`TestCreateDebt_DoubleWrite_EndToEnd` 验证)。
- **fix 是 liab filter**(非 receivable source port;加 source 会 double-count)。

第 4 production bug(CreatedAt + Source + lot ID + BorrowedOut)。

## 2. 目标

修 networth liab:BorrowedOut(receivable)不计 liab(只 BorrowedIn)。asset 不动(receivable 已在)。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 最小 fix liab filter | 是 | `SumRemainingByCurrency` FindAll typeFilter nil → `&BorrowedIn`(1 行);liab 只 BorrowedIn |
| 2 | 不加 receivable source port | 是 | reviewer 误判;receivable 已在 asset account balance(double-write);加 source double-count |
| 3 | filter `domain.BorrowedIn`(显式) | 是 | 非 Unspecified(normalize 语义;SQL `WHERE debt_type='borrowed_in'`;照 GetReceivablesSummary 反向范式) |
| 4 | comment 同步 | 是 | debt service.go("every debt"→"borrowed-in")+ account service.go:310-311(liab 说明 + receivable asset 注) |
| 5 | test 补 BorrowedOut 排除 | 是 | sumbycurrency_test 现全 BorrowedIn(漏 case = bug 根因);加 ExcludesBorrowedOut |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| `SumRemainingByCurrency` filter BorrowedIn(1 行) | receivable source port(double-count 风险) |
| comment 同步(debt + account service.go) | schema/proto/wire 改 |
| debt sumbycurrency_test ExcludesBorrowedOut | double-write best-effort 边缘(debt 创建路径,独立) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| production fix | [debt/application/service.go:166](../../yucai/server/internal/debt/application/service.go) | FindAll typeFilter nil → `&BorrowedIn` |
| comment | debt service.go + [account service.go:310-311](../../yucai/server/internal/account/application/service.go) | liab 只 BorrowedIn + receivable asset 注 |
| test | [debt/application/sumbycurrency_test.go](../../yucai/server/internal/debt/application/sumbycurrency_test.go) | +`TestSumRemainingByCurrency_ExcludesBorrowedOut` |

## 6. 核心改动

### 6.1 fix SumRemainingByCurrency filter

[debt/application/service.go:164-166](../../yucai/server/internal/debt/application/service.go) FindAll:
```go
page := domain.PageRequest{PageSize: 100}
in := domain.BorrowedIn  // liab 只含 borrowed-in(BorrowedOut receivable 已在 asset account balance via double-write)
for {
	result, err := s.repo.FindAll(ctx, tenantID, page, &in)  // ← nil 改 &in
```

### 6.2 comment 同步

- debt service.go:153-161:"every debt" → "every borrowed-in debt (BorrowedOut receivables excluded — tracked as asset account balances via double-write)"
- account service.go:310-311:"liabilities are tracked separately via SumRemainingByCurrency" → "liabilities (borrowed-in only) tracked via SumRemainingByCurrency; receivables (borrowed-out) tracked as asset account balances via debt double-write"

### 6.3 test ExcludesBorrowedOut

[debt/application/sumbycurrency_test.go](../../yucai/server/internal/debt/application/sumbycurrency_test.go)(照现有 test fake repo 范式):
- seed 1 BorrowedIn(principal 5000)+ 1 BorrowedOut(principal 3000)
- `SumRemainingByCurrency` → 验 only BorrowedIn 5000(BorrowedOut 3000 排除)

## 7. 数据流

```
fix: SumRemainingByCurrency FindAll typeFilter &BorrowedIn
→ repo SQL WHERE debt_type = 'borrowed_in'
→ liab 只 BorrowedIn(BorrowedOut receivable 排除)
→ networth: asset(account balance 含 receivable)+ liab(BorrowedIn only)
→ net = asset − liab(BorrowedOut 不双重计)
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestSumRemainingByCurrency_ExcludesBorrowedOut | liab filter BorrowedIn | only BorrowedIn 5000(BorrowedOut 3000 排除) |

零回归:全量 server 测 pass + build green。

## 9. 风险

1. **filter `domain.BorrowedIn` 显式**(非 Unspecified;normalize 语义;SQL WHERE)。
2. **comment 同步**(防未来 reviewer 再误判)。
3. **sumbycurrency_test fake repo**(typeFilter support;sumbycurrency_test.go:45-56 验 typeFilter)。
4. **wire 不动**(debtService filter 改后 networth 自动受益)。
5. **double-write best-effort 边缘**(debt 创建 double-write 失败 → receivable balance=0 but debt.remaining>0;非本 scope,独立)。

## 10. 参考

- bug 现场:[debt/application/service.go:162-183](../../yucai/server/internal/debt/application/service.go)(SumRemainingByCurrency FindAll nil)
- DebtType:[debt/domain/valueobject.go:40-58](../../yucai/server/internal/debt/domain/valueobject.go)(BorrowedIn/BorrowedOut)
- repo filter:[debt/domain/repository.go:24-27](../../yucai/server/internal/debt/domain/repository.go)(FindAll typeFilter)
- BorrowedOut double-write:[debt_handler.go:135-141](../../yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go) + 486-500(receivable asset account)
- networth asset source:[account/application/service.go:304-339](../../yucai/server/internal/account/application/service.go)(SumBalancesByCurrency filter asset,含 receivable)
- GetReceivablesSummary 反向范式:[debt/application/service.go:308-323](../../yucai/server/internal/debt/application/service.go)(BorrowedOut filter)
- networth 多币种套件:[2026-07-19-networth-multicurrency-design.md](2026-07-19-networth-multicurrency-design.md)(out-of-scope note 发现 bug)
