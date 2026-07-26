package middleware

import (
	"context"
	"errors"
	"testing"

	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// TestRequireAdmin_AdminAllowed verifies the interceptor authorizes a guarded
// RPC (CreateSecurity) when is_admin=true is present in context.
func TestRequireAdmin_AdminAllowed(t *testing.T) {
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/CreateSecurity"}
	ctx := authgrpc.WithAdmin(context.Background(), true)

	invoked := false
	handler := func(ctx context.Context, req any) (any, error) {
		invoked = true
		return "ok", nil
	}

	resp, err := RequireAdmin(ctx, nil, info, handler)
	if err != nil {
		t.Fatalf("RequireAdmin blocked admin: %v", err)
	}
	if !invoked {
		t.Error("handler not invoked for admin caller")
	}
	if resp != "ok" {
		t.Errorf("response mismatch: got %v, want %v", resp, "ok")
	}
}

// TestRequireAdmin_NonAdminBlocked verifies the interceptor rejects a guarded
// RPC when is_admin is false / absent, returning PermissionDenied.
func TestRequireAdmin_NonAdminBlocked(t *testing.T) {
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/UpdateSecurityPrice"}

	// Explicitly non-admin (flag present, false).
	t.Run("explicit_non_admin", func(t *testing.T) {
		ctx := authgrpc.WithAdmin(context.Background(), false)
		invoked := false
		handler := func(ctx context.Context, req any) (any, error) {
			invoked = true
			return nil, nil
		}
		_, err := RequireAdmin(ctx, nil, info, handler)
		if invoked {
			t.Error("handler should NOT be invoked for non-admin")
		}
		if !errors.Is(err, nil) && status.Code(err) != codes.PermissionDenied {
			t.Errorf("error code mismatch: got %v, want %v", status.Code(err), codes.PermissionDenied)
		}
	})

	// Absent flag (legacy token without is_admin claim — fail-closed).
	t.Run("absent_admin_flag", func(t *testing.T) {
		ctx := context.Background() // no WithAdmin call
		invoked := false
		handler := func(ctx context.Context, req any) (any, error) {
			invoked = true
			return nil, nil
		}
		_, err := RequireAdmin(ctx, nil, info, handler)
		if invoked {
			t.Error("handler should NOT be invoked when admin flag is absent")
		}
		if status.Code(err) != codes.PermissionDenied {
			t.Errorf("error code mismatch: got %v, want %v", status.Code(err), codes.PermissionDenied)
		}
	})
}

// TestRequireAdmin_AllFourSecuritiesWriteRPCsGuarded guards against a
// regression where one of the four methods is dropped from the whitelist.
func TestRequireAdmin_AllFourSecuritiesWriteRPCsGuarded(t *testing.T) {
	guarded := []string{
		"/yucai.holding.v1.HoldingService/CreateSecurity",
		"/yucai.holding.v1.HoldingService/UpdateSecurityPrice",
		"/yucai.holding.v1.HoldingService/SyncPrices",
		"/yucai.holding.v1.HoldingService/BackfillPriceHistory",
	}
	for _, m := range guarded {
		if _, ok := adminGuardedMethods[m]; !ok {
			t.Errorf("method %q is missing from adminGuardedMethods", m)
		}
	}
	if len(adminGuardedMethods) != len(guarded) {
		t.Errorf("adminGuardedMethods has %d entries, expected %d (no extras allowed without updating test)",
			len(adminGuardedMethods), len(guarded))
	}
}

// TestRequireAdmin_NonGuardedMethodPassesThrough verifies the interceptor
// does not affect methods outside the whitelist (e.g. read RPCs, other
// services). Both admin and non-admin callers should reach the handler.
func TestRequireAdmin_NonGuardedMethodPassesThrough(t *testing.T) {
	info := &grpc.UnaryServerInfo{FullMethod: "/yucai.holding.v1.HoldingService/GetSecurity"}
	cases := []struct {
		name    string
		isAdmin bool
	}{
		{"admin", true},
		{"non_admin", false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			ctx := authgrpc.WithAdmin(context.Background(), c.isAdmin)
			invoked := false
			handler := func(ctx context.Context, req any) (any, error) {
				invoked = true
				return "pass", nil
			}
			_, err := RequireAdmin(ctx, nil, info, handler)
			if err != nil {
				t.Errorf("non-guarded method should pass through, got err: %v", err)
			}
			if !invoked {
				t.Error("handler not invoked for non-guarded method")
			}
		})
	}
}
