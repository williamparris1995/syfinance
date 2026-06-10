package middleware

import (
	"context"

	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
)

// GetTenantID extracts the tenant_id from the context.
func GetTenantID(ctx context.Context) (uuid.UUID, error) {
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	return tenantID, err
}

// GetUserID extracts the user_id from the context.
func GetUserID(ctx context.Context) (uuid.UUID, error) {
	return authgrpc.GetUserIDFromContext(ctx)
}
