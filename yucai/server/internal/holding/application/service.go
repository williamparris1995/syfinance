package application

import (
	"context"
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
}

// NewService creates a new holding application service.
func NewService(secRepo domain.SecurityRepository, hRepo domain.HoldingRepository, tRepo domain.TradeRepository) *Service {
	return &Service{securityRepo: secRepo, holdingRepo: hRepo, tradeRepo: tRepo}
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

// BuyHolding records a buy trade and updates the holding position.
func (s *Service) BuyHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
	h, err := s.holdingRepo.FindByAccountAndSecurity(ctx, req.TenantID, req.AccountID, req.SecurityID)
	if err != nil {
		// Create new holding
		h = &domain.Holding{
			ID: uuid.New(), TenantID: req.TenantID,
			AccountID: req.AccountID, SecurityID: req.SecurityID,
		}
	}
	h.ApplyBuy(req.Quantity, req.PriceCents)

	tradeID := uuid.New()
	newLot := domain.HoldingLot{
		ID: uuid.New(), TenantID: req.TenantID, HoldingID: h.ID, SecurityID: req.SecurityID,
		AcquiredDate: req.TradeDate, AcquiredTradeID: tradeID,
		PriceCents: req.PriceCents, Quantity: req.Quantity, RemainingQuantity: req.Quantity,
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
		PriceCents: req.PriceCents, AmountCents: int64(float64(req.PriceCents) * req.Quantity),
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

	dto := TradeToDTO(trade)
	return &dto, nil
}

// SellHolding records a sell trade and updates the holding position.
func (s *Service) SellHolding(ctx context.Context, req HoldingTradeRequest) (*HoldingTransactionDTO, error) {
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
		realized = consumedRealized
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
		PriceCents: req.PriceCents, AmountCents: int64(float64(req.PriceCents) * req.Quantity),
		FeeCents: req.FeeCents, TradeDate: req.TradeDate, Notes: req.Notes,
		RealizedPnLCents: realized, CreatedAt: h.UpdatedAt,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save trade: %w", err)
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
		date := time.Now().AddDate(0, 0, -i*5)
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
			price, _, err := s.priceRouter.FetchPrice(ctx, view)
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
					SecurityID: sec.ID, PriceDate: truncateToDate(time.Now()),
					PriceCents: price, CurrencyCode: sec.CurrencyCode, Source: "sina",
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
func curveWindow(rangeName string) (from, to time.Time, granularity string) {
	to = truncateToDate(time.Now())
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
	today := truncateToDate(time.Now())
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
				TenantID:          h.TenantID,
				HoldingID:         h.ID,
				SecurityID:        h.SecurityID,
				AccountID:         h.AccountID,
				SnapshotDate:      today,
				MarketValueCents:  h.MarketValue(sec.CurrentPriceCents),
				UnrealizedPnlCents: h.UnrealizedPnL(sec.CurrentPriceCents),
				CurrencyCode:      sec.CurrencyCode,
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
	from, to, granularity := curveWindow(rangeName)
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
	out := &PortfolioPerformance{
		PortfolioPoints: portPts, RealizedCents: realized, UnrealizedCents: unrealized,
		TotalCents: total, AnnualizedPct: fullXirr, RangeAnnualizedPct: rangeXirr,
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
	return s.rateForCode(ctx, base, time.Now())
}

// convertTradeToBase 折算 a single trade amount to base, looking up the
// security's currency code + the from-rate at tradeDate (照 samplePortfolioInBase
// / currentUnrealizedInBase 模式). Missing security or rate → 1.0 (graceful, no
// conversion). If the security's currency equals base, the amount is returned
// unchanged (same currency, no conversion needed).
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
			rateFrom := s.rateForCode(ctx, sec.CurrencyCode, time.Now())
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
			rateFrom := s.rateForCode(ctx, sec.CurrencyCode, time.Now())
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
	from, to, _ := curveWindow(rangeName)
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
func (s *Service) GetHoldingPerformance(ctx context.Context, holdingID uuid.UUID, rangeName string, baseCurrency string) (*HoldingPerformance, error) {
	if s.priceHistoryRepo == nil {
		return nil, fmt.Errorf("holding perf: price history repo not configured")
	}
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	from, to, _ := curveWindow(rangeName)
	h, err := s.holdingRepo.FindByID(ctx, holdingID)
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
	rateFrom := s.rateForCode(ctx, sec.CurrencyCode, time.Now())
	unrealizedRaw := h.UnrealizedPnL(sec.CurrentPriceCents)
	unrealized := currencydomain.ConvertToBase(unrealizedRaw, rateFrom, rateBase)
	// XIRR (Task 4): full-period (original currency, no conversion) + range
	// (rebuilt from price_history endpoint). Both degrade independently to nil.
	fullXirr, _ := s.holdingXIRR(ctx, holdingID, base)
	rangeStart, _, _ := curveWindow(rangeName)
	rng := s.computeHoldingRangeXIRR(ctx, *h, *sec, s.tradesForHolding(ctx, *h), rangeStart, fullXirr)
	return &HoldingPerformance{
		PricePoints: pts, RealizedCents: realized, UnrealizedCents: unrealized,
		TotalCents: realized + unrealized, AnnualizedPct: fullXirr, RangeAnnualizedPct: rng,
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
	cfs = append(cfs, domain.CashFlow{Date: time.Now(), Amount: float64(terminal)})
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
func (s *Service) marketValueAtDateAsOf(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, qtyAsOf, priceAsOf time.Time, rateBase float64, base string) (int64, bool) {
	// Trades are invariant across holding pages — hoist once.
	secTrades, _ := s.allTradesForTenant(ctx, tenantID, accountID)
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
				return 0, false
			}
			qty := domain.QtyAtDate(filterTradesBySecurity(secTrades, h.SecurityID), qtyAsOf)
			if qty == 0 {
				continue
			}
			price, ok := s.priceAtOrBefore(ctx, h.SecurityID, priceAsOf)
			if !ok {
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
		domain.CashFlow{Date: time.Now(), Amount: float64(terminal)})
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
	rangeCfs = append(rangeCfs, domain.CashFlow{Date: time.Now(), Amount: float64(terminal)})
	if r, e := domain.XIRR(rangeCfs); e == nil {
		rng = ptrFloat(r)
	}
	return full, rng, nil
}

// portfolioTWR computes portfolio-level full-period TWR (base-converted, GIPS
// sub-period chaining). Degrades to nil on insufficient data or missing prices.
// subPeriods start from i>0 (first buy's BV_after is the initial BeginValue,
// avoiding divide-by-zero on empty pre-buy position — see spec risk #4).
func (s *Service) portfolioTWR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string) (*float64, error) {
	base := baseCurrency
	if base == "" {
		base = "CNY"
	}
	rateBase := s.rateForBase(ctx, base)
	trades, _ := s.allTradesForTenant(ctx, tenantID, accountID)
	if len(trades) == 0 {
		return nil, nil
	}
	cashFlowDays := uniqueSortedTradeDates(trades)
	if len(cashFlowDays) < 2 {
		return nil, nil // 需 ≥2 现金流日才有子区间
	}
	subPeriods := make([]domain.SubPeriodReturn, 0, len(cashFlowDays)-1)
	var prevAfterCF float64
	for i, day := range cashFlowDays {
		BV_before, ok := s.marketValueAtDateAsOf(ctx, tenantID, accountID, day, day, rateBase, base)
		if !ok {
			return nil, nil // price 缺 → 降级
		}
		BV_after, ok := s.marketValueAtDateAsOf(ctx, tenantID, accountID, day.AddDate(0, 0, 1), day, rateBase, base)
		if !ok {
			return nil, nil
		}
		if i > 0 {
			subPeriods = append(subPeriods, domain.SubPeriodReturn{BeginValueAfterCF: prevAfterCF, EndValueBeforeCF: float64(BV_before)})
		}
		prevAfterCF = float64(BV_after)
	}
	if len(subPeriods) == 0 {
		return nil, nil
	}
	finalValue := s.currentMarketValueInBase(ctx, tenantID, accountID, base)
	totalDays := int(time.Since(cashFlowDays[0]).Hours() / 24)
	rate, err := domain.TWR(subPeriods, float64(finalValue), prevAfterCF, totalDays)
	if err != nil {
		return nil, nil
	}
	return ptrFloat(rate), nil
}

// uniqueSortedTradeDates extracts unique trade_date values sorted ascending.
func uniqueSortedTradeDates(trades []domain.HoldingTransaction) []time.Time {
	seen := map[time.Time]bool{}
	days := make([]time.Time, 0, len(trades))
	for _, t := range trades {
		d := t.TradeDate.Truncate(24 * time.Hour)
		if !seen[d] {
			seen[d] = true
			days = append(days, d)
		}
	}
	sort.Slice(days, func(i, j int) bool { return days[i].Before(days[j]) })
	return days
}

// holdingXIRR computes single-holding full-period XIRR (original currency, no
// conversion). Degrades to nil. Range XIRR is computed separately by Task 4's
// computeHoldingRangeXIRR (needs price_history endpoint rebuild).
func (s *Service) holdingXIRR(ctx context.Context, holdingID uuid.UUID, baseCurrency string) (full *float64, err error) {
	_ = baseCurrency // holding XIRR is original-currency; retained for Task 4 wiring symmetry
	h, err := s.holdingRepo.FindByID(ctx, holdingID)
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
	cfs = append(cfs, domain.CashFlow{Date: time.Now(), Amount: float64(terminal)})
	if r, e := domain.XIRR(cfs); e == nil {
		full = ptrFloat(r)
	}
	return full, nil
}

// holdingTWR computes single-holding full-period TWR (original currency, no
// conversion). Degrades to nil.
func (s *Service) holdingTWR(ctx context.Context, holdingID uuid.UUID) (*float64, error) {
	h, err := s.holdingRepo.FindByID(ctx, holdingID)
	if err != nil {
		return nil, fmt.Errorf("holding twr: find holding: %w", err)
	}
	sec, err := s.securityRepo.FindByID(ctx, h.SecurityID)
	if err != nil || sec == nil {
		return nil, nil
	}
	trades := s.tradesForHolding(ctx, *h)
	if len(trades) < 2 {
		return nil, nil
	}
	cashFlowDays := uniqueSortedTradeDates(trades)
	if len(cashFlowDays) < 2 {
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
	if len(subPeriods) == 0 {
		return nil, nil
	}
	finalValue := float64(h.MarketValue(sec.CurrentPriceCents)) // 原币
	totalDays := int(time.Since(cashFlowDays[0]).Hours() / 24)
	rate, err := domain.TWR(subPeriods, finalValue, prevAfterCF, totalDays)
	if err != nil {
		return nil, nil
	}
	return ptrFloat(rate), nil
}

// priceAtOrBefore returns the security's nearest price_history entry on or
// before [date] (forward-fill). Returns ok=false when priceHistoryRepo is nil
// or no entry covers the date.
func (s *Service) priceAtOrBefore(ctx context.Context, securityID uuid.UUID, date time.Time) (int64, bool) {
	if s.priceHistoryRepo == nil {
		return 0, false
	}
	ph, err := s.priceHistoryRepo.FindBySecurity(ctx, securityID, time.Unix(0, 0), date)
	if err != nil || len(ph) == 0 {
		return 0, false
	}
	// Pick the latest entry ≤ date (FindBySecurity may not be sorted by date).
	latest := ph[0]
	for _, p := range ph {
		if !p.PriceDate.After(date) && p.PriceDate.After(latest.PriceDate) {
			latest = p
		}
	}
	return latest.PriceCents, true
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
