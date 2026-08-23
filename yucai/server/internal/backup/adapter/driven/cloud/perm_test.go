package cloud

import (
	"runtime"
	"context"
	"os"
	"path/filepath"
	"testing"
)

// TestLocalProviderWritePerm0600 (D13): backup files land with owner-only
// permissions on Unix (Windows FileMode is a no-op there).
func TestLocalProviderWritePerm0600(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Windows FileMode is advisory-only (os.WriteFile no-op) — the 0600 bit is Unix semantics")
	}
	dir := t.TempDir()
	p := NewLocalProvider(dir)
	if err := p.Upload(context.Background(), "a.ycb", []byte("data")); err != nil {
		t.Fatalf("Upload: %v", err)
	}
	info, err := os.Stat(filepath.Join(dir, "a.ycb"))
	if err != nil {
		t.Fatalf("Stat: %v", err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("perm = %o, want 600", info.Mode().Perm())
	}
}
