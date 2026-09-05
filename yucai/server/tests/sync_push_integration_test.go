package tests

// F11 T2 — gRPC-level integration tests for sync/v1 PushChanges (spec FR-6).
//
// Everything below drives the REAL SyncHandler (adapter/driving/grpc) — never
// the application service directly — so the covered surface is the full
// production chain: proto DTO decode -> authenticated-tenant extraction from
// the context (the same WithTenantID/WithUserID values the auth middleware
// injects) -> transactional batch dispatch -> per-module entity writers ->
// module repos -> shared in-memory SQLite -> append-only sync_log.
//
// Payload bytes are hand-built to the REAL wire shape the client will send in
// T3: backup-envelope per-row JSON exactly as the Dart LocalSnapshotExporter
// produces it (PascalCase keys — the account domain struct has no json tags,
// so Go default field naming IS the contract; int enums — drift IntColumn on
// the client, int-typed domain enums on the server; RFC3339 "Z" timestamps;
// uuid strings; nested Entries arrays; null DeletedAt; NO TenantID key — the
// authenticated tenant always wins). This pins the server-side acceptance
// surface of the T3 client encoding contract.
//
// slog assertion note (per task brief): the service logs via the default
// slog handler straight to process stderr, which testing.T does not capture,
// so log-line assertions are deliberately omitted here; behavior is asserted
// through DB state and gRPC responses instead.

import (
	"context"
	"database/sql"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountent "github.com/yucai/server/internal/account/ent"
	accpred "github.com/yucai/server/internal/account/ent/account"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	syncpb "github.com/yucai/server/internal/proto/sync/v1"
	"github.com/yucai/server/internal/sync/adapter/driven/entitywriter"
	syncrepo "github.com/yucai/server/internal/sync/adapter/driven/repository"
	syncgrpc "github.com/yucai/server/internal/sync/adapter/driving/grpc"
	syncapp "github.com/yucai/server/internal/sync/application"
	syncdomain "github.com/yucai/server/internal/sync/domain"
	syncent "github.com/yucai/server/internal/sync/ent"
	"github.com/yucai/server/internal/sync/ent/synclog"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	tagent "github.com/yucai/server/internal/tag/ent"
	tagpred "github.com/yucai/server/internal/tag/ent/tag"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnent "github.com/yucai/server/internal/transaction/ent"
	txnentry "github.com/yucai/server/internal/transaction/ent/transactionentry"
)

// sqliteDialect is ent's SQLite dialect string; the service forwards it to
// sqltx so builders emit "?" placeholders (same contract as the T1 harness).
const syncITSqLiteDialect = "sqlite3"

// syncPushIT is the handler-level harness: one named in-memory SQLite DB
// pinned to a single pooled connection (the sqltx contract — the WithTx-bound
// driver and the bare pool must hit the same physical database), four ent
// schemas migrated (account, transaction, tag, sync), real repos, real
// per-module entity writers, the real transactional sync application service,
// and the real gRPC SyncHandler on top.
type syncPushIT struct {
	handler   *syncgrpc.SyncHandler
	accountCl *accountent.Client
	txnCl     *txnent.Client
	tagCl     *tagent.Client
	syncCl    *syncent.Client
}

func newSyncPushIT(t *testing.T) *syncPushIT {
	t.Helper()
	dbName := "sync_push_it_" + strings.ReplaceAll(t.Name(), "/", "_")
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

	// Real module repos + real entity writers (the exact object graph the wire
	// DI builds, minus the five modules this scenario does not push).
	writers := map[string]syncdomain.SyncEntityWriter{
		"account":     entitywriter.NewAccountWriter(accountrepo.NewAccountRepository(accountCl)),
		"transaction": entitywriter.NewTransactionWriter(txnrepo.NewTransactionRepository(txnCl, nil)),
		"tag":         entitywriter.NewTagWriter(tagrepo.NewTagRepository(tagCl)),
	}

	svc := syncapp.NewService(
		syncrepo.NewSyncLogRepository(syncCl),
		syncrepo.NewSyncDeviceRepository(syncCl),
		syncrepo.NewSyncConflictRepository(syncCl),
		syncapp.NewConflictResolver(),
		writers, db, syncITSqLiteDialect,
	)
	return &syncPushIT{
		handler:   syncgrpc.NewSyncHandler(svc),
		accountCl: accountCl,
		txnCl:     txnCl,
		tagCl:     tagCl,
		syncCl:    syncCl,
	}
}

// syncPushCtx builds the context the auth middleware produces in production
// (tenant + user injected from the parsed JWT); the handler reads the tenant
// from it on every RPC.
func syncPushCtx(ctx context.Context, tenantID uuid.UUID) context.Context {
	ctx = authgrpc.WithTenantID(ctx, tenantID)
	return authgrpc.WithUserID(ctx, uuid.New())
}

// --- real-wire payload builders (mirror of the Dart LocalSnapshotExporter
// per-row maps; see file comment) ---

// syncAccountRow builds one account row in the client backup-envelope shape.
// No "TenantID" key: the client never sends one, the authenticated tenant
// must win. "AccountType"/"Category"/"Ownership"/"Status" are INT enums
// (server domain enums are int-typed, drift stores IntColumn).
func syncAccountRow(id, name string, version int64) map[string]any {
	return map[string]any{
		"ID":                       id,
		"Name":                     name,
		"AccountType":              1, // asset
		"Category":                 1, // savings
		"CurrencyCode":             "CNY",
		"InitialBalanceCents":      0,
		"CurrentBalanceCents":      50000,
		"Ownership":                1, // personal
		"Icon":                     "wallet",
		"Color":                    "#102030",
		"ChartCode":                nil,
		"ParentID":                 nil,
		"IsSystem":                 false,
		"SortOrder":                0,
		"Institution":              "",
		"CreditLimitCents":         0,
		"CardNumberTail":           "",
		"Notes":                    "from client",
		"OpeningDate":              nil,
		"InterestRate":             nil,
		"CreditBillingDay":         nil,
		"CreditRepaymentDay":       nil,
		"CreditAnnualFeeCents":     nil,
		"InvestCostCents":          nil,
		"InvestMarketValueCents":   nil,
		"InvestReturnYtd":          nil,
		"FixedPrincipalCents":      nil,
		"FixedStartDate":           nil,
		"FixedMaturityDate":        nil,
		"FixedTermMonths":          nil,
		"GoldProductType":          "",
		"GoldQuantity":             nil,
		"GoldBuyPriceCents":        nil,
		"GoldCurrentPriceCents":    nil,
		"EstatePurchasePriceCents": nil,
		"EstateCurrentValueCents":  nil,
		"EstatePurchaseDate":       nil,
		"EstateDepreciationRate":   nil,
		"LoanOriginalCents":        nil,
		"LoanRemainingCents":       nil,
		"LoanMonthlyCents":         nil,
		"LoanNextPaymentDate":      nil,
		"Status":                   1, // active
		"Version":                  version,
		"DeletedAt":                nil, // client deletes are hard (tombstones)
		"CreatedAt":                "2026-09-03T08:30:00.000Z",
		"UpdatedAt":                "2026-09-03T09:00:00.000Z",
	}
}

// syncTransactionRow builds one transaction row with two balanced entries
// nested, exactly as the client groups heads + entries for the envelope.
func syncTransactionRow(id, accountID, description string, version int64) map[string]any {
	return map[string]any{
		"ID":              id,
		"TransactionDate": "2026-09-03T00:00:00.000Z",
		"TransactionTime": "2026-09-03T10:15:00.000Z",
		"Description":     description,
		"Entries": []map[string]any{
			{
				"ID":                 uuid.New().String(),
				"TransactionID":      id,
				"AccountID":          accountID,
				"ChartOfAccountCode": "1001",
				"DebitCents":         500,
				"CreditCents":        0,
				"Note":               "",
			},
			{
				"ID":                 uuid.New().String(),
				"TransactionID":      id,
				"AccountID":          uuid.New().String(),
				"ChartOfAccountCode": "4101",
				"DebitCents":         0,
				"CreditCents":        500,
				"Note":               "",
			},
		},
		"Version":   version,
		"DeletedAt": nil,
		"CreatedAt": "2026-09-03T10:15:00.000Z",
		"UpdatedAt": "2026-09-03T10:15:00.000Z",
	}
}

// syncTagRow builds one tag row in the client envelope shape.
func syncTagRow(id, name string, version int64) map[string]any {
	return map[string]any{
		"ID":        id,
		"Name":      name,
		"Color":     "#112233",
		"Version":   version,
		"DeletedAt": nil,
		"CreatedAt": "2026-09-03T08:00:00.000Z",
		"UpdatedAt": "2026-09-03T08:00:00.000Z",
	}
}

func marshalSyncRow(t *testing.T, row map[string]any) []byte {
	t.Helper()
	b, err := json.Marshal(row)
	if err != nil {
		t.Fatalf("marshal payload row: %v", err)
	}
	return b
}

// syncChange builds one proto change. DeviceId carries the v1 fallback value
// (tenant string — RegisterDevice is ticket 16), mirroring what the T3
// GrpcOfflineSyncPort will fill.
func syncChange(tenantID uuid.UUID, entityType, entityID string, op syncpb.SyncOperation, payload []byte) *syncpb.SyncPayload {
	return &syncpb.SyncPayload{
		EntityType: entityType,
		EntityId:   entityID,
		Operation:  op,
		Payload:    payload,
		Version:    1,
		DeviceId:   tenantID.String(),
	}
}

// syncLogRows returns the tenant's sync_log rows ordered by version for
// contiguity/ordering assertions.
func (it *syncPushIT) syncLogRows(t *testing.T, ctx context.Context, tenantID uuid.UUID) []*syncent.SyncLog {
	t.Helper()
	rows, err := it.syncCl.SyncLog.Query().
		Where(synclog.TenantID(tenantID)).
		Order(syncent.Asc(synclog.FieldVersion)).
		All(ctx)
	if err != nil {
		t.Fatalf("query sync_log: %v", err)
	}
	return rows
}

// TestSyncPush_MixedBatch_PersistsThreeModulesAndContiguousLog: one
// PushChanges carrying account + transaction + tag (client order deliberately
// scrambled — tag first, transaction before its account) lands all three
// business tables, appends one sync_log entry per change with contiguous
// per-tenant versions 1..N in the canonical account-first upsert order, and
// reports synced_version = N with zero conflicts (v1 single-device, ticket 16).
func TestSyncPush_MixedBatch_PersistsThreeModulesAndContiguousLog(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	accID := uuid.New()
	txnID := uuid.New()
	tagID := uuid.New()

	resp, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		// Scrambled client order: tag, transaction, account.
		syncChange(tenantID, "tag", tagID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncTagRow(tagID.String(), "groceries", 1))),
		syncChange(tenantID, "transaction", txnID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncTransactionRow(txnID.String(), accID.String(), "salary", 1))),
		syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(accID.String(), "Cash", 1))),
	}})
	if err != nil {
		t.Fatalf("PushChanges: %v", err)
	}
	if resp.SyncedVersion != 3 {
		t.Fatalf("synced_version = %d, want 3 (one per change, starting from empty log)", resp.SyncedVersion)
	}
	if len(resp.Conflicts) != 0 {
		t.Fatalf("conflicts must stay empty in v1 (ticket 16), got %d", len(resp.Conflicts))
	}

	// All three business tables persisted.
	if n, err := it.accountCl.Account.Query().Where(accpred.TenantID(tenantID)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("account rows = %d err=%v, want 1", n, err)
	}
	if n, err := it.txnCl.Transaction.Query().Count(ctx); err != nil || n != 1 {
		t.Fatalf("transaction rows = %d err=%v, want 1", n, err)
	}
	if n, err := it.txnCl.TransactionEntry.Query().Where(txnentry.TransactionID(txnID)).Count(ctx); err != nil || n != 2 {
		t.Fatalf("entry rows = %d err=%v, want 2 (nested Entries array persisted)", n, err)
	}
	if n, err := it.tagCl.Tag.Query().Where(tagpred.TenantID(tenantID)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("tag rows = %d err=%v, want 1", n, err)
	}

	// sync_log: three contiguous versions in canonical upsert order
	// (account first so the transaction's account reference exists), with the
	// operation stored in its string form and the payload bytes carried over.
	rows := it.syncLogRows(t, ctx, tenantID)
	if len(rows) != 3 {
		t.Fatalf("sync_log rows = %d, want 3", len(rows))
	}
	want := []struct {
		entityType string
		version    int64
	}{
		{"account", 1},
		{"transaction", 2},
		{"tag", 3},
	}
	for i, w := range want {
		if rows[i].EntityType != w.entityType {
			t.Errorf("log[%d].entity_type = %q, want %q (canonical upsert order)", i, rows[i].EntityType, w.entityType)
		}
		if rows[i].Version != w.version {
			t.Errorf("log[%d].version = %d, want %d (contiguous)", i, rows[i].Version, w.version)
		}
		if rows[i].Operation != "create" {
			t.Errorf("log[%d].operation = %q, want string form %q", i, rows[i].Operation, "create")
		}
		if len(rows[i].Payload) == 0 {
			t.Errorf("log[%d].payload must carry the pushed JSON bytes", i)
		}
	}
}

// TestSyncPush_ClientEnvelopePayloadShape_Accepted: a payload built to the
// REAL client wire shape (PascalCase keys per the account domain struct's
// default Go JSON naming — it has no json tags; int enums; RFC3339 Z
// timestamps; null for unset pointers; no TenantID key; one unknown
// forward-compat field) is accepted end-to-end and decodes into the correct
// persisted column values. This is the server-side acceptance surface the T3
// GrpcOfflineSyncPort encodes against.
func TestSyncPush_ClientEnvelopePayloadShape_Accepted(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	accID := uuid.New()
	row := syncAccountRow(accID.String(), "Envelope Cash", 5)
	// Forward-compat tolerance: a newer client may send fields this server
	// does not know (json.Unmarshal must ignore them, not reject).
	row["FutureFieldNotOnThisServer"] = "ignored"

	if _, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, row)),
	}}); err != nil {
		t.Fatalf("PushChanges with client envelope payload: %v", err)
	}

	got, err := it.accountCl.Account.Query().Where(accpred.ID(accID)).Only(ctx)
	if err != nil {
		t.Fatalf("read back account row: %v", err)
	}
	// Int enum input lands in the string-typed ent enum columns correctly.
	if got.AccountType != accpred.AccountType("asset") {
		t.Errorf("account_type = %q, want %q (int 1 accepted, persisted as string enum)", got.AccountType, "asset")
	}
	if got.Category != accpred.Category("savings") {
		t.Errorf("category = %q, want %q", got.Category, "savings")
	}
	if got.Ownership != accpred.Ownership("personal") {
		t.Errorf("ownership = %q, want %q", got.Ownership, "personal")
	}
	if got.Status != accpred.Status("active") {
		t.Errorf("status = %q, want %q", got.Status, "active")
	}
	// Authenticated tenant wins (payload carries no TenantID at all).
	if got.TenantID != tenantID {
		t.Errorf("tenant_id = %s, want the authenticated tenant %s", got.TenantID, tenantID)
	}
	// RFC3339 timestamps decoded; client version trusted verbatim.
	wantCreated := time.Date(2026, 9, 3, 8, 30, 0, 0, time.UTC)
	if !got.CreatedAt.Equal(wantCreated) {
		t.Errorf("created_at = %v, want %v (RFC3339 Z decoded)", got.CreatedAt, wantCreated)
	}
	if got.Version != 5 {
		t.Errorf("version = %d, want 5 (client version trusted, no server bump)", got.Version)
	}
	if got.CurrentBalanceCents != 50000 {
		t.Errorf("current_balance_cents = %d, want 50000", got.CurrentBalanceCents)
	}
	if got.DeletedAt != nil {
		t.Errorf("deleted_at = %v, want nil (null DeletedAt accepted)", got.DeletedAt)
	}
}

// TestSyncPush_MidBatchInvalidPayload_FailsWholeBatchAtomically: one invalid
// payload (non-JSON bytes) mixed into an otherwise valid batch surfaces as a
// gRPC error from the handler and leaves NOTHING behind — no business rows,
// no sync_log entries (the whole batch shares one sqltx transaction).
func TestSyncPush_MidBatchInvalidPayload_FailsWholeBatchAtomically(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	goodID := uuid.New()
	badID := uuid.New()

	_, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		// Applied first inside the transaction — must be rolled back.
		syncChange(tenantID, "account", goodID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(goodID.String(), "Doomed", 1))),
		// Malformed payload bytes fail the id-probe unmarshal -> tx rollback.
		syncChange(tenantID, "account", badID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			[]byte("not-json{")),
	}})
	if err == nil {
		t.Fatal("PushChanges with a malformed payload must fail")
	}
	// The handler maps every service error to Internal (fail-closed, no
	// partial-state success shape exists).
	assertCode(t, err, codes.Internal)

	if n, err := it.accountCl.Account.Query().Where(accpred.TenantID(tenantID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("account rows after failed batch = %d err=%v, want 0 (full rollback)", n, err)
	}
	if rows := it.syncLogRows(t, ctx, tenantID); len(rows) != 0 {
		t.Fatalf("sync_log rows after failed batch = %d, want 0 (log joins the rollback)", len(rows))
	}
}

// TestSyncPush_TenantIsolation_ScopedWritesAndLogs: two tenants pushing the
// same-scenario batch each land only under their own tenant, get independent
// per-tenant log versioning (both start at 1), and cannot see or affect each
// other's rows. The cross-tenant probes pin the isolation boundary of the
// v1 single-device semantics:
//
//   - A cross-tenant tombstone DELETE is a tenant-scoped no-op: tenant B
//     deleting tenant A's entity id succeeds but removes nothing.
//   - A cross-tenant same-id UPSERT fails closed: entity ids are the physical
//     primary key (per-module ent schemas), so tenant B re-pushing tenant
//     A's id hits the PK constraint and the whole batch rolls back — no
//     hijack, no overwrite, no partial state. (Two tenants can therefore
//     never hold the SAME id value simultaneously; with client-generated
//     uuid v4 ids this collision is not a production scenario — noted in the
//     T2 report rather than "fixed", changing the PK is out of F11 scope.)
func TestSyncPush_TenantIsolation_ScopedWritesAndLogs(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	accA := uuid.New()
	accB := uuid.New()

	// Each tenant pushes the same-scenario batch (its own uuid, as real
	// clients do); both must succeed with the same starting synced_version.
	respA, err := it.handler.PushChanges(syncPushCtx(ctx, tenantA), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantA, "account", accA.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(accA.String(), "A cash", 1))),
	}})
	if err != nil {
		t.Fatalf("tenant A push: %v", err)
	}
	respB, err := it.handler.PushChanges(syncPushCtx(ctx, tenantB), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantB, "account", accB.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(accB.String(), "B cash", 1))),
	}})
	if err != nil {
		t.Fatalf("tenant B push: %v", err)
	}
	if respA.SyncedVersion != 1 || respB.SyncedVersion != 1 {
		t.Fatalf("per-tenant synced_version = (%d, %d), want (1, 1) — versioning is per tenant", respA.SyncedVersion, respB.SyncedVersion)
	}

	// Each tenant sees exactly its own row.
	if n, err := it.accountCl.Account.Query().Where(accpred.TenantID(tenantA)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("tenant A rows = %d err=%v, want 1", n, err)
	}
	if n, err := it.accountCl.Account.Query().Where(accpred.TenantID(tenantB)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("tenant B rows = %d err=%v, want 1", n, err)
	}
	if rows := it.syncLogRows(t, ctx, tenantA); len(rows) != 1 || rows[0].EntityType != "account" {
		t.Fatalf("tenant A log = %+v, want exactly 1 account entry", rows)
	}
	if rows := it.syncLogRows(t, ctx, tenantB); len(rows) != 1 || rows[0].EntityType != "account" {
		t.Fatalf("tenant B log = %+v, want exactly 1 account entry", rows)
	}

	// Cross-tenant tombstone: B deletes A's id — succeeds as a no-op.
	if _, err := it.handler.PushChanges(syncPushCtx(ctx, tenantB), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantB, "account", accA.String(), syncpb.SyncOperation_SYNC_OPERATION_DELETE, nil),
	}}); err != nil {
		t.Fatalf("cross-tenant tombstone must be a tenant-scoped no-op, got error: %v", err)
	}
	if n, err := it.accountCl.Account.Query().Where(accpred.ID(accA)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("tenant A's row must survive tenant B's tombstone, n=%d err=%v", n, err)
	}
	// B's log recorded its own tombstone (version 2), A's log is untouched.
	if rows := it.syncLogRows(t, ctx, tenantA); len(rows) != 1 {
		t.Fatalf("tenant A log must be untouched by B's tombstone, rows=%d", len(rows))
	}
	if rows := it.syncLogRows(t, ctx, tenantB); len(rows) != 2 || rows[1].Operation != "delete" {
		t.Fatalf("tenant B log after tombstone = %+v, want 2 rows with a trailing delete", rows)
	}

	// Cross-tenant same-id upsert: B pushes a change with A's entity id —
	// must fail closed (PK is the entity id) and roll B's whole batch back.
	hijackerID := uuid.New()
	_, err = it.handler.PushChanges(syncPushCtx(ctx, tenantB), &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantB, "account", hijackerID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(hijackerID.String(), "B extra", 1))),
		syncChange(tenantB, "account", accA.String(), syncpb.SyncOperation_SYNC_OPERATION_UPDATE,
			marshalSyncRow(t, syncAccountRow(accA.String(), "Hijacked", 9))),
	}})
	if err == nil {
		t.Fatal("cross-tenant same-id upsert must fail closed, got success")
	}
	// B's own valid change from the same batch must be rolled back too.
	if n, err := it.accountCl.Account.Query().Where(accpred.TenantID(tenantB)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("tenant B rows after failed hijack batch = %d err=%v, want 1 (batch rolled back)", n, err)
	}
	if rows := it.syncLogRows(t, ctx, tenantB); len(rows) != 2 {
		t.Fatalf("tenant B log after failed hijack batch = %d rows, want 2 (log rolled back)", len(rows))
	}
	// A's row content is untouched by the hijack attempt.
	got, err := it.accountCl.Account.Query().Where(accpred.ID(accA)).Only(ctx)
	if err != nil {
		t.Fatalf("read tenant A row: %v", err)
	}
	if got.Name != "A cash" || got.TenantID != tenantA {
		t.Fatalf("tenant A row must be untouched, got name=%q tenant=%s", got.Name, got.TenantID)
	}
}

// TestSyncPush_DeleteThenReUpsertSameID_Resurrects: the single-device
// resurrection semantics end-to-end through the handler — CREATE lands the
// row, a payload-less DELETE tombstone hard-deletes it, and a later re-push
// of the SAME id re-creates it with the client's truth. sync_log versions
// stay contiguous (1..3) and the tombstone entry records an empty payload.
func TestSyncPush_DeleteThenReUpsertSameID_Resurrects(t *testing.T) {
	it := newSyncPushIT(t)
	ctx := context.Background()
	tenantID := uuid.New()
	pushCtx := syncPushCtx(ctx, tenantID)

	accID := uuid.New()

	// 1) Create.
	resp, err := it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(accID.String(), "First life", 1))),
	}})
	if err != nil {
		t.Fatalf("create push: %v", err)
	}
	if resp.SyncedVersion != 1 {
		t.Fatalf("synced_version after create = %d, want 1", resp.SyncedVersion)
	}

	// 2) Delete (tombstone carries no payload bytes).
	resp, err = it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_DELETE, nil),
	}})
	if err != nil {
		t.Fatalf("delete push: %v", err)
	}
	if resp.SyncedVersion != 2 {
		t.Fatalf("synced_version after delete = %d, want 2", resp.SyncedVersion)
	}
	if n, err := it.accountCl.Account.Query().Where(accpred.ID(accID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("row must be hard-deleted by the tombstone, n=%d err=%v", n, err)
	}

	// 3) Re-upsert the same id (client still holds / re-created the entity).
	resp, err = it.handler.PushChanges(pushCtx, &syncpb.PushChangesRequest{Changes: []*syncpb.SyncPayload{
		syncChange(tenantID, "account", accID.String(), syncpb.SyncOperation_SYNC_OPERATION_CREATE,
			marshalSyncRow(t, syncAccountRow(accID.String(), "Second life", 2))),
	}})
	if err != nil {
		t.Fatalf("resurrection push: %v", err)
	}
	if resp.SyncedVersion != 3 {
		t.Fatalf("synced_version after resurrection = %d, want 3", resp.SyncedVersion)
	}
	got, err := it.accountCl.Account.Query().Where(accpred.ID(accID)).Only(ctx)
	if err != nil {
		t.Fatalf("row must exist again after re-upsert: %v", err)
	}
	if got.Name != "Second life" || got.Version != 2 || got.DeletedAt != nil {
		t.Fatalf("resurrected row = name %q v%d deletedAt=%v, want %q v2 nil", got.Name, got.Version, got.DeletedAt, "Second life")
	}

	// Log: versions 1..3 contiguous; the tombstone entry (v2) has the string
	// operation form and an empty (normalized, non-nil) payload.
	rows := it.syncLogRows(t, ctx, tenantID)
	if len(rows) != 3 {
		t.Fatalf("sync_log rows = %d, want 3", len(rows))
	}
	for i, want := range []int64{1, 2, 3} {
		if rows[i].Version != want {
			t.Errorf("log[%d].version = %d, want %d", i, rows[i].Version, want)
		}
	}
	if rows[1].Operation != "delete" {
		t.Errorf("tombstone log operation = %q, want %q", rows[1].Operation, "delete")
	}
	if len(rows[1].Payload) != 0 {
		t.Errorf("tombstone log payload = %d bytes, want 0", len(rows[1].Payload))
	}
	if rows[2].Operation != "create" || rows[2].EntityType != "account" {
		t.Errorf("resurrection log = %s/%s, want account/create", rows[2].EntityType, rows[2].Operation)
	}
}
