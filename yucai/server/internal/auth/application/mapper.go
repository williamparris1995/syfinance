package application

import "github.com/yucai/server/internal/auth/domain"

// UserToDTO converts a domain User to a UserDTO. PreferredCurrency is left
// empty because the User entity does not carry tenant-level settings; use
// UserToDTOWithCurrency when the tenant is available.
func UserToDTO(u *domain.User) UserDTO {
	return UserDTO{
		ID:          u.ID,
		TenantID:    u.TenantID,
		Email:       u.Email,
		DisplayName: u.DisplayName,
		AvatarURL:   u.AvatarURL,
		CreatedAt:   u.CreatedAt.Format("2006-01-02T15:04:05Z"),
	}
}

// UserToDTOWithCurrency is UserToDTO plus the tenant's preferred currency,
// letting the client render the correct currency symbol on first paint
// without a follow-up GetPreferences RPC.
func UserToDTOWithCurrency(u *domain.User, preferredCurrency string) UserDTO {
	dto := UserToDTO(u)
	dto.PreferredCurrency = preferredCurrency
	return dto
}
