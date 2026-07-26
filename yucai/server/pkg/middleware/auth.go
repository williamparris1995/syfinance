package middleware

import (
	"context"
	"log/slog"
	"strings"

	"github.com/google/uuid"

	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/auth/application/command"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// TokenService is set during Wire initialization.
// This package-level variable avoids circular dependencies in the middleware.
var TokenService *authjwt.TokenService

// TokenBlacklist is set during Wire initialization. Defaults to a noop that
// never revokes — production wires a Redis-backed implementation; tests that
// don't care about revocation leave it nil and AuthInterceptor skips the check.
var TokenBlacklist command.TokenBlacklist

// AuthInterceptor validates JWT tokens in gRPC metadata.
// Skip auth for AuthService methods (Register, Login) — they don't require tokens.
// All other methods require a valid access token that extracts user_id and tenant_id into context.
func AuthInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	// Skip auth for auth service public methods (Register, Login)
	if strings.HasPrefix(info.FullMethod, "/yucai.auth.v1.AuthService/") &&
		!strings.Contains(info.FullMethod, "GetProfile") &&
		!strings.Contains(info.FullMethod, "UpdateProfile") {
		return handler(ctx, req)
	}

	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Error(codes.Unauthenticated, "missing metadata")
	}

	tokens := md.Get("authorization")
	if len(tokens) == 0 {
		return nil, status.Error(codes.Unauthenticated, "missing authorization token")
	}

	// Extract Bearer token
	tokenStr := tokens[0]
	if strings.HasPrefix(tokenStr, "Bearer ") {
		tokenStr = strings.TrimPrefix(tokenStr, "Bearer ")
	}

	if TokenService == nil {
		return nil, status.Error(codes.Internal, "token service not initialized")
	}

	// Parse the full claims (not just user/tenant) so we can read the jti for
	// blacklist lookup. Parser enforces signature + expiry + audience + issuer.
	claims, err := TokenService.ParseAccessTokenClaims(tokenStr)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid or expired token")
	}

	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid user_id in token")
	}
	tenantID, err := uuid.Parse(claims.TenantID)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid tenant_id in token")
	}

	// Consult the access-token blacklist. A revoked jti (logout / refresh
	// rotation / tenant deletion) short-circuits to Unauthenticated even though
	// the signature is still valid — closes the post-logout window inside the
	// token's 15min TTL. When no blacklist is wired (nil) the check is skipped,
	// preserving the pre-T02 behavior for tests that don't exercise revocation.
	if TokenBlacklist != nil {
		blocked, err := TokenBlacklist.IsBlacklisted(ctx, claims.JTI())
		if err != nil {
			// Fail-closed on lookup errors: a broken Redis shouldn't silently
			// un-revoke a token the operator explicitly blacklisted. Log the
			// underlying error so the operator can diagnose Redis health.
			slog.Error("blacklist lookup failed",
				"op", "auth.interceptor.blacklist",
				"error", err,
			)
			return nil, status.Error(codes.Unavailable, "token revocation check unavailable")
		}
		if blocked {
			return nil, status.Error(codes.Unauthenticated, "token has been revoked")
		}
	}

	// Inject user_id, tenant_id, and is_admin into context for downstream handlers
	ctx = authgrpc.WithUserID(ctx, userID)
	ctx = authgrpc.WithTenantID(ctx, tenantID)
	ctx = authgrpc.WithAdmin(ctx, claims.IsAdmin)

	return handler(ctx, req)
}
