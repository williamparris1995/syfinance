package cloud

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
)

// LocalProvider stores backups on the local filesystem.
type LocalProvider struct {
	baseDir string
}

// NewLocalProvider creates a new LocalProvider with the given base directory.
func NewLocalProvider(baseDir string) *LocalProvider {
	return &LocalProvider{baseDir: baseDir}
}

// Upload writes backup data to a local file.
func (p *LocalProvider) Upload(ctx context.Context, filename string, data []byte) error {
	if err := os.MkdirAll(p.baseDir, 0755); err != nil {
		return fmt.Errorf("create backup directory: %w", err)
	}

	path := filepath.Join(p.baseDir, filename)
	if err := os.WriteFile(path, data, 0600); err != nil {
		return fmt.Errorf("write backup file: %w", err)
	}
	return nil
}

// TestConnection verifies the base directory is writable.
func (p *LocalProvider) TestConnection(ctx context.Context) error {
	if err := os.MkdirAll(p.baseDir, 0755); err != nil {
		return fmt.Errorf("backup directory not accessible: %w", err)
	}
	// Write and remove a test file to verify write permission
	testPath := filepath.Join(p.baseDir, ".test")
	if err := os.WriteFile(testPath, []byte("test"), 0600); err != nil {
		return fmt.Errorf("backup directory not writable: %w", err)
	}
	os.Remove(testPath)
	return nil
}

// Download reads a backup file from the local filesystem.
func (p *LocalProvider) Download(ctx context.Context, filename string) ([]byte, error) {
	path := filepath.Join(p.baseDir, filename)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read backup file: %w", err)
	}
	return data, nil
}

// Delete removes a backup file. Missing file is not an error.
func (p *LocalProvider) Delete(ctx context.Context, filename string) error {
	path := filepath.Join(p.baseDir, filename)
	if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("delete backup file: %w", err)
	}
	return nil
}
