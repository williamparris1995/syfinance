package middleware

import (
	"context"
	"log/slog"

	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// adminGuardedMethods lists the gRPC FullMethods that mutate the shared
// securities catalog and therefore require platform-admin role. These RPCs
// affect every tenant's market-value / return computation, so non-admin
// invocation could pollute global pricing reference data.
//
// Package is yucai.holding.v1, service is HoldingService (see
// yucai/proto/holding/v1/holding.proto).
var adminGuardedMethods = map[string]struct{}{
	"/yucai.holding.v1.HoldingService/CreateSecurity":        {},
	"/yucai.holding.v1.HoldingService/UpdateSecurityPrice":   {},
	"/yucai.holding.v1.HoldingService/SyncPrices":            {},
	"/yucai.holding.v1.HoldingService/BackfillPriceHistory":  {},
}

// RequireAdmin is a gRPC unary server interceptor that authorizes the four
// securities write RPCs (listed in adminGuardedMethods) against the
// platform-admin flag set in context by AuthInterceptor. Non-guarded methods
// pass through unchanged. Order in the chain MUST be: AuthInterceptor first
// (parses JWT → injects is_admin), RequireAdmin second (reads is_admin).
//
// On a guarded RPC:
//   - admin true  → handler invoked.
//   - admin false → PermissionDenied (fail-closed).
//
// Errors are logged at WARN with op="authorize_admin" so abuse attempts
// (non-admin trying to write securities) surface in structured logs without
// leaking the role into the message string.
func RequireAdmin(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	if _, guarded := adminGuardedMethods[info.FullMethod]; !guarded {
		return handler(ctx, req)
	}

	isAdmin := authgrpc.GetAdminFromContext(ctx)
	if !isAdmin {
		slog.Warn("authorize_admin",
			"op", "require_admin",
			"method", info.FullMethod,
			"reason", "non-admin caller blocked from securities write RPC",
		)
		return nil, status.Error(codes.PermissionDenied, "admin role required")
	}

	return handler(ctx, req)
}
