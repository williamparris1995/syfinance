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
	// PreferredCurrency mirrors the tenant's preferred display currency so the
	// client can render the correct symbol on first paint without a second RPC.
	PreferredCurrency string
}

// TenantPreferencesDTO carries the tenant-level display currency and rate-sync
// interval.
type TenantPreferencesDTO struct {
	PreferredCurrency    string
	RateSyncIntervalHours int32
}

// UpdatePreferencesRequest holds the input for tenant preference updates.
type UpdatePreferencesRequest struct {
	TenantID          uuid.UUID
	PreferredCurrency string
	IntervalHours     int
}
