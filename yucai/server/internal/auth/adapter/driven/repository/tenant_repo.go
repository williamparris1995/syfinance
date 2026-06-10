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

func toDomainTenant(t *ent.Tenant) *domain.Tenant {
	return &domain.Tenant{
		ID:        t.ID,
		Type:      domain.ParseTenantType(string(t.Type)),
		Name:      t.Name,
		CreatedAt: t.CreatedAt,
		UpdatedAt: t.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.TenantRepository = (*TenantRepository)(nil)
