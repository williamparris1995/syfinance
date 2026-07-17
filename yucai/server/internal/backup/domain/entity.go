package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

type BackupProvider int

const (
	BackupProviderLocal BackupProvider = iota + 1
	BackupProviderWebDAV
	BackupProviderDropbox
	BackupProviderGoogleDrive
	BackupProviderOneDrive
)

func (p BackupProvider) String() string {
	switch p {
	case BackupProviderLocal:
		return "local"
	case BackupProviderWebDAV:
		return "webdav"
	case BackupProviderDropbox:
		return "dropbox"
	case BackupProviderGoogleDrive:
		return "google_drive"
	case BackupProviderOneDrive:
		return "one_drive"
	default:
		return "unknown"
	}
}

func ParseBackupProvider(s string) BackupProvider {
	switch s {
	case "local":
		return BackupProviderLocal
	case "webdav":
		return BackupProviderWebDAV
	case "dropbox":
		return BackupProviderDropbox
	case "google_drive":
		return BackupProviderGoogleDrive
	case "one_drive":
		return BackupProviderOneDrive
	default:
		return 0
	}
}

type Backup struct {
	ID         uuid.UUID
	TenantID   uuid.UUID
	Provider   BackupProvider
	Filename   string
	SizeBytes  int64
	Checksum   string
	Encrypted  bool
	Auto       bool
	Version    int64
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

func NewBackup(tenantID uuid.UUID, provider BackupProvider, encrypted bool, auto bool) (*Backup, error) {
	if provider == 0 {
		return nil, fmt.Errorf("provider must be specified")
	}
	now := time.Now()
	suffix := ".json.gz"
	if encrypted {
		suffix = ".enc"
	}
	return &Backup{
		ID:        uuid.New(),
		TenantID:  tenantID,
		Provider:  provider,
		Filename:  fmt.Sprintf("backup_%s_%s%s", now.Format("20060102_150405"), uuid.New().String()[:8], suffix),
		Encrypted: encrypted,
		Auto:      auto,
		Version:   1,
		CreatedAt: now,
		UpdatedAt: now,
	}, nil
}
