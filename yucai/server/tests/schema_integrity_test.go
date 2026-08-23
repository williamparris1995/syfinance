package tests

import (
	"context"
	"strings"
	"testing"

	"github.com/google/uuid"
)

// R5 feature E schema-integrity checks for the transaction module:
// Min(0) money validators and the new transaction_entries FK.

// TestSchemaMinZero_RejectsNegativeEntryAmount verifies the builder-level
// Min(0) validator: a negative debit is rejected before any SQL runs.
func TestSchemaMinZero_RejectsNegativeEntryAmount(t *testing.T) {
	_, txnClient := setupTransactionTestDB(t)
	ctx := context.Background()

	_, err := txnClient.TransactionEntry.Create().
		SetID(uuid.New()).
		SetTransactionID(uuid.New()).
		SetAccountID(uuid.New()).
		SetDebitCents(-1).
		Save(ctx)
	if err == nil {
		t.Fatal("expected Min(0) validator rejection for negative debit, got nil")
	}
	if !strings.Contains(err.Error(), "validator") {
		t.Errorf("expected validator error, got: %v", err)
	}

	_, err = txnClient.TransactionEntry.Create().
		SetID(uuid.New()).
		SetTransactionID(uuid.New()).
		SetAccountID(uuid.New()).
		SetCreditCents(-100).
		Save(ctx)
	if err == nil {
		t.Fatal("expected Min(0) validator rejection for negative credit, got nil")
	}
}

// TestSchemaFK_EntryRequiresExistingTransaction verifies the new edge FK
// transaction_entries.transaction_id -> transactions: an entry pointing at a
// nonexistent transaction is rejected by the database. (Pre-R5-E the column
// accepted anything — the UpdateTransaction path even wrote uuid.Nil rows,
// which this constraint now makes impossible.)
func TestSchemaFK_EntryRequiresExistingTransaction(t *testing.T) {
	acctClient, txnClient := setupTransactionTestDB(t)
	ctx := context.Background()
	tenant := uuid.New()

	acct, err := acctClient.Account.Create().
		SetTenantID(tenant).
		SetName("fk probe").
		SetAccountType("asset").
		Save(ctx)
	if err != nil {
		t.Fatalf("seed account: %v", err)
	}

	_, err = txnClient.TransactionEntry.Create().
		SetID(uuid.New()).
		SetTransactionID(uuid.New()). // no such transaction
		SetAccountID(acct.ID).
		SetDebitCents(100).
		Save(ctx)
	if err == nil {
		t.Fatal("expected FK violation for entry with nonexistent transaction_id, got nil")
	}
	if !strings.Contains(err.Error(), "FOREIGN KEY") {
		t.Errorf("expected FOREIGN KEY constraint error, got: %v", err)
	}
}
