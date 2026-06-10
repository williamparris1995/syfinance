package query

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/shared/application/query"
)

// GetProfileQuery retrieves the current user's profile.
type GetProfileQuery struct {
	UserID   uuid.UUID
	TenantID uuid.UUID
}

// GetProfileResult holds the result of a profile query.
type GetProfileResult struct {
	User *domain.User
}

// GetProfileHandler handles profile queries.
type GetProfileHandler struct {
	userRepo domain.UserRepository
}

// NewGetProfileHandler creates a new GetProfileHandler.
func NewGetProfileHandler(userRepo domain.UserRepository) *GetProfileHandler {
	return &GetProfileHandler{userRepo: userRepo}
}

// Handle implements query.Handler[GetProfileQuery, GetProfileResult].
func (h *GetProfileHandler) Handle(ctx context.Context, q GetProfileQuery) (GetProfileResult, error) {
	user, err := h.userRepo.FindByID(ctx, q.UserID)
	if err != nil {
		return GetProfileResult{}, fmt.Errorf("user not found: %w", err)
	}
	if user.TenantID != q.TenantID {
		return GetProfileResult{}, fmt.Errorf("tenant mismatch: access denied")
	}
	return GetProfileResult{User: user}, nil
}

// Compile-time interface check.
var _ query.Handler[GetProfileQuery, GetProfileResult] = (*GetProfileHandler)(nil)
