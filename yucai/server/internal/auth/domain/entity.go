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
	ID        uuid.UUID
	Type      TenantType
	Name      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// NewTenant creates a validated Tenant entity.
func NewTenant(name string, tenantType TenantType) (*Tenant, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("tenant name must not be empty")
	}
	return &Tenant{
		ID:        uuid.New(),
		Type:      tenantType,
		Name:      name,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}, nil
}

// User represents an authenticated user within a tenant.
type User struct {
	ID            uuid.UUID
	TenantID      uuid.UUID
	Email         string
	PasswordHash  string
	DisplayName   string
	AvatarURL     string
	OAuthProvider string
	OAuthID       string
	FamilyRole    FamilyRole
	CreatedAt     time.Time
	UpdatedAt     time.Time
}

// NewUser creates a validated User entity.
// passwordHash should already be bcrypt-hashed before calling this.
func NewUser(tenantID uuid.UUID, email, passwordHash, displayName string) (*User, error) {
	email = strings.TrimSpace(strings.ToLower(email))
	if email == "" {
		return nil, fmt.Errorf("email must not be empty")
	}
	if _, err := mail.ParseAddress(email); err != nil {
		return nil, fmt.Errorf("invalid email format: %w", err)
	}
	displayName = strings.TrimSpace(displayName)
	if displayName == "" {
		return nil, fmt.Errorf("display_name must not be empty")
	}
	if passwordHash == "" {
		return nil, fmt.Errorf("password_hash must not be empty")
	}
	return &User{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Email:        email,
		PasswordHash: passwordHash,
		DisplayName:  displayName,
		FamilyRole:   FamilyRoleOwner,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
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
