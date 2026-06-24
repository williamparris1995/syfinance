package domain

import (
	"context"

	"github.com/google/uuid"
)

// TenantRepository defines the port for Tenant persistence.
type TenantRepository interface {
	Save(ctx context.Context, tenant *Tenant) error
	FindByID(ctx context.Context, id uuid.UUID) (*Tenant, error)
	// FindAllIDs returns the IDs of all tenants. Used by the startup preset
	// seeder to backfill system categories for tenants created before the
	// seeder was wired into registration.
	FindAllIDs(ctx context.Context) ([]uuid.UUID, error)
	// FindAllIntervalHours returns the rate_sync_interval_hours value of every
	// tenant. The scheduler uses this to pick the minimum interval at which to
	// run exchange-rate sync.
	FindAllIntervalHours(ctx context.Context) ([]int, error)
}

// UserRepository defines the port for User persistence.
type UserRepository interface {
	Save(ctx context.Context, user *User) error
	FindByID(ctx context.Context, id uuid.UUID) (*User, error)
	// FindByEmail finds a user by email within a specific tenant.
	FindByEmail(ctx context.Context, tenantID uuid.UUID, email string) (*User, error)
	// FindByEmailGlobal finds a user by email across all tenants (for login).
	FindByEmailGlobal(ctx context.Context, email string) (*User, error)
	Update(ctx context.Context, user *User) error
}
