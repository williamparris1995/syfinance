package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/debt/domain"
	debtent "github.com/yucai/server/internal/debt/ent"
	"github.com/yucai/server/internal/debt/ent/debtprogresssnapshot"
)

// DebtSnapshotRepository implements domain.DebtSnapshotRepository. Mirrors the
// holding snapshot repo split (own interface + own impl) so adding snapshot
// persistence here does not perturb any DebtRepository implementer.
type DebtSnapshotRepository struct {
	client *debtent.Client
}

// NewDebtSnapshotRepository creates a new DebtSnapshotRepository.
func NewDebtSnapshotRepository(client *debtent.Client) domain.DebtSnapshotRepository {
	return &DebtSnapshotRepository{client: client}
}

// SaveSnapshot writes one snapshot row. ent has no first-class OnConflict
// extension in this codebase, so we mirror holding C Task10's lesson: try
// insert, and on UNIQUE(tenant_id, debt_id, snapshot_date) violation fall
// back to update. This keeps same-day re-runs idempotent.
func (r *DebtSnapshotRepository) SaveSnapshot(ctx context.Context, snap *domain.DebtProgressSnapshot) error {
	err := r.client.DebtProgressSnapshot.Create().
		SetID(snap.ID).
		SetTenantID(snap.TenantID).
		SetDebtID(snap.DebtID).
		SetSnapshotDate(snap.SnapshotDate).
		SetTotalPrincipalCents(snap.TotalPrincipalCents).
		SetRemainingPrincipalCents(snap.RemainingCents).
		SetPaidTotalCents(snap.PaidTotalCents).
		Exec(ctx)
	if err == nil {
		return nil
	}
	// Fallback: a row already exists for this (tenant, debt, date) — update it.
	rows, err := r.client.DebtProgressSnapshot.Update().
		Where(
			debtprogresssnapshot.TenantIDEQ(snap.TenantID),
			debtprogresssnapshot.DebtIDEQ(snap.DebtID),
			debtprogresssnapshot.SnapshotDateEQ(snap.SnapshotDate),
		).
		SetTotalPrincipalCents(snap.TotalPrincipalCents).
		SetRemainingPrincipalCents(snap.RemainingCents).
		SetPaidTotalCents(snap.PaidTotalCents).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("upsert debt snapshot: %w", err)
	}
	if rows == 0 {
		// Insert failed for a non-conflict reason (e.g. constraint other than
		// the unique index); surface the original create error.
		return fmt.Errorf("save debt snapshot: %w", err)
	}
	return nil
}

// FindLatestByDebt returns the most recent snapshot for a debt at or before
// asOf. Returns nil, nil when no such snapshot exists.
func (r *DebtSnapshotRepository) FindLatestByDebt(ctx context.Context, tenantID, debtID uuid.UUID, asOf time.Time) (*domain.DebtProgressSnapshot, error) {
	row, err := r.client.DebtProgressSnapshot.Query().
		Where(
			debtprogresssnapshot.TenantIDEQ(tenantID),
			debtprogresssnapshot.DebtIDEQ(debtID),
			debtprogresssnapshot.SnapshotDateLTE(asOf),
		).
		Order(debtent.Desc(debtprogresssnapshot.FieldSnapshotDate)).
		First(ctx)
	if err != nil {
		if debtent.IsNotFound(err) {
			return nil, nil
		}
		return nil, fmt.Errorf("find latest debt snapshot: %w", err)
	}
	snap := toDomainDebtSnapshot(row)
	return &snap, nil
}

// FindSnapshotRange returns all snapshots in [from, to] for the given debts,
// tenant-scoped. Ordered ascending by snapshot_date (chart-friendly).
func (r *DebtSnapshotRepository) FindSnapshotRange(ctx context.Context, tenantID uuid.UUID, debtIDs []uuid.UUID, from, to time.Time) ([]domain.DebtProgressSnapshot, error) {
	if len(debtIDs) == 0 {
		return nil, nil
	}
	rows, err := r.client.DebtProgressSnapshot.Query().
		Where(
			debtprogresssnapshot.TenantIDEQ(tenantID),
			debtprogresssnapshot.DebtIDIn(debtIDs...),
			debtprogresssnapshot.SnapshotDateGTE(from),
			debtprogresssnapshot.SnapshotDateLTE(to),
		).
		Order(debtent.Asc(debtprogresssnapshot.FieldSnapshotDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find debt snapshot range: %w", err)
	}
	out := make([]domain.DebtProgressSnapshot, 0, len(rows))
	for _, row := range rows {
		out = append(out, toDomainDebtSnapshot(row))
	}
	return out, nil
}

func toDomainDebtSnapshot(row *debtent.DebtProgressSnapshot) domain.DebtProgressSnapshot {
	return domain.DebtProgressSnapshot{
		ID:                  row.ID,
		TenantID:            row.TenantID,
		DebtID:              row.DebtID,
		SnapshotDate:        row.SnapshotDate,
		TotalPrincipalCents: row.TotalPrincipalCents,
		RemainingCents:      row.RemainingPrincipalCents,
		PaidTotalCents:      row.PaidTotalCents,
		CreatedAt:           row.CreatedAt,
	}
}

// Compile-time check.
var _ domain.DebtSnapshotRepository = (*DebtSnapshotRepository)(nil)
