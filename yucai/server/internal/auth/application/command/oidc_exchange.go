package command

import (
	"context"
	"fmt"
	"strings"

	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/ent"
	"github.com/yucai/server/internal/auth/infrastructure/oidc"
)

// OIDCExchangeHandler swaps an authorization code for an OIDC id_token, verifies
// it, and resolves — or just-in-time provisions — the local user that backs the
// verified identity. Token issuance (access JWT + refresh session) is handled
// by the application Service, which wraps the returned *domain.User.
type OIDCExchangeHandler struct {
	registry     *oidc.ProviderRegistry
	userRepo     domain.UserRepository
	identityRepo domain.IdentityRepository
	tenantRepo   domain.TenantRepository
	seeder       PresetSeeder
}

// NewOIDCExchangeHandler constructs an OIDCExchangeHandler. seeder defaults to a
// no-op when nil (unit-test convenience).
func NewOIDCExchangeHandler(
	registry *oidc.ProviderRegistry,
	userRepo domain.UserRepository,
	identityRepo domain.IdentityRepository,
	tenantRepo domain.TenantRepository,
	seeder PresetSeeder,
) *OIDCExchangeHandler {
	if seeder == nil {
		seeder = noopPresetSeeder{}
	}
	return &OIDCExchangeHandler{
		registry:     registry,
		userRepo:     userRepo,
		identityRepo: identityRepo,
		tenantRepo:   tenantRepo,
		seeder:       seeder,
	}
}

// Exchange resolves the user for a verified OIDC identity. An existing user is
// returned as-is; a first-time login just-in-time provisions a fresh tenant
// (with preset categories) + user + identity row.
func (h *OIDCExchangeHandler) Exchange(ctx context.Context, providerName, code, codeVerifier, redirectURI string) (*domain.User, error) {
	provider, ok := h.registry.Get(providerName)
	if !ok {
		return nil, fmt.Errorf("unknown provider: %s", providerName)
	}

	tok, err := provider.Exchange(ctx, code, codeVerifier, redirectURI)
	if err != nil {
		return nil, fmt.Errorf("oidc exchange: %w", err)
	}
	rawIDToken, _ := tok.Extra("id_token").(string)
	if rawIDToken == "" {
		return nil, fmt.Errorf("oidc exchange: no id_token in response")
	}
	verified, err := provider.VerifyIDToken(ctx, rawIDToken)
	if err != nil {
		return nil, fmt.Errorf("oidc verify: %w", err)
	}

	// Existing identity → resolve user in one query (UserRepository joins
	// useridentity). A NotFound is the expected first-login signal; any other
	// repository error (connection blip, timeout) is propagated so we don't
	// silently create a duplicate tenant+user+identity for the same
	// (provider, subject) on a transient lookup failure.
	existing, err := h.userRepo.FindByProviderSubject(ctx, verified.Provider, verified.Subject)
	if err != nil && !ent.IsNotFound(err) {
		return nil, fmt.Errorf("lookup identity by provider subject: %w", err)
	}
	if existing != nil {
		return existing, nil
	}

	// jit provisioning — order matters: tenant → preset seed → user → identity.
	displayName := deriveDisplayName(verified)

	// First-user-is-admin bootstrap: the system's first-ever registered user
	// is promoted to platform admin so they can manage the shared securities
	// catalog. Counted BEFORE tenant/user creation so a concurrent first-login
	// race still resolves to a deterministic admin (eventual-consistency: the
	// second writer's Count sees ≥1 and stays non-admin; only the first
	// transaction's Count sees 0).
	userCount, err := h.userRepo.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count users for admin bootstrap: %w", err)
	}

	tenant, err := domain.NewTenant(displayName+"'s Finances", domain.TenantTypePersonal)
	if err != nil {
		return nil, fmt.Errorf("create tenant: %w", err)
	}
	if err := h.tenantRepo.Save(ctx, tenant); err != nil {
		return nil, fmt.Errorf("save tenant: %w", err)
	}
	if err := h.seeder.SeedTenantPresets(ctx, tenant.ID); err != nil {
		return nil, fmt.Errorf("seed tenant presets: %w", err)
	}

	email := ""
	if verified.EmailVerified {
		email = strings.TrimSpace(strings.ToLower(verified.Email))
	}
	user, err := domain.NewUser(tenant.ID, email, displayName)
	if err != nil {
		return nil, fmt.Errorf("create user: %w", err)
	}
	user.IsAdmin = userCount == 0
	if err := h.userRepo.Save(ctx, user); err != nil {
		return nil, fmt.Errorf("save user: %w", err)
	}

	identity, err := domain.NewUserIdentity(tenant.ID, user.ID, verified.Provider, verified.Subject, verified.Issuer, verified.Email)
	if err != nil {
		return nil, fmt.Errorf("create identity: %w", err)
	}
	if err := h.identityRepo.Save(ctx, identity); err != nil {
		return nil, fmt.Errorf("save identity: %w", err)
	}
	return user, nil
}

// deriveDisplayName picks a display name from the verified id_token claims. The
// OIDC `name`/`preferred_username` claims are not currently surfaced by the
// verifier, so we fall back to the email local-part and finally to "User".
func deriveDisplayName(v *oidc.VerifyResult) string {
	if at := strings.IndexByte(v.Email, '@'); at > 0 {
		return v.Email[:at]
	}
	return "User"
}
