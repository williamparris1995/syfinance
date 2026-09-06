package application

// Tier-A tests for the transactional PushChanges batch (F11 T1, ADR-3/4):
// cross-module business-table persistence + append-only sync_log inside ONE
// sqltx.WithTx, dependents-first DELETE ordering, atomic rollback, and
// idempotent re-push. Everything runs against a single in-memory SQLite DB
// with all nine schemas migrated, wired through the REAL repos and REAL
// entity writers (the exact production object graph minus gRPC).

import (
	"context"
	"database/sql"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
	accpredicate "github.com/yucai/server/internal/account/ent/account"
	"github.com/yucai/server/internal/sync/adapter/driven/entitywriter"
	syncrepo "github.com/yucai/server/internal/sync/adapter/driven/repository"
	syncdomain "github.com/yucai/server/internal/sync/domain"
	syncent "github.com/yucai/server/internal/sync/ent"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	tagdomain "github.com/yucai/server/internal/tag/domain"
	tagent "github.com/yucai/server/internal/tag/ent"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txndomain "github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// sqliteDialect is ent's SQLite dialect string; the service forwards it to
// sqltx so builders emit "?" placeholders (same contract as backup).
const sqliteDialect = "sqlite3"

type pushHarness struct {
	svc          *Service
	logRepo      *syncrepo.SyncLogRepository
	deviceRepo   *syncrepo.SyncDeviceRepository
	conflictRepo *syncrepo.SyncConflictRepository
	resolver     *ConflictResolver
	writers      map[string]syncdomain.SyncEntityWriter
	db           *sql.DB
	accountCl    *accountent.Client
	txnCl        *txnent.Client
	tagCl        *tagent.Client
	syncCl       *syncent.Client
	tenantID     uuid.UUID
	deviceID     uuid.UUID // deliberately NEVER registered (fallback-deviceID path)
	accountWri   *entitywriter.AccountWriter
}

func newPushHarness(t *testing.T) *pushHarness {
	t.Helper()
	dbName := "sync_push_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory&_pragma=foreign_keys(1)")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	db.SetMaxOpenConns(1) // single conn owns the named in-memory DB (sqltx contract)
	t.Cleanup(func() { _ = db.Close() })

	drv := entsql.OpenDB(dialect.SQLite, db)
	ctx := context.Background()

	accountCl := accountent.NewClient(accountent.Driver(drv))
	txnCl := txnent.NewClient(txnent.Driver(drv))
	tagCl := tagent.NewClient(tagent.Driver(drv))
	syncCl := syncent.NewClient(syncent.Driver(drv))

	for _, c := range []struct {
		create func() error
		close  func() error
	}{
		{func() error { return accountCl.Schema.Create(ctx) }, func() error { return accountCl.Close() }},
		{func() error { return txnCl.Schema.Create(ctx) }, func() error { return txnCl.Close() }},
		{func() error { return tagCl.Schema.Create(ctx) }, func() error { return tagCl.Close() }},
		{func() error { return syncCl.Schema.Create(ctx) }, func() error { return syncCl.Close() }},
	} {
		if err := c.create(); err != nil {
			t.Fatalf("migrate schema: %v", err)
		}
		t.Cleanup(func() { _ = c.close() })
	}

	logRepo := syncrepo.NewSyncLogRepository(syncCl)
	deviceRepo := syncrepo.NewSyncDeviceRepository(syncCl)
	conflictRepo := syncrepo.NewSyncConflictRepository(syncCl)

	accountRepo := accountrepo.NewAccountRepository(accountCl)
	txnRepo := txnrepo.NewTransactionRepository(txnCl, nil)
	tagRepo := tagrepo.NewTagRepository(tagCl)

	writers := map[string]syncdomain.SyncEntityWriter{
		"account":     entitywriter.NewAccountWriter(accountRepo),
		"transaction": entitywriter.NewTransactionWriter(txnRepo),
		"tag":         entitywriter.NewTagWriter(tagRepo),
	}

	svc := NewService(logRepo, deviceRepo, conflictRepo, NewConflictResolver(), writers, db, sqliteDialect)
	return &pushHarness{
		svc: svc, logRepo: logRepo, deviceRepo: deviceRepo,
		conflictRepo: conflictRepo, resolver: NewConflictResolver(),
		writers: writers, db: db,
		accountCl: accountCl, txnCl: txnCl, tagCl: tagCl, syncCl: syncCl,
		tenantID: uuid.New(), deviceID: uuid.New(),
		accountWri: entitywriter.NewAccountWriter(accountRepo),
	}
}

func mustMarshal(t *testing.T, v any) []byte {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	return b
}

func accountPayload(t *testing.T, tenantID uuid.UUID, name string, version int64) []byte {
	now := time.Now()
	return mustMarshal(t, accountdomain.Account{
		ID: uuid.New(), TenantID: tenantID, Name: name,
		AccountType: accountdomain.AccountTypeAsset, Category: accountdomain.AccountCategorySavings,
		CurrencyCode: "CNY", Ownership: accountdomain.OwnershipPersonal,
		Status: accountdomain.AccountStatusActive, Version: version, CreatedAt: now, UpdatedAt: now,
	})
}

func transactionPayload(t *testing.T, tenantID, accountID uuid.UUID, description string, version int64) []byte {
	now := time.Now()
	txnID := uuid.New()
	return mustMarshal(t, txndomain.Transaction{
		ID: txnID, TenantID: tenantID, TransactionDate: now, Description: description,
		Entries: []txndomain.TransactionEntry{
			{ID: uuid.New(), TransactionID: txnID, AccountID: accountID, DebitCents: 100},
			{ID: uuid.New(), TransactionID: txnID, AccountID: uuid.New(), CreditCents: 100},
		},
		Version: version, CreatedAt: now, UpdatedAt: now,
	})
}

func tagPayload(t *testing.T, tenantID uuid.UUID, name string, version int64) []byte {
	now := time.Now()
	return mustMarshal(t, tagdomain.Tag{
		ID: uuid.New(), TenantID: tenantID, Name: name, Color: "#000000",
		Version: version, CreatedAt: now, UpdatedAt: now,
	})
}

// TestPushChanges_MixedBatch_PersistsAndAppendsVersionedLog (FR-1): a
// cross-module batch persists the business rows and appends one sync_log entry
// per change with versions LatestVersion+1..N. Upserts are applied in import
// dependency order (account first) regardless of client batch order, so a
// transaction pushed BEFORE its account still lands. The push succeeds with an
// unregistered device (fallback deviceID=tenantID path — RegisterDevice is
// ticket 16) and conflicts stay empty (ticket 16).
func TestPushChanges_MixedBatch_PersistsAndAppendsVersionedLog(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	accountJSON := accountPayload(t, h.tenantID, "Cash", 1)
	var acc accountdomain.Account
	if err := json.Unmarshal(accountJSON, &acc); err != nil {
		t.Fatalf("decode account payload: %v", err)
	}
	txnJSON := transactionPayload(t, h.tenantID, acc.ID, "salary", 1)
	var txn txndomain.Transaction
	if err := json.Unmarshal(txnJSON, &txn); err != nil {
		t.Fatalf("decode txn payload: %v", err)
	}
	tagJSON := tagPayload(t, h.tenantID, "groceries", 1)
	var tg tagdomain.Tag
	if err := json.Unmarshal(tagJSON, &tg); err != nil {
		t.Fatalf("decode tag payload: %v", err)
	}

	// Client order deliberately puts the transaction BEFORE its account.
	v, conflicts, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{
		{EntityType: "transaction", EntityID: txn.ID, Operation: syncdomain.SyncOperationCreate, Payload: txnJSON, Version: 1, DeviceID: h.deviceID},
		{EntityType: "account", EntityID: acc.ID, Operation: syncdomain.SyncOperationCreate, Payload: accountJSON, Version: 1, DeviceID: h.deviceID},
		{EntityType: "tag", EntityID: tg.ID, Operation: syncdomain.SyncOperationCreate, Payload: tagJSON, Version: 1, DeviceID: h.deviceID},
	})
	if err != nil {
		t.Fatalf("PushChanges: %v", err)
	}
	if len(conflicts) != 0 {
		t.Fatalf("conflicts must stay empty in v1 (ticket 16), got %d", len(conflicts))
	}
	if v != 3 {
		t.Fatalf("synced version = %d, want 3", v)
	}

	// Business tables persisted.
	if n, err := h.accountCl.Account.Query().Where(accpredicate.TenantID(h.tenantID)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("account rows = %d err=%v, want 1", n, err)
	}
	if _, err := h.txnCl.Transaction.Get(ctx, txn.ID); err != nil {
		t.Fatalf("transaction row missing: %v", err)
	}
	if _, err := h.tagCl.Tag.Get(ctx, tg.ID); err != nil {
		t.Fatalf("tag row missing: %v", err)
	}

	// sync_log: 3 entries, versions 1..3, account-first upsert order.
	entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil, 500)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 3 {
		t.Fatalf("log entries = %d, want 3", len(entries))
	}
	wantOrder := []struct {
		entityType string
		version    int64
	}{
		{"account", 1},
		{"transaction", 2},
		{"tag", 3},
	}
	for i, w := range wantOrder {
		if entries[i].EntityType != w.entityType || entries[i].Version != w.version {
			t.Fatalf("log[%d] = (%s v%d), want (%s v%d)", i, entries[i].EntityType, entries[i].Version, w.entityType, w.version)
		}
	}
}

// TestPushChanges_MidBatchFailure_RollsBackWholeBatch (FR-1 atomicity): when
// change N fails (here: an entry violating the transaction_entries CHECK
// constraint), the first N-1 changes must NOT persist — neither in the
// business tables nor in sync_log.
func TestPushChanges_MidBatchFailure_RollsBackWholeBatch(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	accountJSON := accountPayload(t, h.tenantID, "Doomed", 1)
	var acc accountdomain.Account
	_ = json.Unmarshal(accountJSON, &acc)

	// Malformed transaction: entry with BOTH debit and credit set violates the
	// schema CHECK ((debit>0 AND credit=0) OR (credit>0 AND debit=0)).
	now := time.Now()
	badTxn := txndomain.Transaction{
		ID: uuid.New(), TenantID: h.tenantID, TransactionDate: now, Description: "bad",
		Entries: []txndomain.TransactionEntry{
			{ID: uuid.New(), TransactionID: uuid.New(), AccountID: uuid.New(), DebitCents: 100, CreditCents: 100},
		},
		Version: 1, CreatedAt: now, UpdatedAt: now,
	}

	_, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{
		{EntityType: "account", EntityID: acc.ID, Operation: syncdomain.SyncOperationCreate, Payload: accountJSON, Version: 1, DeviceID: h.deviceID},
		{EntityType: "transaction", EntityID: badTxn.ID, Operation: syncdomain.SyncOperationCreate, Payload: mustMarshal(t, badTxn), Version: 1, DeviceID: h.deviceID},
	})
	if err == nil {
		t.Fatal("PushChanges must fail when a change violates the schema")
	}

	// The account from change #1 must NOT have persisted (atomic rollback).
	if n, err := h.accountCl.Account.Query().Where(accpredicate.TenantID(h.tenantID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("account rows after rollback = %d err=%v, want 0", n, err)
	}
	// sync_log must be empty too.
	if entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil, 500); err != nil || len(entries) != 0 {
		t.Fatalf("log entries after rollback = %d err=%v, want 0", len(entries), err)
	}
}

// TestPushChanges_DeleteDependencyOrder (FR-2): a client batch listing
// "DELETE account" BEFORE "DELETE transaction" must still delete the
// transaction first — the server reorders DELETEs into the backup purge order
// (dependents first, account last). Pinned via the sync_log append order.
func TestPushChanges_DeleteDependencyOrder(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	// Seed: one account + one transaction referencing it (via writer upserts).
	accountJSON := accountPayload(t, h.tenantID, "Seeded", 1)
	var acc accountdomain.Account
	_ = json.Unmarshal(accountJSON, &acc)
	txnJSON := transactionPayload(t, h.tenantID, acc.ID, "seed", 1)
	var txn txndomain.Transaction
	_ = json.Unmarshal(txnJSON, &txn)
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{
		{EntityType: "account", EntityID: acc.ID, Operation: syncdomain.SyncOperationCreate, Payload: accountJSON, Version: 1, DeviceID: h.deviceID},
		{EntityType: "transaction", EntityID: txn.ID, Operation: syncdomain.SyncOperationCreate, Payload: txnJSON, Version: 1, DeviceID: h.deviceID},
	}); err != nil {
		t.Fatalf("seed push: %v", err)
	}

	// Client order: account delete FIRST — server must reorder.
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{
		{EntityType: "account", EntityID: acc.ID, Operation: syncdomain.SyncOperationDelete, Payload: nil, Version: 1, DeviceID: h.deviceID},
		{EntityType: "transaction", EntityID: txn.ID, Operation: syncdomain.SyncOperationDelete, Payload: nil, Version: 1, DeviceID: h.deviceID},
	}); err != nil {
		t.Fatalf("delete push: %v", err)
	}

	// Both rows gone.
	if n, err := h.accountCl.Account.Query().Where(accpredicate.ID(acc.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("account must be gone, n=%d err=%v", n, err)
	}
	if n, err := h.txnCl.Transaction.Query().Count(ctx); err != nil || n != 0 {
		t.Fatalf("transaction must be gone, n=%d err=%v", n, err)
	}

	// Log order proves the reordering: the transaction delete was appended
	// BEFORE the account delete (versions 3 and 4 after the 2-seed push).
	entries, err := h.logRepo.FindSince(ctx, h.tenantID, 2, nil, 500)
	if err != nil {
		t.Fatalf("FindSince: %v", err)
	}
	if len(entries) != 2 {
		t.Fatalf("delete log entries = %d, want 2", len(entries))
	}
	if entries[0].EntityType != "transaction" || entries[0].Operation != syncdomain.SyncOperationDelete {
		t.Fatalf("log[0] = %s/%s, want transaction/delete", entries[0].EntityType, entries[0].Operation)
	}
	if entries[1].EntityType != "account" || entries[1].Operation != syncdomain.SyncOperationDelete {
		t.Fatalf("log[1] = %s/%s, want account/delete", entries[1].EntityType, entries[1].Operation)
	}
}

// TestPushChanges_IdempotentRepush (FR-3): re-pushing the same payload must
// not duplicate the business row (upsert keyed by entity id). The sync_log
// append on re-push is accepted by design: a single-device client only re-pushes
// when it never received the response, and business-side idempotency is what
// matters (comment contract in PushChanges).
func TestPushChanges_IdempotentRepush(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	payload := accountPayload(t, h.tenantID, "Once", 3)
	var acc accountdomain.Account
	_ = json.Unmarshal(payload, &acc)
	dto := SyncPayloadDTO{
		EntityType: "account", EntityID: acc.ID,
		Operation: syncdomain.SyncOperationCreate, Payload: payload,
		Version: 3, DeviceID: h.deviceID,
	}

	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{dto}); err != nil {
		t.Fatalf("first push: %v", err)
	}
	v2, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{dto})
	if err != nil {
		t.Fatalf("re-push: %v", err)
	}

	if n, err := h.accountCl.Account.Query().Where(accpredicate.TenantID(h.tenantID)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("business rows after re-push = %d err=%v, want 1 (upsert idempotent)", n, err)
	}
	if v2 != 2 {
		t.Fatalf("second push synced version = %d, want 2 (log appends new versions)", v2)
	}
}

// TestPushChanges_UnknownEntityType_FailsClosed: an entity_type with no
// registered writer fails the whole batch (forward-compat gate — the future
// holding_ledger extension will register its own writer).
func TestPushChanges_UnknownEntityType_FailsClosed(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	payload := accountPayload(t, h.tenantID, "X", 1)
	var acc accountdomain.Account
	_ = json.Unmarshal(payload, &acc)
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{
		{EntityType: "holding_ledger", EntityID: uuid.New(), Operation: syncdomain.SyncOperationCreate, Payload: []byte(`{}`), Version: 1, DeviceID: h.deviceID},
		{EntityType: "account", EntityID: acc.ID, Operation: syncdomain.SyncOperationCreate, Payload: payload, Version: 1, DeviceID: h.deviceID},
	}); err == nil {
		t.Fatal("unknown entity_type must fail the batch")
	}
	if n, err := h.accountCl.Account.Query().Where(accpredicate.TenantID(h.tenantID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("no rows may persist, n=%d err=%v", n, err)
	}
}

// TestPushChanges_PayloadIdMismatch_FailsClosed (review fix round 1, item 2):
// when a change's EntityID disagrees with the id inside its payload, the
// batch is rejected — otherwise the log would record one id while the writer
// persisted another (silent substitution).
func TestPushChanges_PayloadIdMismatch_FailsClosed(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	payload := accountPayload(t, h.tenantID, "Mismatched", 1)
	var acc accountdomain.Account
	_ = json.Unmarshal(payload, &acc)

	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{
		{EntityType: "account", EntityID: uuid.New(), Operation: syncdomain.SyncOperationCreate, Payload: payload, Version: 1, DeviceID: h.deviceID},
	}); err == nil {
		t.Fatal("EntityID/payload id mismatch must fail the batch")
	}

	if n, err := h.accountCl.Account.Query().Where(accpredicate.TenantID(h.tenantID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("no rows may persist on mismatch, n=%d err=%v", n, err)
	}
	if entries, err := h.logRepo.FindSince(ctx, h.tenantID, 0, nil, 500); err != nil || len(entries) != 0 {
		t.Fatalf("no log entries may persist on mismatch, got %d err=%v", len(entries), err)
	}
}

// TestPushChanges_TombstoneRepush_NoOp (review fix round 1, item 3): pushing
// the same DELETE twice must not error and must not resurrect anything — the
// second tombstone applies to zero rows (FR-3 idempotency on the delete side).
func TestPushChanges_TombstoneRepush_NoOp(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	payload := accountPayload(t, h.tenantID, "OnceDeleted", 1)
	var acc accountdomain.Account
	_ = json.Unmarshal(payload, &acc)
	create := SyncPayloadDTO{EntityType: "account", EntityID: acc.ID, Operation: syncdomain.SyncOperationCreate, Payload: payload, Version: 1, DeviceID: h.deviceID}
	del := SyncPayloadDTO{EntityType: "account", EntityID: acc.ID, Operation: syncdomain.SyncOperationDelete, Payload: nil, Version: 1, DeviceID: h.deviceID}

	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{create}); err != nil {
		t.Fatalf("seed push: %v", err)
	}
	if _, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{del}); err != nil {
		t.Fatalf("first delete: %v", err)
	}
	v3, _, err := h.svc.PushChanges(ctx, h.tenantID, h.deviceID, []SyncPayloadDTO{del})
	if err != nil {
		t.Fatalf("tombstone re-push must be a no-op, got error: %v", err)
	}

	if n, err := h.accountCl.Account.Query().Where(accpredicate.ID(acc.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("row must stay deleted after tombstone re-push, n=%d err=%v", n, err)
	}
	if v3 != 3 {
		t.Fatalf("third push synced version = %d, want 3 (log still appends)", v3)
	}
}

// TestSyncDeviceRepo_UpdateSyncVersion_TenantScoped (review fix round 1,
// item 1): the device-version bump is scoped by tenant+device — a device id
// from another tenant is never bumped (cross-tenant no-op). Also pins that a
// same-tenant bump still lands.
func TestSyncDeviceRepo_UpdateSyncVersion_TenantScoped(t *testing.T) {
	h := newPushHarness(t)
	ctx := context.Background()

	tenantA := uuid.New()
	tenantB := uuid.New()
	device, err := syncdomain.NewSyncDevice(tenantA, "phone-a")
	if err != nil {
		t.Fatalf("new device: %v", err)
	}
	if err := h.deviceRepo.Register(ctx, device); err != nil {
		t.Fatalf("register device: %v", err)
	}

	// Cross-tenant bump attempt: must be a silent no-op, not an error.
	if err := h.deviceRepo.UpdateSyncVersion(ctx, tenantB, device.ID, 42); err != nil {
		t.Fatalf("cross-tenant UpdateSyncVersion must not error: %v", err)
	}
	got, err := h.deviceRepo.FindByID(ctx, tenantA, device.ID)
	if err != nil {
		t.Fatalf("find device: %v", err)
	}
	if got.LastSyncVersion != 0 {
		t.Fatalf("cross-tenant bump must not stick, LastSyncVersion = %d, want 0", got.LastSyncVersion)
	}

	// Same-tenant bump still lands.
	if err := h.deviceRepo.UpdateSyncVersion(ctx, tenantA, device.ID, 7); err != nil {
		t.Fatalf("same-tenant UpdateSyncVersion: %v", err)
	}
	got, err = h.deviceRepo.FindByID(ctx, tenantA, device.ID)
	if err != nil {
		t.Fatalf("find device after bump: %v", err)
	}
	if got.LastSyncVersion != 7 {
		t.Fatalf("same-tenant bump must land, LastSyncVersion = %d, want 7", got.LastSyncVersion)
	}
}
