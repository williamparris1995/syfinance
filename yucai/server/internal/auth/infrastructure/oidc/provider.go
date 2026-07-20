// Package oidc implements OIDC provider discovery, code exchange (with PKCE)
// and id_token verification. It is a pure technical infrastructure module
// (peer of jwt/ and password/) and intentionally has no dependency on the
// auth domain or application layers; downstream wiring happens in Task 5/6/7.
package oidc

import (
	"context"
	"fmt"

	"github.com/coreos/go-oidc/v3/oidc"
	"golang.org/x/oauth2"
)

// ProviderConfig is the non-sensitive provider description (safe to return via
// GetOIDCConfig). Secret is loaded separately from env and never serialized.
// AuthorizationEndpoint is filled by OIDC discovery at Load time (not from yaml).
type ProviderConfig struct {
	Name                  string   // "google"
	DisplayName           string   // "使用 Google 登录"
	Issuer                string   // "https://accounts.google.com"
	AuthorizationEndpoint string   // filled by discovery (provider.Endpoint().AuthURL)
	ClientID              string
	ClientSecret          string // env-injected, not in yaml
	Scopes                []string
	RedirectURI           string // base, e.g. "http://localhost:PORT/callback" (client binds actual port)
}

// Provider wraps go-oidc discovery + oauth2 config for one IDP.
type Provider struct {
	Config       ProviderConfig
	oauth2Config *oauth2.Config
	verifier     *oidc.IDTokenVerifier
}

// NewProvider runs OIDC discovery against cfg.Issuer and builds the oauth2
// config + id_token verifier.
func NewProvider(ctx context.Context, cfg ProviderConfig) (*Provider, error) {
	p, err := oidc.NewProvider(ctx, cfg.Issuer)
	if err != nil {
		return nil, fmt.Errorf("oidc discovery for %s: %w", cfg.Issuer, err)
	}
	return &Provider{
		Config: cfg,
		oauth2Config: &oauth2.Config{
			ClientID:     cfg.ClientID,
			ClientSecret: cfg.ClientSecret,
			Endpoint:     p.Endpoint(),
			RedirectURL:  cfg.RedirectURI,
			Scopes:       cfg.Scopes,
		},
		verifier: p.Verifier(&oidc.Config{ClientID: cfg.ClientID}),
	}, nil
}

// Exchange swaps an authorization code (+ PKCE verifier) for tokens.
//
// redirectURI must match the auth request; oauth2 uses Config.RedirectURL by
// default, but the loopback port is dynamic so it is overridden per-call when
// non-empty. codeVerifier is the PKCE code_verifier originally used to derive
// the code_challenge sent on the auth request.
func (p *Provider) Exchange(ctx context.Context, code, codeVerifier, redirectURI string) (*oauth2.Token, error) {
	opts := []oauth2.AuthCodeOption{oauth2.SetAuthURLParam("code_verifier", codeVerifier)}
	if redirectURI != "" {
		opts = append(opts, oauth2.SetAuthURLParam("redirect_uri", redirectURI))
	}
	tok, err := p.oauth2Config.Exchange(ctx, code, opts...)
	if err != nil {
		return nil, fmt.Errorf("exchange code: %w", err)
	}
	return tok, nil
}

// AuthorizationEndpoint is exposed for GetOIDCConfig (client builds the auth URL).
func (p *Provider) AuthorizationEndpoint() string {
	return p.oauth2Config.Endpoint.AuthURL
}
