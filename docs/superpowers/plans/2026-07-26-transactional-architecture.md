# 事务一致性架构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立御财 server 跨模块事务一致性架构——共享 `*sql.DB` + `sqltx` TxContext 基础设施,把 P0 四处财务写(交易创建/holding/debt/template autoRecord)包成原子事务,并补 autoRecord 幂等键防并发重复记账。

**Architecture:** wire 注入单例 `*sql.DB` 到 9 个模块 ent client;新 `sqltx` 包提供 `WithTx`(包装 `*sql.Tx` 为跨包通用的 `dialect.Driver`,支持"加入已有 tx"嵌套语义)+ `DriverFrom`;各 P0 repo 加 `clientFor(ctx)` helper(ctx 有 tx→tx-bound client,无→默认 client,向后兼容);编排 service 层 `WithTx` 包原子单元,tx 经 ctx 传播到整条写链(含跨模块 recorder port / balance updater 背后的 repo)。

**Tech Stack:** Go 1.x,ent(多独立 codegen 包),PostgreSQL/pgx,wire(`wire_gen.go` 手维护),SQLite(enttest 单元/集成测),grpcurl(Postgres e2e)。

## Global Constraints

- **wire_gen.go 手改**(CLAUDE.md ②):`wire/wire_gen.go` 是命令式 `InitializeApp` 逐行调 provider,不跑 wire CLI;改 provider 签名后镜像手改,每改一个 `go build ./cmd/server` 验证;消费方在依赖方之后声明。
- **ent schema 改后 regen**(CLAUDE.md ⑤):新表/字段改 `*/ent/schema/*.go` 后 `go generate ./...`(各模块 ent codegen),diff 审查。
- **interface 加方法**(CLAUDE.md ⑥):改 repo/balance interface 签名时 grep 全 implementer(含 test fake),implementer 跑全量 suite。
- **English 日志**:slog 无 CJK,key-value 格式。
- **每步 build+test 绿**:每 task 结束 `go build ./...` + `go test ./...` 通过才进下一 task。
- **执行分支**:在 feature 分支(或 worktree)执行,每 task 一个 commit;commit message 英文 `feat(tx)/refactor(tx)/test(tx): ...`。
- **scope**:A+B+C(本 plan)。D(JIT provisioning,auth 模块,P1)拆独立 plan,不在本 plan。

参考 spec:[2026-07-26-transactional-architecture-design.md](../specs/2026-07-26-transactional-architecture-design.md)。

---

## File Structure

**Create:**
- `yucai/server/internal/sqltx/sqltx.go` — `WithTx` / `DriverFrom` + 内部 txDriver(跨包通用 `dialect.Driver`,包装 `*sql.Tx`)。
- `yucai/server/internal/sqltx/sqltx_test.go` — WithTx 生命周期 + txDriver 转发 + 嵌套(加入已有 tx)测试。
- `yucai/server/internal/sqltx/integration_test.go` — 共享 db 两模块 ent client 同 tx 回滚集成测。
- `yucai/server/internal/template/ent/schema/template_record_log.go` — autoRecord 幂等 log 表(C1)。
- 各 P0 repo 的 `clientFor` helper(加在现有 repo 文件,非新文件)。
- 各 P0 事务化的测试文件(就近 `_test.go`)。

**Modify:**
- `yucai/server/wire/providers.go` — 新 `provideDB` + 9 个 `provide*EntClient` 改签名 + `provideTransactionRepo` db 源。
- `yucai/server/wire/wire_gen.go` — 镜像手改 provider 调用。
- P0 repo 写方法:`transaction_repo.go` / `account_repo.go` / `holding_repo.go` / `trade_repo.go` / `lot_repo.go` / `debt_repo.go` / `template_repo.go` — `r.client.X → r.clientFor(ctx).X`。
- P0 service:`transaction/application/service.go`(SimpleExpense/Income/Transfer+CreateTransaction)/ `holding/application/service.go`(BuyHolding/SellHolding)/ `debt/application/service.go`(还款)/ `template/application/service.go`(autoRecord)— 包 `sqltx.WithTx`,注入 `*sql.DB`。
- `yucai/server/internal/transaction/adapter/driven/balance/updater.go` — 经 accountRepo,account_repo clientFor 即覆盖。
- `yucai/server/wire/wire.go` — 同步 provider 声明(若 wire.go 维护)。

---

## Task 1 (A1): 共享 `provideDB` + ent client 改造 + wire_gen.go 手改

**Files:**
- Modify: `yucai/server/wire/providers.go`
- Modify: `yucai/server/wire/wire_gen.go`
- Test: `go build ./cmd/server` + `go test ./...`(零行为变化,现有测试全绿)

**Interfaces:**
- Produces: `provideDB(cfg *config.Config) (*sql.DB, error)`(单例);各 `provide*EntClient(cfg *config.Config, db *sql.DB)`(签名加 `db`)。

- [ ] **Step 1: 新增 `provideDB` provider**

在 `providers.go` `openEntDriver` 附近新增(保留 `openEntDriver` 暂不动,Task 1 末删):

```go
// provideDB 是全 server 共享的单例 *sql.DB —— 跨模块事务的前提(所有 ent client
// 必须连同一 db,BeginTx 得到的 *sql.Tx 才能注入任意模块 ent client)。
// 替代此前各 provide*EntClient 各自 sql.Open 的 9 个独立池。
func provideDB(cfg *config.Config) (*sql.DB, error) {
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}
	return db, nil
}
```

- [ ] **Step 2: 改 9 个 `provide*EntClient` 签名 + 共享 db**

每个 `provideXxxEntClient`(auth/account/transaction/budget/debt/goal/tag/template/holding)从:

```go
func provideXxxEntClient(cfg *config.Config) (*xxxent.Client, error) {
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := xxxent.NewClient(xxxent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil { ... }
	return client, nil
}
```

改为(接收共享 `db`,不再 `openEntDriver`):

```go
func provideXxxEntClient(cfg *config.Config, db *sql.DB) (*xxxent.Client, error) {
	drv := entsql.OpenDB(dialect.Postgres, db)
	client := xxxent.NewClient(xxxent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil { ... }
	return client, nil
}
```

9 个 provider 全部同模式改。注意 `entsql.OpenDB` 返回 `*entsql.Driver`,与原 `openEntDriver` 返回类型一致,`xxxent.Driver(drv)` 不变。

- [ ] **Step 3: `provideTransactionRepo` db 源切换**

`provideTransactionRepo(client *txnent.Client, db *sql.DB)` 保持签名,但 `db` 来源从 `provideTransactionDB` 改为 `provideDB`(wire 注入端改,见 Step 4)。`provideTransactionDB` 函数删除(或保留 unused 后 Task 1 末删)。`transaction_repo` 内部若有原生 SQL 用这个 `db`,保持不变(后续 Task 4 才让它 tx-aware)。

- [ ] **Step 4: 手改 `wire_gen.go`**

在 `func InitializeApp(cfg *config.Config) (*App, error)` 顶部(`accountClient, err := provideAccountEntClient(cfg)` 之前)插入:

```go
	db, err := provideDB(cfg)
	if err != nil {
		return nil, fmt.Errorf("provide db: %w", err)
	}
```

然后每个 `provideXxxEntClient(cfg)` 调用改为 `provideXxxEntClient(cfg, db)`(共 9 处:`provideAccountEntClient`/`provideTransactionEntClient`/`provideBudgetEntClient`/`provideDebtEntClient`/`provideGoalEntClient`/`provideTagEntClient`/`provideTemplateEntClient`/`provideHoldingEntClient`/`provideAuthEntClient`)。

`txnDB, err := provideTransactionDB(cfg)` 行删除;`provideTransactionRepo(txnClient, txnDB)` 改为 `provideTransactionRepo(txnClient, db)`。

- [ ] **Step 5: build 验证**

Run: `cd yucai/server && go build ./cmd/server`
Expected: 编译通过。若报 "db declared and not used" / "provideXxxEntClient expects 2 args" → 漏改某处,补。

- [ ] **Step 6: 全量测试(零行为变化)**

Run: `cd yucai/server && go test ./...`
Expected: 全绿(与 Task 1 前一致)。现有测试不涉及共享 db 行为,应全过。

- [ ] **Step 7: 删除 `openEntDriver` + `provideTransactionDB`(若已无引用)**

确认 grep 无引用后删 `openEntDriver` 和 `provideTransactionDB` 函数体。再 build + test。

- [ ] **Step 8: Commit**

```bash
git add yucai/server/wire/providers.go yucai/server/wire/wire_gen.go
git commit -m "refactor(tx): share single *sql.DB across all ent clients (D7 root)"
```

---

## Task 2 (A2): `sqltx` 包 + 单元测

**Files:**
- Create: `yucai/server/internal/sqltx/sqltx.go`
- Create: `yucai/server/internal/sqltx/sqltx_test.go`

**Interfaces:**
- Produces: `sqltx.WithTx(ctx, db, opts, fn) error`、`sqltx.DriverFrom(ctx) (dialect.Driver, bool)`。

- [ ] **Step 1: 写 `sqltx.go`**

```go
// Package sqltx 提供跨模块事务的基础设施:把 *sql.Tx 包装成跨包通用的
// entgo dialect.Driver,经 context 传播,使多个独立 ent codegen 包的写
// 加入同一事务。
//
// 设计参照 budget/ent/tx.go 的 codegen txDriver(单模块内 ent.Tx 的驱动
// 包装),提取为跨包公共版。dialect.Driver 是 entgo 公共接口,一个 txDriver
// 实例可喂给任意模块的 ent.Driver() option。
package sqltx

import (
	"context"
	"database/sql"
	"fmt"

	"entgo.io/ent/dialect"
)

type ctxKey struct{}

// WithTx 在 db 上开一个事务,包装成 dialect.Driver 注入 ctx,执行 fn:
//   - fn 返回 nil → Commit(Commit 失败返回其 error)。
//   - fn 返回非 nil err → Rollback(忽略 Rollback error,返回 fn 的 err)。
//   - fn panic → Rollback 后 re-panic。
//
// 加入已有 tx 语义(事务传播):若 ctx 已携带 tx driver(外层 WithTx 已开),
// 不开新事务,直接用外层 driver 跑 fn,commit/rollback 交由最外层。这让被复用
// 的 service 方法(如 transaction.SimpleExpense)既可独立 WithTx(D1 入口),
// 也可被外层 service(holding/debt/template)的 WithTx 包(D2/D3/D4)。
func WithTx(ctx context.Context, db *sql.DB, opts *sql.TxOptions, fn func(context.Context) error) error {
	if _, ok := DriverFrom(ctx); ok {
		// 已在事务内,直接跑 fn,不影响外层 tx。
		return fn(ctx)
	}
	tx, err := db.BeginTx(ctx, opts)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	drv := newDriver(tx)
	ctxT := context.WithValue(ctx, ctxKey{}, drv)
	defer func() {
		if p := recover(); p != nil {
			_ = tx.Rollback()
			panic(p)
		}
	}()
	if err := fn(ctxT); err != nil {
		_ = tx.Rollback()
		return err
	}
	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit tx: %w", err)
	}
	return nil
}

// DriverFrom 从 ctx 取出 tx driver(若有)。repo 的 clientFor helper 用它
// 判断当前是否在事务内并取得 tx-bound driver。
func DriverFrom(ctx context.Context) (dialect.Driver, bool) {
	drv, ok := ctx.Value(ctxKey{}).(dialect.Driver)
	return drv, ok
}
```

`txDriver`(同文件,小写未导出)实现 `dialect.Driver`:

```go
// driver 包装 *sql.Tx 实现 entgo dialect.Driver。Exec/Query 转发到 tx;
// Tx() 返回自身(nop,防嵌套 BeginTx);Close nop;Dialect 返回 postgres。
type driver struct {
	tx *sql.Tx
}

func newDriver(tx *sql.Tx) *driver { return &driver{tx: tx} }

func (d *driver) Exec(ctx context.Context, query string, args, v any) error {
	return d.tx.ExecContext(ctx, query, args, v)
}
func (d *driver) Query(ctx context.Context, query string, args, v any) error {
	return d.tx.QueryContext(ctx, query, args, v)
}
func (d *driver) Tx(context.Context) (dialect.Tx, error) {
	return nil, fmt.Errorf("sqltx: already in a transaction (nested BeginTx not allowed)")
}
func (d *driver) Close() error { return nil }
func (d *driver) Dialect() string { return "postgres" }
```

注意:`dialect.Tx` 接口要求 `Commit/Query/Exec` 方法。因 `driver.Tx()` 返回 error(永不成功),ent builder 不会拿到 dialect.Tx 去调它的方法,故无需让 `driver` 实现 `dialect.Tx`。若 codegen 路径要求 `dialect.Tx`,改 `Tx()` 返回一个 nopTx(struct{ Commit/Rollback/Exec/Query 都委托 driver.tx})。

- [ ] **Step 2: 写单元测 `sqltx_test.go`**

用 SQLite 内存 db(无需 Postgres),测 WithTx commit/rollback/panic + DriverFrom:

```go
package sqltx_test

import (
	"context"
	"errors"
	"testing"

	"github.com/yucai/server/internal/sqltx"
)

func TestWithTx_Commit(t *testing.T) {
	db := newMemDB(t) // helper: sql.Open("sqlite3", ":memory:") + create table
	called := false
	err := sqltx.WithTx(context.Background(), db, nil, func(ctx context.Context) error {
		called = true
		_, ok := sqltx.DriverFrom(ctx)
		if !ok { t.Fatal("DriverFrom should find tx driver inside fn") }
		_, err := db.ExecContext(ctx, "INSERT INTO t(v) VALUES(1)")
		return err
	})
	if err != nil || !called { t.Fatalf("err=%v called=%v", err, called) }
	// 验证 commit 落库
	var n int
	_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
	if n != 1 { t.Fatalf("expected 1 row, got %d", n) }
}

func TestWithTx_RollbackOnError(t *testing.T) {
	db := newMemDB(t)
	sentinel := errors.New("boom")
	err := sqltx.WithTx(context.Background(), db, nil, func(ctx context.Context) error {
		_, _ = db.ExecContext(ctx, "INSERT INTO t(v) VALUES(1)")
		return sentinel
	})
	if !errors.Is(err, sentinel) { t.Fatalf("want sentinel, got %v", err) }
	var n int
	_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
	if n != 0 { t.Fatalf("rollback should leave 0 rows, got %d", n) }
}

func TestWithTx_RollbackOnPanic(t *testing.T) {
	db := newMemDB(t)
	defer func() {
		if r := recover(); r == nil { t.Fatal("expected re-panic") }
		var n int
		_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
		if n != 0 { t.Fatalf("panic rollback should leave 0 rows, got %d", n) }
	}()
	_ = sqltx.WithTx(context.Background(), db, nil, func(ctx context.Context) error {
		_, _ = db.ExecContext(ctx, "INSERT INTO t(v) VALUES(1)")
		panic("kaboom")
	})
}

func TestWithTx_JoinExistingTx(t *testing.T) {
	db := newMemDB(t)
	// 外层 WithTx;内层 WithTx 应复用,不开新 tx(通过观察内层 fn 内 DriverFrom 命中外层 driver)。
	err := sqltx.WithTx(context.Background(), db, nil, func(ctx context.Context) error {
		outer, _ := sqltx.DriverFrom(ctx)
		return sqltx.WithTx(ctx, db, nil, func(ctx2 context.Context) error {
			inner, _ := sqltx.DriverFrom(ctx2)
			if inner != outer { t.Fatal("inner WithTx should reuse outer driver") }
			_, _ = db.ExecContext(ctx2, "INSERT INTO t(v) VALUES(1)")
			// 内层返 error 不应 rollback 外层(由外层决定)
			return nil
		})
	})
	if err != nil { t.Fatalf("unexpected: %v", err) }
	var n int
	_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
	if n != 1 { t.Fatalf("expected 1 row committed, got %d", n) }
}
```

`newMemDB(t)` helper:open sqlite memory,`CREATE TABLE t(v INTEGER)`,注册 t.Cleanup close。

- [ ] **Step 3: 跑测试**

Run: `cd yucai/server && go test ./internal/sqltx/... -count=1 -v`
Expected: 4 测全过。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/internal/sqltx/
git commit -m "feat(tx): add sqltx package — cross-module TxContext + dialect.Driver wrapper"
```

---

## Task 3 (A3): repo `clientFor` helper(定义未启用)+ tx 传播集成测

**Files:**
- Modify: 8 个 P0 链路 repo 文件(各加 `clientFor` helper 方法)
- Create: `yucai/server/internal/sqltx/integration_test.go`

**Interfaces:**
- Produces: 各 repo 的 `clientFor(ctx) *moduleEnt.Client` helper(未启用)。

- [ ] **Step 1: 给每个 P0 链路 repo 加 `clientFor` helper**

对以下 repo 各加一个 helper(返回类型不同,各写;模式完全一致):

| repo 文件 | 返回类型 |
|---|---|
| `transaction/adapter/driven/repository/transaction_repo.go` | `*txnent.Client` |
| `account/adapter/driven/repository/account_repo.go` | `*accountent.Client` |
| `holding/adapter/driven/repository/holding_repo.go`(holding+trade+lot 同包,共用) | `*holdingent.Client` |
| `debt/adapter/driven/repository/debt_repo.go` | `*debtent.Client` |
| `template/adapter/driven/repository/template_repo.go` | `*tmplent.Client` |

每个 repo 加(以 holding 为例,替换类型名):

```go
// clientFor 返回当前 ctx 适用的 ent client:ctx 携带 tx driver(sqltx.WithTx
// 注入)→ tx-bound client(写加入外层事务);否则默认 r.client(非事务路径,
// 向后兼容)。
func (r *HoldingRepository) clientFor(ctx context.Context) *holdingent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return holdingent.NewClient(holdingent.Driver(d))
	}
	return r.client
}
```

import 加 `"github.com/yucai/server/internal/sqltx"`。

**本步只定义 helper,不改任何写方法**(写方法仍用 `r.client`)。build + test 应全绿(无行为变化)。

- [ ] **Step 2: 写 tx 传播集成测 `integration_test.go`**

验证两个独立 ent 包的 client 在同一 sqltx tx 内写、中间失败全回滚。用项目已有的两个轻量 ent 包(如 tag + account)或 transaction + account,SQLite 内存 + 共享 db:

```go
package sqltx_test

import (
	"context"
	"testing"

"github.com/yucai/server/internal/sqltx"
// 两个模块的 ent + enttest
)

// 验证:两个独立 ent codegen 包的 client,在共享 *sql.DB + 一个 sqltx.WithTx 下,
// 一个写成功 + 另一个写失败 → 两者都回滚(tx 传播跨包生效)。
func TestCrossModuleTx_Rollback(t *testing.T) {
	db := newMemDB(t) // 共享 db
	// 用 enttest 为两模块各建 client 绑同一 db(模拟 Task 1 后的共享 db)
	clientA := openModuleA(t, db) // helper: enttest + shared db
	clientB := openModuleB(t, db)

	err := sqltx.WithTx(context.Background(), db, nil, func(ctx context.Context) error {
		// 模拟 clientFor:从 ctx 取 driver 构造 tx-bound client
		writeA(clientA, ctx)  // 模块 A 写
		return errors.New("simulate module B failure") // B 失败
	})
	if err == nil { t.Fatal("want error") }
	// A 的写应回滚:用默认 client(无 tx)查,应 0 行
	if countA(clientA) != 0 { t.Fatalf("module A write should rollback, got %d", countA(clientA)) }
}
```

(具体模块选取 + enttest setup 参照现有 repo test 的 SQLite 模式,如 `transaction_repo_test.go` 的 `setupCountingDB`。)

- [ ] **Step 3: 跑测试 + build**

Run: `cd yucai/server && go test ./internal/sqltx/... -count=1 && go build ./...`
Expected: 全绿。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/internal/ yucai/server/internal/sqltx/integration_test.go
git commit -m "feat(tx): add clientFor helper to P0 repos + cross-module tx propagation test"
```

---

## Task 4 (B1): D1 交易创建事务化

**Files:**
- Modify: `yucai/server/internal/transaction/adapter/driven/repository/transaction_repo.go`(写方法 `r.client → r.clientFor(ctx)`)
- Modify: `yucai/server/internal/account/adapter/driven/repository/account_repo.go`(Update/Save 写方法 `r.client → r.clientFor(ctx)`)
- Modify: `yucai/server/internal/transaction/application/service.go`(SimpleExpense/Income/Transfer + CreateTransaction 包 `sqltx.WithTx`,注入 `*sql.DB`)
- Modify: `yucai/server/wire/providers.go` + `wire_gen.go`(transaction service 注入 `*sql.DB`)
- Test: `transaction/application/service_test.go`(部分失败回滚)

**Interfaces:**
- Consumes: `sqltx.WithTx`、各 repo `clientFor`。
- Produces: transaction Service 持 `*sql.DB`,SimpleXxx/CreateTransaction 原子。

- [ ] **Step 1: 写失败测试 — 部分失败回滚**

在 `transaction/application/service_test.go` 加:用 SQLite enttest 造 transaction + account client(共享 db),插一个 account;调 SimpleExpense,但注入一个在 balance updater Update 时失败的 fake accountRepo(或 monkey-patch)→ 验证 transaction header + entries 未落库(回滚)。

```go
func TestCreateTransaction_RollbackOnBalanceFailure(t *testing.T) {
	// setup: shared db, transaction client + account client + 一个 asset account + 一个 expense account
	// 注入 failingAccountRepo: FindByID 正常,Update 返回 errFake
	// 调 svc.SimpleExpense(ctx, ...)
	// 验证: 返回 errFake;transaction 表 0 行(Save 已执行但回滚)
}
```

具体 setup 参照现有 `transaction_repo_test.go` 的 enttest 模式。

- [ ] **Step 2: 跑测试验证失败**

Run: `cd yucai/server && go test ./internal/transaction/application/ -run TestCreateTransaction_RollbackOnBalanceFailure -v`
Expected: FAIL(当前无 tx,balance 失败时 transaction header/entries 已落库 → 断言"0 行"失败)。

- [ ] **Step 3: 改 repo 写方法用 clientFor**

`transaction_repo.go`:所有写方法(header Create、entries Save、Delete 等)`r.client.X` → `r.clientFor(ctx).X`。grep `r.client\.` 在该文件,逐处改写方法(只读方法如 FindByID 可暂不改,但为一致建议全改——只读在事务内也用 tx client,读的是 tx 内状态)。

`account_repo.go`:`Update`/`Save`/`Create` 写方法 `r.client → r.clientFor(ctx)`。

- [ ] **Step 4: transaction Service 包 WithTx**

`transaction/application/service.go`:`Service` struct 加 `db *sql.DB` 字段。`SimpleExpense/Income/Transfer/CreateTransaction` 方法体包 `sqltx.WithTx`:

```go
func (s *Service) SimpleExpense(ctx context.Context, req SimpleExpenseRequest) (*TransactionDTO, error) {
	var dto *TransactionDTO
	err := sqltx.WithTx(ctx, s.db, nil, func(ctxT context.Context) error {
		d, e := s.simpleExpense(ctxT, req) // 原逻辑抽出,内部 repo 调用传 ctxT
		dto = d
		return e
	})
	return dto, err
}
```

把原方法体重命名为 `simpleExpense(ctx, req)`(unexported,接 tx-aware ctx),导出方法做 WithTx 包装。SimpleIncome/SimpleTransfer/CreateTransaction 同模式。

- [ ] **Step 5: wire 注入 db**

`provideTransactionService` 加 `db *sql.DB` 参数,`wire_gen.go` 调用处传 `db`(Task 1 的共享 db)。build 验证。

- [ ] **Step 6: 跑测试验证通过**

Run: `cd yucai/server && go test ./internal/transaction/... -count=1`
Expected: Step 1 的回滚测过 + 现有 transaction 测全绿。

- [ ] **Step 7: Commit**

```bash
git add yucai/server/internal/transaction/ yucai/server/wire/
git commit -m "feat(tx): transactional transaction creation (D1) — header+entries+balance atomic"
```

---

## Task 5 (B2): D2 holding 交易事务化

**Files:**
- Modify: `holding/adapter/driven/repository/`(holding_repo / trade_repo / lot_repo 写方法 `clientFor`)
- Modify: `holding/application/service.go`(BuyHolding/SellHolding 包 WithTx,注入 db)
- Modify: `holding/adapter/driving/grpc/holding_handler.go`(删 "trade not rolled back" 注释 + best-effort 吞错,改 service 层原子后 handler 不再补偿)
- Modify: wire(holding service 注入 db)
- Test: `holding/application/service_test.go`(trade fan-out 部分失败回滚)

**Interfaces:**
- Consumes: transaction SimpleExpense 等已加入外层 tx(Task 4 + WithTx 加入已有 tx 语义)。
- Produces: BuyHolding/SellHolding 原子(holding+trade+lot+现金 transaction)。

- [ ] **Step 1: 写失败测试 — holding buy 中途失败全回滚**

mock lotRepo.SaveAll 返回 errFake(在 holdingRepo.SaveOrUpdate + tradeRepo.Save 成功之后)→ 验证 holding/trade 都未落库(回滚)。Setup 参照 `holding/application` 现有测试。

- [ ] **Step 2: 跑测试验证失败**

Run: `cd yucai/server && go test ./internal/holding/application/ -run TestBuyHolding_Rollback -v`
Expected: FAIL(当前无 tx,lot 失败时 holding/trade 已落库)。

- [ ] **Step 3: holding/trade/lot repo 写方法 clientFor**

grep `r.client\.` 在三个 repo,写方法改 `r.clientFor(ctx)`(holding+trade+lot 同包共用一个 `clientFor`,或各自加)。

- [ ] **Step 4: BuyHolding/SellHolding 包 WithTx**

`Service` 加 `db *sql.DB`。BuyHolding 体重命名为 `buyHolding(ctx, req)`,导出方法包 WithTx:

```go
func (s *Service) BuyHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	var dto *HoldingTransactionDTO
	err := sqltx.WithTx(ctx, s.db, nil, func(ctxT context.Context) error {
		d, e := s.buyHolding(ctxT, req)
		dto = d
		return e
	})
	return dto, err
}
```

内部 `s.holdingRepo.SaveOrUpdate(ctxT, h)` / `s.tradeRepo.Save(ctxT, ...)` / `s.lotRepo.SaveAll(ctxT, ...)` 全传 ctxT。SellHolding 同。

**现金 transaction**(若 handler 层调 transaction.RecordTransaction/recorder):把现金记录从 handler 下沉到 BuyHolding service 内(经 recorder port 或 transaction service),在同 ctxT 调用——transaction.SimpleXxx 的 WithTx 会"加入已有 tx"。若当前现金写本就在 service 内(非 handler),确认它传 ctxT 即可。

- [ ] **Step 5: 删 handler best-effort 吞错**

`holding_handler.go`:删 "trade not rolled back" 注释 + 任何对 trade/holding 失败的 best-effort 补偿逻辑(service 已原子)。

- [ ] **Step 6: wire 注入 db + build**

`provideHoldingService` 加 `db *sql.DB`,`wire_gen.go` 传 `db`。

- [ ] **Step 7: 跑测试验证通过**

Run: `cd yucai/server && go test ./internal/holding/... -count=1`
Expected: 回滚测过 + 现有 holding 测全绿(注:holding 测试基线见 CLAUDE.md,e2e 套件在 Task 9)。

- [ ] **Step 8: Commit**

```bash
git commit -m "feat(tx): transactional holding trades (D2) — holding+trade+lot+cash atomic"
```

---

## Task 6 (B3): D3 debt 还款事务化

**Files:**
- Modify: `debt/adapter/driven/repository/debt_repo.go`(写方法 clientFor)
- Modify: `debt/application/service.go`(还款方法包 WithTx,注入 db)
- Modify: `debt/adapter/driving/grpc/debt_handler.go`(删 best-effort 吞错)
- Modify: wire(debt service 注入 db)
- Test: `debt/application/service_test.go`(还款 + 现金记录原子)

**Interfaces:** 同 D2 模式。debt 还款经 recorder port 调 transaction(加入外层 tx)。

- [ ] **Step 1: 写失败测试** — 还款时 transaction 记账失败(recorder 返回 errFake)→ 验证 debt schedule.Paid/principal 未落库(回滚,不再 best-effort 吞错)。

- [ ] **Step 2: 跑验证失败** — `go test ./internal/debt/application/ -run TestRepay_Rollback`(FAIL:当前吞错,debt 已更新)。

- [ ] **Step 3: debt_repo 写方法 clientFor** — grep `r.client\.` 写方法改。

- [ ] **Step 4: debt service 还款方法包 WithTx** — `Service` 加 `db`。还款方法体抽 `repay(ctx, ...)`,导出方法包 WithTx。内部 schedule.Paid/principal 写 + recorder.Record(ctxT, ...) 全传 ctxT(加入外层 tx)。**删 best-effort 吞错**(recorder 失败 → return err → WithTx rollback → debt 写回滚)。

- [ ] **Step 5: 删 handler 吞错 + wire 注入 db** — `debt_handler.go` 删补偿逻辑;`provideDebtService` 加 `db`,`wire_gen.go` 传 `db`。

- [ ] **Step 6: 跑测试通过** — `go test ./internal/debt/... -count=1`(回滚测过 + 现有全绿)。

- [ ] **Step 7: Commit** — `git commit -m "feat(tx): transactional debt repayment (D3) — schedule+principal+cash atomic"`

---

## Task 7 (B4): D4 template autoRecord 事务化

**Files:**
- Modify: `template/adapter/driven/repository/template_repo.go`(写方法 clientFor,含 NextDate 推进)
- Modify: `template/application/service.go`(autoRecord 包 WithTx,注入 db)
- Modify: wire(template service 注入 db)
- Test: `template/application/service_test.go`(记账 + NextDate 推进原子)

**Interfaces:** autoRecord 经 recorder 调 transaction(加入外层 tx);NextDate 推进(template_repo)同 tx。

- [ ] **Step 1: 写失败测试** — autoRecord 时 NextDate 推进失败(template_repo.AdvanceNextDate 返回 errFake,在 recorder.Record 成功后)→ 验证 transaction 未落库(回滚,不再重复记账)。

- [ ] **Step 2: 跑验证失败** — `go test ./internal/template/application/ -run TestAutoRecord_Rollback`(FAIL)。

- [ ] **Step 3: template_repo 写方法 clientFor** — 含 NextDate 推进方法。grep `r.client\.` 写方法改。

- [ ] **Step 4: autoRecord 包 WithTx** — `Service` 加 `db`。autoRecord 体重命名 `autoRecord(ctx, ...)`,导出方法包 WithTx。内部 recorder.Record(ctxT) + template_repo.AdvanceNextDate(ctxT) 全传 ctxT。

- [ ] **Step 5: wire 注入 db** — `provideTemplateService` 加 `db`,`wire_gen.go` 传 `db`。build。

- [ ] **Step 6: 跑测试通过** — `go test ./internal/template/... -count=1`。

- [ ] **Step 7: Commit** — `git commit -m "feat(tx): transactional template autoRecord (D4) — record+NextDate atomic"`

---

## Task 8 (C1): `template_record_log` 表 + autoRecord 幂等键

**Files:**
- Create: `yucai/server/internal/template/ent/schema/template_record_log.go`
- Create: `yucai/server/internal/template/adapter/driven/repository/template_record_log_repo.go`
- Modify: `template/application/service.go`(autoRecord 在 Task 7 的 WithTx 内先插 log,OnConflictDoNothing 判幂等)
- Modify: `template/domain/`(若加 port 接口)
- Modify: wire(注入 log repo)
- Test: `template/application/service_test.go`(重复 autoRecord 同 date → 无重复 transaction)

**Interfaces:**
- Produces: `TemplateRecordLogRepo.Upsert(ctx, log) (inserted bool, err)`(OnConflictDoNothing)。

- [ ] **Step 1: 写 schema `template_record_log.go`**

照 `transaction_template.go` 结构:

```go
package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

// TemplateRecordLog 记录 autoRecord 已为某 (template, date) 记过的账,
// 是 autoRecord 幂等键(防 scheduler 并发 + crash 重试导致的重复记账)。
type TemplateRecordLog struct {
	ent.Schema
}

func (TemplateRecordLog) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (TemplateRecordLog) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (TemplateRecordLog) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.UUID("template_id", uuid.UUID{}),
		field.Time("record_date"),
		field.UUID("transaction_id", uuid.UUID{}).Optional().Nillable(),
		field.Time("created_at").Default(time.Now).Immutable(),
	}
}

func (TemplateRecordLog) Edges() []ent.Edge { return nil }

func (TemplateRecordLog) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "template_id", "record_date").Unique(),
	}
}
```

- [ ] **Step 2: ent regen**

Run: `cd yucai/server && go generate ./internal/template/...`
Expected: 生成 `template/ent/template_record_log*.go`。diff 审查(确认 unique index 生效)。若 `go generate` 模板路径不同,参照现有模块的 generate 指令(CLAUDE.md ⑤)。

- [ ] **Step 3: 写 `TemplateRecordLogRepo`**

```go
// Upsert 插一行 log;OnConflictDoNothing —— 返回 inserted=true 表示首次,
// false 表示该 (template, record_date) 已记过(幂等命中,调用方应跳过记账)。
func (r *TemplateRecordLogRepo) Upsert(ctx context.Context, log *domain.TemplateRecordLog) (bool, error) {
	n, err := r.clientFor(ctx).TemplateRecordLog.Create().
		SetID(log.ID).SetTenantID(log.TenantID).SetTemplateID(log.TemplateID).
		SetRecordDate(log.RecordDate).
		OnConflictColumns(templaterl.TemplateID, templaterl.RecordDate).
		DoNothing().
		Save(ctx)
	if err != nil { return false, fmt.Errorf("upsert record log: %w", err) }
	return n > 0, nil
}
```

(列常量名按 regen 产物调整:`templaterl` 是 `template/ent/templaterecordlog` 包。`OnConflictColumns` + tenant 隐含在 unique index 三列——显式列出租户列或用 entsql index 注解,按 ent 版本 API 调整。)

- [ ] **Step 4: autoRecord 接入幂等(在 Task 7 的 WithTx fn 内,最前)**

autoRecord service 的 WithTx fn 内,recorder.Record 之前:

```go
inserted, err := s.logRepo.Upsert(ctxT, &domain.TemplateRecordLog{
	ID: uuid.New(), TenantID: tenantID, TemplateID: tpl.ID, RecordDate: tpl.NextDate,
})
if err != nil { return err }
if !inserted {
	// 已为该 (template, date) 记过 —— 幂等命中,跳过(空 tx 提交)。
	s.log.Info("autoRecord: already recorded, skip", "template_id", tpl.ID, "record_date", tpl.NextDate, "operation", "TemplateAutoRecord")
	return nil
}
txnID, err := s.recorder.Record(ctxT, tenantID, req)  // 加入本 tx
if err != nil { return err }
// 回填 transaction_id + 推进 NextDate(同 tx)
if err := s.logRepo.SetTransactionID(ctxT, logID, txnID); err != nil { return err }
if err := s.templateRepo.AdvanceNextDate(ctxT, tpl.ID); err != nil { return err }
return nil
```

- [ ] **Step 5: wire 注入 log repo** — `provideTemplateRecordLogRepo(client *tmplent.Client)` + 注入 template service;`wire_gen.go` 加调用。build。

- [ ] **Step 6: 写重复记账测试**

```go
func TestAutoRecord_Idempotent_OnSameDate(t *testing.T) {
	// setup template + 共享 db + scheduler 两次 tick 同 NextDate
	// 第一次 autoRecord → 记 1 笔 transaction + log + NextDate 推进
	// 第二次 autoRecord(模拟 crash 后 NextDate 未推进 或 并发)→ log Upsert 命中已存在 → 不记 transaction
	// 验证:transaction 表仅 1 行;log 表 1 行
}
```

- [ ] **Step 7: 跑测试**

Run: `cd yucai/server && go test ./internal/template/... -count=1`
Expected: 幂等测过 + Task 7 回滚测仍过 + 现有全绿。

- [ ] **Step 8: Commit**

```bash
git add yucai/server/internal/template/ yucai/server/wire/
git commit -m "feat(tx): template_record_log idempotency key for autoRecord (D4) — OnConflictDoNothing"
```

---

## Task 9 (e2e): Postgres 跨模块 tx 回滚 e2e

**Files:**
- Modify/Create: `yucai/server/tests/`(参照现有 grpcurl e2e,如 `holding_integration_test.go`)
- Requires: dev Postgres 容器(`yucai-pg`,见 memory `yucai-dev-env`)+ auth token

**Interfaces:** 验证真实 pg 下共享 db + 跨模块 tx 行为。

- [ ] **Step 1: 写 e2e — holding buy 跨模块回滚**

用 grpcurl(或现有 e2e harness)对 dev server:触发一个 BuyHolding,中途注入失败(如传无效 account_id 导致 transaction 记账失败)→ 验证 holding/trade/lot/account 余额**都未变化**(全回滚)。

参照 `tests/holding_integration_test.go` 现有 e2e 模式 + memory `holding-performance-e2e-suite` 的 harness struct。

- [ ] **Step 2: 跑 e2e**

Run: 启动 dev server(`DATABASE_URL=... JWT_SECRET=... ./bin/server.exe`,见 memory `yucai-dev-env`)+ `go test ./tests/ -run TestHoldingBuy_CrossModuleRollback -count=1`
Expected: 回滚生效,各表无残留。

- [ ] **Step 3: 验证共享 db 连接池无死锁/连接耗尽**

观察 server 日志,确认 e2e 期间无 `conn overflow` / deadlock。私域单机负载下 `MaxOpenConns(25)` 应充足。

- [ ] **Step 4: Commit**

```bash
git add yucai/server/tests/
git commit -m "test(tx): Postgres e2e — cross-module rollback on holding buy"
```

---

## Self-Review(plan 自审)

**1. Spec 覆盖**:
- 共享 *sql.DB(Task 1)✓、sqltx 包 + 加入已有 tx 语义(Task 2)✓、clientFor helper(Task 3)✓、D1(Task 4)✓、D2(Task 5)✓、D3(Task 6)✓、D4 事务化(Task 7)✓、autoRecord 幂等键(Task 8)✓、Postgres e2e(Task 9)✓。
- 错误处理(WithTx 语义)✓ Task 2;删 handler best-effort ✓ Task 5/6;mapError 不变 ✓(未改 handler 错误映射,只删补偿)。
- 非目标(D/outbox/04 D5)均不在 plan ✓。
- 缺口:无。

**2. 占位符扫描**:Task 4-7 的 "参照现有 enttest 模式" / "grep r.client 写方法改" 是精确改造指令(非 placeholder,机械重复 clientFor 模式),给了模式 + 定位。`OnConflictColumns` API 细节按 regen 产物调整(Task 8 Step 3 已注明)。

**3. 类型一致性**:`clientFor` 返回类型各模块对应(Task 3 表 + Task 4-7 引用一致);`WithTx(ctx, db, opts, fn)` 签名全 plan 一致;`Upsert(ctx, log) (bool, err)` Task 8 定义 + 使用一致;`simpleTransactionCreator` port(Task 4 SimpleXxx)与 recorder_adapter 现状一致。

---

## Execution Handoff

Plan complete,9 tasks(8 实现 + 1 e2e),每 task TDD + 独立 commit。两种执行方式(见下)。建议在 feature 分支或 worktree 执行(`superpowers:using-git-worktrees`)。
