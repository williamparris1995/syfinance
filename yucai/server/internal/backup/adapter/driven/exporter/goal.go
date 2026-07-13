package exporter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	backupdomain "github.com/yucai/server/internal/backup/domain"
	goalDomain "github.com/yucai/server/internal/goal/domain"
)

// GoalRepository is the goal-repo port subset that GoalExporter consumes.
// Declared as a type alias so backup does not import the concrete goal repo
// type; any implementer of goal/domain.GoalRepository satisfies it (port
// pattern, mirrors AccountExporter/TransactionExporter/DebtExporter/BudgetExporter).
type GoalRepository = interface {
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]goalDomain.Goal, error)
	Save(ctx context.Context, g *goalDomain.Goal) error
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// GoalExporter 导出/导入/清空 tenant 的 goals(含 multi-account + multi-debt
// links),实现 backup TenantDataPort。Each Goal carries its LinkedAccountIDs +
// LinkedDebtIDs nested, so Export marshals []Goal directly (links ride along
// as nested slices). Progress snapshots are derived (recomputed daily) and
// excluded.
type GoalExporter struct {
	repo GoalRepository
}

// NewGoalExporter constructs a GoalExporter from a GoalRepository.
func NewGoalExporter(repo GoalRepository) *GoalExporter {
	return &GoalExporter{repo: repo}
}

// Name returns the module identifier used as BackupEnvelope.Modules key.
func (e *GoalExporter) Name() string { return "goal" }

// Export serializes all tenant goals (with account + debt links) to JSON.
func (e *GoalExporter) Export(ctx context.Context, tenantID uuid.UUID) (json.RawMessage, error) {
	list, err := e.repo.FindAllForBackup(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("export goals: %w", err)
	}
	data, err := json.Marshal(list)
	if err != nil {
		return nil, fmt.Errorf("marshal goals: %w", err)
	}
	return data, nil
}

// Import deserializes goals (with nested account + debt links) from JSON and
// re-saves them under tenantID. Caller is expected to have Purged existing data
// first to avoid ID conflicts. Save creates the goal and its link-table rows in
// one call, honoring the caller-supplied IDs.
func (e *GoalExporter) Import(ctx context.Context, tenantID uuid.UUID, data json.RawMessage) error {
	var list []goalDomain.Goal
	if err := json.Unmarshal(data, &list); err != nil {
		return fmt.Errorf("unmarshal goals: %w", err)
	}
	for i := range list {
		list[i].TenantID = tenantID
		if err := e.repo.Save(ctx, &list[i]); err != nil {
			return fmt.Errorf("save goal %s: %w", list[i].ID, err)
		}
	}
	return nil
}

// Purge hard-deletes all tenant goals and their account/debt links (links
// first, then goals, to respect the FK ordering).
func (e *GoalExporter) Purge(ctx context.Context, tenantID uuid.UUID) error {
	if err := e.repo.DeleteByTenant(ctx, tenantID); err != nil {
		return fmt.Errorf("purge goals: %w", err)
	}
	return nil
}

// Compile-time assertion: GoalExporter satisfies backup TenantDataPort.
var _ backupdomain.TenantDataPort = (*GoalExporter)(nil)
