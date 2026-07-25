package domain

import (
	"regexp"
	"testing"

	"github.com/google/uuid"
)

func TestNewBackup_Valid(t *testing.T) {
	b, err := NewBackup(uuid.New(), BackupProviderLocal, false, false)
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
	_, err := NewBackup(uuid.New(), BackupProvider(0), false, false)
	if err == nil {
		t.Error("expected error for no provider")
	}
}

func TestNewBackup_AutoFlag(t *testing.T) {
	b1, err := NewBackup(uuid.New(), BackupProviderLocal, false, true)
	if err != nil {
		t.Fatalf("NewBackup auto=true: %v", err)
	}
	if !b1.Auto {
		t.Error("Auto=false, want true (auto flag not propagated)")
	}
	b2, err := NewBackup(uuid.New(), BackupProviderLocal, false, false)
	if err != nil {
		t.Fatalf("NewBackup auto=false: %v", err)
	}
	if b2.Auto {
		t.Error("Auto=true, want false")
	}
}

func TestBackupProvider_RoundTrip(t *testing.T) {
	providers := []BackupProvider{BackupProviderLocal}
	for _, p := range providers {
		if ParseBackupProvider(p.String()) != p {
			t.Errorf("round-trip failed for %v", p)
		}
	}
}

// TestNewBackup_FilenameUnique locks in the UUID-short-suffix filename scheme
// (backup_<YYYYMMDD>_<HHMMSS>_<uuid8>.{json.gz,enc}). The uuid8 suffix is what
// roots out same-second collisions: two NewBackup calls within one second must
// produce distinct filenames. This is a regression guard for the pre-restore
// safety net, which creates a backup that frequently lands in the same second
// as a user-triggered one — without the suffix the second Save would overwrite
// the first file and silently lose data. Do not simplify the filename back to a
// bare timestamp.
func TestNewBackup_FilenameUnique(t *testing.T) {
	re := regexp.MustCompile(`^backup_\d{8}_\d{6}_[0-9a-f]{8}\.(json\.gz|enc)$`)
	b1, _ := NewBackup(uuid.New(), BackupProviderLocal, false, false)
	if !re.MatchString(b1.Filename) {
		t.Errorf("filename %q does not match backup_<YYYYMMDD>_<HHMMSS>_<uuid8>.{json.gz,enc}", b1.Filename)
	}
	seen := map[string]bool{}
	for i := 0; i < 20; i++ {
		b, _ := NewBackup(uuid.New(), BackupProviderLocal, false, false)
		if seen[b.Filename] {
			t.Errorf("filename collision on iteration %d: %q (uuid suffix must root out same-second collisions)", i, b.Filename)
		}
		seen[b.Filename] = true
	}
}
