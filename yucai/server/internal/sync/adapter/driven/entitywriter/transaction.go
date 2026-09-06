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
	FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*txndomain.Transaction, bool, error)
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

// CurrentState returns the server's current transaction row (header + nested
// entries in the payload) for the push conflict check (F16 ADR-4). See the
// port doc in sync/domain/entity_writer.go for the full contract.
func (w *TransactionWriter) CurrentState(ctx context.Context, tenantID uuid.UUID, entityID string) (int64, []byte, bool, error) {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return 0, nil, false, fmt.Errorf("parse transaction id %q: %w", entityID, err)
	}
	tx, found, err := w.repo.FindForSync(ctx, tenantID, id)
	if err != nil || !found {
		return 0, nil, false, err
	}
	payload, err := json.Marshal(tx)
	if err != nil {
		return 0, nil, false, fmt.Errorf("marshal transaction %s: %w", id, err)
	}
	return tx.Version, payload, true, nil
}

var _ syncdomain.SyncEntityWriter = (*TransactionWriter)(nil)
