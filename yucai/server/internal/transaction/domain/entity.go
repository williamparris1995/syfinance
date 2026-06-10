package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Transaction is the aggregate root for the double-entry bookkeeping engine.
type Transaction struct {
	ID              uuid.UUID
	TenantID        uuid.UUID
	TransactionDate time.Time
	Description     string
	Entries         []TransactionEntry
	Version         int64
	CreatedAt       time.Time
	UpdatedAt       time.Time
	DeletedAt       *time.Time
}

// TransactionEntry represents a single debit or credit line within a transaction.
type TransactionEntry struct {
	ID                 uuid.UUID
	TransactionID      uuid.UUID
	AccountID          uuid.UUID
	ChartOfAccountCode string
	DebitCents         int64
	CreditCents        int64
	Note               string
}

// NewTransaction creates a validated Transaction with double-entry checking.
func NewTransaction(tenantID uuid.UUID, date time.Time, description string, entries []TransactionEntry) (*Transaction, error) {
	if len(entries) < 2 {
		return nil, fmt.Errorf("transaction must have at least 2 entries, got %d", len(entries))
	}
	validator := DoubleEntryValidator{}
	if err := validator.Validate(entries); err != nil {
		return nil, err
	}

	txnID := uuid.New()
	for i := range entries {
		if entries[i].ID == uuid.Nil {
			entries[i].ID = uuid.New()
		}
		entries[i].TransactionID = txnID
	}

	return &Transaction{
		ID:              txnID,
		TenantID:        tenantID,
		TransactionDate: date,
		Description:     description,
		Entries:         entries,
		Version:         1,
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}, nil
}

// IncrementVersion bumps the optimistic lock version.
func (t *Transaction) IncrementVersion() {
	t.Version++
	t.UpdatedAt = time.Now()
}
