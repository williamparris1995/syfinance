package cloud

import "context"

// Provider is the port interface for cloud backup providers.
// Driven adapters implement this interface to support different cloud backends.
type Provider interface {
	// Upload sends backup data to the cloud provider.
	Upload(ctx context.Context, filename string, data []byte) error

	// Download retrieves backup data from the cloud provider.
	Download(ctx context.Context, filename string) ([]byte, error)

	// Delete removes a backup file from the cloud provider.
	Delete(ctx context.Context, filename string) error

	// TestConnection verifies connectivity to the cloud provider.
	TestConnection(ctx context.Context) error
}
