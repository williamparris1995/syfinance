package sqltx_test

import (
	"context"
	"database/sql"
	"errors"
	"strings"
	"testing"

	_ "modernc.org/sqlite"

	"github.com/yucai/server/internal/sqltx"
)

// testDialect is the ent dialect string for SQLite (== entgo.io/ent/dialect.SQLite).
// The sqltx driver forwards it to ent so mutation builders emit "?" placeholders
// instead of PostgreSQL's "$1".
const testDialect = "sqlite3"

// newMemDB opens a shared in-memory SQLite database with a single `t(v INTEGER)`
// table. The DSN "file:<name>?mode=memory" gives a named in-memory DB that is
// shared across all connections taken from the pool. We pin the pool to a
// single connection so every operation (whether routed through the tx driver
// or through the bare *sql.DB) hits the same physical database.
//
// NOTE: the in-tx assertions in these tests issue statements through the
// dialect.Driver returned by DriverFrom (the very mechanism this package
// provides); they never call db.ExecContext from inside the WithTx callback,
// which would try to grab a second pool conn and deadlock against the tx.
func newMemDB(t *testing.T) *sql.DB {
	t.Helper()
	dbName := "sqltx_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = db.Close() })
	if _, err := db.Exec("CREATE TABLE t(v INTEGER)"); err != nil {
		t.Fatalf("create table: %v", err)
	}
	return db
}

// execInTx runs an INSERT through the tx-bound driver in ctx. It exercises the
// sqltx driver's Exec path (entgo calling convention: args []any, v *sql.Result
// or nil) and routes the statement to the underlying *sql.Tx.
func execInTx(t *testing.T, ctx context.Context, query string) {
	t.Helper()
	drv, ok := sqltx.DriverFrom(ctx)
	if !ok {
		t.Fatal("DriverFrom should find tx driver inside fn")
	}
	if err := drv.Exec(ctx, query, []any{}, nil); err != nil {
		t.Fatalf("exec in tx: %v", err)
	}
}

func TestWithTx_Commit(t *testing.T) {
	db := newMemDB(t)
	called := false
	err := sqltx.WithTx(context.Background(), db, testDialect, nil, func(ctx context.Context) error {
		called = true
		if _, ok := sqltx.DriverFrom(ctx); !ok {
			t.Fatal("DriverFrom should find tx driver inside fn")
		}
		execInTx(t, ctx, "INSERT INTO t(v) VALUES(1)")
		return nil
	})
	if err != nil || !called {
		t.Fatalf("err=%v called=%v", err, called)
	}
	// Verify the row was committed (reads after tx end see committed state).
	var n int
	_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
	if n != 1 {
		t.Fatalf("expected 1 row committed, got %d", n)
	}
}

func TestWithTx_RollbackOnError(t *testing.T) {
	db := newMemDB(t)
	sentinel := errors.New("boom")
	err := sqltx.WithTx(context.Background(), db, testDialect, nil, func(ctx context.Context) error {
		execInTx(t, ctx, "INSERT INTO t(v) VALUES(1)")
		return sentinel
	})
	if !errors.Is(err, sentinel) {
		t.Fatalf("want sentinel, got %v", err)
	}
	var n int
	_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
	if n != 0 {
		t.Fatalf("rollback should leave 0 rows, got %d", n)
	}
}

func TestWithTx_RollbackOnPanic(t *testing.T) {
	db := newMemDB(t)
	defer func() {
		if r := recover(); r == nil {
			t.Fatal("expected re-panic")
		}
		var n int
		_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
		if n != 0 {
			t.Fatalf("panic rollback should leave 0 rows, got %d", n)
		}
	}()
	_ = sqltx.WithTx(context.Background(), db, testDialect, nil, func(ctx context.Context) error {
		execInTx(t, ctx, "INSERT INTO t(v) VALUES(1)")
		panic("kaboom")
	})
}

func TestWithTx_JoinExistingTx(t *testing.T) {
	db := newMemDB(t)
	// Outer WithTx; inner WithTx should reuse the outer driver rather than
	// open a new tx. Verified by:
	//   (a) the inner DriverFrom returns the SAME driver pointer as the outer,
	//   (b) a row inserted inside the inner fn is visible after the outer
	//       commits (proving the inner did not open and commit its own tx).
	err := sqltx.WithTx(context.Background(), db, testDialect, nil, func(ctx context.Context) error {
		outer, _ := sqltx.DriverFrom(ctx)
		return sqltx.WithTx(ctx, db, testDialect, nil, func(ctx context.Context) error {
			inner, _ := sqltx.DriverFrom(ctx)
			if inner != outer {
				t.Fatal("inner WithTx should reuse outer driver")
			}
			execInTx(t, ctx, "INSERT INTO t(v) VALUES(1)")
			return nil
		})
	})
	if err != nil {
		t.Fatalf("unexpected: %v", err)
	}
	var n int
	_ = db.QueryRow("SELECT COUNT(*) FROM t").Scan(&n)
	if n != 1 {
		t.Fatalf("expected 1 row committed, got %d", n)
	}
}
