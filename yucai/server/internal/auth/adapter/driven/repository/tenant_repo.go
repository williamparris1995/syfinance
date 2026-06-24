package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/ent"
	"github.com/yucai/server/internal/auth/ent/tenant"
)

// TenantRepository implements domain.TenantRepository using entGo.
type TenantRepository struct {
	client *ent.Client
}

// NewTenantRepository creates a new TenantRepository.
func NewTenantRepository(client *ent.Client) *TenantRepository {
	return &TenantRepository{client: client}
}

// Save persists a tenant to the database.
func (r *TenantRepository) Save(ctx context.Context, t *domain.Tenant) error {
	tenantType := tenant.Type(t.Type.String())
	_, err := r.client.Tenant.Create().
		SetID(t.ID).
		SetType(tenantType).
		SetName(t.Name).
		SetCreatedAt(t.CreatedAt).
		SetUpdatedAt(t.UpdatedAt).
		SetPreferredCurrency(t.PreferredCurrency).
		SetRateSyncIntervalHours(t.RateSyncIntervalHours).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save tenant: %w", err)
	}
	return nil
}

// FindByID retrieves a tenant by its ID.
func (r *TenantRepository) FindByID(ctx context.Context, id uuid.UUID) (*domain.Tenant, error) {
	result, err := r.client.Tenant.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find tenant by id: %w", err)
	}
	return toDomainTenant(result), nil
}

// FindAllIDs returns the IDs of every tenant. Used by the startup preset
// seeder to backfill system categories for legacy tenants.
func (r *TenantRepository) FindAllIDs(ctx context.Context) ([]uuid.UUID, error) {
	tenants, err := r.client.Tenant.Query().All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query all tenants: %w", err)
	}
	ids := make([]uuid.UUID, 0, len(tenants))
	for _, t := range tenants {
		ids = append(ids, t.ID)
	}
	return ids, nil
}

// FindAllIntervalHours returns the rate_sync_interval_hours of every tenant.
// The scheduler uses this to pick the minimum interval for exchange-rate sync.
func (r *TenantRepository) FindAllIntervalHours(ctx context.Context) ([]int, error) {
	hours, err := r.client.Tenant.Query().
		Select(tenant.FieldRateSyncIntervalHours).
		Ints(ctx)
	if err != nil {
		return nil, fmt.Errorf("query all tenant interval hours: %w", err)
	}
	return hours, nil
}

func toDomainTenant(t *ent.Tenant) *domain.Tenant {
	return &domain.Tenant{
		ID:                    t.ID,
		Type:                  domain.ParseTenantType(string(t.Type)),
		Name:                  t.Name,
		CreatedAt:             t.CreatedAt,
		UpdatedAt:             t.UpdatedAt,
		PreferredCurrency:     t.PreferredCurrency,
		RateSyncIntervalHours: t.RateSyncIntervalHours,
	}
}

// Compile-time check.
var _ domain.TenantRepository = (*TenantRepository)(nil)
