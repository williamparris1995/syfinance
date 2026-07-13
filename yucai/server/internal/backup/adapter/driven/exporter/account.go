package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/domain"
	backupdomain "github.com/yucai/server/internal/backup/domain"
)

// AccountRepository is the account-repo port subset that AccountExporter
// consumes. Declared as a type alias so backup does not import the concrete
// account repo type; any implementer of account/domain.AccountRepository
// satisfies it (port pattern, mirrors networth/goal ports).
type AccountRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Account, error)
	Save(ctx context.Context, a *domain.Account) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// AccountExporter 导出/导入/清空 tenant 的 accounts,实现 backup TenantDataPort。
// 此文件是其他模块 exporter(transaction/debt/budget/...)的模板。
type AccountExporter struct {
	repo AccountRepository
}

// NewAccountExporter constructs an AccountExporter from an AccountRepository.
func NewAccountExporter(repo AccountRepository) *AccountExporter {
	return &AccountExporter{repo: repo}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *AccountExporter) Name() string { return "account" }

// Export serializes all tenant accounts (non-deleted, includes categories) to JSON.
func (e *AccountExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	list, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export accounts: %w", err)
	}
	data, err := json.Marshal(list)
	if err != nil {
		return nil, fmt.Errorf("marshal accounts: %w", err)
	}
	return data, nil
}

// Import deserializes accounts from JSON and re-saves them under tenantID.
// Caller is expected to have Purged existing data first to avoid ID conflicts.
func (e *AccountExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var list []domain.Account
	if err := json.Unmarshal(data, &list); err != nil {
		return fmt.Errorf("unmarshal accounts: %w", err)
	}
	for i := range list {
		list[i].TenantID = tenantID
		if err := e.repo.Save(ctx, &list[i]); err != nil {
			return fmt.Errorf("save account %s: %w", list[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant accounts (including categories).
func (e *AccountExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge accounts: %w", err)
	}
	return nil
}

// Compile-time assertion: AccountExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*AccountExporter)(nil)
