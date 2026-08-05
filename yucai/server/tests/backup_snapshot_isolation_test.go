package tests

import (
	"context"
	"database/sql"
	"fmt"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"

	"github.com/yucai/server/internal/sqltx"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	tagedomain "github.com/yucai/server/internal/tag/domain"
	tagent "github.com/yucai/server/internal/tag/ent"
)

// This file is the Tier-B, real-PostgreSQL acceptance for D5 backup snapshot
// isolation (FR-1). Tier-A service-layer tests (backup/application) prove the
// Export loop runs inside one sqltx.WithTx; this test proves the OTHER half of
// "no torn backup": each module's FindAllForBackup must read INSIDE that shared
// REPEATABLE READ snapshot (via sqltx clientFor). A repo that reads on a fresh
// connection instead (r.client) lets a concurrent writer commit between module
// reads and tear the snapshot. The tearing originates at the repo seam, so that
// is where this acceptance lives.
//
// Skipped unless YUCAI_PG_E2E_URL is set, so it never blocks the pre-commit
// `go test ./...` gate when the container is down.

// setupTagSnapshotDB opens a fresh Postgres sandbox (reusing the
// YUCAI_PG_E2E_URL + swapDBPath/sandboxDBName helpers shared with the holding
// e2e) and migrates only the tag schema into it. Returns the shared pool + a
// tag ent client backed by it. The sandbox is dropped on cleanup.
func setupTagSnapshotDB(t *testing.T) (*sql.DB, *tagent.Client) {
	t.Helper()
	base := pgE2EBaseURL(t)
	adminURL := adminURLFor(base)
	dbName := sandboxDBName(t)
	testURL := testURLFor(base, dbName)
	ctx := context.Background()

	// Admin connection to the maintenance DB — used only for CREATE/DROP.
	adminDB, err := sql.Open("pgx", adminURL)
	if err != nil {
		t.Fatalf("open admin conn: %v", err)
	}
	if err := adminDB.PingContext(ctx); err != nil {
		_ = adminDB.Close()
		t.Fatalf("ping admin conn (is Postgres reachable at %s?): %v", base, err)
	}
	// Terminate any stale connection from an aborted prior run before DROP.
	if _, err := adminDB.ExecContext(ctx, fmt.Sprintf(
		`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%s' AND pid<>pg_backend_pid()`, dbName)); err != nil {
		_ = adminDB.Close()
		t.Fatalf("terminate stale sandbox conns: %v", err)
	}
	if _, err := adminDB.ExecContext(ctx, fmt.Sprintf(`DROP DATABASE IF EXISTS %s`, dbName)); err != nil {
		_ = adminDB.Close()
		t.Fatalf("drop stale sandbox: %v", err)
	}
	if _, err := adminDB.ExecContext(ctx, fmt.Sprintf(`CREATE DATABASE %s`, dbName)); err != nil {
		_ = adminDB.Close()
		t.Fatalf("create sandbox: %v", err)
	}

	// Register sandbox DROP FIRST so it runs LAST (LIFO), after the ent client
	// and the pool close — guaranteeing no idle connection holds the sandbox.
	t.Cleanup(func() {
		dropDB, err := sql.Open("pgx", adminURL)
		if err != nil {
			t.Logf("cleanup: open admin to drop sandbox: %v", err)
			return
		}
		defer dropDB.Close()
		cctx := context.Background()
		_, _ = dropDB.ExecContext(cctx, fmt.Sprintf(
			`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%s' AND pid<>pg_backend_pid()`, dbName))
		_, _ = dropDB.ExecContext(cctx, fmt.Sprintf(`DROP DATABASE IF EXISTS %s`, dbName))
	})

	db, err := sql.Open("pgx", testURL)
	if err != nil {
		_ = adminDB.Close()
		t.Fatalf("open sandbox pool: %v", err)
	}
	if err := adminDB.Close(); err != nil { // admin no longer needed
		t.Fatalf("close admin: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	drv := entsql.OpenDB(dialect.Postgres, db)
	client := tagent.NewClient(tagent.Driver(drv))
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate tag schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })
	return db, client
}

// TestTagRepo_FindAllForBackup_JoinsSnapshotTx (FR-1 / D5 / Tier B): drives the
// exact torn-backup scenario on real PostgreSQL. Inside one REPEATABLE READ +
// ReadOnly transaction it reads the tag repo, a second connection INSERTs and
// COMMITs a new tag, then it reads the tag repo again.
//
// RED before code-2: tag_repo.FindAllForBackup uses r.client → the second read
// opens a fresh connection and observes the committed post-write state (2 tags).
// GREEN after code-2: FindAllForBackup uses clientFor(ctx) → the second read
// joins the RR snapshot established before the write and observes S0 (1 tag).
//
// This stands in for FR-1's "no torn backup under concurrent write" at the repo
// seam where tearing originates; every backup exporter relies on the identical
// tx-joining contract validated here.
func TestTagRepo_FindAllForBackup_JoinsSnapshotTx(t *testing.T) {
	db, tagClient := setupTagSnapshotDB(t)
	ctx := context.Background()
	tenantID := uuid.New()
	tagRepo := tagrepo.NewTagRepository(tagClient)

	// seed inserts one tag for the tenant on a fresh (autocommit) connection.
	seed := func(name string) {
		t.Helper()
		if err := tagRepo.Save(ctx, &tagedomain.Tag{
			ID:        uuid.New(),
			TenantID:  tenantID,
			Name:      name,
			Color:     "#000000",
			Version:   1,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		}); err != nil {
			t.Fatalf("seed tag %q: %v", name, err)
		}
	}
	seed("T1") // S0: exactly one tag for this tenant

	firstReadDone := make(chan struct{})
	writerDone := make(chan struct{})
	var secondCount int

	// Writer (its own pooled connection): wait for the tx's first read, then
	// INSERT+COMMIT a second tag — moving live state to S1 (two tags).
	go func() {
		<-firstReadDone
		seed("T2")
		close(writerDone)
	}()

	txErr := sqltx.WithTx(ctx, db, pgE2EDialect, &sql.TxOptions{
		Isolation: sql.LevelRepeatableRead,
		ReadOnly:  true,
	}, func(ctxT context.Context) error {
		// First read. With code-2 it runs on the RR tx and establishes the S0
		// snapshot; without code-2 it runs on a fresh connection but still
		// predates the writer, so it observes S0 either way. Synchronization
		// point before the concurrent commit.
		if _, err := tagRepo.FindAllForBackup(ctxT, tenantID); err != nil {
			return fmt.Errorf("first backup read: %w", err)
		}
		close(firstReadDone)
		<-writerDone // writer has committed S1 (two tags) on another connection
		// Second read inside the SAME tx. tx-aware (clientFor) → S0 snapshot
		// (one tag); non-tx-aware (r.client) → fresh connection → S1 (two tags),
		// i.e. a torn read.
		second, err := tagRepo.FindAllForBackup(ctxT, tenantID)
		if err != nil {
			return fmt.Errorf("second backup read: %w", err)
		}
		secondCount = len(second)
		return nil
	})
	if txErr != nil {
		t.Fatalf("backup snapshot tx: %v", txErr)
	}

	if secondCount != 1 {
		t.Errorf("second FindAllForBackup saw %d tags, want 1 (the REPEATABLE READ snapshot S0); a tx-unaware repo tore the snapshot and read the post-commit S1 (2 tags)", secondCount)
	}
}
