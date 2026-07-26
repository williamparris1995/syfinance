// Package sqltx provides the cross-module transaction infrastructure: it wraps
// a *sql.Tx as an entgo dialect.Driver and propagates it through context so
// that writes from multiple independent ent codegen packages join the same DB
// transaction.
//
// The design mirrors the codegen txDriver in e.g. budget/ent/tx.go (an
// in-package wrapper around ent.Tx's driver), lifted to a cross-package common
// form. dialect.Driver is the public entgo interface, so one tx driver instance
// can be passed via ent.Driver() to any module's client.
package sqltx

import (
	"context"
	"database/sql"
	"fmt"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
)

type ctxKey struct{}

// WithTx opens a transaction on db, wraps it as a dialect.Driver, injects that
// driver into ctx, and runs fn with the augmented context:
//   - fn returns nil  -> Commit (a Commit failure is returned).
//   - fn returns err  -> Rollback (Rollback error is swallowed; fn's err is returned).
//   - fn panics       -> Rollback, then re-panic.
//
// dialect is the ent dialect string of db (entgo.io/ent/dialect.SQLite =
// "sqlite3", dialect.Postgres = "postgres", ...). It is forwarded to the wrapped
// driver's Dialect() so ent's query/mutation builders emit the correct SQL
// placeholder style ("?" for sqlite3, "$1" for postgres). A mismatch produces
// SQL like "INSERT ... VALUES($1)" against SQLite and fails at runtime.
//
// Join-existing-tx semantics (transaction propagation): if ctx already carries
// a tx driver (an outer WithTx already opened one), WithTx does NOT open a new
// transaction and instead runs fn against the outer driver. The outermost call
// owns commit/rollback. This lets a reused service method (e.g.
// transaction.SimpleExpense) be wrapped in its own WithTx when invoked directly
// (D1 entry) OR join an outer holding/debt/template service's WithTx (D2/D3/D4).
// The dialect argument is ignored on the join-existing-tx path (the outer
// driver already carries its dialect).
func WithTx(ctx context.Context, db *sql.DB, dialect string, opts *sql.TxOptions, fn func(context.Context) error) error {
	if _, ok := DriverFrom(ctx); ok {
		// Already inside a transaction; run fn against the outer driver. The
		// outermost caller owns commit/rollback.
		return fn(ctx)
	}
	tx, err := db.BeginTx(ctx, opts)
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	drv := newDriver(tx, dialect)
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

// DriverFrom extracts the tx driver from ctx, if any. A repo's clientFor helper
// uses it to detect whether the current call is inside a transaction and, when
// so, bind its ent client to the tx driver.
func DriverFrom(ctx context.Context) (dialect.Driver, bool) {
	drv, ok := ctx.Value(ctxKey{}).(dialect.Driver)
	return drv, ok
}

// driver wraps a *sql.Tx as an entgo dialect.Driver. The embedded entsql.Conn
// provides the entgo-correct Exec/Query bridge: ent builders pass args as []any
// and v as *dialect/sql.Rows (Query) or *sql.Result (Exec), and Conn dispatches
// to ExecContext/QueryContext on the underlying *sql.Tx. Tx() returns a nopTx
// (defending against nested BeginTx if a caller invokes client.Tx(ctx) on a
// tx-bound client — a pattern we never use in production but guard against
// here); Close is nop; Dialect reports the dialect string passed at construction
// (configurable so SQLite-backed integration tests get "?" placeholders while
// production PostgreSQL gets "$1").
type driver struct {
	entsql.Conn
	tx      *sql.Tx
	dialect string
}

func newDriver(tx *sql.Tx, dialect string) *driver {
	return &driver{Conn: entsql.Conn{ExecQuerier: tx}, tx: tx, dialect: dialect}
}

// Compile-time interface guards. Guards against silent interface drift on
// future entgo upgrades (the package would fail to compile rather than
// surface a runtime type assertion failure inside a builder).
var (
	_ dialect.Driver = (*driver)(nil)
	_ dialect.Tx     = nopTx{}
)

// Tx returns a nopTx instead of a real nested transaction. ent's query/mutation
// builders never call driver.Tx() — only client.Tx(ctx) (manual nesting) does.
// We return a nopTx (rather than an error) so any code path that does touch
// dialect.Tx still gets Exec/Query delegated to our underlying *sql.Tx, keeping
// every statement inside this transaction.
func (d *driver) Tx(context.Context) (dialect.Tx, error) {
	return nopTx{Conn: entsql.Conn{ExecQuerier: d.tx}, tx: d.tx}, nil
}

func (d *driver) Close() error    { return nil }
func (d *driver) Dialect() string { return d.dialect }

// nopTx implements dialect.Tx by delegating Exec/Query to the underlying *sql.Tx
// (via the embedded entsql.Conn) and treating Commit/Rollback as nop. The real
// commit/rollback is owned by WithTx at the outermost frame; nested callers must
// not finalize the tx.
type nopTx struct {
	entsql.Conn
	tx *sql.Tx
}

func (n nopTx) Commit() error   { return nil }
func (n nopTx) Rollback() error { return nil }
