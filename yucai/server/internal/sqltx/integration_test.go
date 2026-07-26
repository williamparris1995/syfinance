package sqltx_test

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/account/ent/account"
	"github.com/yucai/server/internal/sqltx"
	tagent "github.com/yucai/server/internal/tag/ent"
)

// integrationDialect is the ent dialect string for SQLite
// (== entgo.io/ent/dialect.SQLite). Forwarded to the sqltx driver so ent's
// mutation builders emit "?" placeholders instead of PostgreSQL's "$1".
const integrationDialect = "sqlite3"

// setupSharedDB opens ONE shared in-memory SQLite database, runs BOTH the
// account and tag ent auto-migrations against it, and returns the underlying
// *sql.DB plus an account client and a tag client. Both clients share the same
// physical *sql.DB (the production deployment pattern after Task 1): a single
// sqltx.WithTx can therefore wrap writes from both independent ent codegen
// packages into one atomic transaction.
//
// SetMaxOpenConns(1) is mandatory for shared in-memory SQLite — it pins the
// pool to a single physical connection so the *sql.Tx grabbed by WithTx and the
// subsequent read-through-default-client hit the same database. Without it the
// tx could hold one connection while a post-rollback read grabs another and
// observes stale (or, with a different DSN, empty) state.
func setupSharedDB(t *testing.T) (*sql.DB, *accountent.Client, *tagent.Client) {
	t.Helper()
	dbName := "sqltx_integration_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	// Enable FK enforcement at the driver level BEFORE auto-migration. modernc/sqlite
	// otherwise rejects FK creation in the migration with "missing _fk=1" (same
	// pattern as transaction_repo_test.go's setupTestDB).
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = db.Close() })

	drv := entsql.OpenDB(integrationDialect, db)

	accountClient := accountent.NewClient(accountent.Driver(drv))
	if err := accountClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	tagClient := tagent.NewClient(tagent.Driver(drv))
	if err := tagClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate tag schema: %v", err)
	}
	t.Cleanup(func() {
		_ = accountClient.Close()
		_ = tagClient.Close()
	})
	return db, accountClient, tagClient
}

// txBoundAccountClient replicates AccountRepository.clientFor: when ctx carries
// a sqltx tx driver, it returns a fresh account ent client bound to that driver
// so the caller's writes join the outer transaction; otherwise it returns the
// caller's default (non-tx) client. The repo helper itself is file-private, so
// the test reconstructs the identical 3-line decision to exercise the exact
// mechanism Tasks 4-7 will rely on.
func txBoundAccountClient(ctx context.Context, base *accountent.Client) *accountent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return accountent.NewClient(accountent.Driver(d))
	}
	return base
}

// txBoundTagClient does the same for the tag ent package.
func txBoundTagClient(ctx context.Context, base *tagent.Client) *tagent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return tagent.NewClient(tagent.Driver(d))
	}
	return base
}

// createAccountInTx inserts one account row through the given (tx- or
// non-tx-bound) account client. Uses the minimum required field set (id,
// tenant_id, name, account_type); all other account fields have ent defaults.
func createAccountInTx(ctx context.Context, c *accountent.Client, id, tenantID uuid.UUID, name string) error {
	return c.Account.Create().
		SetID(id).
		SetTenantID(tenantID).
		SetName(name).
		SetAccountType(account.AccountTypeAsset).
		Exec(ctx)
}

// createTagInTx inserts one tag row through the given (tx- or non-tx-bound)
// tag client. Uses the minimum required field set (id, tenant_id, name); all
// other tag fields have ent defaults.
func createTagInTx(ctx context.Context, c *tagent.Client, id, tenantID uuid.UUID, name string) error {
	return c.Tag.Create().
		SetID(id).
		SetTenantID(tenantID).
		SetName(name).
		Exec(ctx)
}

// TestCrossModuleTx_RollbackOnFailure is the core transactional-refactor
// guarantee: two INDEPENDENT ent codegen packages (account + tag), sharing one
// *sql.DB, write inside a single sqltx.WithTx. When the callback returns an
// error, BOTH packages' writes must roll back together — proving the tx driver
// propagates across ent package boundaries (the property that makes the planned
// D2/D3/D4 cross-module services in Tasks 4-7 atomic).
func TestCrossModuleTx_RollbackOnFailure(t *testing.T) {
	db, accountClient, tagClient := setupSharedDB(t)

	tenantID := uuid.New()
	accountID := uuid.New()
	tagID := uuid.New()

	boom := errors.New("simulate module B failure")
	err := sqltx.WithTx(context.Background(), db, integrationDialect, nil, func(ctx context.Context) error {
		// Module A (account) writes inside the tx via a tx-bound client.
		if err := createAccountInTx(ctx, txBoundAccountClient(ctx, accountClient), accountID, tenantID, "rollback-acct"); err != nil {
			return fmt.Errorf("create account: %w", err)
		}
		// Module B (tag) writes inside the SAME tx via its own tx-bound client.
		if err := createTagInTx(ctx, txBoundTagClient(ctx, tagClient), tagID, tenantID, "rollback-tag"); err != nil {
			return fmt.Errorf("create tag: %w", err)
		}
		// Both in-tx writes succeeded, but the callback signals failure — the
		// whole transaction must roll back.
		return boom
	})
	if !errors.Is(err, boom) {
		t.Fatalf("want boom error propagated, got %v", err)
	}

	// Outside the tx (now rolled back), the DEFAULT (non-tx) clients must see
	// zero rows from BOTH modules — proving the rollback crossed package bounds.
	accountCount, err := accountClient.Account.Query().Count(context.Background())
	if err != nil {
		t.Fatalf("count accounts: %v", err)
	}
	if accountCount != 0 {
		t.Fatalf("account write should have rolled back, got %d rows", accountCount)
	}
	tagCount, err := tagClient.Tag.Query().Count(context.Background())
	if err != nil {
		t.Fatalf("count tags: %v", err)
	}
	if tagCount != 0 {
		t.Fatalf("tag write should have rolled back, got %d rows", tagCount)
	}
}

// TestCrossModuleTx_CommitOnSuccess is the paired control for the rollback
// test: when the callback returns nil, both modules' writes commit and are
// visible to subsequent (non-tx) reads. This confirms the rollback test above
// is meaningful — it is the tx FAILURE (not some other mechanism) that reverts
// the writes. Without this control, a bug where WithTx always rolled back would
// pass the test above silently.
func TestCrossModuleTx_CommitOnSuccess(t *testing.T) {
	db, accountClient, tagClient := setupSharedDB(t)

	tenantID := uuid.New()
	accountID := uuid.New()
	tagID := uuid.New()

	err := sqltx.WithTx(context.Background(), db, integrationDialect, nil, func(ctx context.Context) error {
		if err := createAccountInTx(ctx, txBoundAccountClient(ctx, accountClient), accountID, tenantID, "commit-acct"); err != nil {
			return fmt.Errorf("create account: %w", err)
		}
		if err := createTagInTx(ctx, txBoundTagClient(ctx, tagClient), tagID, tenantID, "commit-tag"); err != nil {
			return fmt.Errorf("create tag: %w", err)
		}
		return nil
	})
	if err != nil {
		t.Fatalf("WithTx returned error: %v", err)
	}

	accountCount, err := accountClient.Account.Query().Count(context.Background())
	if err != nil {
		t.Fatalf("count accounts: %v", err)
	}
	if accountCount != 1 {
		t.Fatalf("account write should have committed, got %d rows", accountCount)
	}
	tagCount, err := tagClient.Tag.Query().Count(context.Background())
	if err != nil {
		t.Fatalf("count tags: %v", err)
	}
	if tagCount != 1 {
		t.Fatalf("tag write should have committed, got %d rows", tagCount)
	}
}

// TestClientFor_ReturnsDefaultOutsideTx validates the backward-compatibility
// branch of the clientFor pattern: outside any sqltx.WithTx, the helper returns
// the caller's default client, so writes go through as plain (auto-commit)
// statements. This is the contract that lets Tasks 4-7 swap r.client for
// r.clientFor(ctx) without changing behavior on the non-tx code paths.
func TestClientFor_ReturnsDefaultOutsideTx(t *testing.T) {
	_, accountClient, _ := setupSharedDB(t)

	// No WithTx in scope -> DriverFrom returns (nil, false) -> helper returns base.
	got := txBoundAccountClient(context.Background(), accountClient)
	if got != accountClient {
		t.Fatal("outside a tx, txBoundAccountClient should return the default client")
	}
}
