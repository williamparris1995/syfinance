package application

import "github.com/yucai/server/internal/auth/domain"

// UserToDTO converts a domain User to a UserDTO.
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
