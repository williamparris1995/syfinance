package command

import (
	"context"
	"fmt"

	"github.com/yucai/server/internal/auth/domain"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/internal/auth/infrastructure/password"
	"github.com/yucai/server/internal/shared/application/command"
)

// LoginHandler validates credentials for login.
// Token generation is handled by AuthService since it needs return values.
type LoginHandler struct {
	userRepo     domain.UserRepository
	tokenService *authjwt.TokenService
}

// NewLoginHandler creates a new LoginHandler.
func NewLoginHandler(
	userRepo domain.UserRepository,
	tokenService *authjwt.TokenService,
) *LoginHandler {
	return &LoginHandler{
		userRepo:     userRepo,
		tokenService: tokenService,
	}
}

// Authenticate validates email/password and returns the authenticated user.
func (h *LoginHandler) Authenticate(ctx context.Context, email, passwordStr string) (*domain.User, error) {
	user, err := h.userRepo.FindByEmailGlobal(ctx, email)
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}
	if !password.CheckPassword(passwordStr, user.PasswordHash) {
		return nil, fmt.Errorf("invalid credentials")
	}
	return user, nil
}

// Handle implements command.Handler[LoginCommand] — a no-op since AuthService handles the flow.
func (h *LoginHandler) Handle(ctx context.Context, cmd LoginCommand) error {
	return nil
}

// Compile-time interface check.
var _ command.Handler[LoginCommand] = (*LoginHandler)(nil)
