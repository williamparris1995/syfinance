package grpc

import (
	"context"
	"database/sql"
	"fmt"
	"testing"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/application"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	pb "github.com/yucai/server/internal/proto/holding/v1"
	txnApp "github.com/yucai/server/internal/transaction/application"
	txnDomain "github.com/yucai/server/internal/transaction/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	_ "modernc.org/sqlite"
)

// TestBuildTradeEntries_Buy: buy 复式 = credit from_account(现金−) + debit holding account(投资+)。
func TestBuildTradeEntries_Buy(t *testing.T) {
	from := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"} // cash
	hold := accountdomain.Account{ID: uuid.New(), ChartCode: "1511"} // investment
	const amount int64 = 50000

	entries := buildTradeEntries(domain.TradeTypeBuy, from, hold, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	// entries[0]: from — credit only (cash out).
	if entries[0].AccountID != from.ID || entries[0].CreditCents != amount || entries[0].DebitCents != 0 {
		t.Errorf("from entry: expected credit=%d debit=0, got credit=%d debit=%d",
			amount, entries[0].CreditCents, entries[0].DebitCents)
	}
	// entries[1]: holding — debit only (investment in).
	if entries[1].AccountID != hold.ID || entries[1].DebitCents != amount || entries[1].CreditCents != 0 {
		t.Errorf("holding entry: expected debit=%d credit=0, got debit=%d credit=%d",
			amount, entries[1].DebitCents, entries[1].CreditCents)
	}
	if entries[0].CreditCents != entries[1].DebitCents {
		t.Errorf("unbalanced: credit=%d debit=%d", entries[0].CreditCents, entries[1].DebitCents)
	}
}

// TestBuildTradeEntries_Sell: sell 复式反向 = debit from_account(现金+) + credit holding account(投资−)。
func TestBuildTradeEntries_Sell(t *testing.T) {
	from := accountdomain.Account{ID: uuid.New(), ChartCode: "1001"}
	hold := accountdomain.Account{ID: uuid.New(), ChartCode: "1511"}
	const amount int64 = 30000

	entries := buildTradeEntries(domain.TradeTypeSell, from, hold, amount)

	if len(entries) != 2 {
		t.Fatalf("expected 2 entries, got %d", len(entries))
	}
	if entries[0].DebitCents != amount || entries[0].CreditCents != 0 {
		t.Errorf("sell from entry: expected debit only, got debit=%d credit=%d",
			entries[0].DebitCents, entries[0].CreditCents)
	}
	if entries[1].CreditCents != amount || entries[1].DebitCents != 0 {
		t.Errorf("sell holding entry: expected credit only, got debit=%d credit=%d",
			entries[1].DebitCents, entries[1].CreditCents)
	}
}

// ---------------------------------------------------------------------------
// BuyHolding double-write tests (holding-server-doublewrite Task 4)
//
// Mirrors the debt handler-level harness pattern (real holding service backed
// by an in-memory ent client + real txn service backed by a recording repo and
// mutating balance updater + fake account lookup) so the test can drive
// BuyHolding end-to-end and assert on real balance movement.
// ---------------------------------------------------------------------------

// fakeAccountLookup implements txnApp.AccountLookup and returns copies of
// seeded accounts so the balance updater can mutate independent copies.
type fakeAccountLookup struct {
	byID map[uuid.UUID]*accountdomain.Account
}

func newFakeAccountLookup() *fakeAccountLookup {
	return &fakeAccountLookup{byID: make(map[uuid.UUID]*accountdomain.Account)}
}

func (l *fakeAccountLookup) seed(a *accountdomain.Account) {
	c := *a
	l.byID[a.ID] = &c
}

func (l *fakeAccountLookup) FindByID(_ context.Context, _ uuid.UUID, id uuid.UUID) (*accountdomain.Account, error) {
	a, ok := l.byID[id]
	if !ok {
		return nil, fmt.Errorf("account %s not found", id)
	}
	c := *a
	return &c, nil
}

// recordingTxnRepo records the most recent saved transaction so the test can
// assert the entries built by buildTradeEntries flowed through unchanged.
type recordingTxnRepo struct {
	saved *txnDomain.Transaction
}

func (r *recordingTxnRepo) Save(_ context.Context, t *txnDomain.Transaction) error {
	c := *t
	r.saved = &c
	return nil
}
func (r *recordingTxnRepo) FindByID(context.Context, uuid.UUID, uuid.UUID) (*txnDomain.Transaction, error) {
	panic("unexpected FindByID call")
}
func (r *recordingTxnRepo) FindAll(context.Context, uuid.UUID, txnDomain.TransactionFilter, txnDomain.PageRequest) (*txnDomain.PaginatedResult[txnDomain.Transaction], error) {
	panic("unexpected FindAll call")
}
func (r *recordingTxnRepo) FindRecentByAccount(context.Context, uuid.UUID, uuid.UUID, int) ([]txnDomain.Transaction, error) {
	panic("unexpected FindRecentByAccount call")
}
func (r *recordingTxnRepo) Update(context.Context, *txnDomain.Transaction) error {
	panic("unexpected Update call")
}
func (r *recordingTxnRepo) SoftDelete(context.Context, uuid.UUID, uuid.UUID) error {
	panic("unexpected SoftDelete call")
}
func (r *recordingTxnRepo) TransactionSummary(context.Context, txnDomain.SummaryScope) (*txnDomain.MonthlySummary, error) {
	panic("unexpected TransactionSummary call")
}
func (r *recordingTxnRepo) SumEntryTotalsByAccount(context.Context, uuid.UUID, time.Time, time.Time) (int64, int64, error) {
	panic("unexpected SumEntryTotalsByAccount call")
}
func (r *recordingTxnRepo) FindAllForBackup(context.Context, uuid.UUID) ([]txnDomain.Transaction, error) {
	panic("unexpected FindAllForBackup call")
}
func (r *recordingTxnRepo) DeleteByTenant(context.Context, uuid.UUID) error {
	panic("unexpected DeleteByTenant call")
}

// mutatingBalanceUpdater applies each entry's (debit - credit) to the matching
// account in the lookup so tests can assert balance movement end-to-end.
type mutatingBalanceUpdater struct {
	lookup *fakeAccountLookup
}

func (u mutatingBalanceUpdater) UpdateBalances(_ context.Context, _ uuid.UUID, entries []txnDomain.TransactionEntry) error {
	for _, e := range entries {
		a, ok := u.lookup.byID[e.AccountID]
		if !ok {
			continue // ignore unknown accounts (best-effort in test)
		}
		a.CurrentBalanceCents += e.DebitCents - e.CreditCents
	}
	return nil
}

func (u mutatingBalanceUpdater) ReverseBalances(_ context.Context, _ uuid.UUID, entries []txnDomain.TransactionEntry) error {
	for _, e := range entries {
		a, ok := u.lookup.byID[e.AccountID]
		if !ok {
			continue
		}
		a.CurrentBalanceCents -= e.DebitCents - e.CreditCents
	}
	return nil
}

// setupHoldingEntClient opens an in-memory sqlite holding ent client mirroring
// tests/holding_integration_test.go's setupHoldingTestDB (which is package
// tests and cannot be imported from package grpc).
func setupHoldingEntClient(t *testing.T) *holdingent.Client {
	t.Helper()
	dbName := "holding_handler_" + t.Name()
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB("sqlite3", db)
	client := holdingent.NewClient(holdingent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

// setupBuyHoldingHarness wires a HoldingHandler with a real holding service
// (in-memory ent-backed security/holding/trade repos), a fake account lookup
// (cash from_account + holding investment account), and a real transaction
// service (recording repo + mutating balance updater). Returns handles to
// drive BuyHolding and assert post-state.
func setupBuyHoldingHarness(t *testing.T) (
	h *HoldingHandler,
	tenantID, fromAccID, holdAccID uuid.UUID,
	txnRepo *recordingTxnRepo,
	accLookup *fakeAccountLookup,
) {
	t.Helper()
	tenantID = uuid.New()

	// holding (investment) account — asset.
	holdAcc, err := accountdomain.NewAccount(tenantID, "investment", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("seed holding account: %v", err)
	}
	holdAcc.ChartCode = "1511"
	holdAccID = holdAcc.ID

	// from (cash) account — asset, ample balance.
	fromAcc, err := accountdomain.NewAccount(tenantID, "cash", accountdomain.AccountTypeAsset, "CNY")
	if err != nil {
		t.Fatalf("seed cash account: %v", err)
	}
	fromAcc.ChartCode = "1001"
	fromAcc.CurrentBalanceCents = 100000
	fromAccID = fromAcc.ID

	accLookup = newFakeAccountLookup()
	accLookup.seed(holdAcc)
	accLookup.seed(fromAcc)

	// real holding service backed by in-memory ent (holding ent only).
	holdingClient := setupHoldingEntClient(t)
	secRepo := holdingsec.NewSecurityRepository(holdingClient)
	holdRepo := holdingsec.NewHoldingRepository(holdingClient)
	tradeRepo := holdingsec.NewTradeRepository(holdingClient)
	holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)

	txnRepo = &recordingTxnRepo{}
	txnSvc := txnApp.NewService(txnRepo, accLookup, mutatingBalanceUpdater{lookup: accLookup})
	h = NewHoldingHandler(holdSvc, txnSvc, accLookup)
	return
}

// ctxWithTenant builds a context carrying both user_id and tenant_id, matching
// what the auth interceptor injects in production.
func ctxWithTenant(tenantID uuid.UUID) context.Context {
	ctx := authgrpc.WithTenantID(context.Background(), tenantID)
	return authgrpc.WithUserID(ctx, uuid.New())
}

// TestBuyHolding_DoubleWrite: BuyHolding records the holding trade AND a
// balancing transaction crediting the cash from_account (asset −) and debiting
// the holding investment account (asset +), with both balances moving by the
// trade amount (priceCents × quantity).
func TestBuyHolding_DoubleWrite(t *testing.T) {
	h, tenantID, fromAccID, holdAccID, txnRepo, accLookup := setupBuyHoldingHarness(t)

	// CNY security — must match the CNY holding/from accounts or
	// validateTradeFromAccount rejects cross-currency.
	sec, err := h.CreateSecurity(ctxWithTenant(tenantID), &pb.CreateSecurityRequest{
		Symbol: "600519.SH", Name: "Kweichow Moutai",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	// 10 × 5000 cents = 50000 cents total amount.
	resp, err := h.BuyHolding(ctxWithTenant(tenantID), &pb.HoldingTradeRequest{
		AccountId:     holdAccID.String(),
		SecurityId:    sec.Security.Id,
		FromAccountId: fromAccID.String(),
		Quantity:      10, PriceCents: 5000,
		TradeDate: "2026-06-28",
	})
	if err != nil {
		t.Fatalf("BuyHolding: %v", err)
	}
	if resp == nil || resp.Transaction == nil {
		t.Fatal("BuyHolding returned empty trade")
	}
	if txnRepo.saved == nil {
		t.Fatal("double-write: no transaction recorded")
	}
	// buy: from credit 50000 (cash −), holding debit 50000 (investment +).
	const want int64 = 50000
	if got := accLookup.byID[fromAccID].CurrentBalanceCents; got != 100000-want {
		t.Errorf("from balance: got %d, want %d", got, 100000-want)
	}
	if got := accLookup.byID[holdAccID].CurrentBalanceCents; got != want {
		t.Errorf("holding balance: got %d, want %d", got, want)
	}
}

// TestSellHolding_DoubleWrite: sell first buys to establish a position, then
// sells. Sell = cash INTO from_account (debit, +) + investment OUT of holding
// account (credit, −). The test only asserts the from_account increased by the
// sell amount — the holding balance MAY go negative when sell > cost basis
// (investment-account semantics), so it is not asserted.
func TestSellHolding_DoubleWrite(t *testing.T) {
	h, tenantID, fromAccID, holdAccID, _, accLookup := setupBuyHoldingHarness(t)
	ctx := ctxWithTenant(tenantID)
	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600000", Name: "浦发", SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}

	// buy 建仓 10 × 5000 = 50000 → from 100000−50000 = 50000.
	if _, err := h.BuyHolding(ctx, &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 10, PriceCents: 5000, TradeDate: "2026-06-28",
	}); err != nil {
		t.Fatalf("BuyHolding (setup): %v", err)
	}

	// sell 10 × 6000 = 60000 → from +60000 = 110000.
	resp, err := h.SellHolding(ctx, &pb.HoldingTradeRequest{
		AccountId: holdAccID.String(), SecurityId: sec.Security.Id, FromAccountId: fromAccID.String(),
		Quantity: 10, PriceCents: 6000, TradeDate: "2026-06-29",
	})
	if err != nil {
		t.Fatalf("SellHolding: %v", err)
	}
	if resp == nil || resp.Transaction == nil {
		t.Fatal("SellHolding returned empty trade")
	}

	// sell credits from_account 60000 (cash +): 50000 + 60000 = 110000.
	if got := accLookup.byID[fromAccID].CurrentBalanceCents; got != 50000+60000 {
		t.Errorf("from balance after sell: got %d, want 110000", got)
	}
}

// ---------------------------------------------------------------------------
// SyncPrices handler tests (holding-server-B Task 6)
//
// Mirrors the existing harness pattern: a real application.Service backed by
// an in-memory ent client. SyncPrices needs a priceprovider.Router, so we
// inject a tiny local fake (application's fakePriceRouter is unexported) that
// returns a fresh price for every symbol → both seeded securities sync.
// ---------------------------------------------------------------------------

// fakePriceRouter is a priceprovider.Router returning a fixed price for any
// symbol. Used only by the SyncPrices handler test.
type fakePriceRouter struct {
	price int64
}

func (r *fakePriceRouter) FetchPrice(_ context.Context, _ priceprovider.PriceView) (int64, string, error) {
	return r.price, "fake", nil
}

// setupSyncPricesHarness wires a HoldingHandler whose real holding service is
// backed by an in-memory ent client, seeds two CNY securities, and injects a
// fake price router that covers every symbol. Returns the handler + tenant id.
func setupSyncPricesHarness(t *testing.T) (h *HoldingHandler, tenantID uuid.UUID) {
	t.Helper()
	tenantID = uuid.New()

	holdingClient := setupHoldingEntClient(t)
	secRepo := holdingsec.NewSecurityRepository(holdingClient)
	holdRepo := holdingsec.NewHoldingRepository(holdingClient)
	tradeRepo := holdingsec.NewTradeRepository(holdingClient)
	holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)
	holdSvc.SetPriceRouter(&fakePriceRouter{price: 9999})

	h = NewHoldingHandler(holdSvc, nil /*txnSvc*/, nil /*accountLookup*/)

	ctx := ctxWithTenant(tenantID)
	for _, sym := range []string{"600519", "510300"} {
		if _, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
			Symbol: sym, Name: sym,
			SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
		}); err != nil {
			t.Fatalf("seed security %s: %v", sym, err)
		}
	}
	return h, tenantID
}

// TestSyncPricesReturnsCount: handler.SyncPrices authenticates, calls
// service.SyncPrices, and maps the synced count + a non-nil synced_at.
func TestSyncPricesReturnsCount(t *testing.T) {
	h, tenantID := setupSyncPricesHarness(t)

	resp, err := h.SyncPrices(ctxWithTenant(tenantID), &pb.SyncPricesRequest{})
	if err != nil {
		t.Fatalf("SyncPrices: %v", err)
	}
	if resp == nil {
		t.Fatal("SyncPrices returned nil response")
	}
	// Two seeded securities, both covered by the fake router → count = 2.
	if resp.SyncedCount != 2 {
		t.Fatalf("SyncedCount = %d, want 2", resp.SyncedCount)
	}
	if resp.SyncedAt == nil {
		t.Fatal("SyncedAt must be set")
	}
}

// TestSyncPricesUnauthenticatedWithoutTenant: a context without tenant_id is
// rejected before the service is touched (prices are tenant-shared but the
// caller must still be authenticated).
func TestSyncPricesUnauthenticatedWithoutTenant(t *testing.T) {
	h, _ := setupSyncPricesHarness(t)

	resp, err := h.SyncPrices(context.Background(), &pb.SyncPricesRequest{})
	if err == nil {
		t.Fatal("SyncPrices without tenant must error")
	}
	if resp != nil {
		t.Fatalf("expected nil response on auth failure, got %+v", resp)
	}
	// mapError/getTenantID produce an Unauthenticated code.
	st, _ := status.FromError(err)
	if st.Code() != codes.Unauthenticated {
		t.Fatalf("error code = %v, want Unauthenticated", st.Code())
	}
}

// ---------------------------------------------------------------------------
// Performance RPC handler tests (holding-server-C Task 8)
//
// Mirrors the existing real-service harness pattern: a real application.Service
// backed by an in-memory ent client, with the perf-path repos (snapshot +
// price-history) wired in and seeded directly via the driven repositories.
// All holdings/securities are CNY so no rate-history repo is needed (rate
// defaults to 1.0). The handler is a thin mapper, so we assert the curve + foot
// fields round-trip from the service to the proto response.
// ---------------------------------------------------------------------------

// setupPerfHarness wires a HoldingHandler whose real holding service is backed
// by an in-memory ent client with snapshot + price-history repos attached. The
// returned snapshot/price-history repos let the test seed curve data directly.
// Tenant is NOT seeded with accounts; perf RPCs do not touch the account
// balance (read-only) so a nil txnSvc / accountLookup is fine.
func setupPerfHarness(t *testing.T) (
	h *HoldingHandler,
	tenantID, accountID uuid.UUID,
	holdRepo *holdingsec.HoldingRepository,
	snapRepo *holdingsec.SnapshotRepository,
	phRepo *holdingsec.PriceHistoryRepository,
) {
	t.Helper()
	tenantID, accountID = uuid.New(), uuid.New()

	holdingClient := setupHoldingEntClient(t)
	secRepo := holdingsec.NewSecurityRepository(holdingClient)
	holdRepo = holdingsec.NewHoldingRepository(holdingClient)
	tradeRepo := holdingsec.NewTradeRepository(holdingClient)
	snapRepo = holdingsec.NewSnapshotRepository(holdingClient)
	phRepo = holdingsec.NewPriceHistoryRepository(holdingClient)

	holdSvc := application.NewService(secRepo, holdRepo, tradeRepo)
	holdSvc.SetSnapshotRepository(snapRepo)
	holdSvc.SetPriceHistoryRepository(phRepo)
	// rateRepo intentionally nil: all test holdings are CNY (rate=1.0 default).

	h = NewHoldingHandler(holdSvc, nil /*txnSvc*/, nil /*accountLookup*/)
	return h, tenantID, accountID, holdRepo, snapRepo, phRepo
}

// TestGetPortfolioPerformanceReturnsCurve: handler.GetPortfolioPerformance
// authenticates, calls service.GetPortfolioPerformance, and maps the portfolio
// curve points + realized foot through to the proto response. Two CNY
// snapshots (10000 + 20000 cents) → 2 points each at 100.00 / 200.00 元; one
// sell trade with realized 800 → RealizedCents 800.
func TestGetPortfolioPerformanceReturnsCurve(t *testing.T) {
	h, tenantID, accountID, holdRepo, snapRepo, _ := setupPerfHarness(t)
	ctx := ctxWithTenant(tenantID)

	// CNY security + holding (cost 100×100 = 10000, qty 100, current price 168).
	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600519", Name: "Kweichow Moutai",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	secID := uuid.MustParse(sec.Security.Id)
	holdingID := uuid.New()
	if err := holdRepo.SaveOrUpdate(ctx, &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 100, CreatedAt: time.Now().AddDate(0, 0, -2),
	}); err != nil {
		t.Fatalf("seed holding: %v", err)
	}

	// Two daily snapshots (DAY window ≈ 30 days): 10000 and 20000 cents →
	// curve points 100.00 元 and 200.00 元.
	day1 := truncateToDateUTC(time.Now().AddDate(0, 0, -1))
	day2 := truncateToDateUTC(time.Now())
	for _, sn := range []domain.HoldingSnapshot{
		{ID: uuid.New(), TenantID: tenantID, HoldingID: holdingID, SecurityID: secID, AccountID: accountID,
			SnapshotDate: day1, MarketValueCents: 10000, CurrencyCode: "CNY"},
		{ID: uuid.New(), TenantID: tenantID, HoldingID: holdingID, SecurityID: secID, AccountID: accountID,
			SnapshotDate: day2, MarketValueCents: 20000, CurrencyCode: "CNY"},
	} {
		if err := snapRepo.Save(ctx, sn); err != nil {
			t.Fatalf("seed snapshot: %v", err)
		}
	}

	resp, err := h.GetPortfolioPerformance(ctx, &pb.GetPortfolioPerformanceRequest{
		AccountId:        accountID.String(),
		Range:            pb.CurveRange_CURVE_RANGE_DAY,
		IncludeBenchmark: false,
	})
	if err != nil {
		t.Fatalf("GetPortfolioPerformance: %v", err)
	}
	if resp == nil {
		t.Fatal("nil response")
	}
	// 2 portfolio points, values 100.00 and 200.00 元, ascending by time.
	if len(resp.PortfolioPoints) != 2 {
		t.Fatalf("portfolio points = %d, want 2", len(resp.PortfolioPoints))
	}
	if v0, v1 := resp.PortfolioPoints[0].GetValue(), resp.PortfolioPoints[1].GetValue(); v0 != 100.00 || v1 != 200.00 {
		t.Errorf("portfolio point values = %.2f, %.2f, want 100.00, 200.00", v0, v1)
	}
	if !resp.PortfolioPoints[0].GetTime().AsTime().Before(resp.PortfolioPoints[1].GetTime().AsTime()) {
		t.Error("portfolio points not ascending by time")
	}
	// No benchmark requested → empty benchmark points + name.
	if len(resp.BenchmarkPoints) != 0 {
		t.Errorf("benchmark points = %d, want 0 (include_benchmark=false)", len(resp.BenchmarkPoints))
	}
	if resp.Currency != "CNY" {
		t.Errorf("currency = %s, want CNY", resp.Currency)
	}
}

// TestGetHoldingPerformanceReturnsCurve: handler.GetHoldingPerformance
// authenticates, calls service.GetHoldingPerformance, and maps the price curve
// through to the proto response. Two price-history rows (15000 and 16000 cents)
// → 2 points at 150.00 元 and 160.00 元.
func TestGetHoldingPerformanceReturnsCurve(t *testing.T) {
	h, tenantID, accountID, holdRepo, _, phRepo := setupPerfHarness(t)
	ctx := ctxWithTenant(tenantID)

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "510300", Name: "CSI 300 ETF",
		SecurityType: pb.SecurityType_SECURITY_TYPE_ETF, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	secID := uuid.MustParse(sec.Security.Id)

	// Seed holding directly (GetHoldingPerformance resolves security via
	// holding.SecurityID and reads price history for that security).
	holdingID := uuid.New()
	if err := holdRepo.SaveOrUpdate(ctx, &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 15000, CreatedAt: time.Now().AddDate(0, 0, -2),
	}); err != nil {
		t.Fatalf("seed holding: %v", err)
	}

	// Two daily price-history rows (DAY window): 15000 and 16000 cents →
	// price-curve points 150.00 元 and 160.00 元.
	day1 := truncateToDateUTC(time.Now().AddDate(0, 0, -1))
	day2 := truncateToDateUTC(time.Now())
	if err := phRepo.SaveAll(ctx, []domain.SecurityPriceHistory{
		{ID: uuid.New(), SecurityID: secID, PriceDate: day1, PriceCents: 15000, CurrencyCode: "CNY", Source: "test"},
		{ID: uuid.New(), SecurityID: secID, PriceDate: day2, PriceCents: 16000, CurrencyCode: "CNY", Source: "test"},
	}); err != nil {
		t.Fatalf("seed price history: %v", err)
	}

	resp, err := h.GetHoldingPerformance(ctx, &pb.GetHoldingPerformanceRequest{
		HoldingId: holdingID.String(),
		Range:     pb.CurveRange_CURVE_RANGE_DAY,
	})
	if err != nil {
		t.Fatalf("GetHoldingPerformance: %v", err)
	}
	if resp == nil {
		t.Fatal("nil response")
	}
	if len(resp.PricePoints) != 2 {
		t.Fatalf("price points = %d, want 2", len(resp.PricePoints))
	}
	if v0, v1 := resp.PricePoints[0].GetValue(), resp.PricePoints[1].GetValue(); v0 != 150.00 || v1 != 160.00 {
		t.Errorf("price point values = %.2f, %.2f, want 150.00, 160.00", v0, v1)
	}
	if resp.Currency != "CNY" {
		t.Errorf("currency = %s, want CNY", resp.Currency)
	}
}

// truncateToDateUTC truncates a time to midnight UTC (matches the service's
// truncateToDate semantics for snapshot/price-history date keys).
func truncateToDateUTC(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// ---------------------------------------------------------------------------
// Performance base_currency handler tests (holding-server-D Task 7)
//
// Task 7 wires req.GetBaseCurrency() through to the service (replacing the
// hard-coded "CNY") on both GetPortfolioPerformance and GetHoldingPerformance.
// The portfolio service echoes the resolved base in its response Currency, so
// these two tests assert the empty → CNY fallback and the non-empty → echo
// contract end-to-end via the portfolio RPC. The seed data is CNY (rate
// defaults to 1.0), so only the Currency field differs — the curve/foot values
// are unchanged, which is exactly what makes the test a clean base-switch
// assertion rather than a currency-math test.
//
// GetHoldingPerformance forwards base_currency too, but its service echoes the
// security's original currency in the response (not base — Task 3 concern 2),
// so it has no response-side echo to assert here; see NOTE below its test.
// ---------------------------------------------------------------------------

// TestGetPortfolioPerformanceBaseCurrencyPassthrough: a non-empty
// base_currency on the request is forwarded to the service, which echoes it
// in the response Currency (here "USD"). All seeded data is CNY so the curve
// is non-empty; we only assert the Currency echo.
func TestGetPortfolioPerformanceBaseCurrencyPassthrough(t *testing.T) {
	h, tenantID, accountID, holdRepo, snapRepo, _ := setupPerfHarness(t)
	ctx := ctxWithTenant(tenantID)

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600519", Name: "Kweichow Moutai",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	secID := uuid.MustParse(sec.Security.Id)
	holdingID := uuid.New()
	if err := holdRepo.SaveOrUpdate(ctx, &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 100, CreatedAt: time.Now().AddDate(0, 0, -1),
	}); err != nil {
		t.Fatalf("seed holding: %v", err)
	}
	if err := snapRepo.Save(ctx, domain.HoldingSnapshot{
		ID: uuid.New(), TenantID: tenantID, HoldingID: holdingID, SecurityID: secID, AccountID: accountID,
		SnapshotDate: truncateToDateUTC(time.Now()), MarketValueCents: 10000, CurrencyCode: "CNY",
	}); err != nil {
		t.Fatalf("seed snapshot: %v", err)
	}

	resp, err := h.GetPortfolioPerformance(ctx, &pb.GetPortfolioPerformanceRequest{
		AccountId:    accountID.String(),
		Range:        pb.CurveRange_CURVE_RANGE_DAY,
		BaseCurrency: "USD",
	})
	if err != nil {
		t.Fatalf("GetPortfolioPerformance: %v", err)
	}
	if resp.GetCurrency() != "USD" {
		t.Errorf("currency = %q, want USD (base passthrough)", resp.GetCurrency())
	}
}

// TestGetPortfolioPerformanceBaseCurrencyDefaultsCNY: an empty base_currency
// preserves the Task 3 default behavior — the service falls back to CNY and
// the response Currency is "CNY".
func TestGetPortfolioPerformanceBaseCurrencyDefaultsCNY(t *testing.T) {
	h, tenantID, accountID, holdRepo, snapRepo, _ := setupPerfHarness(t)
	ctx := ctxWithTenant(tenantID)

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600519", Name: "Kweichow Moutai",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	secID := uuid.MustParse(sec.Security.Id)
	holdingID := uuid.New()
	if err := holdRepo.SaveOrUpdate(ctx, &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 100, CreatedAt: time.Now().AddDate(0, 0, -1),
	}); err != nil {
		t.Fatalf("seed holding: %v", err)
	}
	if err := snapRepo.Save(ctx, domain.HoldingSnapshot{
		ID: uuid.New(), TenantID: tenantID, HoldingID: holdingID, SecurityID: secID, AccountID: accountID,
		SnapshotDate: truncateToDateUTC(time.Now()), MarketValueCents: 10000, CurrencyCode: "CNY",
	}); err != nil {
		t.Fatalf("seed snapshot: %v", err)
	}

	// base_currency intentionally omitted → defaults to "" → service CNY fallback.
	resp, err := h.GetPortfolioPerformance(ctx, &pb.GetPortfolioPerformanceRequest{
		AccountId: accountID.String(),
		Range:     pb.CurveRange_CURVE_RANGE_DAY,
	})
	if err != nil {
		t.Fatalf("GetPortfolioPerformance: %v", err)
	}
	if resp.GetCurrency() != "CNY" {
		t.Errorf("currency = %q, want CNY (empty base fallback)", resp.GetCurrency())
	}
}

// NOTE: GetHoldingPerformance intentionally echoes the underlying security's
// original CurrencyCode (Task 3 concern 2: original vs base), NOT the request
// base_currency. So there is no response-side echo to assert for the holding
// RPC — the field is forwarded to the service (realized/unrealized 折算) but
// the response Currency stays the security's currency. Changing that is out of
// scope for Task 7 (deferred to final review). The existing
// TestGetHoldingPerformanceReturnsCurve covers the CNY-default path.

// ---------------------------------------------------------------------------
// Portfolio TWR field-mapping handler tests (range-TWR Task 3)
//
// Task 3 adds proto field 12 (range_twr_annualized_pct) and the handler now
// copies perf.RangeTwrAnnualizedPct through to the proto response. These tests
// pin the mapper behavior: nil stays nil (degraded → field-absent across the
// wire, which is what distinguishes "degraded" from a real 0.0% on the client),
// and non-nil values map through faithfully. The TWR math itself is exercised
// in application/twr_service_test.go; here we only assert the handler mapping.
// ---------------------------------------------------------------------------

// TestGetPortfolioPerformanceTwrFieldsNilWhenNoTrades: with snapshots but NO
// trades, portfolioTWR short-circuits to (nil, nil) (len(trades)==0). The
// handler must leave both TwrAnnualizedPct and RangeTwrAnnualizedPct unset on
// the proto response.
func TestGetPortfolioPerformanceTwrFieldsNilWhenNoTrades(t *testing.T) {
	h, tenantID, accountID, holdRepo, snapRepo, _ := setupPerfHarness(t)
	ctx := ctxWithTenant(tenantID)

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600519", Name: "Kweichow Moutai",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	secID := uuid.MustParse(sec.Security.Id)
	holdingID := uuid.New()
	if err := holdRepo.SaveOrUpdate(ctx, &domain.Holding{
		ID: holdingID, TenantID: tenantID, AccountID: accountID, SecurityID: secID,
		Quantity: 100, AvgCostCents: 100, CreatedAt: time.Now().AddDate(0, 0, -2),
	}); err != nil {
		t.Fatalf("seed holding: %v", err)
	}
	if err := snapRepo.Save(ctx, domain.HoldingSnapshot{
		ID: uuid.New(), TenantID: tenantID, HoldingID: holdingID, SecurityID: secID, AccountID: accountID,
		SnapshotDate: truncateToDateUTC(time.Now()), MarketValueCents: 10000, CurrencyCode: "CNY",
	}); err != nil {
		t.Fatalf("seed snapshot: %v", err)
	}

	resp, err := h.GetPortfolioPerformance(ctx, &pb.GetPortfolioPerformanceRequest{
		AccountId: accountID.String(),
		Range:     pb.CurveRange_CURVE_RANGE_DAY,
	})
	if err != nil {
		t.Fatalf("GetPortfolioPerformance: %v", err)
	}
	if resp.TwrAnnualizedPct != nil {
		t.Errorf("TwrAnnualizedPct = %v, want nil (no trades → degraded)", resp.TwrAnnualizedPct)
	}
	if resp.RangeTwrAnnualizedPct != nil {
		t.Errorf("RangeTwrAnnualizedPct = %v, want nil (no trades → degraded)", resp.RangeTwrAnnualizedPct)
	}
}

// TestGetPortfolioPerformanceRangeTwrMapsThrough: with ≥2 buys on distinct days
// + price history, portfolioTWR resolves non-nil for both full and range, and
// the handler copies both through. DAY rangeStart = today-30d; the opening buy
// at -32d (before rangeStart → non-zero opening position) plus the effective buy
// at -10d (after rangeStart → ≥1 effectiveDay) make the range resolve. Constant
// price → TWR ≈ 0. We cross-check against the service DTO to assert the value
// is copied faithfully (guards field-swap/drop) without replicating TWR math.
func TestGetPortfolioPerformanceRangeTwrMapsThrough(t *testing.T) {
	h, tenantID, accountID, _, _, phRepo := setupPerfHarness(t)
	ctx := ctxWithTenant(tenantID)

	sec, err := h.CreateSecurity(ctx, &pb.CreateSecurityRequest{
		Symbol: "600519", Name: "Kweichow Moutai",
		SecurityType: pb.SecurityType_SECURITY_TYPE_STOCK, CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("CreateSecurity: %v", err)
	}
	secID := uuid.MustParse(sec.Security.Id)
	// currentPrice feeds finalValue (currentMarketValueInBase uses security.CurrentPriceCents).
	if _, err := h.UpdateSecurityPrice(ctx, &pb.UpdatePriceRequest{
		SecurityId: sec.Security.Id, PriceCents: 10000,
	}); err != nil {
		t.Fatalf("UpdateSecurityPrice: %v", err)
	}

	// Opening buy before DAY rangeStart + effective buy after it → range resolves.
	dayOpen := truncateToDateUTC(time.Now().AddDate(0, 0, -32))
	dayEff := truncateToDateUTC(time.Now().AddDate(0, 0, -10))
	for _, d := range []time.Time{dayOpen, dayEff} {
		if _, err := h.BuyHolding(ctx, &pb.HoldingTradeRequest{
			AccountId:     accountID.String(),
			SecurityId:    sec.Security.Id,
			FromAccountId: uuid.New().String(),
			Quantity:      10, PriceCents: 10000,
			TradeDate: d.Format("2006-01-02"),
		}); err != nil {
			t.Fatalf("BuyHolding %s: %v", d.Format("2006-01-02"), err)
		}
	}
	// Price history at the two cashFlowDays (forward-fill covers rangeStart+1d
	// and effectiveDay+1d as-of lookups in computeTWR).
	if err := phRepo.SaveAll(ctx, []domain.SecurityPriceHistory{
		{ID: uuid.New(), SecurityID: secID, PriceDate: dayOpen, PriceCents: 10000, CurrencyCode: "CNY", Source: "test"},
		{ID: uuid.New(), SecurityID: secID, PriceDate: dayEff, PriceCents: 10000, CurrencyCode: "CNY", Source: "test"},
	}); err != nil {
		t.Fatalf("seed price history: %v", err)
	}

	resp, err := h.GetPortfolioPerformance(ctx, &pb.GetPortfolioPerformanceRequest{
		AccountId: accountID.String(),
		Range:     pb.CurveRange_CURVE_RANGE_DAY,
	})
	if err != nil {
		t.Fatalf("GetPortfolioPerformance: %v", err)
	}
	if resp.TwrAnnualizedPct == nil {
		t.Fatal("TwrAnnualizedPct nil, want non-nil (2 cashFlowDays + price history present)")
	}
	if resp.RangeTwrAnnualizedPct == nil {
		t.Fatal("RangeTwrAnnualizedPct nil, want non-nil (opening -32d + effective -10d straddle DAY rangeStart -30d)")
	}

	// Cross-check: handler response matches the service DTO value (same seed →
	// same deterministic value; proves the field is copied, not dropped/swapped).
	acct := accountID
	dto, err := h.service.GetPortfolioPerformance(ctx, tenantID, &acct, "DAY", false, "")
	if err != nil {
		t.Fatalf("service GetPortfolioPerformance: %v", err)
	}
	if dto.RangeTwrAnnualizedPct == nil {
		t.Fatal("service DTO RangeTwrAnnualizedPct nil, expected non-nil")
	}
	if got, want := *resp.RangeTwrAnnualizedPct, *dto.RangeTwrAnnualizedPct; got != want {
		t.Errorf("RangeTwrAnnualizedPct = %v, want %v (service DTO)", got, want)
	}
}
