package schema_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	"github.com/yucai/server/internal/debt/ent"
)

// setupDebtTestDB opens an in-memory SQLite database and runs ent auto-migration
// for the debt schema. Mirrors the holding/goal test pattern (file:<name>?mode=memory,
// MaxOpenConns(1) to keep the same in-memory DB alive across connections).
func setupDebtTestDB(t *testing.T) *ent.Client {
	t.Helper()
	dbName := "debt_ent_" + sanitize(t.Name())
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	client := ent.NewClient(ent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// sanitize strips characters illegal in sqlite file names from a test name.
func sanitize(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '/' || c == '\\' || c == ' ' || c == ':' {
			out = append(out, '_')
			continue
		}
		out = append(out, c)
	}
	return string(out)
}

// TestDebtProgressSnapshotSchema verifies:
//  1. The DebtProgressSnapshot table creates with all expected columns.
//  2. UNIQUE(tenant_id, debt_id, snapshot_date) constraint is enforced —
//     inserting two snapshots with the same (tenant_id, debt_id, snapshot_date)
//     fails the second insert.
//  3. The DebtDetails schema accepts the 3 new nullable fields
//     (contact, contract_ref, collection_account_id) and persists defaults/null.
func TestDebtProgressSnapshotSchema(t *testing.T) {
	tenantID := uuid.New()
	now := time.Now().UTC().Truncate(time.Second)

	client := setupDebtTestDB(t)
	ctx := context.Background()

	// --- DebtDetails: 3 new nullable fields can be left unset (default/null) ---
	acc, err := client.DebtDetails.Create().
		SetTenantID(tenantID).
		SetAccountID(uuid.New()).
		SetCounterparty("Lender A").
		SetInterestRate(0.05).
		SetAmortizationMethod("equal_principal_interest").
		SetStartDate(now).
		SetDueDate(now.AddDate(1, 0, 0)).
		SetTotalPrincipalCents(100000).
		SetDebtType("borrowed_in").
		Save(ctx)
	if err != nil {
		t.Fatalf("create DebtDetails with default contact/contract_ref/collection_account_id: %v", err)
	}
	if acc.Contact != "" {
		t.Errorf("contact default = %q, want %q", acc.Contact, "")
	}
	if acc.ContractRef != "" {
		t.Errorf("contract_ref default = %q, want %q", acc.ContractRef, "")
	}
	if acc.CollectionAccountID != nil {
		t.Errorf("collection_account_id = %v, want nil", acc.CollectionAccountID)
	}

	// And explicit values round-trip.
	collAcc := uuid.New()
	acc2, err := client.DebtDetails.Create().
		SetTenantID(tenantID).
		SetAccountID(uuid.New()).
		SetCounterparty("Lender B").
		SetInterestRate(0.07).
		SetAmortizationMethod("lump_sum").
		SetStartDate(now).
		SetDueDate(now.AddDate(2, 0, 0)).
		SetTotalPrincipalCents(200000).
		SetDebtType("borrowed_out").
		SetContact("Alice").
		SetContractRef("CTR-2026-001").
		SetCollectionAccountID(collAcc).
		Save(ctx)
	if err != nil {
		t.Fatalf("create DebtDetails with explicit contact/contract_ref/collection_account_id: %v", err)
	}
	if acc2.Contact != "Alice" {
		t.Errorf("contact = %q, want %q", acc2.Contact, "Alice")
	}
	if acc2.ContractRef != "CTR-2026-001" {
		t.Errorf("contract_ref = %q, want %q", acc2.ContractRef, "CTR-2026-001")
	}
	if *acc2.CollectionAccountID != collAcc {
		t.Errorf("collection_account_id = %v, want %v", *acc2.CollectionAccountID, collAcc)
	}

	// --- DebtProgressSnapshot: first insert succeeds ---
	snap1, err := client.DebtProgressSnapshot.Create().
		SetTenantID(tenantID).
		SetDebtID(acc.ID).
		SetSnapshotDate(now).
		SetTotalPrincipalCents(100000).
		SetRemainingPrincipalCents(90000).
		SetPaidTotalCents(10000).
		Save(ctx)
	if err != nil {
		t.Fatalf("create first DebtProgressSnapshot: %v", err)
	}
	if snap1.DebtID != acc.ID {
		t.Errorf("debt_id = %v, want %v", snap1.DebtID, acc.ID)
	}

	// --- UNIQUE(tenant_id, debt_id, snapshot_date): second insert with same key fails ---
	_, err = client.DebtProgressSnapshot.Create().
		SetTenantID(tenantID).
		SetDebtID(acc.ID).
		SetSnapshotDate(now).
		SetTotalPrincipalCents(100000).
		SetRemainingPrincipalCents(80000).
		SetPaidTotalCents(20000).
		Save(ctx)
	if err == nil {
		t.Fatalf("expected UNIQUE constraint violation for duplicate (tenant_id, debt_id, snapshot_date), got nil")
	}
}
