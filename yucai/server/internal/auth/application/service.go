package application

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/auth/application/command"
	"github.com/yucai/server/internal/auth/application/query"
	"github.com/yucai/server/internal/auth/domain"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
)

// Service orchestrates authentication operations following the industry-standard
// access/refresh token model (RFC 6749 / RFC 6750):
//   - Access token: short-lived JWT, self-validating via signature.
//   - Refresh token: opaque, server-stored, rotated on each refresh with reuse detection.
type Service struct {
	tenantRepo      domain.TenantRepository
	userRepo        domain.UserRepository
	tokenService    *authjwt.TokenService
	sessionStore    command.SessionStore
	registerHandler *command.RegisterHandler
	loginHandler    *command.LoginHandler
	refreshHandler  *command.RefreshHandler
	profileHandler  *query.GetProfileHandler
}

// NewService creates a new auth application service.
func NewService(
	tenantRepo domain.TenantRepository,
	userRepo domain.UserRepository,
	tokenService *authjwt.TokenService,
	sessionStore command.SessionStore,
	registerHandler *command.RegisterHandler,
	loginHandler *command.LoginHandler,
	refreshHandler *command.RefreshHandler,
	profileHandler *query.GetProfileHandler,
) *Service {
	return &Service{
		tenantRepo:      tenantRepo,
		userRepo:        userRepo,
		tokenService:    tokenService,
		sessionStore:    sessionStore,
		registerHandler: registerHandler,
		loginHandler:    loginHandler,
		refreshHandler:  refreshHandler,
		profileHandler:  profileHandler,
	}
}

// issueSession issues an access JWT + opens a refresh-token session for the user.
func (s *Service) issueSession(ctx context.Context, user *domain.User) (accessToken, refreshToken string, err error) {
	accessToken, err = s.tokenService.GenerateAccessToken(user.ID, user.TenantID)
	if err != nil {
		return "", "", fmt.Errorf("generate access token: %w", err)
	}
	refreshToken = s.tokenService.GenerateRefreshToken()
	familyID := uuid.NewString()
	if err := s.sessionStore.Create(ctx, refreshToken, familyID, user.ID.String(), user.TenantID.String(), s.tokenService.RefreshTokenTTL()); err != nil {
		return "", "", fmt.Errorf("create session: %w", err)
	}
	return accessToken, refreshToken, nil
}

// Register creates a new tenant and user, returns auth tokens.
func (s *Service) Register(ctx context.Context, req RegisterRequest) (*AuthResponse, error) {
	cmd := command.RegisterCommand{
		Email:       req.Email,
		Password:    req.Password,
		DisplayName: req.DisplayName,
	}
	if err := s.registerHandler.Handle(ctx, cmd); err != nil {
		return nil, fmt.Errorf("register: %w", err)
	}

	user, err := s.userRepo.FindByEmailGlobal(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("find user after registration: %w", err)
	}

	accessToken, refreshToken, err := s.issueSession(ctx, user)
	if err != nil {
		return nil, err
	}
	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         UserToDTO(user),
	}, nil
}

// Login authenticates a user and returns auth tokens.
func (s *Service) Login(ctx context.Context, req LoginRequest) (*AuthResponse, error) {
	user, err := s.loginHandler.Authenticate(ctx, req.Email, req.Password)
	if err != nil {
		return nil, err
	}

	accessToken, refreshToken, err := s.issueSession(ctx, user)
	if err != nil {
		return nil, err
	}
	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         UserToDTO(user),
	}, nil
}

// RefreshToken rotates a refresh token and returns a fresh token pair.
// The user identity is resolved from the opaque refresh token itself (via the
// session store), so no client-supplied user identifier is required.
//
// Returns command.ErrInvalidRefreshToken (unknown/expired) or
// command.ErrRefreshTokenReuse (replayed rotated token — family revoked).
func (s *Service) RefreshToken(ctx context.Context, refreshToken string) (*AuthResponse, error) {
	newRefresh := s.tokenService.GenerateRefreshToken()
	userIDStr, tenantIDStr, err := s.refreshHandler.Rotate(ctx, refreshToken, newRefresh, s.tokenService.RefreshTokenTTL())
	if err != nil {
		return nil, err
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, fmt.Errorf("parse user id from session: %w", err)
	}
	tenantID, err := uuid.Parse(tenantIDStr)
	if err != nil {
		return nil, fmt.Errorf("parse tenant id from session: %w", err)
	}

	accessToken, err := s.tokenService.GenerateAccessToken(userID, tenantID)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}
	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefresh,
	}, nil
}

// Logout revokes the refresh-token session. The short-lived access JWT expires
// on its own (standard tradeoff: no server-side access-token blacklist).
func (s *Service) Logout(ctx context.Context, refreshToken string) error {
	if err := s.refreshHandler.Revoke(ctx, refreshToken); err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	return nil
}

// GetProfile returns the user's profile.
func (s *Service) GetProfile(ctx context.Context, userID, tenantID uuid.UUID) (*UserDTO, error) {
	q := query.GetProfileQuery{UserID: userID, TenantID: tenantID}
	result, err := s.profileHandler.Handle(ctx, q)
	if err != nil {
		return nil, err
	}
	dto := UserToDTO(result.User)
	return &dto, nil
}

// UpdateProfile updates the user's profile and returns the updated DTO.
func (s *Service) UpdateProfile(ctx context.Context, req UpdateProfileRequest) (*UserDTO, error) {
	user, err := s.userRepo.FindByID(ctx, req.UserID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	if user.TenantID != req.TenantID {
		return nil, errors.New("tenant mismatch: access denied")
	}
	user.UpdateProfile(req.DisplayName, req.AvatarURL)
	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("update user: %w", err)
	}
	dto := UserToDTO(user)
	return &dto, nil
}
