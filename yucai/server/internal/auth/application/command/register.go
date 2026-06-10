package command

import (
	"context"
	"fmt"

	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/infrastructure/password"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/internal/shared/application/command"
)

// RegisterHandler handles user registration.
type RegisterHandler struct {
	tenantRepo   domain.TenantRepository
	userRepo     domain.UserRepository
	tokenService *authjwt.TokenService
}

// NewRegisterHandler creates a new RegisterHandler.
func NewRegisterHandler(
	tenantRepo domain.TenantRepository,
	userRepo domain.UserRepository,
	tokenService *authjwt.TokenService,
) *RegisterHandler {
	return &RegisterHandler{
		tenantRepo:   tenantRepo,
		userRepo:     userRepo,
		tokenService: tokenService,
	}
}

// Handle implements command.Handler[RegisterCommand].
func (h *RegisterHandler) Handle(ctx context.Context, cmd RegisterCommand) error {
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

	// Create user
	user, err := domain.NewUser(tenant.ID, cmd.Email, hash, cmd.DisplayName)
	if err != nil {
		return fmt.Errorf("create user: %w", err)
	}

	// Check email not taken
	existing, _ := h.userRepo.FindByEmail(ctx, tenant.ID, cmd.Email)
	if existing != nil {
		return fmt.Errorf("email already registered")
	}

	if err := h.userRepo.Save(ctx, user); err != nil {
		return fmt.Errorf("save user: %w", err)
	}

	return nil
}

// Compile-time interface check.
var _ command.Handler[RegisterCommand] = (*RegisterHandler)(nil)
