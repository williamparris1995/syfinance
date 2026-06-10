package domain

// TenantType represents the type of tenant.
type TenantType int

const (
	TenantTypePersonal TenantType = iota + 1
	TenantTypeFamily
)

func (t TenantType) String() string {
	switch t {
	case TenantTypePersonal:
		return "personal"
	case TenantTypeFamily:
		return "family"
	default:
		return "unknown"
	}
}

// ParseTenantType converts a string to TenantType.
func ParseTenantType(s string) TenantType {
	switch s {
	case "personal":
		return TenantTypePersonal
	case "family":
		return TenantTypeFamily
	default:
		return TenantTypePersonal
	}
}

// FamilyRole represents a user's role within a family tenant.
type FamilyRole int

const (
	FamilyRoleOwner FamilyRole = iota + 1
	FamilyRoleAdmin
	FamilyRoleMember
)

func (r FamilyRole) String() string {
	switch r {
	case FamilyRoleOwner:
		return "owner"
	case FamilyRoleAdmin:
		return "admin"
	case FamilyRoleMember:
		return "member"
	default:
		return "unknown"
	}
}

// ParseFamilyRole converts a string to FamilyRole.
func ParseFamilyRole(s string) FamilyRole {
	switch s {
	case "owner":
		return FamilyRoleOwner
	case "admin":
		return FamilyRoleAdmin
	case "member":
		return FamilyRoleMember
	default:
		return FamilyRoleOwner
	}
}
