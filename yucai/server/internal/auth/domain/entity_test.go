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
	validHash := "$2a$10$somehash"

	tests := []struct {
		name        string
		email       string
		passHash    string
		displayName string
		wantErr     bool
	}{
		{"valid user", "test@example.com", validHash, "Alice", false},
		{"empty email", "", validHash, "Alice", true},
		{"invalid email", "not-an-email", validHash, "Alice", true},
		{"empty display name", "test@example.com", validHash, "", true},
		{"whitespace display name", "test@example.com", validHash, "   ", true},
		{"empty password hash", "test@example.com", "", "Alice", true},
		{"email normalized to lowercase", "Test@Example.COM", validHash, "Alice", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := NewUser(tenantID, tt.email, tt.passHash, tt.displayName)
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

func TestUserUpdateProfile(t *testing.T) {
	u, _ := NewUser(uuid.New(), "test@example.com", "hash", "Alice")
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
