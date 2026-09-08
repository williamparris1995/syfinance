package tests

// F16 T1 S1 — Postgres-gated concurrency proof for the per-tenant version
// serialization (spec FR-1 / ADR-1): two goroutines pushing batches to the
// SAME tenant concurrently must end with a sync_log whose per-tenant versions
// are unique (COUNT(DISTINCT version) = COUNT(version), enforced by the
// (tenant_id, version) unique index) and contiguous (no gaps > 1).
//
// Why Postgres-only and gated: the SQLite harness pins the whole DB to ONE
// pooled connection (the sqltx contract), which serializes transactions at
// the connection level — the read-LatestVersion/append race this test targets
// cannot interleave there. Production runs PostgreSQL with a 25-connection
// pool, exactly what this harness mirrors. The test carries the verification
// burden the SQLite suites cannot: WITHOUT the fix (pre-F16: no unique index,
// no retry) both batches read the same base version and append overlapping
// version ranges — the COUNT(DISTINCT) assertion fails RED. With the fix, the
// loser's append trips the unique index, the whole batch transaction reopens
// with a fresh LatestVersion, and both land contiguously.
//
// Skipped unless YUCAI_PG_E2E_URL is set (same paradigm as
// holding_pg_rollback_integration_test.go, whose admin/sandbox helpers this
// file reuses). No PG environment -> t.Skip, never red.

import (
	"context"
	"database/sql"
	"fmt"
	"sync"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib" // register "pgx" database/sql driver for the e2e pool

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/sync/adapter/driven/entitywriter"
	syncrepo "github.com/yucai/server/internal/sync/adapter/driven/repository"
	syncapp "github.com/yucai/server/internal/sync/application"
	syncdomain "github.com/yucai/server/internal/sync/domain"
	syncent "github.com/yucai/server/internal/sync/ent"
)

// setupSyncConcurrencyDB creates the per-test Postgres sandbox (admin
// create/drop + fresh schema migration) and returns the shared pool with the
// account + sync ent clients over it — the production deployment shape
// (every module ent client wraps the same *sql.DB that sqltx.WithTx opens
// transactions on). Mirrors setupE2EDB from holding_pg_rollback_integration_
// test.go, trimmed to the two modules this suite pushes.
func setupSyncConcurrencyDB(t *testing.T) (*sql.DB, *accountent.Client, *syncent.Client) {
	t.Helper()
	base := pgE2EBaseURL(t)
	adminURL := adminURLFor(base)
	dbName := sandboxDBName(t)
	testURL := testURLFor(base, dbName)
	ctx := context.Background()

	adminDB, err := sql.Open("pgx", adminURL)
	if err != nil {
		t.Fatalf("open admin conn: %v", err)
	}
	if err := adminDB.PingContext(ctx); err != nil {
		_ = adminDB.Close()
		t.Fatalf("ping admin conn (is Postgres reachable at %s?): %v", base, err)
	}

	if _, err := adminDB.ExecContext(ctx, fmt.Sprintf(
		`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%s' AND pid<>pg_backend_pid()`,
		dbName,
	)); err != nil {
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

	// DROP runs LAST on cleanup (LIFO): clients and pools registered below
	// are closed by then.
	t.Cleanup(func() {
		dropDB, err := sql.Open("pgx", adminURL)
		if err != nil {
			t.Logf("cleanup: open admin to drop sandbox: %v", err)
			return
		}
		defer dropDB.Close()
		cctx := context.Background()
		if _, err := dropDB.ExecContext(cctx, fmt.Sprintf(
			`SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='%s' AND pid<>pg_backend_pid()`,
			dbName,
		)); err != nil {
			t.Logf("cleanup: terminate sandbox conns: %v", err)
		}
		if _, err := dropDB.ExecContext(cctx, fmt.Sprintf(`DROP DATABASE IF EXISTS %s`, dbName)); err != nil {
			t.Logf("cleanup: drop sandbox: %v", err)
		}
	})
	t.Cleanup(func() { _ = adminDB.Close() })

	db, err := sql.Open("pgx", testURL)
	if err != nil {
		_ = adminDB.Close()
		t.Fatalf("open sandbox pool: %v", err)
	}
	db.SetMaxOpenConns(25) // mirror wire.provideDB so the e2e exercises the real pool behavior
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(30 * time.Minute)
	if err := db.PingContext(ctx); err != nil {
		_ = db.Close()
		_ = adminDB.Close()
		t.Fatalf("ping sandbox pool: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	drv := entsql.OpenDB(dialect.Postgres, db)
	acctClient := accountent.NewClient(accountent.Driver(drv))
	syncClient := syncent.NewClient(syncent.Driver(drv))
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	if err := syncClient.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate sync schema (creates the (tenant_id, version) unique index): %v", err)
	}
	t.Cleanup(func() {
		_ = acctClient.Close()
		_ = syncClient.Close()
	})
	return db, acctClient, syncClient
}

// TestSyncPG_ConcurrentBatches_SerializedVersions is the headline FR-1
// invariant: two devices concurrently pushing batches of account changes to
// the same tenant both succeed, and the tenant's sync_log ends with every
// version UNIQUE and CONTIGUOUS 1..2N — no duplicate versions (the pre-fix
// race duplicated them) and no holes (a rolled-back attempt leaves no
// partial log entries behind).
//
// "Both succeed" is strict here rather than the looser "all-or-countable"
// reading: with the unique index + bounded reopen-retry (ADR-1), two
// concurrent single-tx batches cannot deadlock (the loser blocks once, at its
// first append, on the winner's index entry) and the retry budget (3) far
// exceeds the contention of two racers. If this ever fails with Aborted, the
// failures are countable and loud by construction — the assertions below
// then still prove no torn state survived.
func TestSyncPG_ConcurrentBatches_SerializedVersions(t *testing.T) {
	db, acctClient, syncClient := setupSyncConcurrencyDB(t)
	ctx := context.Background()
	tenantID := uuid.New()

	// Production-shaped object graph: real repos + account writer + the
	// transactional sync service over the shared PG pool.
	logRepo := syncrepo.NewSyncLogRepository(syncClient)
	deviceRepo := syncrepo.NewSyncDeviceRepository(syncClient)
	conflictRepo := syncrepo.NewSyncConflictRepository(syncClient)
	writers := map[string]syncdomain.SyncEntityWriter{
		"account": entitywriter.NewAccountWriter(accountrepo.NewAccountRepository(acctClient)),
	}
	svc := syncapp.NewService(logRepo, deviceRepo, conflictRepo, writers, db, pgE2EDialect)

	// Register both devices first (F16 ADR-2) so the version bumps land.
	phoneID := uuid.New()
	tabletID := uuid.New()
	for _, d := range []uuid.UUID{phoneID, tabletID} {
		if _, err := svc.RegisterDevice(ctx, tenantID, d, "pg-e2e"); err != nil {
			t.Fatalf("register device: %v", err)
		}
	}

	const batchN = 8
	const rounds = 6 // sustained concurrent load, not a single race shot (see comment at the barrier)
	buildBatch := func() []syncapp.SyncPayloadDTO {
		batch := make([]syncapp.SyncPayloadDTO, 0, batchN)
		for i := 0; i < batchN; i++ {
			row := syncAccountRow(uuid.New().String(), fmt.Sprintf("concurrent-%d", i), 1)
			batch = append(batch, syncapp.SyncPayloadDTO{
				EntityType: "account",
				EntityID:   uuid.MustParse(row["ID"].(string)),
				Operation:  syncdomain.SyncOperationCreate,
				Payload:    marshalSyncRow(t, row),
				Version:    1,
			})
		}
		return batch
	}

	// Each device pushes `rounds` sequential batches while the other does the
	// same — a channel barrier starts both loops together. Sustained rounds
	// (rather than one simultaneous batch pair) make the LatestVersion race
	// window reliably reachable: one shot often serializes whole-transaction-
	// before-the-other-reads, which would let the pre-fix bug pass undetected.
	start := make(chan struct{})
	errs := make([]error, 2)
	var wg sync.WaitGroup
	wg.Add(2)
	pusher := func(slot int, device uuid.UUID) {
		defer wg.Done()
		<-start
		for r := 0; r < rounds; r++ {
			if _, _, err := svc.PushChanges(ctx, tenantID, device, buildBatch()); err != nil {
				errs[slot] = fmt.Errorf("round %d: %w", r, err)
				return
			}
		}
	}
	go pusher(0, phoneID)
	go pusher(1, tabletID)
	close(start)
	wg.Wait()

	for i, err := range errs {
		if err != nil {
			t.Errorf("concurrent pusher %d failed: %v (with the unique index + bounded retry both racers must succeed)", i, err)
		}
	}

	// Headline invariant 1 — uniqueness: COUNT(DISTINCT version) == COUNT(*).
	// This is the assertion that was RED before the fix (both batches read
	// the same LatestVersion and appended overlapping ranges).
	var total, distinct int
	if err := db.QueryRowContext(ctx,
		`SELECT COUNT(*), COUNT(DISTINCT version) FROM sync_logs WHERE tenant_id = $1`,
		tenantID,
	).Scan(&total, &distinct); err != nil {
		t.Fatalf("count sync_log versions: %v", err)
	}
	if want := 2 * rounds * batchN; total != want {
		t.Errorf("sync_log rows = %d, want %d (every batch of both pushers fully appended)", total, want)
	}
	if distinct != total {
		t.Errorf("versions not serialized: COUNT(DISTINCT version)=%d != COUNT(*)=%d", distinct, total)
	}

	// Headline invariant 2 — contiguity: versions form 1..2*rounds*N with no
	// gap wider than 1. Best-effort relaxation note: the strict range assumes
	// no other writer touched the tenant (true in this sandbox), so the gap
	// check is asserted strictly here; in a shared-tenant production log,
	// gaps can legitimately appear between reads under heavier load —
	// uniqueness is the hard invariant, contiguity the happy-path one.
	var minV, maxV int
	if err := db.QueryRowContext(ctx,
		`SELECT MIN(version), MAX(version) FROM sync_logs WHERE tenant_id = $1`,
		tenantID,
	).Scan(&minV, &maxV); err != nil {
		t.Fatalf("min/max sync_log versions: %v", err)
	}
	if minV != 1 || maxV != 2*rounds*batchN {
		t.Errorf("version range = [%d, %d], want [1, %d] contiguous (no holes from rolled-back attempts)", minV, maxV, 2*rounds*batchN)
	}

	// Business rows: every pushed account landed exactly once.
	var accCount int
	if err := db.QueryRowContext(ctx,
		`SELECT COUNT(*) FROM accounts WHERE tenant_id = $1`, tenantID,
	).Scan(&accCount); err != nil {
		t.Fatalf("count accounts: %v", err)
	}
	if accCount != 2*rounds*batchN {
		t.Errorf("account rows = %d, want %d (replayed batches did not duplicate business state)", accCount, 2*rounds*batchN)
	}

	// Both registered device rows were bumped. A device's last_sync_version
	// records the synced version of ITS own last batch — NOT necessarily the
	// final frontier (the other pusher may have landed later batches after
	// it). Honest invariant: each device tracked at least its own last batch
	// (>= batchN) and never exceeded the frontier, and the LATER pusher sits
	// exactly at the frontier.
	frontier := int64(2 * rounds * batchN)
	var lastA, lastB int64
	for _, d := range []struct {
		id   string
		last *int64
	}{{phoneID.String(), &lastA}, {tabletID.String(), &lastB}} {
		if err := db.QueryRowContext(ctx,
			`SELECT last_sync_version FROM sync_devices WHERE tenant_id = $1 AND id = $2`,
			tenantID, d.id,
		).Scan(d.last); err != nil {
			t.Fatalf("read device last_sync_version: %v", err)
		}
	}
	for name, last := range map[string]int64{"phone": lastA, "tablet": lastB} {
		if last < batchN || last > frontier {
			t.Errorf("device %s last_sync_version = %d, want in [%d, %d]", name, last, batchN, frontier)
		}
	}
	if lastA != frontier && lastB != frontier {
		t.Errorf("neither device reached the frontier: phone=%d tablet=%d, want the later pusher at %d", lastA, lastB, frontier)
	}

	assertNoPoolOverflow(t, db)
}
