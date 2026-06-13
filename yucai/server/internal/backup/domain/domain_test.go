package domain

import (
	"testing"

	"github.com/google/uuid"
)

func TestNewBackup_Valid(t *testing.T) {
	b, err := NewBackup(uuid.New(), BackupProviderLocal, false)
	if err != nil {
		t.Fatalf("NewBackup failed: %v", err)
	}
	if b.Provider != BackupProviderLocal {
		t.Error("expected local provider")
	}
	if b.Filename == "" {
		t.Error("expected auto-generated filename")
	}
}

func TestNewBackup_NoProvider(t *testing.T) {
	_, err := NewBackup(uuid.New(), BackupProvider(0), false)
	if err == nil {
		t.Error("expected error for no provider")
	}
}

func TestBackupProvider_RoundTrip(t *testing.T) {
	providers := []BackupProvider{BackupProviderLocal, BackupProviderWebDAV, BackupProviderDropbox, BackupProviderGoogleDrive, BackupProviderOneDrive}
	for _, p := range providers {
		if ParseBackupProvider(p.String()) != p {
			t.Errorf("round-trip failed for %v", p)
		}
	}
}
