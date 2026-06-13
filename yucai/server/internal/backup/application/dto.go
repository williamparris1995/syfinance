package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
)

type BackupDTO struct {
	ID        uuid.UUID
	TenantID  uuid.UUID
	Provider  domain.BackupProvider
	Filename  string
	SizeBytes int64
	Checksum  string
	Encrypted bool
	Auto      bool
	Version   int64
	CreatedAt time.Time
}

type ListBackupsResult struct {
	Backups      []BackupDTO
	NextPageToken string
	TotalCount    int32
}

func BackupToDTO(b *domain.Backup) BackupDTO {
	return BackupDTO{
		ID: b.ID, TenantID: b.TenantID, Provider: b.Provider,
		Filename: b.Filename, SizeBytes: b.SizeBytes,
		Checksum: b.Checksum, Encrypted: b.Encrypted,
		Auto: b.Auto, Version: b.Version, CreatedAt: b.CreatedAt,
	}
}
