package domain

import (
	"context"

	"github.com/google/uuid"
)

// TenantRepository defines the port for Tenant persistence.
type TenantRepository interface {
	Save(ctx context.Context, tenant *Tenant) error
	FindByID(ctx context.Context, id uuid.UUID) (*Tenant, error)
	// Update persists changes to an existing tenant's mutable fields
	// (preferred_currency, rate_sync_interval_hours, updated_at). Used by
	// UpdatePreferences.
	Update(ctx context.Context, tenant *Tenant) error
	// FindAllIDs returns the IDs of all tenants. Used by the startup preset
	// seeder to backfill system categories for tenants created before the
	// seeder was wired into registration.
	FindAllIDs(ctx context.Context) ([]uuid.UUID, error)
	// FindAllIntervalHours returns the rate_sync_interval_hours value of every
	// tenant. The scheduler uses this to pick the minimum interval at which to
	// run exchange-rate sync.
	FindAllIntervalHours(ctx context.Context) ([]int, error)
}

// CurrencyCodeChecker is a cross-module port (defined in auth to avoid auth
// importing currency) that reports whether an ISO 4217 code exists in the
// currency catalog. The currency module supplies the concrete adapter in wire.
type CurrencyCodeChecker interface {
	FindByCode(ctx context.Context, code string) (bool, error)
}

// UserRepository defines the port for User persistence.
type UserRepository interface {
	Save(ctx context.Context, user *User) error
	FindByID(ctx context.Context, id uuid.UUID) (*User, error)
	// FindByProviderSubject looks up a user by an OIDC identity's
	// (provider, subject) pair. Used by the login flow to resolve an
	// incoming IDP token to a local user row. Returns an error
	// (wrapping ent's NotFound) when no identity matches.
	FindByProviderSubject(ctx context.Context, provider, subject string) (*User, error)
	Update(ctx context.Context, user *User) error
}

// IdentityRepository defines the port for UserIdentity persistence.
type IdentityRepository interface {
	Save(ctx context.Context, identity *UserIdentity) error
	// FindByProviderSubject returns the identity matching the given
	// (provider, subject) pair, or an error wrapping ent's NotFound.
	FindByProviderSubject(ctx context.Context, provider, subject string) (*UserIdentity, error)
}
