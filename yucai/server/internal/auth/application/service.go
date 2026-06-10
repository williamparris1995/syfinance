package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/application/command"
	"github.com/yucai/server/internal/auth/application/query"
	"github.com/yucai/server/internal/auth/domain"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
)

// Service orchestrates authentication operations.
// It provides convenience methods that coordinate domain logic, CQRS handlers, and infrastructure.
type Service struct {
	tenantRepo      domain.TenantRepository
	userRepo        domain.UserRepository
	tokenService    *authjwt.TokenService
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
	registerHandler *command.RegisterHandler,
	loginHandler *command.LoginHandler,
	refreshHandler *command.RefreshHandler,
	profileHandler *query.GetProfileHandler,
) *Service {
	return &Service{
		tenantRepo:      tenantRepo,
		userRepo:        userRepo,
		tokenService:    tokenService,
		registerHandler: registerHandler,
		loginHandler:    loginHandler,
		refreshHandler:  refreshHandler,
		profileHandler:  profileHandler,
	}
}

// Register creates a new tenant and user, returns auth tokens.
func (s *Service) Register(ctx context.Context, req RegisterRequest) (*AuthResponse, error) {
	// Delegate to register handler for domain logic
	cmd := command.RegisterCommand{
		Email:       req.Email,
		Password:    req.Password,
		DisplayName: req.DisplayName,
	}
	if err := s.registerHandler.Handle(ctx, cmd); err != nil {
		return nil, fmt.Errorf("register: %w", err)
	}

	// Find the newly created user to generate tokens
	user, err := s.userRepo.FindByEmailGlobal(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("find user after registration: %w", err)
	}

	// Generate tokens
	accessToken, err := s.tokenService.GenerateAccessToken(user.ID, user.TenantID)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}
	refreshToken := s.tokenService.GenerateRefreshToken()

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

	accessToken, err := s.tokenService.GenerateAccessToken(user.ID, user.TenantID)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}
	refreshToken := s.tokenService.GenerateRefreshToken()

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         UserToDTO(user),
	}, nil
}

// RefreshToken validates a refresh token and returns new tokens.
func (s *Service) RefreshToken(ctx context.Context, userID uuid.UUID, refreshToken string) (*AuthResponse, error) {
	user, err := s.refreshHandler.ValidateRefreshToken(ctx, userID, refreshToken)
	if err != nil {
		return nil, err
	}

	accessToken, err := s.tokenService.GenerateAccessToken(user.ID, user.TenantID)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}
	newRefreshToken := s.tokenService.GenerateRefreshToken()

	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefreshToken,
		User:         UserToDTO(user),
	}, nil
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
		return nil, fmt.Errorf("tenant mismatch: access denied")
	}
	user.UpdateProfile(req.DisplayName, req.AvatarURL)
	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("update user: %w", err)
	}
	dto := UserToDTO(user)
	return &dto, nil
}
