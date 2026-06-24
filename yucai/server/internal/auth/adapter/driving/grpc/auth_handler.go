package grpc

import (
	"context"
	"errors"
	"fmt"

	pb "github.com/yucai/server/internal/proto/auth/v1"
	"github.com/yucai/server/internal/auth/application"
	"github.com/yucai/server/internal/auth/application/command"
	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// AuthHandler implements the generated AuthServiceServer interface.
type AuthHandler struct {
	pb.UnimplementedAuthServiceServer
	service *application.Service
}

// NewAuthHandler creates a new AuthHandler.
func NewAuthHandler(service *application.Service) *AuthHandler {
	return &AuthHandler{service: service}
}

// Register handles user registration.
func (h *AuthHandler) Register(ctx context.Context, req *pb.RegisterRequest) (*pb.RegisterResponse, error) {
	if req.Email == "" || req.Password == "" || req.DisplayName == "" {
		return nil, status.Error(codes.InvalidArgument, "email, password, and display_name are required")
	}
	resp, err := h.service.Register(ctx, application.RegisterRequest{
		Email:       req.Email,
		Password:    req.Password,
		DisplayName: req.DisplayName,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.RegisterResponse{
		AccessToken:  resp.AccessToken,
		RefreshToken: resp.RefreshToken,
		User:         dtoToProto(resp.User),
	}, nil
}

// Login handles user login.
func (h *AuthHandler) Login(ctx context.Context, req *pb.LoginRequest) (*pb.LoginResponse, error) {
	if req.Email == "" || req.Password == "" {
		return nil, status.Error(codes.InvalidArgument, "email and password are required")
	}
	resp, err := h.service.Login(ctx, application.LoginRequest{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.LoginResponse{
		AccessToken:  resp.AccessToken,
		RefreshToken: resp.RefreshToken,
		User:         dtoToProto(resp.User),
	}, nil
}

// RefreshToken rotates a refresh token. The user identity is resolved from the
// opaque refresh token server-side, so this RPC is auth-bypassed (no Bearer).
func (h *AuthHandler) RefreshToken(ctx context.Context, req *pb.RefreshTokenRequest) (*pb.RefreshTokenResponse, error) {
	if req.RefreshToken == "" {
		return nil, status.Error(codes.InvalidArgument, "refresh_token is required")
	}
	resp, err := h.service.RefreshToken(ctx, req.RefreshToken)
	if err != nil {
		// Invalid/expired or reuse-detected → 401 (forces client re-login).
		if errors.Is(err, command.ErrInvalidRefreshToken) || errors.Is(err, command.ErrRefreshTokenReuse) {
			return nil, status.Error(codes.Unauthenticated, err.Error())
		}
		return nil, mapError(err)
	}
	return &pb.RefreshTokenResponse{
		AccessToken:  resp.AccessToken,
		RefreshToken: resp.RefreshToken,
	}, nil
}

// GetProfile returns the authenticated user's profile.
func (h *AuthHandler) GetProfile(ctx context.Context, req *pb.GetProfileRequest) (*pb.GetProfileResponse, error) {
	userID, tenantID, err := GetUserAndTenantIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	dto, err := h.service.GetProfile(ctx, userID, tenantID)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.GetProfileResponse{User: dtoToProto(*dto)}, nil
}

// UpdateProfile updates the authenticated user's profile.
func (h *AuthHandler) UpdateProfile(ctx context.Context, req *pb.UpdateProfileRequest) (*pb.UpdateProfileResponse, error) {
	userID, tenantID, err := GetUserAndTenantIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	dto, err := h.service.UpdateProfile(ctx, application.UpdateProfileRequest{
		UserID:      userID,
		TenantID:    tenantID,
		DisplayName: req.DisplayName,
		AvatarURL:   req.AvatarUrl,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.UpdateProfileResponse{User: dtoToProto(*dto)}, nil
}

// GetPreferences returns the authenticated tenant's display currency and
// rate-sync interval.
func (h *AuthHandler) GetPreferences(ctx context.Context, req *pb.GetPreferencesRequest) (*pb.GetPreferencesResponse, error) {
	_, tenantID, err := GetUserAndTenantIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	dto, err := h.service.GetPreferences(ctx, tenantID)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.GetPreferencesResponse{Preferences: tenantPreferencesToProto(*dto)}, nil
}

// UpdatePreferences validates and persists the tenant's preferred display
// currency and rate-sync interval.
func (h *AuthHandler) UpdatePreferences(ctx context.Context, req *pb.UpdatePreferencesRequest) (*pb.UpdatePreferencesResponse, error) {
	_, tenantID, err := GetUserAndTenantIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	dto, err := h.service.UpdatePreferences(ctx, application.UpdatePreferencesRequest{
		TenantID:          tenantID,
		PreferredCurrency: req.PreferredCurrency,
		IntervalHours:     int(req.RateSyncIntervalHours),
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.UpdatePreferencesResponse{Preferences: tenantPreferencesToProto(*dto)}, nil
}

func dtoToProto(u application.UserDTO) *pb.UserDTO {
	return &pb.UserDTO{
		Id:                u.ID.String(),
		TenantId:          u.TenantID.String(),
		Email:             u.Email,
		DisplayName:       u.DisplayName,
		AvatarUrl:         u.AvatarURL,
		CreatedAt:         u.CreatedAt,
		PreferredCurrency: u.PreferredCurrency,
	}
}

func tenantPreferencesToProto(p application.TenantPreferencesDTO) *pb.TenantPreferencesDTO {
	return &pb.TenantPreferencesDTO{
		PreferredCurrency:     p.PreferredCurrency,
		RateSyncIntervalHours: p.RateSyncIntervalHours,
	}
}

func mapError(err error) error {
	msg := err.Error()
	switch {
	case contains(msg, "not found"):
		return status.Error(codes.NotFound, msg)
	case contains(msg, "invalid credentials"):
		return status.Error(codes.Unauthenticated, msg)
	case contains(msg, "already registered"), contains(msg, "already exists"):
		return status.Error(codes.AlreadyExists, msg)
	case contains(msg, "must not be empty"), contains(msg, "invalid email"),
		contains(msg, "must be between 1 and 168"), contains(msg, "invalid currency code"):
		return status.Error(codes.InvalidArgument, msg)
	default:
		return status.Error(codes.Internal, msg)
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && searchSubstring(s, substr)
}

func searchSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}

// contextKey is an unexported type for context keys defined in this package.
type contextKey string

const (
	userIDKey   contextKey = "user_id"
	tenantIDKey contextKey = "tenant_id"
)

// WithUserID adds the user ID to the context.
func WithUserID(ctx context.Context, userID uuid.UUID) context.Context {
	return context.WithValue(ctx, userIDKey, userID)
}

// WithTenantID adds the tenant ID to the context.
func WithTenantID(ctx context.Context, tenantID uuid.UUID) context.Context {
	return context.WithValue(ctx, tenantIDKey, tenantID)
}

func getUserID(ctx context.Context) (uuid.UUID, error) {
	return GetUserIDFromContext(ctx)
}

// GetUserIDFromContext extracts the user ID from the context (exported for middleware).
func GetUserIDFromContext(ctx context.Context) (uuid.UUID, error) {
	v := ctx.Value(userIDKey)
	if v == nil {
		return uuid.Nil, fmt.Errorf("user_id not found in context")
	}
	id, ok := v.(uuid.UUID)
	if !ok {
		return uuid.Nil, fmt.Errorf("invalid user_id in context")
	}
	return id, nil
}

// GetUserAndTenantIDFromContext extracts both user_id and tenant_id from context (exported for middleware).
func GetUserAndTenantIDFromContext(ctx context.Context) (uuid.UUID, uuid.UUID, error) {
	userID, err := getUserID(ctx)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	v := ctx.Value(tenantIDKey)
	if v == nil {
		return uuid.Nil, uuid.Nil, fmt.Errorf("tenant_id not found in context")
	}
	tenantID, ok := v.(uuid.UUID)
	if !ok {
		return uuid.Nil, uuid.Nil, fmt.Errorf("invalid tenant_id in context")
	}
	return userID, tenantID, nil
}
