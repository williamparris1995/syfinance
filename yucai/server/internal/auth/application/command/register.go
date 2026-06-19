package command

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/domain"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/internal/auth/infrastructure/password"
	"github.com/yucai/server/internal/shared/application/command"
)

// PresetSeeder seeds per-tenant preset data (e.g. the 10 system categories)
// right after a tenant is created. Implemented by the account module's Service
// via an adapter in wire, to keep auth from importing account directly
// (preserving module boundaries: auth -> port, account -> adapter).
type PresetSeeder interface {
	SeedTenantPresets(ctx context.Context, tenantID uuid.UUID) error
}

// noopPresetSeeder is the default when no seeder is wired (e.g. unit tests).
type noopPresetSeeder struct{}

func (noopPresetSeeder) SeedTenantPresets(_ context.Context, _ uuid.UUID) error { return nil }

// RegisterHandler handles user registration.
type RegisterHandler struct {
	tenantRepo   domain.TenantRepository
	userRepo     domain.UserRepository
	tokenService *authjwt.TokenService
	seeder       PresetSeeder
}

// NewRegisterHandler creates a new RegisterHandler. seeder may be nil (defaults
// to a no-op seeder).
func NewRegisterHandler(
	tenantRepo domain.TenantRepository,
	userRepo domain.UserRepository,
	tokenService *authjwt.TokenService,
	seeder PresetSeeder,
) *RegisterHandler {
	if seeder == nil {
		seeder = noopPresetSeeder{}
	}
	return &RegisterHandler{
		tenantRepo:   tenantRepo,
		userRepo:     userRepo,
		tokenService: tokenService,
		seeder:       seeder,
	}
}

// Handle implements command.Handler[RegisterCommand].
func (h *RegisterHandler) Handle(ctx context.Context, cmd RegisterCommand) error {
	// Global email-uniqueness check FIRST. Email is the login key, so it must be
	// unique across ALL tenants (not just the new one — a new tenant is always
	// empty, so a per-tenant check would never block a re-registration).
	if existing, _ := h.userRepo.FindByEmailGlobal(ctx, cmd.Email); existing != nil {
		return fmt.Errorf("email already registered")
	}

	// Hash password
	hash, err := password.HashPassword(cmd.Password)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}

	// Create tenant (personal by default)
	tenant, err := domain.NewTenant(cmd.DisplayName+"'s Finances", domain.TenantTypePersonal)
	if err != nil {
		return fmt.Errorf("create tenant: %w", err)
	}
	if err := h.tenantRepo.Save(ctx, tenant); err != nil {
		return fmt.Errorf("save tenant: %w", err)
	}

	// Seed per-tenant presets (system categories) before creating the user so a
	// failed seed aborts registration cleanly. SeedPresetCategories is idempotent,
	// so a client retry after a transient failure will not double-create.
	if err := h.seeder.SeedTenantPresets(ctx, tenant.ID); err != nil {
		return fmt.Errorf("seed tenant presets (tenant %s created): %w", tenant.ID, err)
	}

	// Create user
	user, err := domain.NewUser(tenant.ID, cmd.Email, hash, cmd.DisplayName)
	if err != nil {
		return fmt.Errorf("create user: %w", err)
	}

	if err := h.userRepo.Save(ctx, user); err != nil {
		return fmt.Errorf("save user: %w", err)
	}

	return nil
}

// Compile-time interface check.
var _ command.Handler[RegisterCommand] = (*RegisterHandler)(nil)
