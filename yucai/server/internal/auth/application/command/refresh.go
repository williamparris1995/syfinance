package command

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/domain"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/internal/shared/application/command"
)

// RefreshHandler validates and rotates refresh tokens.
type RefreshHandler struct {
	userRepo     domain.UserRepository
	tokenService *authjwt.TokenService
	sessionStore SessionStore
}

// SessionStore defines the interface for storing/validating refresh tokens.
type SessionStore interface {
	Store(ctx context.Context, userID string, refreshToken string, ttlSeconds int64) error
	Validate(ctx context.Context, userID string, refreshToken string) (bool, error)
	Delete(ctx context.Context, userID string) error
}

// NewRefreshHandler creates a new RefreshHandler.
func NewRefreshHandler(
	userRepo domain.UserRepository,
	tokenService *authjwt.TokenService,
	sessionStore SessionStore,
) *RefreshHandler {
	return &RefreshHandler{
		userRepo:     userRepo,
		tokenService: tokenService,
		sessionStore: sessionStore,
	}
}

// ValidateRefreshToken checks if the refresh token is valid and returns user info.
func (h *RefreshHandler) ValidateRefreshToken(ctx context.Context, userID uuid.UUID, refreshToken string) (*domain.User, error) {
	valid, err := h.sessionStore.Validate(ctx, userID.String(), refreshToken)
	if err != nil {
		return nil, fmt.Errorf("validate refresh token: %w", err)
	}
	if !valid {
		return nil, fmt.Errorf("invalid or expired refresh token")
	}
	user, err := h.userRepo.FindByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	return user, nil
}

// Handle implements command.Handler[RefreshCommand].
func (h *RefreshHandler) Handle(ctx context.Context, cmd RefreshCommand) error {
	return nil
}

// Compile-time interface check.
var _ command.Handler[RefreshCommand] = (*RefreshHandler)(nil)
