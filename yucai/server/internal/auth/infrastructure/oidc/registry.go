package oidc

import (
	"context"
	"fmt"
	"os"
	"strings"

	"gopkg.in/yaml.v3"
)

// yamlProvider is the on-disk shape of oidc_providers.yaml (no secret).
type yamlProvider struct {
	Name        string   `yaml:"name"`
	DisplayName string   `yaml:"display_name"`
	Issuer      string   `yaml:"issuer"`
	ClientID    string   `yaml:"client_id"`
	Scopes      []string `yaml:"scopes"`
	RedirectURI string   `yaml:"redirect_uri"`
}

type yamlConfig struct {
	Providers []yamlProvider `yaml:"providers"`
}

// ProviderRegistry holds discovered providers keyed by name.
type ProviderRegistry struct {
	providers map[string]*Provider
	configs   []ProviderConfig
}

// Load reads yaml + injects per-provider secret from env
// (OIDC_<NAME_UPPER>_CLIENT_SECRET), then runs discovery for each provider.
//
// On success every provider in the yaml has been discovered, has a usable
// id_token verifier, and its AuthorizationEndpoint is populated.
func Load(ctx context.Context, yamlPath string) (*ProviderRegistry, error) {
	data, err := os.ReadFile(yamlPath)
	if err != nil {
		return nil, fmt.Errorf("read oidc providers yaml: %w", err)
	}
	var yc yamlConfig
	if err := yaml.Unmarshal(data, &yc); err != nil {
		return nil, fmt.Errorf("parse oidc providers yaml: %w", err)
	}

	reg := &ProviderRegistry{providers: map[string]*Provider{}}
	for _, yp := range yc.Providers {
		secret := os.Getenv("OIDC_" + strings.ToUpper(yp.Name) + "_CLIENT_SECRET")
		cfg := ProviderConfig{
			Name:         yp.Name,
			DisplayName:  yp.DisplayName,
			Issuer:       yp.Issuer,
			ClientID:     yp.ClientID,
			ClientSecret: secret,
			Scopes:       yp.Scopes,
			RedirectURI:  yp.RedirectURI,
		}
		p, err := NewProvider(ctx, cfg)
		if err != nil {
			return nil, fmt.Errorf("init provider %s: %w", yp.Name, err)
		}
		cfg.AuthorizationEndpoint = p.AuthorizationEndpoint()
		reg.providers[yp.Name] = p
		reg.configs = append(reg.configs, cfg)
	}
	return reg, nil
}

// Get returns the discovered provider with the given name (e.g. "google").
// The boolean is false if no provider with that name is configured.
func (r *ProviderRegistry) Get(name string) (*Provider, bool) {
	p, ok := r.providers[name]
	return p, ok
}

// ListConfigs returns non-sensitive configs for GetOIDCConfig. ClientSecret is
// blanked before returning so the slice is safe to serialize into a gRPC
// response or log line.
func (r *ProviderRegistry) ListConfigs() []ProviderConfig {
	out := make([]ProviderConfig, 0, len(r.configs))
	for _, c := range r.configs {
		c.ClientSecret = ""
		out = append(out, c)
	}
	return out
}
