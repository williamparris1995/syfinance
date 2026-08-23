package middleware

import (
	"context"
	"testing"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	

	"github.com/google/uuid"

	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
)

type fakeChecker struct{ frozen map[uuid.UUID]bool }

func (c *fakeChecker) IsFrozen(t uuid.UUID) bool { return c.frozen[t] }

func withTenant(ctx context.Context, tenant uuid.UUID) context.Context {
	return authgrpc.WithUserID(authgrpc.WithTenantID(ctx, tenant), uuid.New())
}

func runInterceptor(t *testing.T, checker RestoreFreezeChecker, ctx context.Context, method string) error {
	t.Helper()
	old := restoreFreezeChecker
	defer func() { restoreFreezeChecker = old }()
	restoreFreezeChecker = checker
	handler := func(ctx context.Context, req any) (any, error) { return "ok", nil }
	_, err := RestoreFreezeInterceptor(ctx, nil, &grpc.UnaryServerInfo{FullMethod: method}, handler)
	return err
}

func TestFreezeInterceptorWriteRejected(t *testing.T) {
	tid := uuid.New()
	c := &fakeChecker{frozen: map[uuid.UUID]bool{tid: true}}
	err := runInterceptor(t, c, withTenant(context.Background(), tid), "/yucai.account.v1.AccountService/CreateAccount")
	if err == nil {
		t.Fatal("write RPC must be rejected while frozen")
	}
	if code := grpc.Code(err); code != codes.Unavailable {
		t.Fatalf("want Unavailable, got %v", code)
	}
}

func TestFreezeInterceptorReadAllowed(t *testing.T) {
	tid := uuid.New()
	c := &fakeChecker{frozen: map[uuid.UUID]bool{tid: true}}
	for _, m := range []string{
		"/yucai.account.v1.AccountService/ListAccounts",
		"/yucai.transaction.v1.TransactionService/GetTransaction",
		"/yucai.holding.v1.HoldingService/Summary",
		"/yucai.auth.v1.AuthService/GetProfile",
	} {
		if err := runInterceptor(t, c, withTenant(context.Background(), tid), m); err != nil {
			t.Fatalf("%s must pass while frozen: %v", m, err)
		}
	}
}

func TestFreezeInterceptorUnknownMethodAllowed(t *testing.T) {
	tid := uuid.New()
	c := &fakeChecker{frozen: map[uuid.UUID]bool{tid: true}}
	if err := runInterceptor(t, c, withTenant(context.Background(), tid), "/yucai.sync.v1.SyncService/PushChanges"); err != nil {
		t.Fatalf("unknown (unlisted write) defaults to allow: %v", err)
	}
}

func TestFreezeInterceptorUnfrozenPasses(t *testing.T) {
	tid := uuid.New()
	c := &fakeChecker{frozen: map[uuid.UUID]bool{}}
	if err := runInterceptor(t, c, withTenant(context.Background(), tid), "/yucai.account.v1.AccountService/CreateAccount"); err != nil {
		t.Fatalf("unfrozen tenant write must pass: %v", err)
	}
}

func TestFreezeInterceptorNoTenantPasses(t *testing.T) {
	c := &fakeChecker{frozen: map[uuid.UUID]bool{}}
	if err := runInterceptor(t, c, context.Background(), "/yucai.account.v1.AccountService/CreateAccount"); err != nil {
		t.Fatalf("no-tenant context must pass: %v", err)
	}
}
