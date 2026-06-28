# 信用卡双轨同步(RecordPayment 双写)Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Checkbox (`- [ ]`) syntax.

**Goal:** RecordPayment(debt 还款 / receivable 收款)双写 —— 标 debt schedule paid(现状)+ 创建 transaction(复式)更新 account 余额,补 debt_handler.go:120 TODO。

**Architecture:** debt handler 注入 transaction service + AccountLookup;RecordPayment 按 debt.type 构建复式 entries(borrowedIn: asset-/liability-;borrowedOut: asset+/应收-),调 transaction.RecordTransaction → UpdateBalances。失败 best-effort。

**Tech Stack:** Go(ent + gRPC + proto + wire DI)+ Flutter(flutter_bloc,余额刷新)。

## Global Constraints

- **RecordPayment 双写**:debt.service.RecordPayment(标 schedule paid,现状)+ transaction.service.RecordTransaction(复式 entries)→ UpdateBalances。
- **borrowedIn entries**(我还债):credit from_account(asset-)+ debit debt.account_id(liability-)。金额 = entry.total。
- **borrowedOut entries**(我收款):debit from_account(asset+)+ credit debt.account_id(应收 asset-)。金额 = entry.total。
- **ChartOfAccountCode**:entries 用 account.chart_code(查 AccountLookup)。
- **from_account 验证**:AccountType.asset + current_balance ≥ entry.total(borrowedIn 还款);borrowedOut from_account 也 asset。货币同(debt.account_id + from_account 同 currency,否则 error)。
- **失败 best-effort**:debt.RecordPayment 先;transaction.RecordTransaction 后,失败 → `tracing` log + client toast「债务已记录,账户更新失败」(不回滚 debt)。
- **跨域注入**:debt handler 构造加 `transaction.Service` + `AccountLookup`(wire DI,同 server providers)。
- **分支**:`credit-card-sync`,BASE `a67c9aa`(spec)。
- **参考**:debt_handler.go RecordPayment(line 110-132,line 120 TODO);transaction RecordTransaction(service.go:33,entries + UpdateBalances)。
- **make 未装**:`go test ./internal/debt/...` 直接跑;`go generate ./internal/debt/ent/...`(scoped)。
- **tracing log(英文)**:御财 server 用 tracing,禁 println。

---

### Task 1: debt handler 注入 transaction service + AccountLookup

**Files:**
- Modify: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go`(构造加 transactionSvc + accountLookup)
- Modify: 御财 wire providers(debt handler 构造调用处,`yucai/server/cmd/server/wire*.go` 或 providers.go)

**Interfaces:**
- Consumes: `transaction.Service.RecordTransaction`(service.go:33)+ `AccountLookup`(transaction 包的 account 查询接口)
- Produces: `DebtHandler` 持有 `transactionSvc` + `accountLookup` 字段 → Task 2-3 用

- [ ] **Step 1: debt handler 构造加字段 + param**

`debt_handler.go` DebtHandler struct 加:
```go
type DebtHandler struct {
    service        application.Service
    transactionSvc *transactionApp.Service       // 双写:RecordPayment 创建 transaction
    accountLookup  transactionApp.AccountLookup   // 查 account chart_code + 余额验证
}
```
构造函数加 params(wire 注入)。找现有构造(likely `NewDebtHandler(service application.Service)`),改为 `NewDebtHandler(service application.Service, txnSvc *transactionApp.Service, accountLookup transactionApp.AccountLookup)`。

- [ ] **Step 2: wire providers 更新**

找 wire/providers.go 里 `NewDebtHandler` 调用处,加 transaction.Service + AccountLookup provider(御财 transaction 已有 providers,复用)。

- [ ] **Step 3: go build + test + commit**

```bash
cd yucai/server && go build ./... && go test ./internal/debt/...
git add yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go yucai/server/cmd/server/
git commit -m "feat(debt-handler): 注入 transaction service + AccountLookup(双写准备)"
```

---

### Task 2: RecordPayment 双写复式 entries(borrowedIn + borrowedOut)

**Files:**
- Modify: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler.go`(RecordPayment handler,补 line 120 TODO)
- Test: `yucai/server/internal/debt/adapter/driving/grpc/debt_handler_test.go`

**Interfaces:**
- Consumes: Task 1 transactionSvc + accountLookup;debt.service.RecordPayment(现状)
- Produces: RecordPayment 双写(debt paid + transaction entries → UpdateBalances)

- [ ] **Step 1: 写失败 test**

test:RecordPayment(borrowedIn)→ debt schedule paid + transaction 创建(credit from_account + debit debt.account_id)+ 两 account 余额更新。RecordPayment(borrowedOut)→ entries(debit from_account + credit debt.account_id)。

- [ ] **Step 2: 实现 buildEntries + 双写**

`debt_handler.go` RecordPayment(line 110-132)补:在 `h.service.RecordPayment`(标 paid)后,构建 entries 调 `h.transactionSvc.RecordTransaction`:
```go
// 按 debt.type 构建复式 entries(金额 = entry.total)
fromAcc, _ := h.accountLookup.Get(ctx, tenantID, fromAccountID)
debtAcc, _ := h.accountLookup.Get(ctx, tenantID, debt.AccountID)
entries := buildPaymentEntries(debt, fromAcc, debtAcc, resp.Entry.TotalCents)
txnResp, txnErr := h.transactionSvc.RecordTransaction(ctx, transactionApp.RecordTransactionRequest{
    TenantID:        tenantID,
    Description:     "RecordPayment 双写",
    Entries:         entries,
})
if txnErr != nil {
    // best-effort:debt 已 paid,transaction 失败 log(不回滚)
    // log 用 tracing
}
```
`buildPaymentEntries`:
```go
// borrowedIn:credit from_account(asset-)+ debit debt.account_id(liability-)
// borrowedOut:debit from_account(asset+)+ credit debt.account_id(应收 asset-)
func buildPaymentEntries(debt domain.DebtDetails, fromAcc, debtAcc Account, total int64) []transactionApp.EntryInput {
    if debt.DebtType == domain.DebtTypeBorrowedIn {
        return []transactionApp.EntryInput{
            {AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, CreditCents: total},
            {AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, DebitCents: total},
        }
    }
    // borrowedOut
    return []transactionApp.EntryInput{
        {AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, DebitCents: total},
        {AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, CreditCents: total},
    }
}
```
(EntryInput 字段名对齐 transaction.RecordTransactionRequest.Entries element type — implementer 确认 `RecordTransactionRequest` 的 entry 字段名。)

- [ ] **Step 3: test pass + commit**

```bash
cd yucai/server && go test ./internal/debt/...
git commit -m "feat(debt): RecordPayment 双写复式 entries(borrowedIn 还款 + borrowedOut 收款)"
```

---

### Task 3: 验证(from_account asset + 余额 + 货币)+ 失败 best-effort log

**Files:**
- Modify: `debt_handler.go`(RecordPayment 验证 + 失败 log)
- Test: `debt_handler_test.go`

**Interfaces:**
- Consumes: Task 2 buildEntries + transactionSvc
- Produces: 验证 + best-effort 失败处理

- [ ] **Step 1: 写失败 test**

test:from_account 非 asset → error;余额不足 → error;跨币种 → error;transaction 失败 → debt paid 保留 + log(best-effort,无 panic)。

- [ ] **Step 2: 实现验证 + log**

RecordPayment 前验证:
```go
if fromAcc.AccountType != AccountTypeAsset {
    return nil, status.Error(codes.InvalidArgument, "from_account must be asset")
}
if debt.DebtType == DebtTypeBorrowedIn && fromAcc.CurrentBalanceCents < total {
    return nil, status.Error(codes.FailedPrecondition, "from_account 余额不足")
}
if fromAcc.CurrencyCode != debtAcc.CurrencyCode {
    return nil, status.Error(codes.InvalidArgument, "跨币种,需手动处理")
}
```
失败 log(tracing):
```go
if txnErr != nil {
    error!(operation="record_payment_double_write", error=%txnErr, debt_id=%debt.ID, "transaction creation failed, debt kept paid (best-effort)")
}
```

- [ ] **Step 3: test pass + commit**

```bash
cd yucai/server && go test ./internal/debt/...
git commit -m "feat(debt): RecordPayment 验证(asset/余额/币种)+ 失败 best-effort log"
```

---

### Task 4: client RecordPayment 后 account 余额刷新

**Files:**
- Modify: `yucai/client/lib/debt/presentation/bloc/debt_bloc.dart`(RecordPayment 成功后触发 account 余额刷新)
- Modify: 详情页(可能 reload debt + account)
- Test: `debt_bloc_test.dart` / detail page test

**Interfaces:**
- Consumes: Task 2-3 server 双写(account 余额已更新 server 端)
- Produces: client 余额刷新(详情/列表反映新余额)

- [ ] **Step 1: 写失败 test**

test:RecordPayment 成功 → bloc 触发 account reload(或 detail reload 拿新余额)。

- [ ] **Step 2: 实现 refresh**

debt_bloc RecordPayment 成功后,dispatch AccountBloc reload(或 detail reload)。御财 AccountBloc 有 reload 机制(参考 currency/transaction bloc)。最简:bloc RecordPayment 成功 → emit trigger → 详情页 listen → reload debt(GetDebt)+ account。

- [ ] **Step 3: test pass + commit**

```bash
cd yucai/client && flutter test test/debt/presentation/
git commit -m "feat(debt-bloc): RecordPayment 后刷新 account 余额(双写结果反映)"
```

---

### Task 5: 全量验证 + 收尾

- [ ] **Step 1: 全量验证**

```bash
cd yucai/server && go test ./internal/debt/... ./internal/transaction/...
cd yucai/client && flutter test test/debt/ test/app/
cd yucai/client && flutter analyze lib/debt/ lib/app/
```

- [ ] **Step 2: GUI 验证(可选)**

```bash
cd yucai/server && go build -o bin/server ./cmd/server
# 启动 server(migrate 无新 column,只代码改)
cd yucai/client && flutter build windows --debug
```
GUI:登录 → 信用卡债务 → 确认还款(RecordPayment)→ from_account + credit_card 余额更新。

- [ ] **Step 3: commit 收尾**

```bash
git commit --allow-empty -m "chore(credit-card-sync): 全量验证通过"
```

---

## Self-Review

**1. Spec coverage**:
- §3 数据流(RecordPayment 双写)→ Task 1-2 ✓
- §4 复式 entries(borrowedIn/borrowedOut)→ Task 2 ✓
- §5 验证 + 失败 best-effort → Task 3 ✓
- §6 测试 → Task 1-4 test ✓
- client 余额刷新 → Task 4 ✓

**2. Placeholder scan**:无 TBD。Task 2 buildEntries 注释 implementer 确认 EntryInput 字段名(对齐 transaction.RecordTransactionRequest)—— 这是对齐提示,非 placeholder(代码完整,字段名可能微调)。

**3. Type consistency**:`buildPaymentEntries` 一致(Task 2 定义,Task 3 用)。`DebtTypeBorrowedIn`/`AccountTypeAsset` 御财 domain 常量(确认存在)。

无 gap。
