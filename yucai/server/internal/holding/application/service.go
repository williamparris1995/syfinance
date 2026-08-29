package application

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"sort"
	"time"

	"github.com/google/uuid"
	currencydomain "github.com/yucai/server/internal/currency/domain"
	"github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
	"github.com/yucai/server/internal/holding/domain"
	"github.com/yucai/server/internal/sqltx"
)

// Service orchestrates holding operations.
type Service struct {
	securityRepo       domain.SecurityRepository
	holdingRepo        domain.HoldingRepository
	tradeRepo          domain.TradeRepository
	priceRouter        priceprovider.Router             // injected via SetPriceRouter (wire); nil = SyncPrices errors
	lotRepo            domain.LotRepository             // C: FIFO lot (nil = fallback to ApplySell)
	snapshotRepo       domain.SnapshotRepository        // C: daily snapshot
	priceHistoryRepo   domain.PriceHistoryRepository    // C: price history + backfill gate
	historicalProvider priceprovider.HistoricalProvider // C: backfill
	rateRepo           domain.RateHistoryRepository     // C: portfolio curve CNY折算 (cross-module currency interface)
	tenantLister       domain.TenantLister              // C: SnapshotAllHoldings fan-out (wire injects auth.TenantRepository)
	cashRecorder       domain.TradeCashRecorder         // D2: cash-side trade double-write port (nil = skip)
	db                 *sql.DB                          // D2: shared *sql.DB backing the holding ent client
	nowFn              func() time.Time                 // perf e2e 注入固定评估日;默认 time.Now (nil → time.Now via now())
}

// NewService creates a new holding application service.
func NewService(secRepo domain.SecurityRepository, hRepo domain.HoldingRepository, tRepo domain.TradeRepository) *Service {
	return &Service{securityRepo: secRepo, holdingRepo: hRepo, tradeRepo: tRepo, nowFn: time.Now}
}

// now returns the injected clock, falling back to time.Now when unset (e.g.
// tests constructing &Service{} directly). Perf e2e injects a fixed eval date
// via SetNow so annualized day counts (XIRR/CAGR/TWR) are deterministic.
func (s *Service) now() time.Time {
	if s.nowFn == nil {
		return time.Now()
	}
	return s.nowFn()
}

// CreateSecurity creates a new global security.
func (s *Service) CreateSecurity(ctx context.Context, req CreateSecurityRequest) (*SecurityDTO, error) {
	sec, err := domain.NewSecurity(req.Symbol, req.Name, req.SecurityType, req.Exchange, req.CurrencyCode)
	if err != nil {
		return nil, fmt.Errorf("create security: %w", err)
	}
	if err := s.securityRepo.Save(ctx, sec); err != nil {
		return nil, fmt.Errorf("save security: %w", err)
	}
	dto := SecurityToDTO(sec)
	return &dto, nil
}

// ListSecurities returns paginated securities.
func (s *Service) ListSecurities(ctx context.Context, securityType *domain.SecurityType, page domain.PageRequest) (*ListSecuritiesResult, error) {
	result, err := s.securityRepo.FindAll(ctx, securityType, page)
	if err != nil {
		return nil, fmt.Errorf("list securities: %w", err)
	}
	dtos := make([]SecurityDTO, len(result.Items))
	for i, sec := range result.Items {
		dtos[i] = SecurityToDTO(&sec)
	}
	return &ListSecuritiesResult{Securities: dtos, NextPageToken: result.NextPageToken, TotalCount: result.TotalCount}, nil
}

// UpdateSecurityPrice updates the current price of a security.
func (s *Service) UpdateSecurityPrice(ctx context.Context, securityID uuid.UUID, priceCents int64) error {
	return s.securityRepo.UpdatePrice(ctx, securityID, priceCents)
}

// SearchSecurities searches securities by name or symbol.
func (s *Service) SearchSecurities(ctx context.Context, query string, limit int) ([]SecurityDTO, error) {
	securities, err := s.securityRepo.Search(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("search securities: %w", err)
	}
	dtos := make([]SecurityDTO, len(securities))
	for i, sec := range securities {
		dtos[i] = SecurityToDTO(&sec)
	}
	return dtos, nil
}

// BuyHolding records a buy trade and updates the holding position. The entire
// operation — holding upsert, trade insert, lot create, and (when req.CashRecord
// is non-nil) the cash-side double-entry transaction via cashRecorder — runs
// inside one sqltx.WithTx so a partial failure rolls back the whole trade. See
// runInTx for the nil-skip / join-existing-tx semantics.
func (s *Service) BuyHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*HoldingTransactionDTO, error) {
		return s.buyHolding(ctx, req)
	})
}

// buyHolding is the transactional-body implementation of BuyHolding. Every
// repo call it makes must receive the ctx threaded down from runInTx (either
// the original ctx on the nil-skip path or the tx-bound ctxT) so the writes
// join the surrounding transaction.
func (s *Service) buyHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	h, err := s.holdingRepo.FindByAccountAndSecurity(ctx, req.TenantID, req.AccountID, req.SecurityID)
	if err != nil {
		// Create new holding
		h = &domain.Holding{
			ID: uuid.New(), TenantID: req.TenantID,
			AccountID: req.AccountID, SecurityID: req.SecurityID,
		}
	}
	h.ApplyBuy(req.Quantity, req.PriceCents, req.FeeCents)

	tradeID := uuid.New()
	// Lot per-share cost capitalizes the buy fee (brokerage standard):
	// (price×qty + fee) / qty. Rounding to per-share cents is acceptable — the
	// tiny residual (sub-cent) is absorbed into the lot's cost basis. This
	// mirrors ApplyBuy's fee-inclusive AvgCostCents; legacy pre-fix lots use
	// fee-EXCLUSIVE PriceCents (see ApplyBuy backward-compat note).
	lotPriceCents := int64(math.Round((float64(req.PriceCents)*req.Quantity + float64(req.FeeCents)) / req.Quantity))
	newLot := domain.HoldingLot{
		// ID 留 zero(uuid.Nil)—— lot_repo SaveAll Create 分支(==Nil)走 ent Default。
		// 修陷阱 A:原 ID: uuid.New() 非 Nil → SaveAll Update 分支(UpdateOneID)→ ent NotFound。
		TenantID: req.TenantID, HoldingID: h.ID, SecurityID: req.SecurityID,
		AcquiredDate: req.TradeDate, AcquiredTradeID: tradeID,
		PriceCents: lotPriceCents, Quantity: req.Quantity, RemainingQuantity: req.Quantity,
	}
	// AvgCost from FIFO lots (existing + new), consistent with lot state.
	if s.lotRepo != nil {
		existing, _ := s.lotRepo.FindByHolding(ctx, h.ID)
		h.AvgCostCents = domain.LotAvgCost(append(existing, newLot))
	}

	if err := s.holdingRepo.SaveOrUpdate(ctx, h); err != nil {
		return nil, fmt.Errorf("save holding: %w", err)
	}

	trade := &domain.HoldingTransaction{
		ID: tradeID, TenantID: req.TenantID,
		AccountID: req.AccountID, SecurityID: req.SecurityID,
		TradeType: domain.TradeTypeBuy, Quantity: req.Quantity,
		PriceCents: req.PriceCents, AmountCents: TradeAmountCents(req.PriceCents, req.Quantity),
		FeeCents: req.FeeCents, TradeDate: req.TradeDate, Notes: req.Notes,
		CreatedAt: h.UpdatedAt,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save trade: %w", err)
	}
	if s.lotRepo != nil {
		if err := s.lotRepo.SaveAll(ctx, []domain.HoldingLot{newLot}); err != nil {
			return nil, fmt.Errorf("save buy lot: %w", err)
		}
	}

	// Cash side (D2 atomicity): record the cash + investment legs as a double-
	// entry transaction inside the same tx. Skipped when CashRecord is nil
	// (seed/perf/test path) or when no recorder is injected. recorder.Record
	// delegates to transaction.Service.RecordTransaction whose runInTx join-
	// existing-tx semantics (Task 4) enlist it in this outer WithTx — so a
	// cash-write failure rolls back the trade, and a lot/trade failure (above)
	// means this call never fires.
	if req.CashRecord != nil && s.cashRecorder != nil {
		if _, err := s.cashRecorder.Record(ctx, *req.CashRecord); err != nil {
			return nil, fmt.Errorf("record trade cash: %w", err)
		}
	}

	dto := TradeToDTO(trade)
	return &dto, nil
}

// SellHolding records a sell trade and updates the holding position. Like
// BuyHolding it wraps the entire trade (holding + trade + lot consume + cash
// double-write) in one sqltx.WithTx so partial failure rolls back atomically.
func (s *Service) SellHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*HoldingTransactionDTO, error) {
		return s.sellHolding(ctx, req)
	})
}

// sellHolding is the transactional-body implementation of SellHolding. Every
// repo call it makes must receive the ctx threaded down from runInTx so the
// writes join the surrounding transaction.
func (s *Service) sellHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	h, err := s.holdingRepo.FindByAccountAndSecurity(ctx, req.TenantID, req.AccountID, req.SecurityID)
	if err != nil {
		return nil, fmt.Errorf("holding not found: %w", err)
	}

	var realized int64
	if s.lotRepo != nil {
		lots, err := s.lotRepo.FindByHolding(ctx, h.ID)
		if err != nil {
			return nil, fmt.Errorf("load lots: %w", err)
		}
		consumedRealized, consumed, err := domain.ConsumeLotsFIFO(req.Quantity, req.PriceCents, lots)
		if err != nil {
			return nil, err
		}
		// Sell fee reduces net realized proceeds (brokerage standard): gross FIFO
		// (already using fee-inclusive lot cost via BuyHolding) minus the sell
		// fee. ConsumeLotsFIFO is GROSS (signature unchanged); the fee adjustment
		// lives here at the call site.
		realized = consumedRealized - req.FeeCents
		// Apply consumption in-memory, then persist.
		consumedByID := map[uuid.UUID]float64{}
		for _, c := range consumed {
			consumedByID[c.LotID] = c.ConsumedQuantity
		}
		for i := range lots {
			lots[i].RemainingQuantity -= consumedByID[lots[i].ID]
		}
		if err := s.lotRepo.SaveAll(ctx, lots); err != nil {
			return nil, fmt.Errorf("save lots after sell: %w", err)
		}
		// Oversell guard + qty decrement via ApplySell (its moving-weighted realized ignored).
		if _, err := h.ApplySell(req.Quantity, req.PriceCents); err != nil {
			return nil, err
		}
		h.AvgCostCents = domain.LotAvgCost(lots) // consistent with FIFO remaining lots
	} else {
		realized, err = h.ApplySell(req.Quantity, req.PriceCents) // fallback (no lot repo)
		if err != nil {
			return nil, err
		}
	}

	if err := s.holdingRepo.SaveOrUpdate(ctx, h); err != nil {
		return nil, fmt.Errorf("save holding: %w", err)
	}

	trade := &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: req.TenantID,
		AccountID: req.AccountID, SecurityID: req.SecurityID,
		TradeType: domain.TradeTypeSell, Quantity: req.Quantity,
		PriceCents: req.PriceCents, AmountCents: TradeAmountCents(req.PriceCents, req.Quantity),
		FeeCents: req.FeeCents, TradeDate: req.TradeDate, Notes: req.Notes,
		RealizedPnLCents: realized, CreatedAt: h.UpdatedAt,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save trade: %w", err)
	}

	// Cash side (D2 atomicity) — see buyHolding for the contract.
	if req.CashRecord != nil && s.cashRecorder != nil {
		if _, err := s.cashRecorder.Record(ctx, *req.CashRecord); err != nil {
			return nil, fmt.Errorf("record trade cash: %w", err)
		}
	}

	dto := TradeToDTO(trade)
	return &dto, nil
}

// RecordDividend records a dividend payment.
func (s *Service) RecordDividend(ctx context.Context, req RecordDividendRequest) (*HoldingTransactionDTO, error) {
	trade := &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: req.TenantID,
		AccountID: req.AccountID, SecurityID: req.SecurityID,
		TradeType: domain.TradeTypeDividend, Quantity: req.Quantity,
		PriceCents: req.CashPerShareCents, AmountCents: req.TotalAmountCents,
		TradeDate: req.TradeDate, Notes: req.Notes,
		CreatedAt: req.TradeDate,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save dividend: %w", err)
	}
	dto := TradeToDTO(trade)
	return &dto, nil
}

// RecordSplit records a stock split.
func (s *Service) RecordSplit(ctx context.Context, req RecordSplitRequest) (*HoldingTransactionDTO, error) {
	// F12 守卫:ratio≤0 会把 quantity 乘成 0/负且成本不调整(数据静默损坏),
	// fail-closed 在任何读取/持久化之前拒绝(mapError → InvalidArgument)。
	if req.Ratio <= 0 {
		return nil, fmt.Errorf("record split: invalid ratio %v (must be > 0)", req.Ratio)
	}
	h, err := s.holdingRepo.FindByAccountAndSecurity(ctx, req.TenantID, req.AccountID, req.SecurityID)
	if err != nil {
		return nil, fmt.Errorf("holding not found: %w", err)
	}

	// FIFO lot split-adjust: quantity×ratio + remaining×ratio + price/ratio
	// (keeps per-share cost correct so post-split FIFO realized is right).
	if s.lotRepo != nil {
		lots, err := s.lotRepo.FindByHolding(ctx, h.ID)
		if err != nil {
			return nil, fmt.Errorf("load lots for split: %w", err)
		}
		for i := range lots {
			lots[i].Quantity *= req.Ratio
			lots[i].RemainingQuantity *= req.Ratio
			if req.Ratio > 0 {
				lots[i].PriceCents = int64(math.Round(float64(lots[i].PriceCents) / req.Ratio))
			}
		}
		if err := s.lotRepo.SaveAll(ctx, lots); err != nil {
			return nil, fmt.Errorf("save lots after split: %w", err)
		}
	}
	h.ApplySplit(req.Ratio)
	if err := s.holdingRepo.SaveOrUpdate(ctx, h); err != nil {
		return nil, fmt.Errorf("save holding: %w", err)
	}

	trade := &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: req.TenantID,
		AccountID: req.AccountID, SecurityID: req.SecurityID,
		TradeType: domain.TradeTypeSplit, Quantity: req.Ratio,
		TradeDate: req.SplitDate, Notes: req.Notes,
		CreatedAt: h.UpdatedAt,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save split: %w", err)
	}
	dto := TradeToDTO(trade)
	return &dto, nil
}

// ListHoldings returns paginated holdings with market value.
func (s *Service) ListHoldings(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, page domain.PageRequest) (*ListHoldingsResult, error) {
	result, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
	if err != nil {
		return nil, fmt.Errorf("list holdings: %w", err)
	}
	dtos := make([]HoldingDTO, len(result.Items))
	for i, h := range result.Items {
		sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
		if err != nil {
			continue
		}
		dtos[i] = HoldingToDTO(&h, sec)
	}
	return &ListHoldingsResult{Holdings: dtos, NextPageToken: result.NextPageToken, TotalCount: result.TotalCount}, nil
}

// ListHoldingTransactions returns paginated trade history.
func (s *Service) ListHoldingTransactions(ctx context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID, page domain.PageRequest) (*ListTradesResult, error) {
	result, err := s.tradeRepo.FindAll(ctx, tenantID, accountID, securityID, page)
	if err != nil {
		return nil, fmt.Errorf("list trades: %w", err)
	}
	dtos := make([]HoldingTransactionDTO, len(result.Items))
	for i, tr := range result.Items {
		dtos[i] = TradeToDTO(&tr)
	}
	return &ListTradesResult{Trades: dtos, NextPageToken: result.NextPageToken, TotalCount: result.TotalCount}, nil
}

// seedSecurity presets one representative security per SecurityType plus a few
// extras, giving the holding UI data across all categories (stock/fund/etf/
// bond/gold/option). Prices are illustrative (cents).
type seedSecurity struct {
	symbol   string
	name     string
	secType  domain.SecurityType
	exchange string
	currency string
	price    int64
}

var seedSecurities = []seedSecurity{
	{"AAPL", "苹果公司", domain.SecurityTypeStock, "NASDAQ", "USD", 19500},
	{"600519", "贵州茅台", domain.SecurityTypeStock, "SSE", "CNY", 168000},
	{"000001", "华夏成长基金", domain.SecurityTypeFund, "OTC", "CNY", 145},
	{"510300", "沪深300ETF", domain.SecurityTypeETF, "SSE", "CNY", 425},
	{"511010", "国债ETF", domain.SecurityTypeBond, "SSE", "CNY", 119},
	{"AU9999", "黄金现货", domain.SecurityTypeGold, "SGE", "CNY", 55000},
	{"OP100006", "50ETF认购期权", domain.SecurityTypeOption, "SSE", "CNY", 826},
	{"000300", "沪深300指数", domain.SecurityTypeIndex, "SSE", "CNY", 3800},
}

// SeedSecurities idempotently creates the preset securities covering every
// SecurityType. Skips symbols already present (FindBySymbol), so it is safe to
// run on every startup. Returns the number of newly created rows.
func (s *Service) SeedSecurities(ctx context.Context) (int, error) {
	created := 0
	for _, p := range seedSecurities {
		if existing, err := s.securityRepo.FindBySymbol(ctx, p.symbol, p.exchange); err == nil && existing != nil {
			continue
		}
		sec, err := domain.NewSecurity(p.symbol, p.name, p.secType, p.exchange, p.currency)
		if err != nil {
			return created, fmt.Errorf("build seed security %s: %w", p.symbol, err)
		}
		sec.CurrentPriceCents = p.price
		if err := s.securityRepo.Save(ctx, sec); err != nil {
			return created, fmt.Errorf("save seed security %s: %w", p.symbol, err)
		}
		created++
	}
	return created, nil
}

// SeedSampleHoldings idempotently buys a basket of securities for a tenant's
// investment account, producing holdings + buy trades so the list/detail/
// performance pages have data. Skips if the tenant already has any holding.
// Uses the application-layer BuyHolding (no cash double-write — seed data only,
// bypassing the gRPC handler's from-account validation).
func (s *Service) SeedSampleHoldings(ctx context.Context, tenantID, accountID uuid.UUID) error {
	existing, err := s.holdingRepo.FindAll(ctx, tenantID, nil, domain.PageRequest{PageSize: 1})
	if err != nil {
		return fmt.Errorf("check existing holdings: %w", err)
	}
	if existing != nil && len(existing.Items) > 0 {
		return nil
	}
	result, err := s.securityRepo.FindAll(ctx, nil, domain.PageRequest{PageSize: 50})
	if err != nil {
		return fmt.Errorf("list securities for seed: %w", err)
	}
	for i, sec := range result.Items {
		qty := 50.0 + float64(i*30)
		date := s.now().AddDate(0, 0, -i*5)
		if _, err := s.BuyHolding(ctx, HoldingTradeRequest{
			TenantID:   tenantID,
			AccountID:  accountID,
			SecurityID: sec.ID,
			Quantity:   qty,
			PriceCents: sec.CurrentPriceCents,
			TradeDate:  date,
			Notes:      "种子数据",
		}); err != nil {
			return fmt.Errorf("seed buy %s: %w", sec.Symbol, err)
		}
	}
	return nil
}

// SetPriceRouter injects the price router used by SyncPrices. Called by wire
// after construction (NewService signature stays unchanged so existing tests
// and callers are not broken).
func (s *Service) SetPriceRouter(r priceprovider.Router) {
	s.priceRouter = r
}

// SetLotRepository injects the FIFO lot repo (Task 5 C). nil = SellHolding
// falls back to moving-weighted ApplySell; Buy/Split skip lot maintenance.
func (s *Service) SetLotRepository(r domain.LotRepository) { s.lotRepo = r }

// SetDB injects the shared *sql.DB backing the holding ent client. BuyHolding
// and SellHolding wrap their holding+trade+lot (+ optional cash) writes in a
// single sqltx.WithTx over db so a partial failure rolls back the whole
// operation (Task 5 / audit D2). Nil preserves the legacy non-transactional
// behavior that mock-based unit tests rely on; production wire always injects
// the shared db (Task 1's provideDB).
func (s *Service) SetDB(db *sql.DB) { s.db = db }

// SetCashRecorder injects the cross-module recorder used to write the cash side
// of a holding trade (debit/credit the from/cash account + holding investment
// account) as a double-entry transaction inside the same WithTx as the holding
// write. Wire binds the transaction application service's adapter; nil = the
// cash side is skipped (test / seed-data / perf-test path).
func (s *Service) SetCashRecorder(r domain.TradeCashRecorder) { s.cashRecorder = r }

// runInTx wraps fn in a single sqltx.WithTx over the shared *sql.DB so the
// holding write, trade write, lot write (and the optional cash-side
// transaction via cashRecorder) all join one atomic DB transaction. A failure
// anywhere in fn (e.g. a lot-save error after holding+trade succeeded) rolls
// back the whole operation.
//
// When s.db is nil the wrapper is skipped and fn runs directly against the
// repos' default (auto-commit) clients. This preserves the legacy
// non-transactional behavior that mock-based unit tests rely on (they inject
// mock repos without a *sql.DB); production wire always injects the shared db
// from Task 1's provideDB, so the rollback guarantee holds in deployment.
//
// Join-existing-tx semantics: when ctx already carries a tx driver (an outer
// WithTx — e.g. seed data invoking BuyHolding from inside another WithTx),
// sqltx.WithTx runs fn against that outer driver without opening a new
// transaction; the outermost caller owns commit/rollback.
func (s *Service) runInTx(ctx context.Context, fn func(ctx context.Context) (*HoldingTransactionDTO, error)) (*HoldingTransactionDTO, error) {
	if s.db == nil {
		return fn(ctx)
	}
	var dto *HoldingTransactionDTO
	err := sqltx.WithTx(ctx, s.db, "postgres", nil, func(ctxT context.Context) error {
		d, e := fn(ctxT)
		dto = d
		return e
	})
	return dto, err
}

// SetSnapshotRepository injects the daily snapshot repo (Task 5 C).
func (s *Service) SetSnapshotRepository(r domain.SnapshotRepository) { s.snapshotRepo = r }

// SetPriceHistoryRepository injects the price history repo (Task 5 C). Enables
// SyncPrices to record daily price points and gates backfill.
func (s *Service) SetPriceHistoryRepository(r domain.PriceHistoryRepository) { s.priceHistoryRepo = r }

// SetHistoricalProvider injects the historical K-line provider (Task 5 C backfill).
func (s *Service) SetHistoricalProvider(p priceprovider.HistoricalProvider) { s.historicalProvider = p }

// SetRateHistoryRepository injects the FX rate history repo (Task 5 C, portfolio
// curve CNY折算). Structural type — currency's RateHistoryRepo satisfies this.
func (s *Service) SetRateHistoryRepository(r domain.RateHistoryRepository) { s.rateRepo = r }

// SetTenantLister injects the tenant enumerator used by SnapshotAllHoldings
// (Task 7 C). Wire binds auth's TenantRepository (its FindAllIDs satisfies
// domain.TenantLister). nil = SnapshotAllHoldings errors.
func (s *Service) SetTenantLister(l domain.TenantLister) { s.tenantLister = l }

// SetNow overrides the clock (perf e2e injects a fixed eval date; production uses time.Now).
func (s *Service) SetNow(f func() time.Time) {
	if f == nil {
		f = time.Now
	}
	s.nowFn = f
}

// truncateToDate clips a time to 00:00 UTC of its day, so same-day re-syncs
// hit the same price_history row (UNIQUE(security_id, price_date) guard).
func truncateToDate(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
}

// SyncPrices refreshes current_price_cents for every security via the price
// router, best-effort: ErrNoSource skips the security (keeps old price, not a
// failure); any other error is logged and the security is skipped without
// aborting the batch. Returns the count of successfully updated securities.
// Implements holding/scheduler.PriceSyncer.
func (s *Service) SyncPrices(ctx context.Context) (int, error) {
	if s.priceRouter == nil {
		return 0, fmt.Errorf("sync prices: price router not configured")
	}
	synced := 0
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.securityRepo.FindAll(ctx, nil, page)
		if err != nil {
			return synced, fmt.Errorf("sync prices: list securities: %w", err)
		}
		for _, sec := range result.Items {
			if err := ctx.Err(); err != nil {
				return synced, err
			}
			view := priceprovider.PriceView{Symbol: sec.Symbol, Exchange: sec.Exchange, Type: sec.SecurityType}
			price, source, err := s.priceRouter.FetchPrice(ctx, view)
			if err != nil {
				if errors.Is(err, priceprovider.ErrNoSource) {
					continue // not covered (e.g. US stock) — keep old price
				}
				slog.Warn("holding price sync: fetch failed, keep old price",
					slog.String("symbol", sec.Symbol),
					slog.String("exchange", sec.Exchange),
					slog.String("error", err.Error()),
					slog.String("operation", "SyncPrices"))
				continue
			}
			if err := s.securityRepo.UpdatePrice(ctx, sec.ID, price); err != nil {
				slog.Warn("holding price sync: update failed",
					slog.String("symbol", sec.Symbol),
					slog.String("error", err.Error()),
					slog.String("operation", "SyncPrices"))
				continue
			}
			// C: record daily price history point (idempotent — same-day re-sync
			// upserts the same row via UNIQUE(security_id, price_date)).
			if s.priceHistoryRepo != nil {
				ph := domain.SecurityPriceHistory{
					SecurityID: sec.ID, PriceDate: truncateToDate(s.now()),
					PriceCents: price, CurrencyCode: sec.CurrencyCode, Source: source,
				}
				if err := s.priceHistoryRepo.Save(ctx, ph); err != nil {
					slog.Warn("holding price sync: save history failed",
						slog.String("symbol", sec.Symbol),
						slog.String("error", err.Error()),
						slog.String("operation", "SyncPrices"))
					// not fatal — price_history missing just means thinner curves
				}
			}
			synced++
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return synced, nil
}

// --- Task 6 C: snapshot / backfill / performance ---

// curveWindow maps a proto CurveRange name to (from, to, granularity).
// granularity = "day"/"month"/"year" sampling.
func (s *Service) curveWindow(rangeName string) (from, to time.Time, granularity string) {
	to = truncateToDate(s.now())
	switch rangeName {
	case "MONTH":
		return to.AddDate(0, -12, 0), to, "month"
	case "YEAR":
		return to.AddDate(-5, 0, 0), to, "year"
	default: // DAY
		return to.AddDate(0, 0, -30), to, "day"
	}
}

// SnapshotHoldings writes one market-value snapshot per active holding for
// today. Best-effort: a holding whose security is missing is skipped + logged,
// not fatal. Implements scheduler.Snapshotter (Task 7).
func (s *Service) SnapshotHoldings(ctx context.Context, tenantID uuid.UUID) (int, error) {
	if s.snapshotRepo == nil {
		return 0, fmt.Errorf("snapshot: snapshot repo not configured")
	}
	today := truncateToDate(s.now())
	synced := 0
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.holdingRepo.FindAll(ctx, tenantID, nil, page)
		if err != nil {
			return synced, fmt.Errorf("snapshot: list holdings: %w", err)
		}
		for _, h := range result.Items {
			if err := ctx.Err(); err != nil {
				return synced, err
			}
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				slog.Warn("holding snapshot: security missing, skip",
					slog.String("holding_id", h.ID.String()),
					slog.String("operation", "SnapshotHoldings"))
				continue
			}
			snap := domain.HoldingSnapshot{
				TenantID:           h.TenantID,
				HoldingID:          h.ID,
				SecurityID:         h.SecurityID,
				AccountID:          h.AccountID,
				SnapshotDate:       today,
				MarketValueCents:   h.MarketValue(sec.CurrentPriceCents),
				UnrealizedPnlCents: h.UnrealizedPnL(sec.CurrentPriceCents),
				CurrencyCode:       sec.CurrencyCode,
			}
			if err := s.snapshotRepo.Save(ctx, snap); err != nil {
				slog.Warn("holding snapshot: save failed",
					slog.String("holding_id", h.ID.String()),
					slog.String("error", err.Error()),
					slog.String("operation", "SnapshotHoldings"))
				continue
			}
			synced++
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return synced, nil
}

// SnapshotAllHoldings snapshots every active holding across all tenants. It is
// the cross-tenant entry point used by the SnapshotScheduler (Task 7).
//
// Implementation note: HoldingRepository.FindAll is tenant-scoped — passing
// uuid.Nil returns EMPTY (ent matches WHERE tenant_id = Nil against no rows),
// not "all tenants". So this method fans out by enumerating tenant IDs via the
// injected TenantLister and accumulates each tenant's snapshot count. A
// per-tenant error is logged but does not abort the batch (best-effort, like
// SyncPrices/SnapshotHoldings); a failure to list tenants is fatal. Implements
// holding/scheduler.Snapshotter.
func (s *Service) SnapshotAllHoldings(ctx context.Context) (int, error) {
	if s.tenantLister == nil {
		return 0, fmt.Errorf("snapshot all: tenant lister not configured")
	}
	tenantIDs, err := s.tenantLister.FindAllIDs(ctx)
	if err != nil {
		return 0, fmt.Errorf("snapshot all: list tenants: %w", err)
	}
	total := 0
	for _, tid := range tenantIDs {
		if err := ctx.Err(); err != nil {
			return total, err
		}
		n, err := s.SnapshotHoldings(ctx, tid)
		if err != nil {
			slog.Warn("holding snapshot: tenant batch failed, continue",
				slog.String("tenant_id", tid.String()),
				slog.String("error", err.Error()),
				slog.String("operation", "SnapshotAllHoldings"))
			continue
		}
		total += n
	}
	return total, nil
}

// datalenForRange maps CurveRange to Sina K-line datalen (bar count).
func datalenForRange(rangeName string) int {
	switch rangeName {
	case "MONTH":
		return 250
	case "YEAR":
		return 1200
	default:
		return 30
	}
}

// BackfillPriceHistory fetches historical daily K-line for every security,
// writing price_history. Fetching goes through HistoricalRouter
// (s.historicalProvider): SinaProvider for A-shares (SSE/SZSE) + CSI300,
// YahooProvider as the non A-share fallback (US/global etc.). Best-effort:
// per-security fetch failure logged, not fatal. Backfills every security on
// each startup (no per-security Exists gate) so history is refreshed even
// when the B SyncPrices scheduler already wrote the current-day point —
// SaveAll upserts on UNIQUE(security_id, price_date), so pre-existing points
// are updated rather than skipped. ErrNoSource (a symbol no provider covers,
// e.g. OTC/SGE with no Yahoo data) is still skipped silently.
func (s *Service) BackfillPriceHistory(ctx context.Context, rangeName string) (int, error) {
	if s.historicalProvider == nil || s.priceHistoryRepo == nil {
		return 0, fmt.Errorf("backfill: historical provider/price history repo not configured")
	}
	datalen := datalenForRange(rangeName)
	backfilled := 0
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.securityRepo.FindAll(ctx, nil, page)
		if err != nil {
			return backfilled, fmt.Errorf("backfill: list securities: %w", err)
		}
		for _, sec := range result.Items {
			if err := ctx.Err(); err != nil {
				return backfilled, err
			}
			view := priceprovider.PriceView{Symbol: sec.Symbol, Exchange: sec.Exchange, Type: sec.SecurityType}
			pts, err := s.historicalProvider.FetchHistory(ctx, view, datalen)
			if err != nil {
				if errors.Is(err, priceprovider.ErrNoSource) {
					continue // non A-share (US/OTC/SGE) — no history in batch
				}
				slog.Warn("holding backfill: fetch history failed",
					slog.String("symbol", sec.Symbol),
					slog.String("error", err.Error()),
					slog.String("operation", "BackfillPriceHistory"))
				continue
			}
			ph := make([]domain.SecurityPriceHistory, 0, len(pts))
			for _, p := range pts {
				ph = append(ph, domain.SecurityPriceHistory{
					SecurityID: sec.ID, PriceDate: p.Date, PriceCents: p.PriceCents,
					CurrencyCode: sec.CurrencyCode, Source: "backfill",
				})
			}
			if err := s.priceHistoryRepo.SaveAll(ctx, ph); err != nil {
				slog.Warn("holding backfill: save failed",
					slog.String("symbol", sec.Symbol),
					slog.String("error", err.Error()),
					slog.String("operation", "BackfillPriceHistory"))
				continue
			}
			backfilled++
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return backfilled, nil
}

// GetPortfolioPerformance builds the portfolio base-currency curve +
// realized/unrealized + annualized + optional CSI300 benchmark. baseCurrency
// configures the reporting currency (default "CNY" when empty): all components
// (curve sample, realized, unrealized, cost basis) are 折算 to base via the
// CNY-base cross rate (ConvertToBase); out.Currency reflects base.
func (s *Service) GetPortfolioPerformance(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, rangeName string, withBenchmark bool, baseCurrency string) (*PortfolioPerformance, error) {
	if s.snapshotRepo == nil {
		return nil, fmt.Errorf("portfolio perf: snapshot repo not configured")
	}
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	from, to, granularity := s.curveWindow(rangeName)
	snaps, err := s.snapshotRepo.FindSnapshots(ctx, tenantID, from, to, accountID, nil)
	if err != nil {
		return nil, fmt.Errorf("portfolio perf: find snapshots: %w", err)
	}
	// Sample by granularity: group snapshots by day/month/year bucket, take last per bucket.
	portPts := s.samplePortfolioInBase(snaps, granularity, base)
	// Realized: Σ sell realized + Σ dividend (from trades), 折算 to base.
	realized, _ := s.aggregateRealized(ctx, tenantID, accountID, base)
	// Unrealized (current): Σ current holding unrealized, 折算 to base.
	unrealized := s.currentUnrealizedInBase(ctx, tenantID, accountID, base)
	total := realized + unrealized
	// Cost basis (current): Σ qty×avgCost, 折算 to base — for total %.
	costBasis := s.currentCostBasisInBase(ctx, tenantID, accountID, base)
	totalPct := 0.0
	if costBasis != 0 {
		totalPct = float64(total) / float64(costBasis) * 100
	}
	// XIRR (Task 4): full-period (money-weighted, all cash flows) + range
	// (window = `from` from curveWindow). Degrades to nil independently when
	// historical prices are missing or there are no trades. Replaces the legacy
	// simple-annualization helper (annualizedPct, retired).
	fullXirr, rangeXirr, _ := s.portfolioXIRR(ctx, tenantID, accountID, base, from)
	// TWR (Task 4): full-period time-weighted annualized % + range (window =
	// `from` from curveWindow, same rangeStart XIRR uses). Degrades to nil
	// independently of XIRR (insufficient sub-periods or missing prices); range
	// degrades independently of full (rangeStart outside [first, last] cashFlowDay
	// or empty opening position).
	fullTwr, rangeTwr, _ := s.portfolioTWR(ctx, tenantID, accountID, base, from)
	// CAGR (Task 1): simple compound annualized (final/initial)^(365/days)-1.
	// Full: costBasis→currentMV; range: rangeStartMV→currentMV. Independent nil
	// degrade (照 XIRR/TWR); a third return alongside XIRR + TWR for comparison.
	fullCagr, rangeCagr, _ := s.portfolioCAGR(ctx, tenantID, accountID, base, from)
	out := &PortfolioPerformance{
		PortfolioPoints: portPts, RealizedCents: realized, UnrealizedCents: unrealized,
		TotalCents: total, AnnualizedPct: fullXirr, RangeAnnualizedPct: rangeXirr,
		TwrAnnualizedPct: fullTwr, RangeTwrAnnualizedPct: rangeTwr,
		CagrAnnualizedPct: fullCagr, RangeCagrAnnualizedPct: rangeCagr,
		TotalPct: totalPct, Currency: base,
	}
	if withBenchmark {
		out.BenchmarkName = "沪深300"
		out.BenchmarkPoints = s.benchmarkCurve(ctx, rangeName)
	}
	return out, nil
}

// samplePortfolioInBase groups snapshots by granularity bucket
// (day/month/year), takes the last snapshot per holding per bucket, sums to
// portfolio market value per bucket date,折算 each holding's original currency
// to baseCurrency via CNY-base cross rate (ConvertToBase). baseCurrency
// defaults to CNY when empty; holdings whose currency equals base stay raw.
func (s *Service) samplePortfolioInBase(snaps []domain.HoldingSnapshot, granularity string, baseCurrency string) []CurvePointDTO {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(context.Background(), base)
	// bucket key = truncated date; collect last snapshot per (holding, bucket).
	type key struct {
		holding uuid.UUID
		bucket  time.Time
	}
	last := map[key]domain.HoldingSnapshot{}
	for _, sn := range snaps {
		b := bucketOf(sn.SnapshotDate, granularity)
		k := key{sn.HoldingID, b}
		if cur, ok := last[k]; !ok || sn.SnapshotDate.After(cur.SnapshotDate) {
			last[k] = sn
		}
	}
	// sum market value per bucket date,折算 each holding's currency to base.
	byDate := map[time.Time]int64{}
	for _, sn := range last {
		rateFrom := s.rateForCode(context.Background(), sn.CurrencyCode, sn.SnapshotDate)
		converted := currencydomain.ConvertToBase(sn.MarketValueCents, rateFrom, rateBase)
		byDate[bucketOf(sn.SnapshotDate, granularity)] += converted
	}
	// sorted points (double value in 元).
	dates := make([]time.Time, 0, len(byDate))
	for d := range byDate {
		dates = append(dates, d)
	}
	sort.Slice(dates, func(i, j int) bool { return dates[i].Before(dates[j]) })
	pts := make([]CurvePointDTO, 0, len(dates))
	for _, d := range dates {
		pts = append(pts, CurvePointDTO{Time: d, Value: float64(byDate[d]) / 100.0})
	}
	return pts
}

// bucketOf truncates a time to the start of its granularity bucket
// (day/month/year), in UTC.
func bucketOf(t time.Time, granularity string) time.Time {
	switch granularity {
	case "month":
		return time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC)
	case "year":
		return time.Date(t.Year(), 1, 1, 0, 0, 0, 0, time.UTC)
	default:
		return truncateToDate(t)
	}
}

// aggregateRealized sums sell FIFO realized + dividend total across the
// portfolio's trades, 折算 each trade's original currency to baseCurrency via
// rate history. baseCurrency="" defaults to CNY (rate=1.0).照 samplePortfolioCNY
// 模式:每 trade → security.CurrencyCode → FindRate(code, tradeDate) +
// FindRate(base) → ConvertToBase → Σ base. FindRate 缺失返 1.0 (graceful).
func (s *Service) aggregateRealized(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string) (int64, error) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(ctx, base)
	var sum int64
	page := domain.PageRequest{PageSize: 200}
	for {
		res, err := s.tradeRepo.FindAll(ctx, tenantID, accountID, nil, page)
		if err != nil {
			return sum, nil
		}
		for _, tr := range res.Items {
			amount := tr.RealizedPnLCents // sell realized
			if tr.TradeType == domain.TradeTypeDividend {
				amount = tr.AmountCents // dividend as realized income
			}
			sum += s.convertTradeToBase(ctx, amount, tr.SecurityID, tr.TradeDate, rateBase, base)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum, nil
}

// aggregateRealizedForSecurity narrows aggregateRealized to one security
// (GetHoldingPerformance — this holding's realized only), 折算 to baseCurrency.
func (s *Service) aggregateRealizedForSecurity(ctx context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID, baseCurrency string) (int64, error) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(ctx, base)
	var sum int64
	page := domain.PageRequest{PageSize: 200}
	for {
		res, err := s.tradeRepo.FindAll(ctx, tenantID, accountID, securityID, page)
		if err != nil {
			return sum, nil
		}
		for _, tr := range res.Items {
			amount := tr.RealizedPnLCents
			if tr.TradeType == domain.TradeTypeDividend {
				amount = tr.AmountCents
			}
			sum += s.convertTradeToBase(ctx, amount, tr.SecurityID, tr.TradeDate, rateBase, base)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum, nil
}

// rateForCode returns the CNY-base rate for [code] at [date] (1 unit of code
// = X CNY), or 1.0 when rateRepo is unset, [code] is empty, or the rate is
// missing — the graceful-fallback idiom repeated across D-currency. Used as
// rateFrom in ConvertToBase(amount, rateFrom, rateBase).
func (s *Service) rateForCode(ctx context.Context, code string, date time.Time) float64 {
	if s.rateRepo == nil || code == "" {
		return 1.0
	}
	r, _ := s.rateRepo.FindRate(ctx, code, date)
	return r
}

// rateForBase returns the current CNY-base rate for the base currency [base]
// (the denominator in cross-rate ConvertToBase). 1.0 fallback when rateRepo is
// unset or the rate is missing.
func (s *Service) rateForBase(ctx context.Context, base string) float64 {
	return s.rateForCode(ctx, base, s.now())
}

// convertTradeToBase 折算 a single trade amount to base via the CNY-base cross
// rate (照 samplePortfolioInBase / currentUnrealizedInBase 模式). Looks up the
// security's currency code + the from-rate at tradeDate. Missing security or
// rate → 1.0 (graceful, no conversion). If the security's currency equals base,
// the amount is returned unchanged (same currency, no conversion needed).
func (s *Service) convertTradeToBase(ctx context.Context, amount int64, securityID uuid.UUID, tradeDate time.Time, rateBase float64, base string) int64 {
	if amount == 0 || s.rateRepo == nil {
		return amount
	}
	sec, err := s.securityRepo.FindByID(ctx, securityID)
	if err != nil || sec == nil {
		return amount // security missing → no conversion (best-effort)
	}
	if sec.CurrencyCode == "" || sec.CurrencyCode == base {
		return amount // same currency as base, no conversion needed
	}
	rateFrom := s.rateForCode(ctx, sec.CurrencyCode, tradeDate)
	return currencydomain.ConvertToBase(amount, rateFrom, rateBase)
}

// currentUnrealizedInBase sums the current unrealized P&L across all holdings,
// 折算 each holding's currency to baseCurrency via CNY-base cross rate
// (ConvertToBase). baseCurrency defaults to CNY when empty (rate=1.0).
func (s *Service) currentUnrealizedInBase(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string) int64 {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(ctx, base)
	var sum int64
	page := domain.PageRequest{PageSize: 100}
	for {
		res, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
		if err != nil {
			return sum
		}
		for _, h := range res.Items {
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				continue
			}
			pnl := h.UnrealizedPnL(sec.CurrentPriceCents)
			rateFrom := s.rateForCode(ctx, sec.CurrencyCode, s.now())
			sum += currencydomain.ConvertToBase(pnl, rateFrom, rateBase)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}

// currentCostBasisInBase sums the current cost basis (qty × avgCost) across all
// holdings,折算 each holding's currency to baseCurrency via CNY-base cross rate
// (ConvertToBase). baseCurrency defaults to CNY when empty (rate=1.0).
func (s *Service) currentCostBasisInBase(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string) int64 {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(ctx, base)
	var sum int64
	page := domain.PageRequest{PageSize: 100}
	for {
		res, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
		if err != nil {
			return sum
		}
		for _, h := range res.Items {
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				continue
			}
			basis := int64(math.Round(float64(h.AvgCostCents) * h.Quantity))
			rateFrom := s.rateForCode(ctx, sec.CurrencyCode, s.now())
			sum += currencydomain.ConvertToBase(basis, rateFrom, rateBase)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}

// benchmarkCurve returns CSI300 (000300) price history as curve points (元).
// Empty if the security is not seeded or has no history.
func (s *Service) benchmarkCurve(ctx context.Context, rangeName string) []CurvePointDTO {
	if s.priceHistoryRepo == nil {
		return nil
	}
	from, to, _ := s.curveWindow(rangeName)
	sec, err := s.securityRepo.FindBySymbol(ctx, "000300", "SSE")
	if err != nil || sec == nil {
		return nil
	}
	ph, err := s.priceHistoryRepo.FindBySecurity(ctx, sec.ID, from, to)
	if err != nil {
		return nil
	}
	pts := make([]CurvePointDTO, 0, len(ph))
	for _, p := range ph {
		pts = append(pts, CurvePointDTO{Time: p.PriceDate, Value: float64(p.PriceCents) / 100.0})
	}
	return pts
}

// GetHoldingPerformance builds a single-holding curve (original-currency price
// from price_history) + this holding's realized + current unrealized.
// baseCurrency configures the foot reporting currency (default "CNY" when
// empty): realized is 折算 to base via aggregateRealizedForSecurity. The price
// curve stays in the security's original currency (single-holding display);
// unrealized is left in original currency for the same reason. out.Currency
// reflects the security's original currency (curve/foot currency).
func (s *Service) GetHoldingPerformance(ctx context.Context, tenantID uuid.UUID, holdingID uuid.UUID, rangeName string, baseCurrency string) (*HoldingPerformance, error) {
	if s.priceHistoryRepo == nil {
		return nil, fmt.Errorf("holding perf: price history repo not configured")
	}
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	from, to, _ := s.curveWindow(rangeName)
	h, err := s.holdingRepo.FindByID(ctx, tenantID, holdingID)
	if err != nil {
		return nil, fmt.Errorf("holding perf: find holding: %w", err)
	}
	sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
	if err != nil || sec == nil {
		return nil, fmt.Errorf("holding perf: security missing: %w", err)
	}
	// Price curve (original currency).
	ph, err := s.priceHistoryRepo.FindBySecurity(ctx, h.SecurityID, from, to)
	if err != nil {
		return nil, fmt.Errorf("holding perf: price history: %w", err)
	}
	pts := make([]CurvePointDTO, 0, len(ph))
	for _, p := range ph {
		pts = append(pts, CurvePointDTO{Time: p.PriceDate, Value: float64(p.PriceCents) / 100.0})
	}
	// Realized for this holding: Σ trade.realized where trade.securityID = holding.securityID
	// within the same (tenant, account), 折算 to base.
	realized, _ := s.aggregateRealizedForSecurity(ctx, h.TenantID, &h.AccountID, &h.SecurityID, base)
	// Unrealized (current), 折算 to base (mirrors GetPortfolioPerformance/currentUnrealizedInBase
	// so TotalCents is base+base, not base+原币 — spec §4.4 + I-1).
	rateBase := s.rateForBase(ctx, base)
	rateFrom := s.rateForCode(ctx, sec.CurrencyCode, s.now())
	unrealizedRaw := h.UnrealizedPnL(sec.CurrentPriceCents)
	unrealized := currencydomain.ConvertToBase(unrealizedRaw, rateFrom, rateBase)
	// XIRR (Task 4): full-period (original currency, no conversion) + range
	// (rebuilt from price_history endpoint). Both degrade independently to nil.
	fullXirr, _ := s.holdingXIRR(ctx, tenantID, holdingID, base)
	rangeStart, _, _ := s.curveWindow(rangeName)
	// trades fetched once, shared by range XIRR + CAGR (split-adjustment).
	trades := s.tradesForHolding(ctx, *h)
	rng := s.computeHoldingRangeXIRR(ctx, *h, *sec, trades, rangeStart, fullXirr)
	// TWR (Task 4): full-period time-weighted annualized % in original currency,
	// degrades to nil independently of XIRR.
	twr, _ := s.holdingTWR(ctx, tenantID, holdingID)
	// CAGR (Task 1): simple compound annualized (final/initial)^(365/days)-1 in
	// original currency. Full: first price → current; range: rangeStart price →
	// current. Independent nil degrade (照 holdingXIRR/holdingTWR).
	fullCagr, rangeCagr, _ := s.holdingCAGR(ctx, *h, *sec, trades, rangeStart)
	return &HoldingPerformance{
		PricePoints: pts, RealizedCents: realized, UnrealizedCents: unrealized,
		TotalCents: realized + unrealized, AnnualizedPct: fullXirr, RangeAnnualizedPct: rng,
		TwrAnnualizedPct: twr, CagrAnnualizedPct: fullCagr, RangeCagrAnnualizedPct: rangeCagr,
		Currency: base,
	}, nil
}

// tradesForHolding pages through every trade for one holding (account+security).
// Shared by computeHoldingRangeXIRR (range XIRR rebuild) and any helper that
// needs this holding's cash-flow stream in original currency.
func (s *Service) tradesForHolding(ctx context.Context, h domain.Holding) []domain.HoldingTransaction {
	res, _ := s.tradeRepo.FindAll(ctx, h.TenantID, &h.AccountID, &h.SecurityID, domain.PageRequest{PageSize: 500})
	if res == nil {
		return nil
	}
	return res.Items
}

// computeHoldingRangeXIRR computes the single-holding range XIRR in original
// currency. rangeStart is the window start (from curveWindow). Cash flows:
// opening market value (qty_at_date × price_at_or_before rangeStart) as outflow,
// in-range trades ± fee/sign, and current terminal market value.
// Degrades independently:
//   - qty==0 at rangeStart (rangeStart before first buy) → fallback (full XIRR)
//   - price_history missing at rangeStart → nil (cannot rebuild opening MV)
//   - XIRR fails to converge → nil
//
// `fallback` is provided by the caller (full-period XIRR) so the range path
// degrades gracefully to the full-period value when there is nothing to compute.
func (s *Service) computeHoldingRangeXIRR(ctx context.Context, h domain.Holding, sec domain.Security, trades []domain.HoldingTransaction, rangeStart time.Time, fallback *float64) *float64 {
	qty := domain.QtyAtDate(trades, rangeStart)
	if qty == 0 {
		return fallback // rangeStart before first buy → degrade to full
	}
	price, ok := s.priceAtOrBefore(ctx, h.SecurityID, rangeStart)
	if !ok {
		return nil // history missing → degrade
	}
	startMV := int64(math.Round(qty * float64(price)))
	terminal := h.MarketValue(sec.CurrentPriceCents)
	cfs := []domain.CashFlow{{Date: rangeStart, Amount: -float64(startMV)}}
	for _, tr := range trades {
		if !tr.TradeDate.After(rangeStart) {
			continue
		}
		var signed int64
		switch tr.TradeType {
		case domain.TradeTypeBuy:
			signed = -(tr.AmountCents + tr.FeeCents)
		case domain.TradeTypeSell:
			signed = tr.AmountCents - tr.FeeCents
		case domain.TradeTypeDividend:
			signed = tr.AmountCents
		case domain.TradeTypeSplit:
			continue
		default:
			continue
		}
		cfs = append(cfs, domain.CashFlow{Date: tr.TradeDate, Amount: float64(signed)})
	}
	cfs = append(cfs, domain.CashFlow{Date: s.now(), Amount: float64(terminal)})
	if r, e := domain.XIRR(cfs); e == nil {
		return ptrFloat(r)
	}
	return nil
}

// --- XIRR orchestration (Task 3): portfolioXIRR / holdingXIRR + helpers ---
// Reuses Task 1 domain.XIRR / CashFlow + Task 2 domain.QtyAtDate. Plugged into
// GetPortfolioPerformance / GetHoldingPerformance in Task 4.

// ptrFloat wraps a float64 as *float64 (DTO nullable field helper).
func ptrFloat(v float64) *float64 { return &v }

// collectTradeCashFlows maps trades to XIRR cash flows (base cents, converted).
// buy=−(amount+fee)、sell=+(amount−fee)、dividend=+amount、split ignored.
// mode="full" takes all trades; "range" only takes trades after rangeStart.
func (s *Service) collectTradeCashFlows(ctx context.Context, trades []domain.HoldingTransaction, mode string, rangeStart time.Time, rateBase float64, base string) []domain.CashFlow {
	cfs := make([]domain.CashFlow, 0, len(trades))
	for _, tr := range trades {
		if mode == "range" && !tr.TradeDate.After(rangeStart) {
			continue // range mode: only trades strictly after rangeStart
		}
		var signed int64
		switch tr.TradeType {
		case domain.TradeTypeBuy:
			signed = -(tr.AmountCents + tr.FeeCents)
		case domain.TradeTypeSell:
			signed = tr.AmountCents - tr.FeeCents
		case domain.TradeTypeDividend:
			signed = tr.AmountCents
		case domain.TradeTypeSplit:
			continue
		default:
			continue
		}
		amount := s.convertTradeToBase(ctx, signed, tr.SecurityID, tr.TradeDate, rateBase, base)
		cfs = append(cfs, domain.CashFlow{Date: tr.TradeDate, Amount: float64(amount)})
	}
	return cfs
}

// currentMarketValueInBase returns the current total portfolio market value
// (base cents) = Σ qty×currentPrice converted. Reuses currentCostBasisInBase +
// currentUnrealizedInBase (both base; their sum = market value).
func (s *Service) currentMarketValueInBase(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, base string) int64 {
	return s.currentCostBasisInBase(ctx, tenantID, accountID, base) +
		s.currentUnrealizedInBase(ctx, tenantID, accountID, base)
}

// marketValueAtDate rebuilds the portfolio market value (base cents) at [date]
// using historical prices + QtyAtDate. Any holding missing a historical price
// yields ok=false (caller degrades range XIRR).
//
// Thin delegate to marketValueAtDateAsOf(date, date): XIRR's single-as-of
// semantics (qty and price read at the same instant) is the AsOf(t,t) case.
func (s *Service) marketValueAtDate(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, date time.Time, rateBase float64, base string) (int64, bool) {
	return s.marketValueAtDateAsOf(ctx, tenantID, accountID, date, date, rateBase, base)
}

// marketValueAtDateAsOf rebuilds portfolio market value (base cents) with
// SEPARATE qty as-of [qtyAsOf] and price as-of [priceAsOf]. TWR needs this:
// BV_before(t_i) = qty@(trade 前)× price@(t_i)  → AsOf(t_i, t_i)
// BV_after(t_i)  = qty@(trade 后)× price@(t_i)  → AsOf(t_i+1day, t_i)
// ok=false if any holding's price missing (caller degrades).
//
// Thin wrapper: hoists trades once then delegates to
// marketValueAtDateAsOfWithTrades. Callers that walk many as-of dates
// (portfolioTWR's cashFlowDay loop) already hoist trades and call
// marketValueAtDateAsOfWithTrades directly to avoid re-fetching
// allTradesForTenant per cashFlowDay (Task 3 review Important #1 perf fix:
// N days × M holdings → ~5000 repo round trips on a 10-year portfolio).
func (s *Service) marketValueAtDateAsOf(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, qtyAsOf, priceAsOf time.Time, rateBase float64, base string) (int64, bool) {
	secTrades, _ := s.allTradesForTenant(ctx, tenantID, accountID)
	return s.marketValueAtDateAsOfWithTrades(ctx, secTrades, tenantID, accountID, qtyAsOf, priceAsOf, rateBase, base)
}

// marketValueAtDateAsOfWithTrades is the trades-injected core of
// marketValueAtDateAsOf. The caller hoists allTradesForTenant once and passes
// the slice so the cashFlowDay loop in portfolioTWR doesn't re-fetch trades
// per iteration. Result is byte-identical to marketValueAtDateAsOf for the
// same (trades, as-of) inputs — XIRR's marketValueAtDate → marketValueAtDateAsOf
// delegation chain stays transparent.
func (s *Service) marketValueAtDateAsOfWithTrades(ctx context.Context, secTrades []domain.HoldingTransaction, tenantID uuid.UUID, accountID *uuid.UUID, qtyAsOf, priceAsOf time.Time, rateBase float64, base string) (int64, bool) {
	var sum int64
	page := domain.PageRequest{PageSize: 100}
	for {
		res, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
		if err != nil {
			return 0, false
		}
		for _, h := range res.Items {
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				slog.Warn("portfolio range market-value degrade: holding security missing",
					slog.String("security_id", h.SecurityID.String()),
					slog.String("qty_as_of", qtyAsOf.Format("2006-01-02")),
					slog.String("price_as_of", priceAsOf.Format("2006-01-02")),
					slog.String("operation", "marketValueAtDateAsOfWithTrades"))
				return 0, false
			}
			qty := domain.QtyAtDate(filterTradesBySecurity(secTrades, h.SecurityID), qtyAsOf)
			if qty == 0 {
				continue
			}
			price, ok := s.priceAtOrBefore(ctx, h.SecurityID, priceAsOf)
			if !ok {
				slog.Warn("portfolio range market-value degrade: holding price history missing for date",
					slog.String("security_id", h.SecurityID.String()),
					slog.String("price_as_of", priceAsOf.Format("2006-01-02")),
					slog.String("operation", "marketValueAtDateAsOfWithTrades"))
				return 0, false // history missing (US stocks/OTC) → degrade
			}
			mv := int64(math.Round(qty * float64(price)))
			rateFrom := s.rateForCode(ctx, sec.CurrencyCode, priceAsOf)
			sum += currencydomain.ConvertToBase(mv, rateFrom, rateBase)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum, true
}

// allTradesForTenant pages through every trade for (tenant, account) — shared
// by portfolio XIRR cash flows + QtyAtDate rebuild. Returns trades in
// deterministic (trade_date ASC, id ASC) order so same-day Split+Buy cannot
// reorder unpredictably between runs.
func (s *Service) allTradesForTenant(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) ([]domain.HoldingTransaction, error) {
	var all []domain.HoldingTransaction
	page := domain.PageRequest{PageSize: 500}
	for {
		res, err := s.tradeRepo.FindAll(ctx, tenantID, accountID, nil, page)
		if err != nil {
			return all, nil
		}
		all = append(all, res.Items...)
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	sort.Slice(all, func(i, j int) bool {
		if !all[i].TradeDate.Equal(all[j].TradeDate) {
			return all[i].TradeDate.Before(all[j].TradeDate)
		}
		return all[i].ID.String() < all[j].ID.String()
	})
	return all, nil
}

// portfolioXIRR computes portfolio-level full-period + range XIRR (base-converted).
// rangeStart is the range window start (CurveRange.from, computed by Task 4's
// GetPortfolioPerformance via curveWindow). Degrades to nil; range degrades
// independently of full when historical prices are missing.
func (s *Service) portfolioXIRR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string, rangeStart time.Time) (full, rng *float64, err error) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(ctx, base)
	trades, _ := s.allTradesForTenant(ctx, tenantID, accountID)
	if len(trades) == 0 {
		return nil, nil, nil
	}
	terminal := s.currentMarketValueInBase(ctx, tenantID, accountID, base)
	// Full period: all trades + current terminal value.
	fullCfs := append(s.collectTradeCashFlows(ctx, trades, "full", time.Time{}, rateBase, base),
		domain.CashFlow{Date: s.now(), Amount: float64(terminal)})
	if r, e := domain.XIRR(fullCfs); e == nil {
		full = ptrFloat(r)
	}
	// Range: opening market value as outflow (−) + in-range trades + terminal.
	startMV, ok := s.marketValueAtDate(ctx, tenantID, accountID, rangeStart, rateBase, base)
	if !ok {
		return full, nil, nil // range history missing → degrade, full still returned
	}
	rangeCfs := []domain.CashFlow{{Date: rangeStart, Amount: -float64(startMV)}}
	rangeCfs = append(rangeCfs, s.collectTradeCashFlows(ctx, trades, "range", rangeStart, rateBase, base)...)
	rangeCfs = append(rangeCfs, domain.CashFlow{Date: s.now(), Amount: float64(terminal)})
	if r, e := domain.XIRR(rangeCfs); e == nil {
		rng = ptrFloat(r)
	}
	return full, rng, nil
}

// mvCacheKey identifies a cached market-value computation within one request.
// tenantID/rateBase/base are fixed inside portfolioTWR (single base per request),
// so they are not part of the key.
type mvCacheKey struct {
	accountID uuid.UUID // nil (portfolio-level) → uuid.Nil; specific account → *accountID
	qtyAsOf   time.Time
	priceAsOf time.Time
}

// mvCache memoizes marketValueAtDateAsOfWithTrades results within one portfolioTWR
// call so full + range computeTWR share BV(day) (range ⊂ full). Both val and ok
// (ok=false = price missing → degrade) are cached to avoid recomputing misses.
type mvCache map[mvCacheKey]struct {
	val int64
	ok  bool
}

// cachedMV is a memoizing wrapper around marketValueAtDateAsOfWithTrades. On cache
// hit it returns the cached (val, ok); on miss it computes, stores, and returns.
// Transparent: identical results to a direct marketValueAtDateAsOfWithTrades call.
func (s *Service) cachedMV(ctx context.Context, cache mvCache, trades []domain.HoldingTransaction,
	tenantID uuid.UUID, accountID *uuid.UUID, qtyAsOf, priceAsOf time.Time, rateBase float64, base string) (int64, bool) {
	ac := uuid.Nil
	if accountID != nil {
		ac = *accountID
	}
	key := mvCacheKey{accountID: ac, qtyAsOf: qtyAsOf, priceAsOf: priceAsOf}
	if v, hit := cache[key]; hit {
		return v.val, v.ok
	}
	val, ok := s.marketValueAtDateAsOfWithTrades(ctx, trades, tenantID, accountID, qtyAsOf, priceAsOf, rateBase, base)
	cache[key] = struct {
		val int64
		ok  bool
	}{val, ok}
	return val, ok
}

// computeTWR computes GIPS TWR over [rangeStart, now] using sub-period chaining
// with full-liquidation segmentation (design ADR-4, spec FR-3):
//
//   - 中途完全清仓段(qty=0 区间)整段跳过,重建日重启子链,逐段链乘
//     (GIPS:完全清仓=组合终止,重建视为新 track;清仓 gap 不贡献收益也不贡献天数);
//   - 终态完全清仓:链终止于清仓日(尾因子=1),年化按实际存续天数——不乘 0
//     (乘 0 会把"清仓"误报为 -100%);
//   - qty>0 但 MV=0(退市/坏价格)= 数据错误 ≠ 收益:sentinel 降级 nil + 英文日志。
//
//	effectiveDays = cashFlowDays strictly after rangeStart (sub-period endpoints)
//	begin = BV_after(rangeStart) = qty@rangeStart+1d × price@rangeStart
//	subPeriods[i] = {Begin: prevAfter, End: BV_before(day_i)}
//	finalValue = current market value (open final segment only)
//
// 无清仓路径与旧实现 byte-identical(单段 = 同样的 subs + 尾因子 + totalDays)。
// Returns nil on insufficient data or missing prices (degrade, mirrors portfolioTWR).
//
// cache memoizes marketValueAtDateAsOfWithTrades results across calls sharing the
// same BV(day) (e.g. portfolioTWR's full + range computeTWR). Transparent: a nil
// or empty cache is functionally identical to no caching.
func (s *Service) computeTWR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, base string, rateBase float64, trades []domain.HoldingTransaction, cashFlowDays []time.Time, rangeStart time.Time, cache mvCache) (*float64, error) {
	var effectiveDays []time.Time
	for _, d := range cashFlowDays {
		if d.After(rangeStart) {
			effectiveDays = append(effectiveDays, d)
		}
	}
	if len(effectiveDays) == 0 {
		return nil, nil
	}
	beginAfter, ok := s.cachedMV(ctx, cache, trades, tenantID, accountID, rangeStart.AddDate(0, 0, 1), rangeStart, rateBase, base)
	if !ok {
		return nil, nil
	}

	// twrSegment 是清仓分段链乘中的一段。
	type twrSegment struct {
		subs       []domain.SubPeriodReturn
		lastAfter  float64   // BV_after(段内最后处理的现金流日)
		tailBase   float64   // terminated 段的尾因子基准 = BV_before(清仓日)
		finalMV    float64   // 开段闭合时的当前市值(尾因子分子)
		startDay   time.Time // 段起点(rangeStart 或重建日)
		endDay     time.Time // 段终点(清仓日或 now)
		terminated bool      // 段末为完全清仓(GIPS discontinued)
	}
	var (
		segments []twrSegment
		cur      twrSegment
		active   bool
	)
	if beginAfter > 0 {
		cur = twrSegment{startDay: rangeStart, lastAfter: float64(beginAfter)}
		active = true
	} else if !s.portfolioEmptyAt(ctx, trades, tenantID, accountID, rangeStart.AddDate(0, 0, 1)) {
		// 开盘 MV=0 但持仓非空:坏价 sentinel(数据错误 ≠ 收益)。
		slog.Warn("portfolio twr degrade: zero market value with open quantity at range start",
			slog.String("qty_as_of", rangeStart.AddDate(0, 0, 1).Format("2006-01-02")),
			slog.String("operation", "computeTWR"))
		return nil, nil
	}

	for _, day := range effectiveDays {
		bvBefore, okB := s.cachedMV(ctx, cache, trades, tenantID, accountID, day, day, rateBase, base)
		if !okB {
			return nil, nil
		}
		bvAfter, okA := s.cachedMV(ctx, cache, trades, tenantID, accountID, day.AddDate(0, 0, 1), day, rateBase, base)
		if !okA {
			return nil, nil
		}
		if !active {
			// 清仓 gap 中:等待重建日(trade 后 MV>0 的首个现金流日)。
			if bvAfter > 0 {
				cur = twrSegment{startDay: day, lastAfter: float64(bvAfter)}
				active = true
			} else if bvAfter == 0 && !s.portfolioEmptyAt(ctx, trades, tenantID, accountID, day.AddDate(0, 0, 1)) {
				slog.Warn("portfolio twr degrade: zero market value with open quantity in liquidation gap",
					slog.String("qty_as_of", day.AddDate(0, 0, 1).Format("2006-01-02")),
					slog.String("operation", "computeTWR"))
				return nil, nil
			}
			continue
		}
		if bvBefore == 0 {
			// active 段的端点不可能合法为 0(前一现金流日后有持仓):
			// 必为坏价(价格拍到 0)→ sentinel 降级。
			slog.Warn("portfolio twr degrade: zero market value with open quantity at sub-period end",
				slog.String("price_as_of", day.Format("2006-01-02")),
				slog.String("operation", "computeTWR"))
			return nil, nil
		}
		cur.subs = append(cur.subs, domain.SubPeriodReturn{
			BeginValueAfterCF: cur.lastAfter,
			EndValueBeforeCF:  float64(bvBefore),
		})
		cur.lastAfter = float64(bvAfter)
		if bvAfter == 0 {
			// 当日完全清仓 → 闭段(终止语义:尾因子基准 = 清仓日前市值)。
			if !s.portfolioEmptyAt(ctx, trades, tenantID, accountID, day.AddDate(0, 0, 1)) {
				slog.Warn("portfolio twr degrade: zero market value with open quantity at liquidation day",
					slog.String("qty_as_of", day.AddDate(0, 0, 1).Format("2006-01-02")),
					slog.String("operation", "computeTWR"))
				return nil, nil
			}
			cur.tailBase = float64(bvBefore)
			cur.endDay = day
			cur.terminated = true
			segments = append(segments, cur)
			cur = twrSegment{}
			active = false
		}
	}
	if active {
		finalValue := s.currentMarketValueInBase(ctx, tenantID, accountID, base)
		if float64(finalValue) == 0 && cur.lastAfter > 0 {
			slog.Warn("portfolio twr degrade: zero current market value with open quantity",
				slog.String("operation", "computeTWR"))
			return nil, nil
		}
		cur.finalMV = float64(finalValue)
		cur.endDay = s.now()
		segments = append(segments, cur)
	}
	if len(segments) == 0 {
		return nil, nil // 全程空仓无重建:无收益可算
	}

	chainProduct := 1.0
	totalDays := 0
	for _, seg := range segments {
		var cum float64
		if seg.terminated {
			// 终止段:尾因子 = tailBase/tailBase = 1(收益止于清仓日)。
			c, err := domain.CumulativeTWR(seg.subs, seg.tailBase, seg.tailBase)
			if err != nil {
				slog.Warn("portfolio twr degrade: segment cumulative rejected",
					slog.String("error", err.Error()),
					slog.String("operation", "computeTWR"))
				return nil, nil
			}
			cum = c
		} else if len(seg.subs) == 0 {
			// 重建后无后续现金流日:单尾因子段(rebuild → now)。
			if seg.lastAfter == 0 {
				return nil, nil
			}
			cum = seg.finalMV/seg.lastAfter - 1
		} else {
			c, err := domain.CumulativeTWR(seg.subs, seg.finalMV, seg.lastAfter)
			if err != nil {
				slog.Warn("portfolio twr degrade: segment cumulative rejected",
					slog.String("error", err.Error()),
					slog.String("operation", "computeTWR"))
				return nil, nil
			}
			cum = c
		}
		chainProduct *= 1 + cum
		totalDays += int(seg.endDay.Sub(seg.startDay).Hours() / 24)
	}
	rate, err := domain.AnnualizeTWR(chainProduct-1, totalDays)
	if err != nil {
		slog.Warn("portfolio twr degrade: annualization rejected",
			slog.String("error", err.Error()),
			slog.String("operation", "computeTWR"))
		return nil, nil
	}
	return ptrFloat(rate), nil
}

// portfolioEmptyAt 判断 qtyAsOf 时点全部持仓数量是否为零(纯清仓态)。
// 用于区分 MV=0 的两种成因:完全清仓(合法,链终止/分段)vs 持仓未清但价格
// 为 0(数据错误 → sentinel 降级)。repo 出错时返回 false(fail-closed:
// 无法确认清仓 → 按"非空"处理 → 上层降级而非误判终止)。
func (s *Service) portfolioEmptyAt(ctx context.Context, secTrades []domain.HoldingTransaction, tenantID uuid.UUID, accountID *uuid.UUID, qtyAsOf time.Time) bool {
	page := domain.PageRequest{PageSize: 100}
	for {
		res, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
		if err != nil {
			return false
		}
		for _, h := range res.Items {
			if domain.QtyAtDate(filterTradesBySecurity(secTrades, h.SecurityID), qtyAsOf) != 0 {
				return false
			}
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return true
}

// portfolioTWR computes full-period + range TWR (base currency), mirroring
// portfolioXIRR(full, rng).
//
//	full: rangeStart = first trade date (cashFlowDays[0]) — byte-identical to
//	      the pre-Task-2 portfolioTWR (computeTWR full-period special case).
//	rng:  rangeStart = curveWindow(rangeName).from (passed by caller).
//
// Returns (nil, nil, nil) on insufficient data; full + rng degrade independently
// (range degrades when rangeStart is outside [first, last] cashFlowDay or the
// opening position is empty, but full still resolves).
func (s *Service) portfolioTWR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string, rangeStart time.Time) (full, rng *float64, err error) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(ctx, base)
	trades, _ := s.allTradesForTenant(ctx, tenantID, accountID)
	if len(trades) == 0 {
		return nil, nil, nil
	}
	cashFlowDays := uniqueSortedTradeDates(trades)
	if len(cashFlowDays) < 2 {
		return nil, nil, nil
	}
	// Request-scoped cache: full + range computeTWR share BV(day) for any
	// cashFlowDay inside the range window (range ⊂ full). Rebuilt per call so
	// there's no cross-request state. Transparent — byte-identical results.
	cache := mvCache{}
	full, _ = s.computeTWR(ctx, tenantID, accountID, base, rateBase, trades, cashFlowDays, cashFlowDays[0], cache)
	rng, _ = s.computeTWR(ctx, tenantID, accountID, base, rateBase, trades, cashFlowDays, rangeStart, cache)
	return full, rng, nil
}

// uniqueSortedTradeDates extracts unique trade_date values (day-truncated,
// sorted ascending) that are TWR cash-flow days — days with at least one
// buy/sell/dividend. Pure-split days are excluded: a split is a non-cash-flow
// event (market-value-neutral under GIPS), so it must not seed a TWR sub-period,
// or BV_before/after would pair one price with cross-scale (pre-/post-split)
// quantities → phantom HPR. The split trade stays in trades so QtyAtDate replay
// folds the ratio into the BV of the adjacent cash-flow days.
func uniqueSortedTradeDates(trades []domain.HoldingTransaction) []time.Time {
	hasCashFlow := map[time.Time]bool{}
	for _, t := range trades {
		if t.TradeType == domain.TradeTypeSplit {
			continue
		}
		hasCashFlow[t.TradeDate.Truncate(24*time.Hour)] = true
	}
	days := make([]time.Time, 0, len(hasCashFlow))
	for d := range hasCashFlow {
		days = append(days, d)
	}
	sort.Slice(days, func(i, j int) bool { return days[i].Before(days[j]) })
	return days
}

// holdingXIRR computes single-holding full-period XIRR (original currency, no
// conversion). Degrades to nil. Range XIRR is computed separately by Task 4's
// computeHoldingRangeXIRR (needs price_history endpoint rebuild).
func (s *Service) holdingXIRR(ctx context.Context, tenantID uuid.UUID, holdingID uuid.UUID, baseCurrency string) (full *float64, err error) {
	_ = baseCurrency // holding XIRR is original-currency; retained for Task 4 wiring symmetry
	h, err := s.holdingRepo.FindByID(ctx, tenantID, holdingID)
	if err != nil {
		return nil, fmt.Errorf("holding xirr: find holding: %w", err)
	}
	sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
	if err != nil || sec == nil {
		return nil, nil
	}
	res, err := s.tradeRepo.FindAll(ctx, h.TenantID, &h.AccountID, &h.SecurityID, domain.PageRequest{PageSize: 500})
	if err != nil || res == nil || len(res.Items) == 0 {
		return nil, nil
	}
	trades := res.Items
	// Original-currency cash flows (no conversion): trade amount ± fee directly.
	cfs := make([]domain.CashFlow, 0, len(trades)+1)
	for _, tr := range trades {
		var signed int64
		switch tr.TradeType {
		case domain.TradeTypeBuy:
			signed = -(tr.AmountCents + tr.FeeCents)
		case domain.TradeTypeSell:
			signed = tr.AmountCents - tr.FeeCents
		case domain.TradeTypeDividend:
			signed = tr.AmountCents
		case domain.TradeTypeSplit:
			continue
		default:
			continue
		}
		cfs = append(cfs, domain.CashFlow{Date: tr.TradeDate, Amount: float64(signed)})
	}
	terminal := h.MarketValue(sec.CurrentPriceCents) // original-currency market value
	cfs = append(cfs, domain.CashFlow{Date: s.now(), Amount: float64(terminal)})
	if r, e := domain.XIRR(cfs); e == nil {
		full = ptrFloat(r)
	}
	return full, nil
}

// holdingTWR computes single-holding full-period TWR (original currency, no
// conversion). Degrades to nil.
func (s *Service) holdingTWR(ctx context.Context, tenantID uuid.UUID, holdingID uuid.UUID) (*float64, error) {
	h, err := s.holdingRepo.FindByID(ctx, tenantID, holdingID)
	if err != nil {
		return nil, fmt.Errorf("holding twr: find holding: %w", err)
	}
	sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
	if err != nil || sec == nil {
		return nil, nil
	}
	trades := s.tradesForHolding(ctx, *h)
	if len(trades) == 0 {
		return nil, nil
	}
	cashFlowDays := uniqueSortedTradeDates(trades)
	if len(cashFlowDays) == 0 {
		return nil, nil
	}
	subPeriods := make([]domain.SubPeriodReturn, 0, len(cashFlowDays)-1)
	var prevAfterCF float64
	for i, day := range cashFlowDays {
		qtyBefore := domain.QtyAtDate(trades, day)
		price, ok := s.priceAtOrBefore(ctx, h.SecurityID, day)
		if !ok {
			return nil, nil
		}
		BV_before := float64(qtyBefore) * float64(price)
		qtyAfter := domain.QtyAtDate(trades, day.AddDate(0, 0, 1))
		BV_after := float64(qtyAfter) * float64(price)
		if i > 0 {
			subPeriods = append(subPeriods, domain.SubPeriodReturn{BeginValueAfterCF: prevAfterCF, EndValueBeforeCF: BV_before})
		}
		prevAfterCF = BV_after
	}
	finalValue := float64(h.MarketValue(sec.CurrentPriceCents)) // 原币
	totalDays := int(s.now().Sub(cashFlowDays[0]).Hours() / 24)
	if len(subPeriods) == 0 {
		// Single cashFlowDay(单 buy,或 buy+split —— split 经 uniqueSortedTradeDates
		// 排除后剩 1 个现金流日):无法切分 ≥2 个 GIPS 子区间,改走 single-period-link。
		//   TWR_annualized = (finalValue / BV_after(t0)) ^ (365 / totalDays) − 1
		// BV_after(t0) = prevAfterCF(loop 唯一一次迭代设);BV_after==0 除零 → 仍 nil;
		// totalDays<1 → nil(同多区间路径 ErrInsufficientPeriods 等价降级)。
		if prevAfterCF <= 0 || totalDays < 1 {
			return nil, nil
		}
		rate := math.Pow(finalValue/prevAfterCF, 365.0/float64(totalDays)) - 1
		return ptrFloat(rate), nil
	}
	cum, err := domain.CumulativeTWR(subPeriods, finalValue, prevAfterCF)
	if err != nil {
		return nil, nil
	}
	rate, err := domain.AnnualizeTWR(cum, totalDays)
	if err != nil {
		return nil, nil
	}
	return ptrFloat(rate), nil
}

// priceAtOrBefore returns the security's nearest price_history entry on or
// before [date] (forward-fill). Returns ok=false when priceHistoryRepo is nil
// or no entry covers the date.
//
// Split correctness: post-split BV relies on a raw price entry dated on/after
// the split day. A stale pre-split entry surviving a fetch gap across a split
// would pair post-split qty with pre-split price → 2× overstatement (the mirror
// of the cashFlowDays split-day bug fixed by excluding pure-split days). Price
// storage freshness is the providers' concern (out of scope per spec §3).
//
// priceAtOrBefore scans price_history for the latest row at or before [date].
// FindBySecurity's concrete impl sorts ASC by PriceDate, but the interface
// contract doesn't guarantee ordering, so we iterate defensively (same reason
// holdingCAGR scans for min-PriceDate rather than trusting all[0]).
func (s *Service) priceAtOrBefore(ctx context.Context, securityID uuid.UUID, date time.Time) (int64, bool) {
	if s.priceHistoryRepo == nil {
		return 0, false
	}
	ph, err := s.priceHistoryRepo.FindBySecurity(ctx, securityID, time.Unix(0, 0), date)
	if err != nil || len(ph) == 0 {
		return 0, false
	}
	// Pick the latest entry ≤ date (defensive scan — interface doesn't guarantee order).
	latest := ph[0]
	for _, p := range ph {
		if !p.PriceDate.After(date) && p.PriceDate.After(latest.PriceDate) {
			latest = p
		}
	}
	return latest.PriceCents, true
}

// --- CAGR orchestration: portfolioCAGR (MV-based) + holdingCAGR (price-based) ---
// Simple compound annualized growth = (final/initial)^(365/days)-1. Unlike XIRR
// (money-weighted, cash-flow sensitive) and TWR (time-weighted, sub-period
// chained), CAGR compares two endpoint values only — a single ratio over the
// elapsed calendar days. Degrades to nil independently for full + range when
// initial<=0, days<1, or history is missing (照 XIRR/TWR nil-degrade 范式).

// portfolioCAGR computes full + range portfolio CAGR (base currency, MV-based).
//
//	full: initial = currentCostBasisInBase, final = currentMarketValueInBase,
//	      days = earliest holding CreatedAt → now (portfolio inception proxy).
//	rng:  initial = marketValueAtDate(rangeStart), final = currentMarketValueInBase,
//	      days = rangeStart → now. Degrades when range history missing.
//
// Both degrade independently; full + rng each fall back to nil silently.
func (s *Service) portfolioCAGR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string, rangeStart time.Time) (full, rng *float64, err error) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	finalMV := s.currentMarketValueInBase(ctx, tenantID, accountID, base)
	// Full: cost basis → current market value over earliest-holding→now days.
	costBasis := s.currentCostBasisInBase(ctx, tenantID, accountID, base)
	earliest := s.earliestHoldingCreated(ctx, tenantID, accountID)
	if costBasis > 0 && !earliest.IsZero() {
		if days := int(s.now().Sub(earliest).Hours() / 24); days >= 1 {
			f := math.Pow(float64(finalMV)/float64(costBasis), 365.0/float64(days)) - 1
			full = ptrFloat(f)
		}
	}
	// Range: rangeStart MV → current MV over rangeStart→now days.
	startMV, ok := s.marketValueAtDate(ctx, tenantID, accountID, rangeStart, s.rateForBase(ctx, base), base)
	if ok && startMV > 0 {
		if days := int(s.now().Sub(rangeStart).Hours() / 24); days >= 1 {
			r := math.Pow(float64(finalMV)/float64(startMV), 365.0/float64(days)) - 1
			rng = ptrFloat(r)
		}
	}
	return full, rng, nil
}

// holdingCAGR computes full + range single-holding CAGR (original currency,
// price-based). No cash flows — purely a price ratio.
//
//	full: initial = priceAtOrBefore(earliestBuyDate) — the user's actual acquisition
//	      start (earliest TradeTypeBuy), NOT the security's price-history inception
//	      (spec §6.2 originally said "first price_history point" — that was a design
//	      oversight corrected P1-5: price_history backfilled earlier than the buy
//	      would understate CAGR via inflated day count). final = sec.CurrentPriceCents,
//	      days = earliestBuyDate → now. No buy trade → nil (production holdings always
//	      have a buy; tests passing nil trades must add one).
//	rng:  initial = priceAtOrBefore(rangeStart) (split-adjusted forward-fill),
//	      final = sec.CurrentPriceCents, days = rangeStart → now.
//
// Split correction (FIX 2, spec 2026-07-16-split-adjusted §3): price_history 存储
// raw(non-split-adjusted),post-split 行才是真值。所以 initial 用 raw first/start
// price 时,必须 ON-THE-FLY 按 price date 之后的累计拆分比 R 折算到 post-split:
//   price_adjusted = price_raw / R   (R = Π r_i, every split strictly after priceDate)
// Otherwise a 2:1 split 会把 ¥100 raw firstPrice 对 ¥50 current → spurious −33% CAGR。
// storage 不动(spec §3 明令),只在计算时折算。
//
// `trades` is the holding's trade stream (for split detection) — passed by the
// caller GetHoldingPerformance which already has them; nil/empty → R=1 (no splits).
//
// Both degrade independently to nil when initial<=0, days<1, history missing,
// or R is invalid (non-positive ratio — shouldn't happen; degrade 不造假).
func (s *Service) holdingCAGR(ctx context.Context, h domain.Holding, sec domain.Security, trades []domain.HoldingTransaction, rangeStart time.Time) (full, rng *float64, err error) {
	cur := float64(sec.CurrentPriceCents)
	if cur <= 0 {
		return nil, nil, nil
	}
	// Full: 持仓首个 buy 日(用户实际持有起点),非证券 price_history 起始日。
	// spec §6.2 原写 "first price_history point" 是设计疏漏 —— 那量的是证券价格史
	// 起点而非用户个人回报;回填早于买入时会低估(天数偏大)。现用首买日 +
	// priceAtOrBefore 取当时市价(forward-fill)。无 buy trade → 降级 nil(生产中
	// holding 必有 buy;单测 nil-trades 场景需补 buy trade)。
	firstDate := earliestBuyDate(trades)
	if !firstDate.IsZero() {
		if firstPrice, ok := s.priceAtOrBefore(ctx, h.SecurityID, firstDate); ok && firstPrice > 0 {
			R := cumulativeSplitRatio(trades, firstDate, s.now())
			if R > 0 { // R==0 → invalid split ratio → degrade (don't fabricate)
				if adjFirst := float64(firstPrice) / R; adjFirst > 0 {
					if days := int(s.now().Sub(firstDate).Hours() / 24); days >= 1 {
						full = ptrFloat(math.Pow(cur/adjFirst, 365.0/float64(days)) - 1)
					}
				}
			}
		}
	}
	// Range: priceAtOrBefore(rangeStart) → current over rangeStart→now days.
	startPriceCents, ok := s.priceAtOrBefore(ctx, h.SecurityID, rangeStart)
	if ok && startPriceCents > 0 {
		R := cumulativeSplitRatio(trades, rangeStart, s.now())
		if R > 0 {
			adjStart := float64(startPriceCents) / R
			if adjStart > 0 {
				if days := int(s.now().Sub(rangeStart).Hours() / 24); days >= 1 {
					r := math.Pow(cur/adjStart, 365.0/float64(days)) - 1
					rng = ptrFloat(r)
				}
			}
		}
	}
	return full, rng, nil
}

// cumulativeSplitRatio returns Π(r_i) for every TradeTypeSplit of this holding
// with tradeDate strictly AFTER priceDate and ≤ now. Returns 0 if any split
// ratio is non-positive (invalid — caller degrades to nil for that path).
//
// Split semantics: ratio r means qty *= r AND price /= r (see Holding.ApplySplit
// — `h.Quantity *= ratio; h.AvgCostCents /= ratio`). To express a pre-split
// price in post-split terms, divide by R: a ¥100 pre-split row with one r=2
// split after it becomes ¥50 in post-split terms (100 / 2).
//
// TradeTypeSplit stores the ratio in HoldingTransaction.Quantity (see
// Service.RecordSplit which builds `Quantity: req.Ratio`).
//
// now upper bound: splits dated after `now` (future) are excluded — they don't
// affect the price series observed up to `now`.
func cumulativeSplitRatio(trades []domain.HoldingTransaction, priceDate, now time.Time) float64 {
	product := 1.0
	for _, t := range trades {
		if t.TradeType != domain.TradeTypeSplit {
			continue
		}
		if !t.TradeDate.After(priceDate) {
			continue
		}
		if t.TradeDate.After(now) {
			continue
		}
		r := t.Quantity // TradeTypeSplit stores ratio here (see RecordSplit).
		if r <= 0 {
			return 0
		}
		product *= r
	}
	return product
}

// earliestBuyDate returns the earliest TradeTypeBuy date for a holding — the
// user's actual acquisition start (holdingCAGR full-period uses this so the
// annualized return reflects the user's holding period, not the security's
// price-history inception). Zero time when the holding has no buy trades.
func earliestBuyDate(trades []domain.HoldingTransaction) time.Time {
	var first time.Time
	for _, t := range trades {
		if t.TradeType != domain.TradeTypeBuy {
			continue
		}
		if first.IsZero() || t.TradeDate.Before(first) {
			first = t.TradeDate
		}
	}
	return first
}

// earliestHoldingCreated returns the earliest holding.CreatedAt across the
// tenant (account-scoped when accountID != nil). Zero time when no holdings
// exist or the repo errors (caller degrades — portfolioCAGR full → nil). Used
// by portfolioCAGR as a portfolio-inception proxy for full-period day count.
// Pages through FindAll (mirrors currentCostBasisInBase's pagination shape).
func (s *Service) earliestHoldingCreated(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) time.Time {
	var earliest time.Time
	page := domain.PageRequest{PageSize: 100}
	for {
		res, err := s.holdingRepo.FindAll(ctx, tenantID, accountID, page)
		if err != nil {
			break
		}
		for _, h := range res.Items {
			if earliest.IsZero() || h.CreatedAt.Before(earliest) {
				earliest = h.CreatedAt
			}
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return earliest
}

// filterTradesBySecurity narrows trades to one security (QtyAtDate rebuild).
func filterTradesBySecurity(trades []domain.HoldingTransaction, securityID uuid.UUID) []domain.HoldingTransaction {
	out := make([]domain.HoldingTransaction, 0, len(trades))
	for _, t := range trades {
		if t.SecurityID == securityID {
			out = append(out, t)
		}
	}
	return out
}

// --- D-goal Task 2 / Task 6: GetAccountsMarketValue (port exposed to goal) ---

// accountMarketValue returns the total market value (original currency, NOT
// CNY-converted — investment goal tracks raw mv) of all holdings under an
// account: Σ holding.MarketValue(security.CurrentPriceCents). Tenant-scoped
// (a specific tenantID is required — passing uuid.Nil returns empty against
// ent's WHERE clause, see SnapshotAllHoldings note). Paginates through all of
// the account's holdings. Best-effort: a holding whose security is missing is
// skipped + logged, not fatal.
func (s *Service) accountMarketValue(ctx context.Context, tenantID, accountID uuid.UUID) (int64, error) {
	var total int64
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.holdingRepo.FindAll(ctx, tenantID, &accountID, page)
		if err != nil {
			return 0, fmt.Errorf("account market value: list holdings: %w", err)
		}
		for _, h := range result.Items {
			if err := ctx.Err(); err != nil {
				return total, err
			}
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				slog.Warn("account market value: security missing, skip",
					slog.String("security_id", h.SecurityID.String()),
					slog.String("operation", "accountMarketValue"))
				continue
			}
			total += h.MarketValue(sec.CurrentPriceCents)
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return total, nil
}

// GetAccountsMarketValue returns Σ market value across multiple accounts
// (multi-account port for goal SyncAllGoals). Implements
// goal/domain.AccountMarketValueSource.GetAccountsMarketValue (structural).
//
// Thin delegation to accountMarketValue per account. Best-effort: an account
// whose market-value query fails (e.g. listing error) is skipped + logged, not
// fatal — the remaining accounts still contribute (mirrors the skip-missing
// pattern used by the account/debt goal ports and by accountMarketValue's
// per-holding security skip). Empty accountIDs returns 0.
func (s *Service) GetAccountsMarketValue(ctx context.Context, tenantID uuid.UUID, accountIDs []uuid.UUID) (int64, error) {
	var total int64
	for _, accID := range accountIDs {
		if err := ctx.Err(); err != nil {
			return total, err
		}
		mv, err := s.accountMarketValue(ctx, tenantID, accID)
		if err != nil {
			slog.Warn("goal mv: account error, skip",
				slog.String("account_id", accID.String()),
				slog.String("operation", "GetAccountsMarketValue"))
			continue
		}
		total += mv
	}
	return total, nil
}

// SumMarketValueByCurrency sums the current market value (qty × current price)
// of every holding for a tenant, grouped by the security's CurrencyCode.
// Implements networth/domain.HoldingMarketValueSource (structural — networth
// does not import holding).
//
// Best-effort: a holding whose security is missing is skipped + logged, not
// fatal (mirrors SnapshotHoldings / GetAccountMarketValue). Paginates at
// PageSize 100.
func (s *Service) SumMarketValueByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error) {
	byCur := map[string]int64{}
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.holdingRepo.FindAll(ctx, tenantID, nil, page)
		if err != nil {
			return nil, fmt.Errorf("sum market value by currency: list holdings: %w", err)
		}
		for _, h := range result.Items {
			if err := ctx.Err(); err != nil {
				return nil, err
			}
			sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
			if err != nil || sec == nil {
				slog.Warn("holding market-value sum: security missing, skip",
					slog.String("holding_id", h.ID.String()),
					slog.String("operation", "SumMarketValueByCurrency"))
				continue
			}
			byCur[sec.CurrencyCode] += h.MarketValue(sec.CurrentPriceCents)
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return byCur, nil
}
