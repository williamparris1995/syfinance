package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// PageRequest for cursor-based pagination.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult wraps results with pagination metadata.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

// DebtRepository defines the port for DebtDetails persistence.
type DebtRepository interface {
	Save(ctx context.Context, debt *DebtDetails) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*DebtDetails, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, page PageRequest, typeFilter *DebtType) (*PaginatedResult[DebtDetails], error)
	Update(ctx context.Context, debt *DebtDetails) error
	Delete(ctx context.Context, tenantID, id uuid.UUID) error
	FindUpcomingPayments(ctx context.Context, tenantID uuid.UUID, daysAhead int) ([]PaymentScheduleEntry, error)
	// FindAllForBackup returns every debt for a tenant with its payment schedule
	// eager-loaded (single batched query, no pagination). Used by the backup
	// exporter to serialize a tenant's full debt graph.
	FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]DebtDetails, error)
	// DeleteByTenant hard-deletes every debt belonging to the tenant, removing
	// child payment_schedules first (FK ordering). Used by the backup exporter's
	// Purge step before a restore.
	DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error
}

// DebtSnapshotRepository is the persistence port for DebtProgressSnapshot rows.
// Kept as a separate interface (rather than methods on DebtRepository) so adding
// snapshot persistence does not force every existing DebtRepository
// implementer (and test fake) to grow — mirrors the holding snapshot-repo
// split. Implementers are added in Task 4 (ent repo).
type DebtSnapshotRepository interface {
	SaveSnapshot(ctx context.Context, snap *DebtProgressSnapshot) error
	FindLatestByDebt(ctx context.Context, tenantID, debtID uuid.UUID, asOf time.Time) (*DebtProgressSnapshot, error)
	FindSnapshotRange(ctx context.Context, tenantID uuid.UUID, debtIDs []uuid.UUID, from, to time.Time) ([]DebtProgressSnapshot, error)
}
