package domain

import (
	"fmt"
	"net/mail"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Tenant represents a multi-tenancy isolation boundary.
type Tenant struct {
	ID                   uuid.UUID
	Type                 TenantType
	Name                 string
	CreatedAt            time.Time
	UpdatedAt            time.Time
	PreferredCurrency    string
	RateSyncIntervalHours int
}

// NewTenant creates a validated Tenant entity.
func NewTenant(name string, tenantType TenantType) (*Tenant, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("tenant name must not be empty")
	}
	return &Tenant{
		ID:                    uuid.New(),
		Type:                  tenantType,
		Name:                  name,
		CreatedAt:             time.Now(),
		UpdatedAt:             time.Now(),
		PreferredCurrency:     "CNY",
		RateSyncIntervalHours: 8,
	}, nil
}

// UpdatePreferences updates the tenant's preferred display currency and
// exchange-rate sync interval. preferredCurrency is trimmed and upper-cased
// and must be a non-empty ISO 4217 code; intervalHours must be in [1, 168].
func (t *Tenant) UpdatePreferences(preferredCurrency string, intervalHours int) error {
	currency := strings.ToUpper(strings.TrimSpace(preferredCurrency))
	if currency == "" {
		return fmt.Errorf("preferred_currency must not be empty")
	}
	if intervalHours < 1 || intervalHours > 168 {
		return fmt.Errorf("rate_sync_interval_hours must be between 1 and 168, got %d", intervalHours)
	}
	t.PreferredCurrency = currency
	t.RateSyncIntervalHours = intervalHours
	t.UpdatedAt = time.Now()
	return nil
}

// User represents an authenticated user within a tenant.
// Authentication is exclusively via OIDC identities (UserIdentity); the User
// row itself carries only profile state. Email may be empty when no OIDC
// identity has supplied a verified address yet.
type User struct {
	ID          uuid.UUID
	TenantID    uuid.UUID
	Email       string
	DisplayName string
	AvatarURL   string
	FamilyRole  FamilyRole
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// NewUser creates a validated User entity.
// email is optional (OIDC identity may not yet have supplied one); when
// non-empty it is normalized lowercase and format-checked.
func NewUser(tenantID uuid.UUID, email, displayName string) (*User, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	if email != "" {
		if _, err := mail.ParseAddress(email); err != nil {
			return nil, fmt.Errorf("invalid email format: %w", err)
		}
	}
	displayName = strings.TrimSpace(displayName)
	if displayName == "" {
		return nil, fmt.Errorf("display_name must not be empty")
	}
	return &User{
		ID:          uuid.New(),
		TenantID:    tenantID,
		Email:       email,
		DisplayName: displayName,
		FamilyRole:  FamilyRoleOwner,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}, nil
}

// UserIdentity binds an external OIDC identity (provider+subject) to a User.
// One User may have multiple identities (one per provider). Login lookup is
// by (provider, subject) which is globally unique.
type UserIdentity struct {
	ID              uuid.UUID
	TenantID        uuid.UUID
	UserID          uuid.UUID
	Provider        string
	Subject         string
	Issuer          string
	EmailAtProvider string
	CreatedAt       time.Time
	UpdatedAt       time.Time
}

// NewUserIdentity creates a validated UserIdentity entity.
// provider and subject must be non-empty (they are the login key); issuer and
// emailAtProvider are optional metadata trimmed of surrounding whitespace.
func NewUserIdentity(tenantID, userID uuid.UUID, provider, subject, issuer, emailAtProvider string) (*UserIdentity, error) {
	provider = strings.TrimSpace(provider)
	subject = strings.TrimSpace(subject)
	if provider == "" || subject == "" {
		return nil, fmt.Errorf("provider and subject must not be empty")
	}
	return &UserIdentity{
		ID:              uuid.New(),
		TenantID:        tenantID,
		UserID:          userID,
		Provider:        provider,
		Subject:         subject,
		Issuer:          strings.TrimSpace(issuer),
		EmailAtProvider: strings.TrimSpace(emailAtProvider),
		CreatedAt:       time.Now(),
		UpdatedAt:       time.Now(),
	}, nil
}

// UpdateProfile updates mutable profile fields.
func (u *User) UpdateProfile(displayName, avatarURL string) {
	if displayName = strings.TrimSpace(displayName); displayName != "" {
		u.DisplayName = displayName
	}
	u.AvatarURL = avatarURL
	u.UpdatedAt = time.Now()
}
