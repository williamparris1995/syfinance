package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	backupdomain "github.com/yucai/server/internal/backup/domain"
	"github.com/yucai/server/internal/budget/domain"
)

// BudgetRepository is the budget-repo port subset that BudgetExporter consumes.
// Declared as a type alias so backup does not import the concrete budget repo
// type; any implementer of budget/domain.BudgetRepository satisfies it (port
// pattern, mirrors AccountExporter/TransactionExporter/DebtExporter).
type BudgetRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Budget, error)
	Save(ctx context.Context, b *domain.Budget) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// BudgetExporter 导出/导入/清空 tenant 的 budgets(含 items),实现 backup
// TenantDataPort。Each Budget carries its Items nested, so Export marshals
// []Budget directly (items ride along as a nested array).
type BudgetExporter struct {
	repo BudgetRepository
}

// NewBudgetExporter constructs a BudgetExporter from a BudgetRepository.
func NewBudgetExporter(repo BudgetRepository) *BudgetExporter {
	return &BudgetExporter{repo: repo}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *BudgetExporter) Name() string { return "budget" }

// Export serializes all tenant budgets (non-deleted, with items) to JSON.
func (e *BudgetExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	list, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export budgets: %w", err)
	}
	data, err := json.Marshal(list)
	if err != nil {
		return nil, fmt.Errorf("marshal budgets: %w", err)
	}
	return data, nil
}

// Import deserializes budgets (with nested items) from JSON and re-saves them
// under tenantID. Caller is expected to have Purged existing data first to
// avoid ID conflicts. Save creates the budget and its items in one call,
// honoring the caller-supplied IDs.
func (e *BudgetExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var list []domain.Budget
	if err := json.Unmarshal(data, &list); err != nil {
		return fmt.Errorf("unmarshal budgets: %w", err)
	}
	for i := range list {
		list[i].TenantID = tenantID
		if err := e.repo.Save(ctx, &list[i]); err != nil {
			return fmt.Errorf("save budget %s: %w", list[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant budgets and their items (items first, then
// budgets, to respect the FK ordering).
func (e *BudgetExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge budgets: %w", err)
	}
	return nil
}

// Compile-time assertion: BudgetExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*BudgetExporter)(nil)
