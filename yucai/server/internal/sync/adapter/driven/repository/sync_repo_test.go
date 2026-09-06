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
