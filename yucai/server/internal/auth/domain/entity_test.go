package domain

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestNewTenant(t *testing.T) {
	tests := []struct {
		name    string
		inName  string
		inType  TenantType
		wantErr bool
	}{
		{"valid personal", "My Finances", TenantTypePersonal, false},
		{"valid family", "Lee Family", TenantTypeFamily, false},
		{"empty name", "", TenantTypePersonal, true},
		{"whitespace name", "   ", TenantTypePersonal, true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := NewTenant(tt.inName, tt.inType)
			if (err != nil) != tt.wantErr {
				t.Errorf("NewTenant() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr {
				if got.Name != tt.inName {
					t.Errorf("expected name %q, got %q", tt.inName, got.Name)
				}
				if got.ID == uuid.Nil {
					t.Error("expected non-nil UUID")
				}
			}
		})
	}
}

func TestNewUser(t *testing.T) {
	tenantID := uuid.New()

	tests := []struct {
		name        string
		email       string
		displayName string
		wantErr     bool
	}{
		{"valid user with email", "test@example.com", "Alice", false},
		{"valid user without email (OIDC no verified email yet)", "", "Alice", false},
		{"invalid email", "not-an-email", "Alice", true},
		{"empty display name", "test@example.com", "", true},
		{"whitespace display name", "test@example.com", "   ", true},
		{"email normalized to lowercase", "Test@Example.COM", "Alice", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := NewUser(tenantID, tt.email, tt.displayName)
			if (err != nil) != tt.wantErr {
				t.Errorf("NewUser() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr {
				if got.TenantID != tenantID {
					t.Error("tenant ID mismatch")
				}
				if got.FamilyRole != FamilyRoleOwner {
					t.Error("default role should be owner")
				}
			}
		})
	}
}

func TestNewUserIdentity(t *testing.T) {
	tenantID := uuid.New()
	userID := uuid.New()

	tests := []struct {
		name            string
		provider        string
		subject         string
		issuer          string
		emailAtProvider string
		wantErr         bool
	}{
		{"valid identity", "google", "sub-123", "https://accounts.google.com", "u@example.com", false},
		{"valid identity without optional fields", "github", "sub-456", "", "", false},
		{"empty provider", "", "sub-123", "", "", true},
		{"empty subject", "google", "", "", "", true},
		{"whitespace provider", "  ", "sub", "", "", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := NewUserIdentity(tenantID, userID, tt.provider, tt.subject, tt.issuer, tt.emailAtProvider)
			if (err != nil) != tt.wantErr {
				t.Errorf("NewUserIdentity() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr {
				if got.TenantID != tenantID || got.UserID != userID {
					t.Error("tenant/user ID mismatch")
				}
			}
		})
	}
}

func TestUserUpdateProfile(t *testing.T) {
	u, _ := NewUser(uuid.New(), "test@example.com", "Alice")
	u.UpdatedAt = time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC) // freeze to ensure difference
	u.UpdateProfile("Bob", "https://avatar.url")
	if u.DisplayName != "Bob" {
		t.Errorf("expected Bob, got %s", u.DisplayName)
	}
	if u.AvatarURL != "https://avatar.url" {
		t.Errorf("expected avatar URL, got %s", u.AvatarURL)
	}
	if !u.UpdatedAt.After(time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC)) {
		t.Error("UpdatedAt should be updated")
	}
}

func TestTenantTypeString(t *testing.T) {
	if TenantTypePersonal.String() != "personal" {
		t.Errorf("expected personal, got %s", TenantTypePersonal.String())
	}
	if TenantTypeFamily.String() != "family" {
		t.Errorf("expected family, got %s", TenantTypeFamily.String())
	}
	if ParseTenantType("family") != TenantTypeFamily {
		t.Error("ParseTenantType should return family")
	}
}

func TestFamilyRoleString(t *testing.T) {
	if FamilyRoleOwner.String() != "owner" {
		t.Errorf("expected owner, got %s", FamilyRoleOwner.String())
	}
	if ParseFamilyRole("admin") != FamilyRoleAdmin {
		t.Error("ParseFamilyRole should return admin")
	}
}
