package tests

import (
	"context"
	"database/sql"
	"net"
	"strings"
	"testing"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	feedbackrepo "github.com/yucai/server/internal/feedback/adapter/driven/repository"
	feedbackgrpc "github.com/yucai/server/internal/feedback/adapter/driving/grpc"
	feedbackapp "github.com/yucai/server/internal/feedback/application"
	feedbackent "github.com/yucai/server/internal/feedback/ent"
	feedbackpb "github.com/yucai/server/internal/proto/feedback/v1"
	tagpb "github.com/yucai/server/internal/proto/tag/v1"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	taggrpc "github.com/yucai/server/internal/tag/adapter/driving/grpc"
	tagapp "github.com/yucai/server/internal/tag/application"
	tagent "github.com/yucai/server/internal/tag/ent"
	"github.com/yucai/server/pkg/middleware"
)

// feedbackTestSecret / feedbackTestIssuer mirror the authz-matrix constants:
// a local HMAC key + issuer shared by the test TokenService and the real
// AuthInterceptor running in the chain (the interceptor's package-level
// TokenService is swapped in setupFeedbackHarness).
const (
	feedbackTestSecret = "feedback-integration-test-secret"
	feedbackTestIssuer = "yucai-server-test"
)

// feedbackBodyMedium is a realistic mid-length feedback body.
const feedbackBodyMedium = "The transaction list occasionally freezes for a second when scrolling quickly past the month boundary."

// setupFeedbackHarness wires the real feedback stack (ent repo → application
// service → gRPC handler with rate limiter) behind a bufconn gRPC server
// running the FULL production interceptor chain, and additionally registers
// the existing TagService so the anonymous-allowlist regression can assert a
// business RPC without credentials still gets Unauthenticated.
//
// All SubmitFeedback calls in these tests go out WITHOUT authorization
// metadata — the wire-level proof that the method is anonymously reachable.
func setupFeedbackHarness(t *testing.T) (client feedbackpb.FeedbackServiceClient, tags tagpb.TagServiceClient, entCl *feedbackent.Client, db *sql.DB) {
	t.Helper()

	// 1. in-memory sqlite + feedback schema (global table, no tenant column).
	db, err := sql.Open("sqlite", "file:feedback_"+sanitizeSQLiteName(t.Name())+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	entCl = feedbackent.NewClient(feedbackent.Driver(drv))
	if err := entCl.Schema.Create(context.Background()); err != nil {
		t.Fatalf("create feedback schema: %v", err)
	}
	t.Cleanup(func() { entCl.Close() })

	// 2. tag schema on its own in-memory DB (only used for the auth-surface
	// regression — its handler must exist so the call gets past Unimplemented
	// and dies in AuthInterceptor exactly as in production).
	tagDB, err := sql.Open("sqlite", "file:feedback_tag_"+sanitizeSQLiteName(t.Name())+"?mode=memory&_fk=1")
	if err != nil {
		t.Fatalf("open tag sqlite: %v", err)
	}
	t.Cleanup(func() { tagDB.Close() })
	tagDB.SetMaxOpenConns(1)
	if _, err := tagDB.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable tag foreign keys: %v", err)
	}
	tagDrv := entsql.OpenDB(dialect.SQLite, tagDB)
	tagClientEnt := tagent.NewClient(tagent.Driver(tagDrv))
	if err := tagClientEnt.Schema.Create(context.Background()); err != nil {
		t.Fatalf("create tag schema: %v", err)
	}
	t.Cleanup(func() { tagClientEnt.Close() })

	// 3. real stack: repo → service → handler(+rate limiter).
	repo := feedbackrepo.NewFeedbackRepository(entCl)
	svc := feedbackapp.NewService(repo)
	limiter := feedbackgrpc.NewFeedbackRateLimiter()
	handler := feedbackgrpc.NewFeedbackHandler(svc, limiter)

	tagHandler := taggrpc.NewTagHandler(tagapp.NewService(tagrepo.NewTagRepository(tagClientEnt)))

	// 4. bufconn server with the production interceptor chain (same order as
	// wire/providers.go provideGRPCServer). AuthInterceptor reads the
	// package-level TokenService, so pin one with the local test secret.
	prevTS := middleware.TokenService
	prevBL := middleware.TokenBlacklist
	middleware.TokenService = authjwt.NewTokenService(feedbackTestSecret, feedbackTestIssuer)
	middleware.TokenBlacklist = nil
	t.Cleanup(func() {
		middleware.TokenService = prevTS
		middleware.TokenBlacklist = prevBL
	})

	lis := bufconn.Listen(1024 * 1024)
	srv := grpc.NewServer(grpc.ChainUnaryInterceptor(
		middleware.UnaryLoggingInterceptor,
		middleware.AuthInterceptor,
		middleware.RestoreFreezeInterceptor,
		middleware.RequireAdmin,
	))
	feedbackpb.RegisterFeedbackServiceServer(srv, handler)
	tagpb.RegisterTagServiceServer(srv, tagHandler)
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

	return feedbackpb.NewFeedbackServiceClient(conn), tagpb.NewTagServiceClient(conn), entCl, db
}

// validFeedbackRequest returns a fully-populated, valid submission request
// (issue / medium body / all four diagnostics fields / optional contact).
func validFeedbackRequest() *feedbackpb.SubmitFeedbackRequest {
	return &feedbackpb.SubmitFeedbackRequest{
		Type:    feedbackpb.FeedbackType_ISSUE,
		Body:    feedbackBodyMedium,
		Contact: "user@example.com",
		Diagnostics: &feedbackpb.FeedbackDiagnostics{
			AppVersion:  "2.5.0+42",
			Platform:   "windows",
			AccountMode: "guest",
			ThemeMode:  "dark",
		},
	}
}

// TestFeedback_SubmitFeedback_PersistsRow: an anonymous submission (no
// authorization metadata) succeeds, returns id>0, and persists a row whose
// fields round-trip — on a GLOBAL table that must not carry a tenant column.
func TestFeedback_SubmitFeedback_PersistsRow(t *testing.T) {
	client, _, entCl, db := setupFeedbackHarness(t)
	ctx := context.Background()

	resp, err := client.SubmitFeedback(ctx, validFeedbackRequest())
	if err != nil {
		t.Fatalf("SubmitFeedback failed: %v", err)
	}
	if resp == nil || resp.Id <= 0 {
		t.Fatalf("expected positive id, got %+v", resp)
	}

	// Row check via ent: exactly one row, all fields round-tripped.
	rows, err := entCl.Feedback.Query().All(ctx)
	if err != nil {
		t.Fatalf("query feedback rows: %v", err)
	}
	if len(rows) != 1 {
		t.Fatalf("expected 1 feedback row, got %d", len(rows))
	}
	got := rows[0]
	if int64(got.ID) != resp.Id {
		t.Errorf("row id %d != response id %d", got.ID, resp.Id)
	}
	if got.Type != "issue" {
		t.Errorf("type = %q, want issue", got.Type)
	}
	if got.Body != feedbackBodyMedium {
		t.Errorf("body mismatch: %q", got.Body)
	}
	if got.Contact != "user@example.com" {
		t.Errorf("contact = %q, want user@example.com", got.Contact)
	}
	if got.AppVersion != "2.5.0+42" || got.Platform != "windows" ||
		got.AccountMode != "guest" || got.ThemeMode != "dark" {
		t.Errorf("diagnostics mismatch: %q/%q/%q/%q",
			got.AppVersion, got.Platform, got.AccountMode, got.ThemeMode)
	}
	if got.CreatedAt.IsZero() {
		t.Error("created_at not persisted")
	}

	// Global-table guarantee: the physical schema must have NO tenant_id
	// column (feedback is cross-tenant by design — anonymous submitters have
	// no tenant), and must carry the expected columns.
	cols := map[string]bool{}
	rs, err := db.Query("PRAGMA table_info(feedbacks)")
	if err != nil {
		t.Fatalf("pragma table_info: %v", err)
	}
	for rs.Next() {
		var cid int
		var name, ctype string
		var notNull, pk int
		var dflt sql.NullString
		if err := rs.Scan(&cid, &name, &ctype, &notNull, &dflt, &pk); err != nil {
			t.Fatalf("scan pragma row: %v", err)
		}
		cols[name] = true
	}
	rs.Close()
	if cols["tenant_id"] {
		t.Error("feedbacks table must NOT have a tenant_id column")
	}
	for _, want := range []string{"id", "type", "body", "contact", "app_version", "platform", "account_mode", "theme_mode", "created_at"} {
		if !cols[want] {
			t.Errorf("feedbacks table missing column %q (have %v)", want, cols)
		}
	}
}

// TestFeedback_SubmitFeedback_ValidationRejections: malformed submissions are
// rejected with InvalidArgument — unspecified type, empty body, body over 1000
// runes, contact over 100 runes.
func TestFeedback_SubmitFeedback_ValidationRejections(t *testing.T) {
	client, _, _, _ := setupFeedbackHarness(t)
	ctx := context.Background()

	cases := []struct {
		name string
		req  *feedbackpb.SubmitFeedbackRequest
	}{
		{"unspecified_type", func() *feedbackpb.SubmitFeedbackRequest {
			r := validFeedbackRequest()
			r.Type = feedbackpb.FeedbackType_FEEDBACK_TYPE_UNSPECIFIED
			return r
		}()},
		{"empty_body", func() *feedbackpb.SubmitFeedbackRequest {
			r := validFeedbackRequest()
			r.Body = ""
			return r
		}()},
		{"body_1001_runes", func() *feedbackpb.SubmitFeedbackRequest {
			r := validFeedbackRequest()
			r.Body = strings.Repeat("正", 1001)
			return r
		}()},
		{"contact_101_runes", func() *feedbackpb.SubmitFeedbackRequest {
			r := validFeedbackRequest()
			r.Contact = strings.Repeat("c", 101)
			return r
		}()},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			_, err := client.SubmitFeedback(ctx, c.req)
			assertCode(t, err, codes.InvalidArgument)
		})
	}

	// Boundary sanity: exactly 1000 body runes and 100 contact runes pass.
	r := validFeedbackRequest()
	r.Body = strings.Repeat("正", 1000)
	r.Contact = strings.Repeat("c", 100)
	if _, err := client.SubmitFeedback(ctx, r); err != nil {
		t.Errorf("boundary-length submission should pass: %v", err)
	}
}

// TestFeedback_SubmitFeedback_DiagnosticsValidation: each of the four
// diagnostics fields is capped at 64 runes server-side (fix round 1, NFR-3
// review item) — a 65-rune field is InvalidArgument, exactly 64 passes.
// Separate harness so the rate-limit budget (5/min per peer) is not shared
// with the validation test above.
func TestFeedback_SubmitFeedback_DiagnosticsValidation(t *testing.T) {
	client, _, _, _ := setupFeedbackHarness(t)
	ctx := context.Background()

	// 65 runes in a diagnostics field (app_version here; the cap applies to
	// all four fields uniformly via the domain validator) → InvalidArgument.
	over := validFeedbackRequest()
	over.Diagnostics.AppVersion = strings.Repeat("v", 65)
	_, err := client.SubmitFeedback(ctx, over)
	assertCode(t, err, codes.InvalidArgument)

	// Boundary: exactly 64 runes passes and persists.
	at := validFeedbackRequest()
	at.Diagnostics.AppVersion = strings.Repeat("v", 64)
	if _, err := client.SubmitFeedback(ctx, at); err != nil {
		t.Errorf("64-rune diagnostics field should pass: %v", err)
	}
}

// TestFeedback_SubmitFeedback_RateLimit: the same source IP may submit
// feedbackRatePerMin (5) submissions per window; the 6th consecutive call is
// rejected with ResourceExhausted while a DIFFERENT IP is unaffected.
func TestFeedback_SubmitFeedback_RateLimit(t *testing.T) {
	client, _, _, _ := setupFeedbackHarness(t)
	ctx := context.Background()

	// bufconn conns share one peer address, so these wire calls exercise the
	// same per-IP bucket: first 5 pass, 6th is ResourceExhausted.
	for i := 1; i <= 5; i++ {
		resp, err := client.SubmitFeedback(ctx, validFeedbackRequest())
		if err != nil {
			t.Fatalf("call %d/5 should pass, got %v", i, err)
		}
		if resp.Id <= 0 {
			t.Fatalf("call %d/5: expected positive id", i)
		}
	}
	_, err := client.SubmitFeedback(ctx, validFeedbackRequest())
	assertCode(t, err, codes.ResourceExhausted)
	if !strings.Contains(status.Convert(err).Message(), "rate limit") {
		t.Errorf("error message should mention the rate limit, got: %v", err)
	}

	// Different IP unaffected: invoke the handler directly with synthetic
	// peer addresses (wire-level peer spoofing is not possible over one
	// bufconn pair, so per-IP keying is proven through the same real
	// handler+limiter path the interceptor chain dispatches to).
	handler := newDirectFeedbackHandler(t)
	ipA := peerCtx(ctx, "198.51.100.10")
	for i := 1; i <= 5; i++ {
		if _, err := handler.SubmitFeedback(ipA, validFeedbackRequest()); err != nil {
			t.Fatalf("direct call %d/5 from IP A should pass, got %v", i, err)
		}
	}
	_, err = handler.SubmitFeedback(ipA, validFeedbackRequest())
	assertCode(t, err, codes.ResourceExhausted)

	ipB := peerCtx(ctx, "198.51.100.99")
	respB, err := handler.SubmitFeedback(ipB, validFeedbackRequest())
	if err != nil {
		t.Fatalf("different IP must be unaffected by IP A exhaustion: %v", err)
	}
	if respB.Id <= 0 {
		t.Fatalf("different-IP submission should return positive id, got %+v", respB)
	}
}

// TestFeedback_AnonymousReachability_And_AuthSurfaceRegression: SubmitFeedback
// must succeed with NO authentication metadata at all, while any other
// business RPC called the same way must still be Unauthenticated — the
// allowlist must not leak to the rest of the surface.
func TestFeedback_AnonymousReachability_And_AuthSurfaceRegression(t *testing.T) {
	client, tags, _, _ := setupFeedbackHarness(t)
	ctx := context.Background()

	// Plain context — no metadata attached anywhere in this test.
	resp, err := client.SubmitFeedback(ctx, validFeedbackRequest())
	if err != nil {
		t.Fatalf("anonymous SubmitFeedback should succeed, got %v", err)
	}
	if resp.Id <= 0 {
		t.Fatalf("anonymous submission should return positive id, got %+v", resp)
	}

	// Regression on the allowlist surface: an existing business RPC without
	// credentials must still be Unauthenticated.
	_, err = tags.ListTags(ctx, &tagpb.ListTagsRequest{})
	assertCode(t, err, codes.Unauthenticated)
}

// peerCtx decorates ctx with a synthetic gRPC peer address (used to prove
// per-IP rate-limit keying through the real handler).
func peerCtx(ctx context.Context, ip string) context.Context {
	return peer.NewContext(ctx, &peer.Peer{Addr: &net.TCPAddr{IP: net.ParseIP(ip), Port: 50051}})
}

// newDirectFeedbackHandler builds a real handler stack on its own in-memory
// DB for direct (non-wire) invocation with synthetic peers.
func newDirectFeedbackHandler(t *testing.T) *feedbackgrpc.FeedbackHandler {
	t.Helper()
	db, err := sql.Open("sqlite", "file:feedback_rl_"+sanitizeSQLiteName(t.Name())+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	drv := entsql.OpenDB(dialect.SQLite, db)
	entCl := feedbackent.NewClient(feedbackent.Driver(drv))
	if err := entCl.Schema.Create(context.Background()); err != nil {
		t.Fatalf("create feedback schema: %v", err)
	}
	t.Cleanup(func() { entCl.Close() })
	return feedbackgrpc.NewFeedbackHandler(
		feedbackapp.NewService(feedbackrepo.NewFeedbackRepository(entCl)),
		feedbackgrpc.NewFeedbackRateLimiter(),
	)
}
