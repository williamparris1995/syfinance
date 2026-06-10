package application

import "github.com/google/uuid"

// RegisterRequest holds the input for user registration.
type RegisterRequest struct {
	Email       string
	Password    string
	DisplayName string
}

// LoginRequest holds the input for user login.
type LoginRequest struct {
	Email    string
	Password string
}

// RefreshRequest holds the input for token refresh.
type RefreshRequest struct {
	RefreshToken string
}

// UpdateProfileRequest holds the input for profile update.
type UpdateProfileRequest struct {
	UserID      uuid.UUID
	TenantID    uuid.UUID
	DisplayName string
	AvatarURL   string
}

// AuthResponse is returned after successful authentication.
type AuthResponse struct {
	AccessToken  string
	RefreshToken string
	User         UserDTO
}

// UserDTO is the user data transfer object.
type UserDTO struct {
	ID          uuid.UUID
	TenantID    uuid.UUID
	Email       string
	DisplayName string
	AvatarURL   string
	CreatedAt   string
}
