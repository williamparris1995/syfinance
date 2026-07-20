package command

import "github.com/google/uuid"

// RefreshCommand exchanges a refresh token for new tokens.
type RefreshCommand struct {
	RefreshToken string
	UserID       uuid.UUID
	TenantID     uuid.UUID
}

// UpdateProfileCommand updates user profile fields.
type UpdateProfileCommand struct {
	UserID      uuid.UUID
	TenantID    uuid.UUID
	DisplayName string
	AvatarURL   string
}
