package cloud

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"path"
)

// WebDAVProvider stores backups via WebDAV protocol.
type WebDAVProvider struct {
	baseURL  string
	username string
	password string
	client   *http.Client
}

// NewWebDAVProvider creates a new WebDAVProvider.
func NewWebDAVProvider(baseURL, username, password string) *WebDAVProvider {
	return &WebDAVProvider{
		baseURL:  baseURL,
		username: username,
		password: password,
		client:   &http.Client{},
	}
}

// Upload sends backup data to a WebDAV server.
func (p *WebDAVProvider) Upload(ctx context.Context, filename string, data []byte) error {
	url := fmt.Sprintf("%s/%s", p.baseURL, path.Base(filename))

	req, err := http.NewRequestWithContext(ctx, http.MethodPut, url, bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("create webdav request: %w", err)
	}
	req.SetBasicAuth(p.username, p.password)

	resp, err := p.client.Do(req)
	if err != nil {
		return fmt.Errorf("webdav upload: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("webdav upload failed: status %d, body: %s", resp.StatusCode, string(body))
	}
	return nil
}

// TestConnection verifies WebDAV connectivity with a PROPFIND request.
func (p *WebDAVProvider) TestConnection(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, "PROPFIND", p.baseURL, nil)
	if err != nil {
		return fmt.Errorf("create webdav test request: %w", err)
	}
	req.SetBasicAuth(p.username, p.password)

	resp, err := p.client.Do(req)
	if err != nil {
		return fmt.Errorf("webdav connection test: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 400 {
		return fmt.Errorf("webdav connection failed: status %d", resp.StatusCode)
	}
	return nil
}
