package middleware

import (
	"context"
	"strings"

	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// TokenService is set during Wire initialization.
// This package-level variable avoids circular dependencies in the middleware.
var TokenService *authjwt.TokenService

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

	userID, tenantID, err := TokenService.ParseAccessToken(tokenStr)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "invalid or expired token")
	}

	// Inject user_id and tenant_id into context for downstream handlers
	ctx = authgrpc.WithUserID(ctx, userID)
	ctx = authgrpc.WithTenantID(ctx, tenantID)

	return handler(ctx, req)
}
