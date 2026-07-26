package tests

import (
	"context"
	"database/sql"
	"net"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	pb "github.com/yucai/server/internal/proto/holding/v1"
	holdinggrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	"github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/application"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/pkg/middleware"
)

// authzTestSecret is the HMAC key shared between the test TokenService and the
// AuthInterceptor under test. Any constant works; this is local to the matrix.
const authzTestSecret = "authz-matrix-test-secret"

// authzTestIssuer is the iss claim stamped on forged tokens. Must match what
// the test TokenService is configured with so the post-T02 Parser accepts them.
const authzTestIssuer = "yucai-server-test"

// TestAuthz_GetHoldingPerformance_CrossTenant is the handler/wire-layer twin
// of TestGetHoldingPerformance_RejectsCrossTenant (service-layer, fixed in T01
// phase 1). Caller B authenticates with tenantB's tid and presents tenantA's
// holding_id; the handler must thread tenantB's tid through to the repo's
// tenant-scoped FindByID, which returns NotFound — no existence leak, no cost
// basis, no price curve. The owner sanity-check at the start guards against a
// regression that over-rejects (e.g. RequireAdmin accidentally absorbing the
// read RPC).
//
// What this regression gate catches that the service-layer test cannot:
//   - handler ctx extraction (getTenantID) silently dropping the tid again;
//   - AuthInterceptor failing to inject tid into ctx;
//   - a future refactor that re-introduces the IDOR at the wire boundary.
func TestAuthz_GetHoldingPerformance_CrossTenant(t *testing.T) {
	client, svc, phRepo, holdRepo, tenantA, accountA := setupAuthzMatrix(t)
	ctx := context.Background()

	// Seed tenantA's baseline holding (buy 100 @ ¥100, current ¥130).
	_, holdingA := seedBaselineHolding(t, ctx, svc, phRepo, holdRepo, tenantA, accountA)

	// Sanity: tenantA owner can read its own holding performance.
	userA := uuid.New()
	ownerCtx := withToken(ctx, tokenFor(t, userA, tenantA, false /*non-admin OK for read*/))
	if _, err := client.GetHoldingPerformance(ownerCtx, &pb.GetHoldingPerformanceRequest{
		HoldingId: holdingA.ID.String(),
		Range:     pb.CurveRange_CURVE_RANGE_MONTH,
	}); err != nil {
		t.Fatalf("owner read: expected success, got %v", err)
	}

	// tenantB caller presents tenantA's holding_id — must NotFound (no leak).
	tenantB, userB := uuid.New(), uuid.New()
	crossCtx := withToken(ctx, tokenFor(t, userB, tenantB, false))
	_, err := client.GetHoldingPerformance(crossCtx, &pb.GetHoldingPerformanceRequest{
		HoldingId: holdingA.ID.String(),
		Range:     pb.CurveRange_CURVE_RANGE_MONTH,
	})
	assertCode(t, err, codes.NotFound)
}

// TestAuthz_SecuritiesWrite_NonAdminDenied pins the fail-closed rule for the
// four securities write RPCs guarded by RequireAdmin: a non-admin caller with
// a valid token must be rejected with PermissionDenied BEFORE the handler runs.
// Table-driven so the full whitelist is scanned in one test, making
// regressions (a method dropped from adminGuardedMethods, or a new RPC added
// without admin gating) visible.
func TestAuthz_SecuritiesWrite_NonAdminDenied(t *testing.T) {
	client, svc, _, _, tenantA, _ := setupAuthzMatrix(t)
	ctx := context.Background()

	// Pre-create a security so UpdateSecurityPrice has a valid target. The
	// assertion is about PermissionDenied, not InvalidArgument, and non-admin
	// callers cannot reach the handler — so seed via service directly.
	sec, err := svc.CreateSecurity(ctx, application.CreateSecurityRequest{
		Symbol: "600519.SH", Name: "Kweichow Moutai",
		SecurityType: domain.SecurityTypeStock, Exchange: "SSE", CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("seed security: %v", err)
	}

	user := uuid.New()
	authCtx := withToken(ctx, tokenFor(t, user, tenantA, false /*non-admin*/))

	cases := []struct {
		name string
		call func() error
	}{
		{"CreateSecurity", func() error {
			_, err := client.CreateSecurity(authCtx, &pb.CreateSecurityRequest{
				Symbol: "000001.SZ", Name: "Ping An Bank",
				SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
				Exchange: "SZSE", CurrencyCode: "CNY",
			})
			return err
		}},
		{"UpdateSecurityPrice", func() error {
			_, err := client.UpdateSecurityPrice(authCtx, &pb.UpdatePriceRequest{
				SecurityId: sec.ID.String(), PriceCents: 13500,
			})
			return err
		}},
		{"SyncPrices", func() error {
			_, err := client.SyncPrices(authCtx, &pb.SyncPricesRequest{})
			return err
		}},
		{"BackfillPriceHistory", func() error {
			_, err := client.BackfillPriceHistory(authCtx, &pb.BackfillPriceHistoryRequest{
				Range: pb.CurveRange_CURVE_RANGE_MONTH,
			})
			return err
		}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := c.call()
			assertCode(t, err, codes.PermissionDenied)
		})
	}
}

// TestAuthz_SecuritiesWrite_AdminAllowed is the positive twin of
// NonAdminDenied: with is_admin=true the same four RPCs must NOT be rejected
// at the authz layer. They may still fail downstream (SyncPrices /
// BackfillPriceHistory return Internal when no price provider is configured in
// the test env), so the matrix only asserts the returned code is anything
// other than PermissionDenied — i.e. RequireAdmin let the call through.
func TestAuthz_SecuritiesWrite_AdminAllowed(t *testing.T) {
	client, svc, _, _, tenantA, _ := setupAuthzMatrix(t)
	ctx := context.Background()

	sec, err := svc.CreateSecurity(ctx, application.CreateSecurityRequest{
		Symbol: "600519.SH", Name: "Kweichow Moutai",
		SecurityType: domain.SecurityTypeStock, Exchange: "SSE", CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("seed security: %v", err)
	}

	admin := uuid.New()
	authCtx := withToken(ctx, tokenFor(t, admin, tenantA, true /*admin*/))

	cases := []struct {
		name string
		call func() error
	}{
		{"CreateSecurity", func() error {
			_, err := client.CreateSecurity(authCtx, &pb.CreateSecurityRequest{
				Symbol: "000001.SZ", Name: "Ping An Bank",
				SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
				Exchange: "SZSE", CurrencyCode: "CNY",
			})
			return err
		}},
		{"UpdateSecurityPrice", func() error {
			_, err := client.UpdateSecurityPrice(authCtx, &pb.UpdatePriceRequest{
				SecurityId: sec.ID.String(), PriceCents: 13500,
			})
			return err
		}},
		{"SyncPrices", func() error {
			_, err := client.SyncPrices(authCtx, &pb.SyncPricesRequest{})
			return err
		}},
		{"BackfillPriceHistory", func() error {
			_, err := client.BackfillPriceHistory(authCtx, &pb.BackfillPriceHistoryRequest{
				Range: pb.CurveRange_CURVE_RANGE_MONTH,
			})
			return err
		}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			err := c.call()
			assertNotCode(t, err, codes.PermissionDenied)
		})
	}
}

// TestAuthz_NonGuardedRPCs_NotBlocked verifies RequireAdmin does not
// over-block: read RPCs (ListSecurities, GetHoldingPerformance) must accept
// both admin and non-admin tokens — the caller reaches normal handler logic.
// Catches a regression where the admin whitelist accidentally absorbs a read
// RPC (e.g. a copy-paste of FullMethod into adminGuardedMethods).
func TestAuthz_NonGuardedRPCs_NotBlocked(t *testing.T) {
	client, svc, phRepo, holdRepo, tenantA, accountA := setupAuthzMatrix(t)
	ctx := context.Background()

	_, holdingA := seedBaselineHolding(t, ctx, svc, phRepo, holdRepo, tenantA, accountA)

	cases := []struct {
		name    string
		isAdmin bool
		call    func(ctx context.Context) error
	}{
		{"ListSecurities_admin", true, func(ctx context.Context) error {
			_, err := client.ListSecurities(ctx, &pb.ListSecuritiesRequest{})
			return err
		}},
		{"ListSecurities_non_admin", false, func(ctx context.Context) error {
			_, err := client.ListSecurities(ctx, &pb.ListSecuritiesRequest{})
			return err
		}},
		{"GetHoldingPerformance_admin", true, func(ctx context.Context) error {
			_, err := client.GetHoldingPerformance(ctx, &pb.GetHoldingPerformanceRequest{
				HoldingId: holdingA.ID.String(), Range: pb.CurveRange_CURVE_RANGE_MONTH,
			})
			return err
		}},
		{"GetHoldingPerformance_non_admin", false, func(ctx context.Context) error {
			_, err := client.GetHoldingPerformance(ctx, &pb.GetHoldingPerformanceRequest{
				HoldingId: holdingA.ID.String(), Range: pb.CurveRange_CURVE_RANGE_MONTH,
			})
			return err
		}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			user := uuid.New()
			authCtx := withToken(ctx, tokenFor(t, user, tenantA, c.isAdmin))
			err := c.call(authCtx)
			assertNotCode(t, err, codes.PermissionDenied)
		})
	}
}

// TestAuthz_LegacyToken_SecuritiesWriteDenied pins the fail-closed behavior
// documented on GetAdminFromContext: a token issued before is_admin was added
// to Claims (no is_admin field in the JWT body) cannot write securities.
// ParseAccessToken returns IsAdmin=false for the absent field, and RequireAdmin
// rejects the call. This protects pre-upgrade clients / stale sessions from
// accidentally inheriting admin privileges after the rollout.
func TestAuthz_LegacyToken_SecuritiesWriteDenied(t *testing.T) {
	client, _, _, _, tenantA, _ := setupAuthzMatrix(t)
	ctx := context.Background()

	user := uuid.New()
	legacyCtx := withToken(ctx, legacyTokenFor(t, user, tenantA))

	_, err := client.CreateSecurity(legacyCtx, &pb.CreateSecurityRequest{
		Symbol: "600519.SH", Name: "Kweichow Moutai",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK,
		Exchange: "SSE", CurrencyCode: "CNY",
	})
	assertCode(t, err, codes.PermissionDenied)
}

// TestAuthz_MissingToken_Unauthenticated verifies that any caller without an
// "authorization" metadata header is rejected by AuthInterceptor before the
// handler runs. The bufconn path validates real metadata → ctx propagation:
// a missing header must surface as Unauthenticated, never reach the handler.
func TestAuthz_MissingToken_Unauthenticated(t *testing.T) {
	client, _, _, _, _, _ := setupAuthzMatrix(t)
	ctx := context.Background()

	// No withToken — plain context, no authorization metadata.
	_, err := client.GetHoldingPerformance(ctx, &pb.GetHoldingPerformanceRequest{
		HoldingId: uuid.New().String(), Range: pb.CurveRange_CURVE_RANGE_MONTH,
	})
	assertCode(t, err, codes.Unauthenticated)
}

// --- helpers ---

// setupAuthzMatrix wires a real ent-backed holding Service + HoldingHandler
// behind a bufconn gRPC server with the production interceptor chain
// (AuthInterceptor → RequireAdmin). Returns the gRPC client (for cross-tenant
// / admin-matrix calls that exercise the wire), plus the underlying service /
// repos and tenant IDs (for seeding fixtures directly via the service layer,
// bypassing auth — service methods do not check tenant auth themselves).
//
// The bufconn approach is preferred over direct middleware invocation because
// it exercises real gRPC metadata → ctx propagation, real interceptor ordering
// (AuthInterceptor first to inject is_admin, RequireAdmin second to read it),
// and real handler-level tenant extraction. A regression in any of those
// layers surfaces here, not just at the interceptor alone. Mirrors the
// setupPerformanceHarness sqlite + Service wiring pattern.
func setupAuthzMatrix(t *testing.T) (client pb.HoldingServiceClient, svc *application.Service, phRepo domain.PriceHistoryRepository, holdRepo domain.HoldingRepository, tenantA, accountA uuid.UUID) {
	t.Helper()

	// 1. in-memory sqlite + holding schema (mirrors setupPerformanceHarness).
	db, err := sql.Open("sqlite", "file:authz_"+sanitizeSQLiteName(t.Name())+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	entClient := holdingent.NewClient(holdingent.Driver(drv))
	if err := entClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("create holding schema: %v", err)
	}
	t.Cleanup(func() { entClient.Close() })

	secRepo := repository.NewSecurityRepository(entClient)
	holdRepo = repository.NewHoldingRepository(entClient)
	tradeRepo := repository.NewTradeRepository(entClient)
	snapRepo := repository.NewSnapshotRepository(entClient)
	phRepo = repository.NewPriceHistoryRepository(entClient)

	svc = application.NewService(secRepo, holdRepo, tradeRepo)
	svc.SetSnapshotRepository(snapRepo)
	svc.SetPriceHistoryRepository(phRepo)
	// rateRepo intentionally nil (all-CNY; rateForCode returns 1.0), mirroring
	// setupPerformanceHarness. priceRouter / historicalProvider intentionally
	// nil — SyncPrices / BackfillPriceHistory return Internal, which the
	// admin-allowed matrix asserts is NOT PermissionDenied.

	// 2. wire the production interceptor chain on a bufconn gRPC server.
	// AuthInterceptor reads the package-level middleware.TokenService, so we
	// install a test-secret TokenService (restored on cleanup). Order MUST be
	// AuthInterceptor first (parses JWT → injects is_admin) then RequireAdmin
	// (reads is_admin) — see pkg/middleware/admin.go.
	prevTS := middleware.TokenService
	middleware.TokenService = authjwt.NewTokenService(authzTestSecret, authzTestIssuer)
	// TokenBlacklist defaults to nil — AuthInterceptor skips the check when nil,
	// which is what this matrix wants (it exercises signature/admin logic only).
	prevBL := middleware.TokenBlacklist
	middleware.TokenBlacklist = nil
	t.Cleanup(func() {
		middleware.TokenService = prevTS
		middleware.TokenBlacklist = prevBL
	})

	// txnSvc + accountLookup are nil because the matrix only exercises RPCs
	// that don't touch the transaction double-write or from-account validation
	// (CreateSecurity, UpdateSecurityPrice, SyncPrices, BackfillPriceHistory,
	// ListSecurities, GetHoldingPerformance). HoldingHandler accepts nil here
	// because no method in the matrix dereferences these fields.
	handler := holdinggrpc.NewHoldingHandler(svc, nil, nil)

	lis := bufconn.Listen(1024 * 1024)
	srv := grpc.NewServer(grpc.ChainUnaryInterceptor(middleware.AuthInterceptor, middleware.RequireAdmin))
	pb.RegisterHoldingServiceServer(srv, handler)
	go func() { _ = srv.Serve(lis) }()
	t.Cleanup(func() { srv.Stop() })

	conn, err := grpc.DialContext(context.Background(), "bufnet",
		grpc.WithContextDialer(func(context.Context, string) (net.Conn, error) { return lis.Dial() }),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("dial bufnet: %v", err)
	}
	t.Cleanup(func() { conn.Close() })

	client = pb.NewHoldingServiceClient(conn)
	tenantA, accountA = uuid.New(), uuid.New()
	return client, svc, phRepo, holdRepo, tenantA, accountA
}

// sanitizeSQLiteName replaces characters illegal in sqlite DSN filenames
// (notably '/' from t.Run subtests) so a single setupAuthzMatrix call works
// even when the test nests subtests. Top-level matrix tests don't nest, but
// the guard keeps the helper reusable.
func sanitizeSQLiteName(s string) string {
	out := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '/' || c == '\\' || c == ':' || c == ' ' {
			out = append(out, '_')
		} else {
			out = append(out, c)
		}
	}
	return string(out)
}

// tokenFor returns a "Bearer <jwt>" header value for the given identity. The
// token carries user_id, tenant_id, and is_admin exactly like the production
// auth service. Tests attach this to outgoing gRPC metadata via withToken.
func tokenFor(t *testing.T, userID, tenantID uuid.UUID, isAdmin bool) string {
	t.Helper()
	ts := authjwt.NewTokenService(authzTestSecret, authzTestIssuer)
	tok, err := ts.GenerateAccessToken(userID, tenantID, isAdmin)
	if err != nil {
		t.Fatalf("generate access token: %v", err)
	}
	return "Bearer " + tok
}

// legacyTokenFor returns a "Bearer <jwt>" header value for a token issued
// BEFORE the is_admin claim existed (an old install that never logged out and
// is still presenting a pre-upgrade JWT). The token includes user_id and
// tenant_id but omits is_admin entirely. RequireAdmin must fail-closed
// (default non-admin) so this token cannot write securities.
//
// We forge the JWT with jwt.MapClaims directly (rather than reuse
// authjwt.Claims) so the is_admin field is genuinely absent from the JSON
// body — not just zero-valued. This is the realistic pre-upgrade shape.
func legacyTokenFor(t *testing.T, userID, tenantID uuid.UUID) string {
	t.Helper()
	now := time.Now()
	claims := jwt.MapClaims{
		"sub": userID.String(),
		"exp": now.Add(15 * time.Minute).Unix(),
		"iat": now.Unix(),
		// aud+iss are present so the post-T02 Parser accepts the token; the
		// scenario we're modeling is "is_admin rolled out and a stale client
		// still sends a pre-is_admin token" — aud/iss existed by then.
		"aud":       authjwt.AccessTokenAudience,
		"iss":       authzTestIssuer,
		"user_id":   userID.String(),
		"tenant_id": tenantID.String(),
		// is_admin intentionally ABSENT — mimics pre-upgrade token.
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := tok.SignedString([]byte(authzTestSecret))
	if err != nil {
		t.Fatalf("sign legacy token: %v", err)
	}
	return "Bearer " + signed
}

// withToken returns a ctx carrying the given "Bearer ..." value as outgoing
// gRPC "authorization" metadata, matching what the production client sends.
func withToken(ctx context.Context, bearer string) context.Context {
	return metadata.AppendToOutgoingContext(ctx, "authorization", bearer)
}

// assertCode verifies err carries the expected gRPC status code.
func assertCode(t *testing.T, err error, want codes.Code) {
	t.Helper()
	if status.Code(err) != want {
		t.Fatalf("status code: got %v, want %v (err=%v)", status.Code(err), want, err)
	}
}

// assertNotCode verifies err does NOT carry the given gRPC status code. Used
// for "admin allowed" / "non-guarded pass-through" cases where the call may
// legitimately fail for other reasons (e.g. SyncPrices hits no price provider
// in the test env) — the matrix only asserts it isn't blocked at the authz
// layer.
func assertNotCode(t *testing.T, err error, blocked codes.Code) {
	t.Helper()
	if status.Code(err) == blocked {
		t.Fatalf("expected NOT %v, got exactly that (err=%v)", blocked, err)
	}
}
