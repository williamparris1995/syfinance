package application

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/auth/application/command"
	"github.com/yucai/server/internal/auth/application/query"
	"github.com/yucai/server/internal/auth/domain"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/internal/auth/infrastructure/oidc"
)

// Service orchestrates authentication operations following the industry-standard
// access/refresh token model (RFC 6749 / RFC 6750):
//   - Access token: short-lived JWT, self-validating via signature.
//   - Refresh token: opaque, server-stored, rotated on each refresh with reuse detection.
//
// Login itself is delegated to OIDC (ProviderRegistry + OIDCExchangeHandler):
// the server never sees a password.
//
// Access-token revocation is layered on top of the JWT model via a Redis jti
// blacklist: logout and refresh rotation both push the old access token's jti
// into blacklist so it stops validating inside its 15min TTL window.
type Service struct {
	tenantRepo      domain.TenantRepository
	userRepo        domain.UserRepository
	tokenService    *authjwt.TokenService
	sessionStore    command.SessionStore
	blacklist       command.TokenBlacklist
	oidcHandler     *command.OIDCExchangeHandler
	oidcRegistry    *oidc.ProviderRegistry
	refreshHandler  *command.RefreshHandler
	profileHandler  *query.GetProfileHandler
	currencyChecker domain.CurrencyCodeChecker
}

// NewService creates a new auth application service.
func NewService(
	tenantRepo domain.TenantRepository,
	userRepo domain.UserRepository,
	tokenService *authjwt.TokenService,
	sessionStore command.SessionStore,
	blacklist command.TokenBlacklist,
	oidcHandler *command.OIDCExchangeHandler,
	oidcRegistry *oidc.ProviderRegistry,
	refreshHandler *command.RefreshHandler,
	profileHandler *query.GetProfileHandler,
	currencyChecker domain.CurrencyCodeChecker,
) *Service {
	if blacklist == nil {
		blacklist = command.NoopTokenBlacklist()
	}
	return &Service{
		tenantRepo:      tenantRepo,
		userRepo:        userRepo,
		tokenService:    tokenService,
		sessionStore:    sessionStore,
		blacklist:       blacklist,
		oidcHandler:     oidcHandler,
		oidcRegistry:    oidcRegistry,
		refreshHandler:  refreshHandler,
		profileHandler:  profileHandler,
		currencyChecker: currencyChecker,
	}
}

// issueSession issues an access JWT + opens a refresh-token session for the user.
func (s *Service) issueSession(ctx context.Context, user *domain.User) (accessToken, refreshToken string, err error) {
	accessToken, err = s.tokenService.GenerateAccessToken(user.ID, user.TenantID, user.IsAdmin)
	if err != nil {
		return "", "", fmt.Errorf("generate access token: %w", err)
	}
	refreshToken = s.tokenService.GenerateRefreshToken()
	familyID := uuid.NewString()
	if err := s.sessionStore.Create(ctx, refreshToken, familyID, user.ID.String(), user.TenantID.String(), s.tokenService.RefreshTokenTTL()); err != nil {
		return "", "", fmt.Errorf("create session: %w", err)
	}
	return accessToken, refreshToken, nil
}

// preferredCurrencyFor looks up the tenant's preferred display currency.
// On any error (tenant missing, repo failure) it falls back to the empty
// string so a transient storage hiccup never blocks login/profile reads —
// the client can still issue GetPreferences to recover.
func (s *Service) preferredCurrencyFor(ctx context.Context, tenantID uuid.UUID) string {
	tenant, err := s.tenantRepo.FindByID(ctx, tenantID)
	if err != nil || tenant == nil {
		return ""
	}
	return tenant.PreferredCurrency
}
// OIDCExchange handles the OIDC authorization-code exchange (code → id_token →
// verified identity) and just-in-time provisioning of a local user when the
// identity is new, then issues a御财 access/refresh token pair via the shared
// issueSession helper.
func (s *Service) OIDCExchange(ctx context.Context, provider, code, codeVerifier, redirectURI string) (*AuthResponse, error) {
	user, err := s.oidcHandler.Exchange(ctx, provider, code, codeVerifier, redirectURI)
	if err != nil {
		return nil, err
	}
	accessToken, refreshToken, err := s.issueSession(ctx, user)
	if err != nil {
		return nil, err
	}
	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: refreshToken,
		User:         UserToDTOWithCurrency(user, s.preferredCurrencyFor(ctx, user.TenantID)),
	}, nil
}

// GetOIDCConfig returns the non-sensitive description of every enabled OIDC
// provider (secrets stripped by the registry) so the client can render a
// provider picker and build the auth URL + PKCE challenge itself.
func (s *Service) GetOIDCConfig() []oidc.ProviderConfig {
	return s.oidcRegistry.ListConfigs()
}

// RefreshToken rotates a refresh token and returns a fresh token pair.
// The user identity is resolved from the opaque refresh token itself (via the
// session store), so no client-supplied user identifier is required.
//
// If oldAccessToken is non-empty, its jti is added to the blacklist so the
// previous access JWT stops validating immediately (instead of lingering for
// the rest of its 15min TTL). Clients that send their expiring access token as
// Bearer metadata on this RPC get this revocation for free; clients that don't
// are still correct, just slower to invalidate the old token.
//
// Returns command.ErrInvalidRefreshToken (unknown/expired) or
// command.ErrRefreshTokenReuse (replayed rotated token — family revoked).
func (s *Service) RefreshToken(ctx context.Context, refreshToken, oldAccessToken string) (*AuthResponse, error) {
	newRefresh := s.tokenService.GenerateRefreshToken()
	userIDStr, tenantIDStr, err := s.refreshHandler.Rotate(ctx, refreshToken, newRefresh, s.tokenService.RefreshTokenTTL())
	if err != nil {
		return nil, err
	}

	userID, err := uuid.Parse(userIDStr)
	if err != nil {
		return nil, fmt.Errorf("parse user id from session: %w", err)
	}
	tenantID, err := uuid.Parse(tenantIDStr)
	if err != nil {
		return nil, fmt.Errorf("parse tenant id from session: %w", err)
	}

	// Look up the user to read IsAdmin for the refreshed access token. Refresh
	// is infrequent (access TTL is minutes), so the extra DB read is cheap and
	// avoids stashing role state in the session row. A missing user (deleted
	// between session issue and refresh) short-circuits to InvalidRefreshToken.
	user, err := s.userRepo.FindByID(ctx, userID)
	if err != nil || user == nil {
		return nil, fmt.Errorf("%w: user lookup failed during refresh", command.ErrInvalidRefreshToken)
	}

	// Blacklist the old access token's jti before issuing the new pair. Done
	// AFTER successful rotation so a failed refresh doesn't prematurely revoke a
	// still-valid token. Errors here are logged but non-fatal — losing the
	// revocation just means the old token lives out its short TTL.
	if oldAccessToken != "" {
		if jti, exp, ok := s.tokenService.ParseAccessTokenJTI(oldAccessToken); ok && jti != "" {
			if err := s.blacklist.Add(ctx, jti, exp); err != nil {
				slog.Warn("blacklist add on refresh failed",
					"op", "auth.refresh.blacklist",
					"error", err,
				)
			}
		}
	}

	accessToken, err := s.tokenService.GenerateAccessToken(userID, tenantID, user.IsAdmin)
	if err != nil {
		return nil, fmt.Errorf("generate access token: %w", err)
	}
	return &AuthResponse{
		AccessToken:  accessToken,
		RefreshToken: newRefresh,
	}, nil
}

// Logout revokes the refresh-token session AND blacklists the access token's
// jti so it stops validating immediately (closes the post-logout window inside
// the access token's 15min TTL). accessToken may be empty — in that case only
// the refresh session is revoked and the access JWT expires on its own (the
// pre-T02 behavior, kept for callers that haven't been updated yet).
func (s *Service) Logout(ctx context.Context, refreshToken, accessToken string) error {
	if err := s.refreshHandler.Revoke(ctx, refreshToken); err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}
	if accessToken != "" {
		if jti, exp, ok := s.tokenService.ParseAccessTokenJTI(accessToken); ok && jti != "" {
			if err := s.blacklist.Add(ctx, jti, exp); err != nil {
				// Non-fatal: refresh revocation succeeded. The access token
				// still expires within ≤15min; we just lose the immediate
				// revocation window.
				slog.Warn("blacklist add on logout failed",
					"op", "auth.logout.blacklist",
					"error", err,
				)
			}
		}
	}
	return nil
}

// GetProfile returns the user's profile.
func (s *Service) GetProfile(ctx context.Context, userID, tenantID uuid.UUID) (*UserDTO, error) {
	q := query.GetProfileQuery{UserID: userID, TenantID: tenantID}
	result, err := s.profileHandler.Handle(ctx, q)
	if err != nil {
		return nil, err
	}
	dto := UserToDTOWithCurrency(result.User, s.preferredCurrencyFor(ctx, tenantID))
	return &dto, nil
}

// UpdateProfile updates the user's profile and returns the updated DTO.
func (s *Service) UpdateProfile(ctx context.Context, req UpdateProfileRequest) (*UserDTO, error) {
	user, err := s.userRepo.FindByID(ctx, req.UserID)
	if err != nil {
		return nil, fmt.Errorf("user not found: %w", err)
	}
	if user.TenantID != req.TenantID {
		return nil, errors.New("tenant mismatch: access denied")
	}
	user.UpdateProfile(req.DisplayName, req.AvatarURL)
	if err := s.userRepo.Update(ctx, user); err != nil {
		return nil, fmt.Errorf("update user: %w", err)
	}
	dto := UserToDTOWithCurrency(user, s.preferredCurrencyFor(ctx, req.TenantID))
	return &dto, nil
}

// GetPreferences returns the tenant's display currency and rate-sync interval.
func (s *Service) GetPreferences(ctx context.Context, tenantID uuid.UUID) (*TenantPreferencesDTO, error) {
	tenant, err := s.tenantRepo.FindByID(ctx, tenantID)
	if err != nil {
		return nil, fmt.Errorf("tenant not found: %w", err)
	}
	return &TenantPreferencesDTO{
		PreferredCurrency:     tenant.PreferredCurrency,
		RateSyncIntervalHours: int32(tenant.RateSyncIntervalHours),
	}, nil
}

// UpdatePreferences validates and persists the tenant's preferred display
// currency and rate-sync interval. The currency code must exist in the currency
// catalog (checked via the cross-module CurrencyCodeChecker port); the interval
// must be in [1, 168]. Domain-level invariants are re-asserted by Tenant.UpdatePreferences.
func (s *Service) UpdatePreferences(ctx context.Context, req UpdatePreferencesRequest) (*TenantPreferencesDTO, error) {
	tenant, err := s.tenantRepo.FindByID(ctx, req.TenantID)
	if err != nil {
		return nil, fmt.Errorf("tenant not found: %w", err)
	}

	// Normalize then validate the currency code against the catalog. The domain
	// entity upper-cases it too, but we validate before calling UpdatePreferences
	// so an unknown code is rejected before mutation.
	currency := strings.ToUpper(strings.TrimSpace(req.PreferredCurrency))
	if currency == "" {
		return nil, fmt.Errorf("preferred_currency must not be empty")
	}
	exists, err := s.currencyChecker.FindByCode(ctx, currency)
	if err != nil {
		return nil, fmt.Errorf("check currency code: %w", err)
	}
	if !exists {
		return nil, fmt.Errorf("invalid currency code: %s is not in the catalog", currency)
	}

	if err := tenant.UpdatePreferences(currency, req.IntervalHours); err != nil {
		return nil, err
	}

	if err := s.tenantRepo.Update(ctx, tenant); err != nil {
		return nil, fmt.Errorf("update tenant preferences: %w", err)
	}

	return &TenantPreferencesDTO{
		PreferredCurrency:     tenant.PreferredCurrency,
		RateSyncIntervalHours: int32(tenant.RateSyncIntervalHours),
	}, nil
}
