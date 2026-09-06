package repository

// Tier-A tests for the sync repo behaviors hardened in F16 T1:
//   - LatestVersion must swallow ONLY the ent NotFound case (empty log -> 0);
//     every other DB error propagates. The old implementation returned (0, nil)
//     for ANY query failure, so a real fault (conn drop, timeout) was
//     indistinguishable from an empty log and PushChanges would silently
//     re-allocate versions from 1 (spec FR-1 precondition fix).
//   - Register is idempotent per device id (F16 ADR-2): re-registering the
//     same id in the same tenant returns the existing row's state instead of
//     tripping the PK; a same-id row in another tenant fails closed.
//
// Single-connection named in-memory SQLite throughout (the sqltx contract this
// repo's clientFor relies on in production pushes).

import (
	"context"
	"database/sql"
	"strings"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	syncdomain "github.com/yucai/server/internal/sync/domain"
	syncent "github.com/yucai/server/internal/sync/ent"
)

func newRepoHarness(t *testing.T) (*SyncDeviceRepository, *SyncLogRepository, *sql.DB) {
	t.Helper()
	dbName := "sync_repo_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory&_pragma=foreign_keys(1)")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	db.SetMaxOpenConns(1) // single conn owns the named in-memory DB (sqltx contract)
	t.Cleanup(func() { _ = db.Close() })

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := syncent.NewClient(syncent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate sync schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	return NewSyncDeviceRepository(client), NewSyncLogRepository(client), db
}

func mustNewDevice(t *testing.T, tenantID uuid.UUID, name string) *syncdomain.SyncDevice {
	t.Helper()
	d, err := syncdomain.NewSyncDevice(tenantID, name)
	if err != nil {
		t.Fatalf("new device: %v", err)
	}
	return d
}

// TestLatestVersion_EmptyLog_ReturnsZero pins the tolerated case: a tenant
// with no sync_log rows yields version 0 (push batches then start at 1).
func TestLatestVersion_EmptyLog_ReturnsZero(t *testing.T) {
	_, logRepo, _ := newRepoHarness(t)
	v, err := logRepo.LatestVersion(context.Background(), uuid.New())
	if err != nil {
		t.Fatalf("LatestVersion on empty log must not error: %v", err)
	}
	if v != 0 {
		t.Fatalf("LatestVersion on empty log = %d, want 0", v)
	}
}

// TestLatestVersion_NonNotFoundError_Propagates (F16 FR-1 precondition): a
// query failure that is NOT "empty log" must surface as an error — never as a
// silent (0, nil) that would make PushChanges re-allocate versions from 1 and
// trip the (tenant_id, version) unique index (or worse, before the index
// existed, duplicate versions). Simulated by closing the underlying pool: the
// next query fails with a non-NotFound "database is closed" driver error.
func TestLatestVersion_NonNotFoundError_Propagates(t *testing.T) {
	_, logRepo, db := newRepoHarness(t)

	// Close the underlying pool the ent client wraps; the repo keeps its
	// (now-broken) client reference, exactly like a runtime conn-pool fault.
	if err := db.Close(); err != nil {
		t.Fatalf("close db: %v", err)
	}

	if _, err := logRepo.LatestVersion(context.Background(), uuid.New()); err == nil {
		t.Fatal("LatestVersion must propagate non-NotFound query errors, got nil")
	}
}

// TestRegister_IdempotentSameIDReturnsExisting (F16 ADR-2): registering a
// device whose id already exists in the SAME tenant is idempotent — the call
// succeeds and the passed device is refreshed from the stored row (keeping
// its current last_sync_version), never tripping the PK.
func TestRegister_IdempotentSameIDReturnsExisting(t *testing.T) {
	deviceRepo, _, _ := newRepoHarness(t)
	ctx := context.Background()
	tenant := uuid.New()

	first := mustNewDevice(t, tenant, "phone")
	if err := deviceRepo.Register(ctx, first); err != nil {
		t.Fatalf("first register: %v", err)
	}
	// The device syncs forward between the two registration attempts.
	if err := deviceRepo.UpdateSyncVersion(ctx, tenant, first.ID, 42); err != nil {
		t.Fatalf("bump device version: %v", err)
	}

	// Retried registration with the SAME id (fresh domain object, as a
	// caller-side retry would construct): must succeed and reflect the
	// EXISTING row, not reset it.
	retry := mustNewDevice(t, tenant, "phone-retry")
	retry.ID = first.ID
	if err := deviceRepo.Register(ctx, retry); err != nil {
		t.Fatalf("idempotent re-register must not error: %v", err)
	}
	if retry.ID != first.ID {
		t.Fatalf("re-registered id = %s, want existing %s", retry.ID, first.ID)
	}
	if retry.LastSyncVersion != 42 {
		t.Fatalf("re-registered LastSyncVersion = %d, want existing row's 42", retry.LastSyncVersion)
	}

	// Exactly one device row exists.
	d, err := deviceRepo.FindByID(ctx, tenant, first.ID)
	if err != nil {
		t.Fatalf("find device: %v", err)
	}
	if d.LastSyncVersion != 42 || d.DeviceName != "phone" {
		t.Fatalf("stored row must be untouched by idempotent re-register, got name=%q v=%d", d.DeviceName, d.LastSyncVersion)
	}
}

// TestRegister_SameIDOtherTenant_FailsClosed: a device id already owned by
// ANOTHER tenant must not be silently adopted — the cross-tenant register
// attempt errors (fail-closed; uuid v4 makes this a practical non-scenario,
// but the boundary stays closed).
func TestRegister_SameIDOtherTenant_FailsClosed(t *testing.T) {
	deviceRepo, _, _ := newRepoHarness(t)
	ctx := context.Background()

	owned := mustNewDevice(t, uuid.New(), "tenant-a-phone")
	if err := deviceRepo.Register(ctx, owned); err != nil {
		t.Fatalf("seed register: %v", err)
	}

	hijack := mustNewDevice(t, uuid.New(), "tenant-b-clone")
	hijack.ID = owned.ID
	if err := deviceRepo.Register(ctx, hijack); err == nil {
		t.Fatal("registering another tenant's device id must fail closed")
	}
}

// --- F16 T2 S3: FindSince ordered replay pagination (ADR-3) ---

// appendLogRow appends one sync_log row directly (repo-level seeding with
// EXPLICIT versions, so ordering tests are independent of the push path's
// sequential version assignment).
func appendLogRow(t *testing.T, logRepo *SyncLogRepository, ctx context.Context, tenantID uuid.UUID, entityType string, version int64) {
	t.Helper()
	entry := &syncdomain.SyncLogEntry{
		ID: uuid.New(), TenantID: tenantID,
		EntityType: entityType, EntityID: uuid.New(),
		Operation: syncdomain.SyncOperationCreate,
		Payload:   []byte(`{}`),
		Version:   version, DeviceID: uuid.New(),
		CreatedAt: time.Now(),
	}
	if err := logRepo.Append(ctx, entry); err != nil {
		t.Fatalf("append log row v%d: %v", version, err)
	}
}

// TestFindSince_OrdersByVersionAscending (ADR-3 ordering contract): rows
// appended with SHUFFLED version values must come back strictly ascending —
// the client replays the page in version order (upsert/delete idempotent
// application depends on it), so insertion order must never leak through.
func TestFindSince_OrdersByVersionAscending(t *testing.T) {
	_, logRepo, _ := newRepoHarness(t)
	ctx := context.Background()
	tenant := uuid.New()

	// Deliberately shuffled append order: v5, v1, v4, v2, v3.
	for _, v := range []int64{5, 1, 4, 2, 3} {
		appendLogRow(t, logRepo, ctx, tenant, "account", v)
	}

	entries, err := logRepo.FindSince(ctx, tenant, 0, nil, 100)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 5 {
		t.Fatalf("entries = %d, want 5", len(entries))
	}
	for i, want := range []int64{1, 2, 3, 4, 5} {
		if entries[i].Version != want {
			t.Fatalf("entries[%d].version = %d, want %d (ascending, not insertion order)", i, entries[i].Version, want)
		}
	}
}

// TestFindSince_FetchesLimitPlusOne (ADR-3 has_more mechanics): the repo fetches
// n+1 rows for a page of n so the caller can compute has_more from the extra
// row. Exactly n rows in range -> exactly n back; n+2 in range -> n+1 back.
func TestFindSince_FetchesLimitPlusOne(t *testing.T) {
	_, logRepo, _ := newRepoHarness(t)
	ctx := context.Background()
	tenant := uuid.New()

	for v := int64(1); v <= 4; v++ {
		appendLogRow(t, logRepo, ctx, tenant, "account", v)
	}

	// Exact fit: 4 rows in range, limit 4 -> 4 rows (no extra row available).
	entries, err := logRepo.FindSince(ctx, tenant, 0, nil, 4)
	if err != nil {
		t.Fatalf("FindSince exact fit: %v", err)
	}
	if len(entries) != 4 {
		t.Fatalf("exact-fit entries = %d, want 4", len(entries))
	}

	// Overflow: 4 rows in range, limit 2 -> 3 rows (2 + the has_more sentinel).
	entries, err = logRepo.FindSince(ctx, tenant, 0, nil, 2)
	if err != nil {
		t.Fatalf("FindSince overflow: %v", err)
	}
	if len(entries) != 3 {
		t.Fatalf("overflow entries = %d, want 3 (limit 2 + sentinel row)", len(entries))
	}

	// since_version still bounds the range BEFORE the limit applies.
	entries, err = logRepo.FindSince(ctx, tenant, 3, nil, 2)
	if err != nil {
		t.Fatalf("FindSince since=3: %v", err)
	}
	if len(entries) != 1 || entries[0].Version != 4 {
		t.Fatalf("since=3 entries = %+v, want only v4", entries)
	}
}

// TestFindSince_EntityTypeFilterWithPagination: the entity_types filter composes
// with ORDER + LIMIT — a page over a filtered stream still returns n+1 rows of
// ONLY the requested types, ascending.
func TestFindSince_EntityTypeFilterWithPagination(t *testing.T) {
	_, logRepo, _ := newRepoHarness(t)
	ctx := context.Background()
	tenant := uuid.New()

	// Interleaved types: account v1, tag v2, account v3, tag v4, account v5.
	for v := int64(1); v <= 5; v++ {
		et := "tag"
		if v%2 == 1 {
			et = "account"
		}
		appendLogRow(t, logRepo, ctx, tenant, et, v)
	}

	entries, err := logRepo.FindSince(ctx, tenant, 0, []string{"account"}, 2)
	if err != nil {
		t.Fatalf("FindSince filtered: %v", err)
	}
	if len(entries) != 3 { // 2-page + sentinel (accounts v1, v3, v5 exist)
		t.Fatalf("filtered entries = %d, want 3 (limit 2 + sentinel)", len(entries))
	}
	for i, want := range []int64{1, 3, 5} {
		if entries[i].Version != want || entries[i].EntityType != "account" {
			t.Fatalf("filtered entries[%d] = %s v%d, want account v%d", i, entries[i].EntityType, entries[i].Version, want)
		}
	}
}

// TestFindSince_EmptyLog_NoRows: an empty log (or a since_version past the
// frontier) yields zero rows, not an error — the client's steady-state poll.
func TestFindSince_EmptyLog_NoRows(t *testing.T) {
	_, logRepo, _ := newRepoHarness(t)
	ctx := context.Background()

	entries, err := logRepo.FindSince(ctx, uuid.New(), 0, nil, 500)
	if err != nil {
		t.Fatalf("FindSince empty log: %v", err)
	}
	if len(entries) != 0 {
		t.Fatalf("empty-log entries = %d, want 0", len(entries))
	}

	tenant := uuid.New()
	appendLogRow(t, logRepo, ctx, tenant, "account", 1)
	entries, err = logRepo.FindSince(ctx, tenant, 1, nil, 500)
	if err != nil {
		t.Fatalf("FindSince since=frontier: %v", err)
	}
	if len(entries) != 0 {
		t.Fatalf("since=frontier entries = %d, want 0", len(entries))
	}
}

// TestFindSince_TenantScoped: another tenant's rows never leak into a page.
func TestFindSince_TenantScoped(t *testing.T) {
	_, logRepo, _ := newRepoHarness(t)
	ctx := context.Background()
	tenantA, tenantB := uuid.New(), uuid.New()

	appendLogRow(t, logRepo, ctx, tenantA, "account", 1)
	appendLogRow(t, logRepo, ctx, tenantB, "account", 1)
	appendLogRow(t, logRepo, ctx, tenantB, "tag", 2)

	entries, err := logRepo.FindSince(ctx, tenantB, 0, nil, 500)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 2 {
		t.Fatalf("tenant B entries = %d, want 2 (tenant A's row excluded)", len(entries))
	}
}
