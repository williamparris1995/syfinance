package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	syncdomain "github.com/yucai/server/internal/sync/domain"
	txndomain "github.com/yucai/server/internal/transaction/domain"
)

// TransactionRepository is the transaction-repo port subset the sync writer
// consumes (type alias, port pattern).
type TransactionRepository = interface {
	UpsertForSync(ctx context.Context, tx *txndomain.Transaction) error
	HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error
}

// TransactionWriter persists pushed transaction changes (entity_type
// "transaction"). Payload shape: one Transaction domain row with its Entries
// nested (the backup envelope per-row serialization).
type TransactionWriter struct {
	repo TransactionRepository
}

// NewTransactionWriter constructs a TransactionWriter.
func NewTransactionWriter(repo TransactionRepository) *TransactionWriter {
	return &TransactionWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *TransactionWriter) Name() string { return "transaction" }

// Upsert decodes one transaction payload (header + nested entries) and
// upserts it under tenantID (authenticated tenant wins, anti injection).
func (w *TransactionWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var tx txndomain.Transaction
	if err := json.Unmarshal(payload, &tx); err != nil {
		return fmt.Errorf("unmarshal transaction payload: %w", err)
	}
	tx.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &tx); err != nil {
		return fmt.Errorf("upsert transaction %s: %w", tx.ID, err)
	}
	return nil
}

// Delete hard-deletes one transaction (entries cascade in-repo) under tenantID.
func (w *TransactionWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse transaction id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete transaction %s: %w", id, err)
	}
	return nil
}

var _ syncdomain.SyncEntityWriter = (*TransactionWriter)(nil)
