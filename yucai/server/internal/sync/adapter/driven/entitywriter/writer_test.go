package entitywriter_test

// Tier-A tests for the sync entity writers (F11 T1, ADR-1). Each writer is
// exercised against its REAL module repo on a shared in-memory SQLite database
// (migrated per module schema) because the value under test is the ent-level
// upsert semantics (find by id+tenant -> full-field update / create, tx-aware
// via clientFor), which fakes cannot prove.

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

	accountdomain "github.com/yucai/server/internal/account/domain"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountent "github.com/yucai/server/internal/account/ent"
	accpredicate "github.com/yucai/server/internal/account/ent/account"
	budgetdomain "github.com/yucai/server/internal/budget/domain"
	budgetrepo "github.com/yucai/server/internal/budget/adapter/driven/repository"
	budgetent "github.com/yucai/server/internal/budget/ent"
	budgetpred "github.com/yucai/server/internal/budget/ent/budget"
	debtdomain "github.com/yucai/server/internal/debt/domain"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtent "github.com/yucai/server/internal/debt/ent"
	finpred "github.com/yucai/server/internal/debt/ent/debtdetails"
	goaldomain "github.com/yucai/server/internal/goal/domain"
	goalrepo "github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalent "github.com/yucai/server/internal/goal/ent"
	goalpred "github.com/yucai/server/internal/goal/ent/goal"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
	holdingrepo "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdingent "github.com/yucai/server/internal/holding/ent"
	holdpred "github.com/yucai/server/internal/holding/ent/holding"
	tagdomain "github.com/yucai/server/internal/tag/domain"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	tagent "github.com/yucai/server/internal/tag/ent"
	tagpred "github.com/yucai/server/internal/tag/ent/tag"
	templatedomain "github.com/yucai/server/internal/template/domain"
	templaterepo "github.com/yucai/server/internal/template/adapter/driven/repository"
	tmplent "github.com/yucai/server/internal/template/ent"
	tmplpred "github.com/yucai/server/internal/template/ent/transactiontemplate"
	txndomain "github.com/yucai/server/internal/transaction/domain"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnent "github.com/yucai/server/internal/transaction/ent"
	txnpred "github.com/yucai/server/internal/transaction/ent/transaction"
	"github.com/yucai/server/internal/sync/adapter/driven/entitywriter"
)

// openWriterDB opens a fresh named in-memory SQLite DB pinned to one pooled
// connection (the Tier-A sqltx contract: the WithTx-bound driver and the bare
// pool must hit the same physical database). The DSN pragma enables FK
// enforcement so in-module child-row ordering bugs surface as failures.
func openWriterDB(t *testing.T) *sql.DB {
	t.Helper()
	dbName := "sync_writer_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory&_pragma=foreign_keys(1)")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { _ = db.Close() })
	return db
}

// withUnknownField re-marshals a JSON payload with an extra unknown key
// appended, emulating a newer client sending a field this server does not know
// (forward-compat tolerance: json.Unmarshal must ignore it).
func withUnknownField(t *testing.T, payload []byte) []byte {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(payload, &m); err != nil {
		t.Fatalf("unmarshal payload for unknown-field injection: %v", err)
	}
	m["FutureFieldNotOnThisServer"] = "ignored"
	out, err := json.Marshal(m)
	if err != nil {
		t.Fatalf("re-marshal payload with unknown field: %v", err)
	}
	return out
}

func mustMarshal(t *testing.T, v any) []byte {
	t.Helper()
	b, err := json.Marshal(v)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	return b
}

// --- account (deep) ---

func newAccountFixture(tenantID uuid.UUID, name string, version int64) accountdomain.Account {
	now := time.Now()
	return accountdomain.Account{
		ID:                  uuid.New(),
		TenantID:            tenantID,
		Name:                name,
		AccountType:         accountdomain.AccountTypeAsset,
		Category:            accountdomain.AccountCategorySavings,
		CurrencyCode:        "CNY",
		CurrentBalanceCents: 12345,
		Ownership:           accountdomain.OwnershipPersonal,
		Status:              accountdomain.AccountStatusActive,
		Version:             version,
		CreatedAt:           now,
		UpdatedAt:           now,
	}
}

func TestAccountWriter_Upsert_CreateThenUpdate(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := accountent.NewClient(accountent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := accountrepo.NewAccountRepository(client)
	w := entitywriter.NewAccountWriter(repo)
	tenantID := uuid.New()

	// Create path: no row exists -> repo.Save with the client-supplied id.
	a := newAccountFixture(tenantID, "Cash", 1)
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, a)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	got, err := repo.FindByID(ctx, tenantID, a.ID)
	if err != nil {
		t.Fatalf("find after create: %v", err)
	}
	if got.Name != "Cash" || got.Version != 1 {
		t.Fatalf("created account = %+v", got)
	}

	// Update path: same id -> full-field update, client version trusted.
	a.Name = "Cash Renamed"
	a.CurrentBalanceCents = 999
	a.Version = 7 // client-side version, not server-incremented
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, a)); err != nil {
		t.Fatalf("upsert update: %v", err)
	}
	count, err := client.Account.Query().Where(accpredicate.TenantID(tenantID)).Count(ctx)
	if err != nil {
		t.Fatalf("count accounts: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected exactly 1 account row after re-upsert, got %d", count)
	}
	got, err = repo.FindByID(ctx, tenantID, a.ID)
	if err != nil {
		t.Fatalf("find after update: %v", err)
	}
	if got.Name != "Cash Renamed" || got.CurrentBalanceCents != 999 || got.Version != 7 {
		t.Fatalf("updated account = %+v", got)
	}
}

func TestAccountWriter_TenantInjectionOverridden(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := accountent.NewClient(accountent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := accountrepo.NewAccountRepository(client)
	w := entitywriter.NewAccountWriter(repo)
	authenticated := uuid.New()
	evil := uuid.New()

	// Payload claims another tenant; the authenticated tenant must win.
	a := newAccountFixture(evil, "Hijack", 1)
	if err := w.Upsert(ctx, authenticated, mustMarshal(t, a)); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if _, err := repo.FindByID(ctx, evil, a.ID); err == nil {
		t.Fatal("row must NOT be visible under the payload-forged tenant")
	}
	got, err := repo.FindByID(ctx, authenticated, a.ID)
	if err != nil {
		t.Fatalf("row must exist under the authenticated tenant: %v", err)
	}
	if got.TenantID != authenticated {
		t.Fatalf("tenant = %s, want %s", got.TenantID, authenticated)
	}

	// Delete is tenant-scoped too: another tenant cannot remove the row.
	if err := w.Delete(ctx, evil, a.ID.String()); err != nil {
		t.Fatalf("cross-tenant delete should be a no-op, got error: %v", err)
	}
	if n, err := client.Account.Query().Where(accpredicate.ID(a.ID)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("row must survive a cross-tenant delete (n=%d err=%v)", n, err)
	}
}

func TestAccountWriter_Upsert_UnknownFieldTolerated(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := accountent.NewClient(accountent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	w := entitywriter.NewAccountWriter(accountrepo.NewAccountRepository(client))
	tenantID := uuid.New()
	a := newAccountFixture(tenantID, "FutureProof", 1)
	if err := w.Upsert(ctx, tenantID, withUnknownField(t, mustMarshal(t, a))); err != nil {
		t.Fatalf("upsert with unknown field: %v", err)
	}
}

func TestAccountWriter_Delete_HardDeletesRow(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := accountent.NewClient(accountent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := accountrepo.NewAccountRepository(client)
	w := entitywriter.NewAccountWriter(repo)
	tenantID := uuid.New()
	a := newAccountFixture(tenantID, "Doomed", 1)
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, a)); err != nil {
		t.Fatalf("upsert: %v", err)
	}

	// DELETE on the sync path is a HARD delete (single-device semantics; the
	// server soft-delete column is a server-only concept, never used here).
	if err := w.Delete(ctx, tenantID, a.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.Account.Query().Where(accpredicate.ID(a.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("row must be physically gone, got n=%d err=%v (soft-delete would leave 1)", n, err)
	}
}

// --- transaction (deep) ---

func newTransactionFixture(tenantID, accountID uuid.UUID, description string, version int64) txndomain.Transaction {
	now := time.Now()
	txnID := uuid.New()
	return txndomain.Transaction{
		ID:              txnID,
		TenantID:        tenantID,
		TransactionDate: now.Truncate(24 * time.Hour),
		Description:     description,
		Entries: []txndomain.TransactionEntry{
			{ID: uuid.New(), TransactionID: txnID, AccountID: accountID, ChartOfAccountCode: "1001", DebitCents: 500, CreditCents: 0},
			{ID: uuid.New(), TransactionID: txnID, AccountID: uuid.New(), ChartOfAccountCode: "4101", DebitCents: 0, CreditCents: 500},
		},
		Version:   version,
		CreatedAt: now,
		UpdatedAt: now,
	}
}

func TestTransactionWriter_Upsert_CreateUpdateDelete(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := txnent.NewClient(txnent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate transaction schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := txnrepo.NewTransactionRepository(client, nil)
	w := entitywriter.NewTransactionWriter(repo)
	tenantID := uuid.New()
	accountID := uuid.New()

	// Create: header + nested entries.
	tx := newTransactionFixture(tenantID, accountID, "lunch", 1)
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, tx)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	got, err := repo.FindByID(ctx, tenantID, tx.ID)
	if err != nil {
		t.Fatalf("find after create: %v", err)
	}
	if len(got.Entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(got.Entries))
	}

	// Update: description changes AND the entry set is fully replaced.
	tx.Description = "lunch edited"
	tx.Entries = []txndomain.TransactionEntry{
		{ID: uuid.New(), TransactionID: tx.ID, AccountID: accountID, ChartOfAccountCode: "1001", DebitCents: 700, CreditCents: 0},
		{ID: uuid.New(), TransactionID: tx.ID, AccountID: uuid.New(), ChartOfAccountCode: "4101", DebitCents: 0, CreditCents: 700},
	}
	tx.Version = 4
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, tx)); err != nil {
		t.Fatalf("upsert update: %v", err)
	}
	got, err = repo.FindByID(ctx, tenantID, tx.ID)
	if err != nil {
		t.Fatalf("find after update: %v", err)
	}
	if got.Description != "lunch edited" || got.Version != 4 {
		t.Fatalf("updated txn = %+v", got)
	}
	if len(got.Entries) != 2 || got.Entries[0].DebitCents != 700 {
		t.Fatalf("entries not replaced: %+v", got.Entries)
	}

	// Delete: entries first, then the header (in-module FK ordering).
	if err := w.Delete(ctx, tenantID, tx.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.Transaction.Query().Where(txnpred.ID(tx.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("header must be gone, n=%d err=%v", n, err)
	}
	// All seeded entries belonged to tx, so the table must be empty.
	if n, err := client.TransactionEntry.Query().Count(ctx); err != nil || n != 0 {
		t.Fatalf("entries must be gone, n=%d err=%v", n, err)
	}
}

func TestTransactionWriter_TenantInjectionOverridden(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := txnent.NewClient(txnent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate transaction schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := txnrepo.NewTransactionRepository(client, nil)
	w := entitywriter.NewTransactionWriter(repo)
	authenticated := uuid.New()
	evil := uuid.New()

	tx := newTransactionFixture(evil, uuid.New(), "hijack", 1)
	if err := w.Upsert(ctx, authenticated, mustMarshal(t, tx)); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if _, err := repo.FindByID(ctx, authenticated, tx.ID); err != nil {
		t.Fatalf("row must exist under authenticated tenant: %v", err)
	}
	if n, err := client.Transaction.Query().Where(txnpred.TenantID(evil)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("no rows may land under the forged tenant, n=%d err=%v", n, err)
	}
}

// --- debt (deep) ---

func newDebtFixture(tenantID, accountID uuid.UUID, counterparty string, version int64) debtdomain.DebtDetails {
	now := time.Now()
	debtID := uuid.New()
	return debtdomain.DebtDetails{
		ID:                  debtID,
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        counterparty,
		InterestRate:        5.5,
		AmortizationMethod:  debtdomain.AmortizationEqualPrincipalInterest,
		StartDate:           now,
		DueDate:             now.AddDate(1, 0, 0),
		TotalPrincipalCents: 100000,
		DebtType:            debtdomain.BorrowedIn,
		Schedule: []debtdomain.PaymentScheduleEntry{
			{ID: uuid.New(), DebtID: debtID, PaymentDate: now.AddDate(0, 1, 0), PrincipalCents: 8000, InterestCents: 458, TotalCents: 8458},
			{ID: uuid.New(), DebtID: debtID, PaymentDate: now.AddDate(0, 2, 0), PrincipalCents: 8000, InterestCents: 425, TotalCents: 8425},
		},
		Version:   version,
		CreatedAt: now,
		UpdatedAt: now,
	}
}

func TestDebtWriter_Upsert_CreateUpdateDelete(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := debtent.NewClient(debtent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate debt schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := debtrepo.NewDebtRepository(client)
	w := entitywriter.NewDebtWriter(repo)
	tenantID := uuid.New()
	accountID := uuid.New()

	d := newDebtFixture(tenantID, accountID, "bank", 1)
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, d)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	got, err := repo.FindByID(ctx, tenantID, d.ID)
	if err != nil {
		t.Fatalf("find after create: %v", err)
	}
	if len(got.Schedule) != 2 {
		t.Fatalf("expected 2 schedule rows, got %d", len(got.Schedule))
	}

	// Update replaces the schedule and trusts the client version.
	d.Counterparty = "bank edited"
	d.Schedule = d.Schedule[:1]
	d.Version = 5
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, d)); err != nil {
		t.Fatalf("upsert update: %v", err)
	}
	got, err = repo.FindByID(ctx, tenantID, d.ID)
	if err != nil {
		t.Fatalf("find after update: %v", err)
	}
	if got.Counterparty != "bank edited" || got.Version != 5 || len(got.Schedule) != 1 {
		t.Fatalf("updated debt = %+v (schedule=%d)", got, len(got.Schedule))
	}

	// Delete cascades the payment schedule.
	if err := w.Delete(ctx, tenantID, d.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.DebtDetails.Query().Where(finpred.ID(d.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("debt row must be gone, n=%d err=%v", n, err)
	}
}

// --- holding (deep) ---

func TestHoldingWriter_Upsert_CreateUpdateDelete(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := holdingent.NewClient(holdingent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate holding schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := holdingrepo.NewHoldingRepository(client)
	w := entitywriter.NewHoldingWriter(repo)
	tenantID := uuid.New()
	accountID := uuid.New()
	securityID := uuid.New()
	now := time.Now()

	// The sync payload for entity_type=holding is ONE Holding position row
	// (per-row serialization, ADR-2) — not the backup envelope's two-array
	// shape. The trade ledger rides the future holding_ledger extension.
	h := holdingdomain.Holding{
		ID: uuid.New(), TenantID: tenantID, AccountID: accountID, SecurityID: securityID,
		Quantity: 100, AvgCostCents: 1250, Version: 1, CreatedAt: now, UpdatedAt: now,
	}
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, h)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	got, err := repo.FindByID(ctx, tenantID, h.ID)
	if err != nil {
		t.Fatalf("find after create: %v", err)
	}
	if got.Quantity != 100 || got.AvgCostCents != 1250 {
		t.Fatalf("created holding = %+v", got)
	}

	// Upsert keyed by entity id: same id -> position update (client truth).
	h.Quantity = 250
	h.AvgCostCents = 1100
	h.Version = 6
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, h)); err != nil {
		t.Fatalf("upsert update: %v", err)
	}
	if n, err := client.Holding.Query().Where(holdpred.TenantID(tenantID)).Count(ctx); err != nil || n != 1 {
		t.Fatalf("expected exactly 1 holding row, n=%d err=%v", n, err)
	}
	got, err = repo.FindByID(ctx, tenantID, h.ID)
	if err != nil {
		t.Fatalf("find after update: %v", err)
	}
	if got.Quantity != 250 || got.AvgCostCents != 1100 || got.Version != 6 {
		t.Fatalf("updated holding = %+v", got)
	}

	// Tenant injection override. (Distinct security from h: the holding table
	// has a UNIQUE (tenant, account, security) index, so a second position row
	// under the same tenant needs its own security.)
	evil := uuid.New()
	h2 := holdingdomain.Holding{
		ID: uuid.New(), TenantID: evil, AccountID: accountID, SecurityID: uuid.New(),
		Quantity: 1, AvgCostCents: 1, Version: 1, CreatedAt: now, UpdatedAt: now,
	}
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, h2)); err != nil {
		t.Fatalf("upsert forged tenant: %v", err)
	}
	if n, err := client.Holding.Query().Where(holdpred.TenantID(tenantID)).Count(ctx); err != nil || n != 2 {
		t.Fatalf("forged-tenant row must land under the authenticated tenant, n=%d err=%v", n, err)
	}
	if n, err := client.Holding.Query().Where(holdpred.TenantID(evil)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("no rows may land under the forged tenant, n=%d err=%v", n, err)
	}

	if err := w.Delete(ctx, tenantID, h.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.Holding.Query().Where(holdpred.ID(h.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("holding row must be gone, n=%d err=%v", n, err)
	}
}

// --- budget / goal / tag / template (light: create + delete each) ---

func TestBudgetWriter_CreateAndDelete(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := budgetent.NewClient(budgetent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate budget schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := budgetrepo.NewBudgetRepository(client)
	w := entitywriter.NewBudgetWriter(repo)
	tenantID := uuid.New()
	now := time.Now()
	b := budgetdomain.Budget{
		ID: uuid.New(), TenantID: tenantID, Name: "food", Month: "2026-09",
		TotalAmountCents: 50000, CurrencyCode: "CNY", IsActive: true,
		Items: []budgetdomain.BudgetItem{
			{ID: uuid.New(), BudgetID: uuid.Nil, AccountID: uuid.New(), PlannedAmountCents: 50000},
		},
		Version: 1, CreatedAt: now, UpdatedAt: now,
	}
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, b)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	got, err := repo.FindByID(ctx, tenantID, b.ID)
	if err != nil {
		t.Fatalf("find after create: %v", err)
	}
	if len(got.Items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(got.Items))
	}

	if err := w.Delete(ctx, tenantID, b.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.Budget.Query().Where(budgetpred.ID(b.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("budget must be gone, n=%d err=%v", n, err)
	}
}

func TestGoalWriter_CreateAndDelete(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := goalent.NewClient(goalent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate goal schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := goalrepo.NewGoalRepository(client)
	w := entitywriter.NewGoalWriter(repo)
	tenantID := uuid.New()
	now := time.Now()
	g := goaldomain.Goal{
		ID: uuid.New(), TenantID: tenantID, Name: "emergency fund",
		GoalType: goaldomain.GoalTypeSavings, TargetAmountCents: 1000000,
		CurrentAmountCents: 100, CurrencyCode: "CNY",
		LinkedAccountIDs: []uuid.UUID{uuid.New()},
		Version:          1, CreatedAt: now, UpdatedAt: now,
	}
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, g)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	got, err := repo.FindByID(ctx, tenantID, g.ID)
	if err != nil {
		t.Fatalf("find after create: %v", err)
	}
	if len(got.LinkedAccountIDs) != 1 {
		t.Fatalf("expected 1 account link, got %d", len(got.LinkedAccountIDs))
	}

	if err := w.Delete(ctx, tenantID, g.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.Goal.Query().Where(goalpred.ID(g.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("goal must be gone, n=%d err=%v", n, err)
	}
}

func TestTagWriter_CreateAndDelete(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := tagent.NewClient(tagent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate tag schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := tagrepo.NewTagRepository(client)
	w := entitywriter.NewTagWriter(repo)
	tenantID := uuid.New()
	now := time.Now()
	tg := tagdomain.Tag{
		ID: uuid.New(), TenantID: tenantID, Name: "travel", Color: "#112233",
		Version: 1, CreatedAt: now, UpdatedAt: now,
	}
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, tg)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	if _, err := repo.FindByID(ctx, tenantID, tg.ID); err != nil {
		t.Fatalf("find after create: %v", err)
	}

	if err := w.Delete(ctx, tenantID, tg.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.Tag.Query().Where(tagpred.ID(tg.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("tag must be gone (hard delete), n=%d err=%v", n, err)
	}
}

func TestTemplateWriter_CreateAndDelete(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := tmplent.NewClient(tmplent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate template schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := templaterepo.NewTemplateRepository(client)
	w := entitywriter.NewTemplateWriter(repo)
	tenantID := uuid.New()
	now := time.Now()
	tpl := templatedomain.TransactionTemplate{
		ID: uuid.New(), TenantID: tenantID, Name: "rent", Description: "monthly rent",
		AmountCents: 300000, Direction: templatedomain.DirectionExpense,
		SourceAccountID: uuid.New(), Cycle: templatedomain.CycleWeekly,
		NextDate: now.AddDate(0, 0, 7), StartDate: now,
		Version: 1, CreatedAt: now, UpdatedAt: now,
	}
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, tpl)); err != nil {
		t.Fatalf("upsert create: %v", err)
	}
	if _, err := repo.FindByID(ctx, tenantID, tpl.ID); err != nil {
		t.Fatalf("find after create: %v", err)
	}

	if err := w.Delete(ctx, tenantID, tpl.ID.String()); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if n, err := client.TransactionTemplate.Query().Where(tmplpred.ID(tpl.ID)).Count(ctx); err != nil || n != 0 {
		t.Fatalf("template must be gone, n=%d err=%v", n, err)
	}
}

// TestAccountWriter_Upsert_ResurrectsSoftDeletedRow (review fix round 1,
// item 3): a server-side soft-deleted row that the client still holds is
// resurrected by an upsert — the client is the single-device source of truth,
// so the update path finds soft-deleted rows and clears deleted_at.
func TestAccountWriter_Upsert_ResurrectsSoftDeletedRow(t *testing.T) {
	db := openWriterDB(t)
	drv := entsql.OpenDB(dialect.SQLite, db)
	client := accountent.NewClient(accountent.Driver(drv))
	ctx := context.Background()
	if err := client.Schema.Create(ctx); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() { _ = client.Close() })

	repo := accountrepo.NewAccountRepository(client)
	w := entitywriter.NewAccountWriter(repo)
	tenantID := uuid.New()

	// Seed + server-side soft delete (server-only semantics, not from sync).
	a := newAccountFixture(tenantID, "Zombie", 1)
	if err := repo.Save(ctx, &a); err != nil {
		t.Fatalf("seed account: %v", err)
	}
	if err := repo.SoftDelete(ctx, tenantID, a.ID); err != nil {
		t.Fatalf("soft delete account: %v", err)
	}
	if _, err := repo.FindByID(ctx, tenantID, a.ID); err == nil {
		t.Fatal("precondition: soft-deleted row must be invisible to FindByID")
	}

	// Client still holds the row and pushes v2 -> resurrection.
	a.Name = "Resurrected"
	a.Version = 2
	if err := w.Upsert(ctx, tenantID, mustMarshal(t, a)); err != nil {
		t.Fatalf("upsert over soft-deleted row: %v", err)
	}
	got, err := repo.FindByID(ctx, tenantID, a.ID)
	if err != nil {
		t.Fatalf("row must be visible again after upsert: %v", err)
	}
	if got.Name != "Resurrected" || got.Version != 2 {
		t.Fatalf("resurrected account = %+v", got)
	}
	// deleted_at must be physically cleared (not merely filtered).
	row, err := client.Account.Query().Where(accpredicate.ID(a.ID)).Only(ctx)
	if err != nil {
		t.Fatalf("query raw row: %v", err)
	}
	if row.DeletedAt != nil {
		t.Fatalf("deleted_at must be cleared on resurrection, got %v", row.DeletedAt)
	}
}
