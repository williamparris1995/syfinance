package cloud

import "context"

// Provider is the port interface for cloud backup providers.
// Driven adapters implement this interface to support different cloud backends.
type Provider interface {
	// Upload sends backup data to the cloud provider.
	Upload(ctx context.Context, filename string, data []byte) error

	// TestConnection verifies connectivity to the cloud provider.
	TestConnection(ctx context.Context) error
}
