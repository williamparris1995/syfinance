package domain

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

type BackupProvider int

const (
	// BackupProviderLocal is the only backup provider after cloud-backup removal
	// (2026-07-25). The typed const is kept (rather than collapsing to iota) so
	// the BackupProvider enum, CloudProvider map key, and proto mapping remain
	// extensible if a remote provider is ever re-added.
	BackupProviderLocal BackupProvider = iota + 1
)

func (p BackupProvider) String() string {
	switch p {
	case BackupProviderLocal:
		return "local"
	default:
		return "unknown"
	}
}

func ParseBackupProvider(s string) BackupProvider {
	switch s {
	case "local":
		return BackupProviderLocal
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
