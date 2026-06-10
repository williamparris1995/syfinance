package command

import (
	"context"
	"fmt"

	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/shared/application/command"
)

// UpdateProfileHandler updates user profile fields.
type UpdateProfileHandler struct {
	userRepo domain.UserRepository
}

// NewUpdateProfileHandler creates a new UpdateProfileHandler.
func NewUpdateProfileHandler(userRepo domain.UserRepository) *UpdateProfileHandler {
	return &UpdateProfileHandler{userRepo: userRepo}
}

// Handle implements command.Handler[UpdateProfileCommand].
func (h *UpdateProfileHandler) Handle(ctx context.Context, cmd UpdateProfileCommand) error {
	user, err := h.userRepo.FindByID(ctx, cmd.UserID)
	if err != nil {
		return fmt.Errorf("user not found: %w", err)
	}
	if user.TenantID != cmd.TenantID {
		return fmt.Errorf("tenant mismatch: access denied")
	}
	user.UpdateProfile(cmd.DisplayName, cmd.AvatarURL)
	if err := h.userRepo.Update(ctx, user); err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	return nil
}

// Compile-time interface check.
var _ command.Handler[UpdateProfileCommand] = (*UpdateProfileHandler)(nil)
