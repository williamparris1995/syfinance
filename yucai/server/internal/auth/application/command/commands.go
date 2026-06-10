package command

import "github.com/google/uuid"

// RegisterCommand creates a new user account.
type RegisterCommand struct {
	Email       string
	Password    string
	DisplayName string
}

// LoginCommand authenticates an existing user.
type LoginCommand struct {
	Email    string
	Password string
}

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
