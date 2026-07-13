package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	backupdomain "github.com/yucai/server/internal/backup/domain"
	"github.com/yucai/server/internal/transaction/domain"
)

// TransactionRepository is the transaction-repo port subset that
// TransactionExporter consumes. Declared as a type alias so backup does not
// import the concrete transaction repo type; any implementer of
// transaction/domain.TransactionRepository satisfies it (port pattern, mirrors
// AccountExporter).
type TransactionRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Transaction, error)
	Save(ctx context.Context, tx *domain.Transaction) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// TransactionExporter 导出/导入/清空 tenant 的 transactions(含 entries),
// 实现 backup TenantDataPort。Each Transaction carries its Entries nested, so
// Export marshals []Transaction directly (entries ride along as a nested array).
type TransactionExporter struct {
	repo TransactionRepository
}

// NewTransactionExporter constructs a TransactionExporter from a TransactionRepository.
func NewTransactionExporter(repo TransactionRepository) *TransactionExporter {
	return &TransactionExporter{repo: repo}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *TransactionExporter) Name() string { return "transaction" }

// Export serializes all tenant transactions (non-deleted, with entries) to JSON.
func (e *TransactionExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	list, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export transactions: %w", err)
	}
	data, err := json.Marshal(list)
	if err != nil {
		return nil, fmt.Errorf("marshal transactions: %w", err)
	}
	return data, nil
}

// Import deserializes transactions (with nested entries) from JSON and re-saves
// them under tenantID. Caller is expected to have Purged existing data first to
// avoid ID conflicts. Save creates the transaction and its entries in one call,
// honoring the caller-supplied IDs.
func (e *TransactionExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var list []domain.Transaction
	if err := json.Unmarshal(data, &list); err != nil {
		return fmt.Errorf("unmarshal transactions: %w", err)
	}
	for i := range list {
		list[i].TenantID = tenantID
		if err := e.repo.Save(ctx, &list[i]); err != nil {
			return fmt.Errorf("save transaction %s: %w", list[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant transactions and their entries (entries first,
// then transactions, to respect the FK ordering).
func (e *TransactionExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge transactions: %w", err)
	}
	return nil
}

// Compile-time assertion: TransactionExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*TransactionExporter)(nil)
