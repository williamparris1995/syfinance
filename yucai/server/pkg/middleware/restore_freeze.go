package middleware

import (
	"context"
	"strings"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"github.com/google/uuid"

	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
)

// RestoreFreezeChecker is the read-only freeze probe the interceptor needs.
// Declared here (not importing the backup module) so pkg/middleware keeps
// its dependency direction; the concrete *application.RestoreFreeze
// satisfies it structurally.
type RestoreFreezeChecker interface {
	IsFrozen(tenantID uuid.UUID) bool
}

// restoreFreezeChecker is injected as a package-level variable, mirroring
// the TokenService/TokenBlacklist pattern: the wire provider assigns it
// before the gRPC server starts serving. Exposed for tests via
// SetRestoreFreezeChecker.
var restoreFreezeChecker RestoreFreezeChecker

// SetRestoreFreezeChecker wires the concrete freeze table (called from the
// wire provider; tests may swap it).
func SetRestoreFreezeChecker(c RestoreFreezeChecker) { restoreFreezeChecker = c }

// writeMethodPrefixes is the explicit blacklist of mutating RPC verbs
// (D12 FR-2). A method whose name starts with one of these is REJECTED
// while the tenant is frozen. New write RPCs must register their prefix
// here (checklist item).
var writeMethodPrefixes = []string{
	"Create", "Update", "Delete", "Record", "Buy", "Sell", "Save", "Import",
	"Restore", "Upload", "Add", "Remove", "Pause", "Resume", "Complete",
	"Clone", "Apply", "Write", "Mark", "Set",
}

// readMethodPrefixes is the allowlist for known read RPCs. Anything that
// matches NEITHER list is allowed through by default — new read RPCs stay
// functional without a middleware change; a missed new write prefix falls
// back to the restore's whole-replace idempotency (accepted, design R1).
var readMethodPrefixes = []string{
	"Get", "List", "Find", "Search", "Summary", "Export", "Sync", "Health",
}

// RestoreFreezeInterceptor rejects WRITE RPCs for tenants with a restore in
// progress (UNAVAILABLE + human message) and lets reads through — the D6
// atomic tx guarantees readers only ever see consistent pre/post states.
// Must run AFTER AuthInterceptor (it needs the injected tenant_id).
func RestoreFreezeInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	if restoreFreezeChecker == nil {
		return handler(ctx, req) // pre-wire startup window (same nil semantics as TokenService)
	}
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	if err != nil {
		return handler(ctx, req) // no tenant context (auth-public / health): not freeze-scoped
	}
	if !restoreFreezeChecker.IsFrozen(tenantID) {
		return handler(ctx, req) // hot path: unfrozen tenant passes
	}

	method := methodName(info.FullMethod)
	if isWriteMethod(method) {
		return nil, status.Error(codes.Unavailable, "正在恢复数据，请稍后")
	}
	return handler(ctx, req)
}

func methodName(fullMethod string) string {
	if i := strings.LastIndex(fullMethod, "/"); i >= 0 && i+1 < len(fullMethod) {
		return fullMethod[i+1:]
	}
	return fullMethod
}

func isWriteMethod(method string) bool {
	for _, p := range writeMethodPrefixes {
		if strings.HasPrefix(method, p) {
			return true
		}
	}
	return false
}
