package cloud

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestLocalProviderUploadDownloadDelete(t *testing.T) {
	dir := t.TempDir()
	p := NewLocalProvider(dir)
	data := []byte("backup payload 渡假")

	if err := p.Upload(t.Context(), "b.enc", data); err != nil {
		t.Fatalf("Upload: %v", err)
	}
	got, err := p.Download(t.Context(), "b.enc")
	if err != nil {
		t.Fatalf("Download: %v", err)
	}
	if !bytes.Equal(got, data) {
		t.Fatalf("Download mismatch: got %q want %q", got, data)
	}
	// file present
	if _, err := os.Stat(filepath.Join(dir, "b.enc")); err != nil {
		t.Fatalf("file should exist: %v", err)
	}
	if err := p.Delete(t.Context(), "b.enc"); err != nil {
		t.Fatalf("Delete: %v", err)
	}
	if _, err := os.Stat(filepath.Join(dir, "b.enc")); !os.IsNotExist(err) {
		t.Fatalf("file should be gone, got %v", err)
	}
}

func TestLocalProviderDeleteMissingNotError(t *testing.T) {
	p := NewLocalProvider(t.TempDir())
	if err := p.Delete(t.Context(), "nope.enc"); err != nil {
		t.Fatalf("Delete missing should not error: %v", err)
	}
}
