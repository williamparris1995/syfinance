package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/holdingsnapshot"
)

// SnapshotRepository implements domain.SnapshotRepository.
type SnapshotRepository struct {
	client *holdingent.Client
}

// NewSnapshotRepository creates a new SnapshotRepository.
func NewSnapshotRepository(client *holdingent.Client) *SnapshotRepository {
	return &SnapshotRepository{client: client}
}

// FindSnapshots returns daily snapshots for a tenant in [from, to], optionally
// narrowed by account and/or security. Ordered by SnapshotDate ascending
// (curve-friendly). Tenant scoping is mandatory (snapshots are tenant-owned).
func (r *SnapshotRepository) FindSnapshots(ctx context.Context, tenantID uuid.UUID, from, to time.Time, accountID, securityID *uuid.UUID) ([]domain.HoldingSnapshot, error) {
	q := r.client.HoldingSnapshot.Query().Where(
		holdingsnapshot.TenantIDEQ(tenantID),
		holdingsnapshot.SnapshotDateGTE(from),
		holdingsnapshot.SnapshotDateLTE(to),
	)
	if accountID != nil {
		q = q.Where(holdingsnapshot.AccountIDEQ(*accountID))
	}
	if securityID != nil {
		q = q.Where(holdingsnapshot.SecurityIDEQ(*securityID))
	}
	rows, err := q.Order(holdingent.Asc(holdingsnapshot.FieldSnapshotDate)).All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query holding snapshots: %w", err)
	}
	out := make([]domain.HoldingSnapshot, 0, len(rows))
	for _, row := range rows {
		out = append(out, toDomainSnapshot(row))
	}
	return out, nil
}

// Save inserts one daily snapshot. A duplicate daily tick — same
// (tenant, holding, snapshot_date) — hits UNIQUE(tenant_id, holding_id,
// snapshot_date) and is ignored: first-wins, the original time-point snapshot is
// kept (D18), so a scheduler re-tick or retry can no longer abort the day's
// snapshot. Any OTHER create error (FK violation, NOT NULL, connection drop)
// surfaces verbatim — only the daily-dedup conflict is swallowed. The ent
// codegen exposes no first-class OnConflict helper (sql/upsert feature not
// enabled), so this mirrors the create-then-tolerate-constraint pattern of
// debt_snapshot_repo, but first-wins rather than overwrite per D18.
func (r *SnapshotRepository) Save(ctx context.Context, s domain.HoldingSnapshot) error {
	if err := r.client.HoldingSnapshot.Create().
		SetTenantID(s.TenantID).
		SetHoldingID(s.HoldingID).
		SetSecurityID(s.SecurityID).
		SetAccountID(s.AccountID).
		SetSnapshotDate(s.SnapshotDate).
		SetMarketValueCents(s.MarketValueCents).
		SetUnrealizedPnlCents(s.UnrealizedPnlCents).
		SetCurrencyCode(s.CurrencyCode).
		Exec(ctx); err != nil {
		if holdingent.IsConstraintError(err) {
			// D18: duplicate (tenant, holding, date) tick — keep the original
			// (first-wins). The UNIQUE constraint above guarantees a row exists.
			return nil
		}
		return fmt.Errorf("save holding snapshot: %w", err)
	}
	return nil
}

func toDomainSnapshot(row *holdingent.HoldingSnapshot) domain.HoldingSnapshot {
	return domain.HoldingSnapshot{
		ID:                 row.ID,
		TenantID:           row.TenantID,
		HoldingID:          row.HoldingID,
		SecurityID:         row.SecurityID,
		AccountID:          row.AccountID,
		SnapshotDate:       row.SnapshotDate,
		MarketValueCents:   row.MarketValueCents,
		UnrealizedPnlCents: row.UnrealizedPnlCents,
		CurrencyCode:       row.CurrencyCode,
		CreatedAt:          row.CreatedAt,
	}
}

var _ domain.SnapshotRepository = (*SnapshotRepository)(nil)
