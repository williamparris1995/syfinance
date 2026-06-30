package grpc

import (
	"context"
	"database/sql"
	"fmt"
	"testing"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"
	accountdomain "github.com/yucai/server/internal/account/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
	"github.com/yucai/server/internal/holding/application"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	pb "github.com/yucai/server/internal/proto/holding/v1"
	txnApp "github.com/yucai/server/internal/transaction/application"
	txnDomain "github.com/yucai/server/internal/transaction/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
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
