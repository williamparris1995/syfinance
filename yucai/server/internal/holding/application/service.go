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

// BackfillPriceHistory fetches historical daily K-line for every Sina-covered
// security + CSI300, writing price_history. Best-effort: per-security fetch
// failure logged, not fatal. Backfills every Sina-covered security on each
// startup (no per-security Exists gate) so history is refreshed even when the
// B SyncPrices scheduler already wrote the current-day point — SaveAll
// upserts on UNIQUE(security_id, price_date), so pre-existing points are
// updated rather than skipped. ErrNoSource (non A-share: US/OTC/SGE) is
// still skipped silently.
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

// GetPortfolioPerformance builds the portfolio CNY curve + realized/unrealized
// + annualized + optional CSI300 benchmark.
func (s *Service) GetPortfolioPerformance(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, rangeName string, withBenchmark bool) (*PortfolioPerformance, error) {
	if s.snapshotRepo == nil {
		return nil, fmt.Errorf("portfolio perf: snapshot repo not configured")
	}
	from, to, granularity := curveWindow(rangeName)
	snaps, err := s.snapshotRepo.FindSnapshots(ctx, tenantID, from, to, accountID, nil)
	if err != nil {
		return nil, fmt.Errorf("portfolio perf: find snapshots: %w", err)
	}
	// Sample by granularity: group snapshots by day/month/year bucket, take last per bucket.
	portPts := s.samplePortfolioCNY(snaps, granularity)
	// Realized: Σ sell realized + Σ dividend (from trades).
	realized := s.aggregateRealized(ctx, tenantID, accountID)
	// Unrealized (current): Σ current holding unrealized (CNY折算).
	unrealized := s.currentUnrealizedCNY(ctx, tenantID, accountID)
	total := realized + unrealized
	// Cost basis (current): Σ qty×avgCost (CNY) — for total %.
	costBasis := s.currentCostBasisCNY(ctx, tenantID, accountID)
	totalPct := 0.0
	if costBasis != 0 {
		totalPct = float64(total) / float64(costBasis) * 100
	}
	annualized := s.annualizedPct(ctx, total, costBasis, tenantID)
	out := &PortfolioPerformance{
		PortfolioPoints: portPts, RealizedCents: realized, UnrealizedCents: unrealized,
		TotalCents: total, AnnualizedPct: annualized, TotalPct: totalPct, Currency: "CNY",
	}
	if withBenchmark {
		out.BenchmarkName = "沪深300"
		out.BenchmarkPoints = s.benchmarkCurve(ctx, rangeName)
	}
	return out, nil
}

// samplePortfolioCNY groups snapshots by granularity bucket (day/month/year),
// takes the last snapshot per holding per bucket, sums to portfolio market
// value per bucket date,折算 each holding's original currency to CNY via rate
// history. CNY holdings assume rate=1.0.
func (s *Service) samplePortfolioCNY(snaps []domain.HoldingSnapshot, granularity string) []CurvePointDTO {
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
	// sum market value per bucket date,折算 each holding's currency to CNY.
	byDate := map[time.Time]int64{}
	for _, sn := range last {
		rate := 1.0
		if s.rateRepo != nil && sn.CurrencyCode != "CNY" {
			rate, _ = s.rateRepo.FindRate(context.Background(), sn.CurrencyCode, sn.SnapshotDate)
		}
		byDate[bucketOf(sn.SnapshotDate, granularity)] += int64(float64(sn.MarketValueCents) * rate)
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
// portfolio's trades. Multi-currency折算 deferred (first batch: realized landed
// in trade's original currency; for CNY-only portfolios this is exact; mixed
// portfolios will be折算 in a follow-up).
func (s *Service) aggregateRealized(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) int64 {
	var sum int64
	page := domain.PageRequest{PageSize: 200}
	for {
		res, err := s.tradeRepo.FindAll(ctx, tenantID, accountID, nil, page)
		if err != nil {
			return sum
		}
		for _, tr := range res.Items {
			sum += tr.RealizedPnLCents // sell realized
			if tr.TradeType == domain.TradeTypeDividend {
				sum += tr.AmountCents // dividend as realized income
			}
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}

// aggregateRealizedForSecurity narrows aggregateRealized to one security
// (GetHoldingPerformance — this holding's realized only). First batch: no折算
// (original currency).
func (s *Service) aggregateRealizedForSecurity(ctx context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID) int64 {
	var sum int64
	page := domain.PageRequest{PageSize: 200}
	for {
		res, err := s.tradeRepo.FindAll(ctx, tenantID, accountID, securityID, page)
		if err != nil {
			return sum
		}
		for _, tr := range res.Items {
			sum += tr.RealizedPnLCents
			if tr.TradeType == domain.TradeTypeDividend {
				sum += tr.AmountCents
			}
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}

// currentUnrealizedCNY sums the current unrealized P&L across all holdings,
// 折算 each holding's currency to CNY via rate history (CNY=1.0).
func (s *Service) currentUnrealizedCNY(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) int64 {
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
			rate := 1.0
			if s.rateRepo != nil && sec.CurrencyCode != "CNY" {
				rate, _ = s.rateRepo.FindRate(ctx, sec.CurrencyCode, time.Now())
			}
			sum += int64(float64(pnl) * rate)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}

// currentCostBasisCNY sums the current cost basis (qty × avgCost) across all
// holdings,折算 each holding's currency to CNY via rate history (CNY=1.0).
func (s *Service) currentCostBasisCNY(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID) int64 {
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
			rate := 1.0
			if s.rateRepo != nil && sec.CurrencyCode != "CNY" {
				rate, _ = s.rateRepo.FindRate(ctx, sec.CurrencyCode, time.Now())
			}
			sum += int64(float64(basis) * rate)
		}
		if res.NextPageToken == "" || len(res.Items) == 0 {
			break
		}
		page.PageToken = res.NextPageToken
	}
	return sum
}

// annualizedPct annualizes total return over the holding period (earliest
// holding created_at → now). Returns 0 if period < 1 day or costBasis 0.
// Simple annualization (totalReturn / years × 100) — not CAGR (first batch).
func (s *Service) annualizedPct(ctx context.Context, total, costBasis int64, tenantID uuid.UUID) float64 {
	if costBasis == 0 {
		return 0
	}
	page := domain.PageRequest{PageSize: 200}
	earliest := time.Now()
	res, err := s.holdingRepo.FindAll(ctx, tenantID, nil, page)
	if err != nil || len(res.Items) == 0 {
		return 0
	}
	for _, h := range res.Items {
		if h.CreatedAt.Before(earliest) {
			earliest = h.CreatedAt
		}
	}
	years := time.Since(earliest).Hours() / 24 / 365.25
	if years < 1.0/365.25 {
		return 0
	}
	totalReturn := float64(total) / float64(costBasis) // fraction
	return totalReturn / years * 100
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
func (s *Service) GetHoldingPerformance(ctx context.Context, holdingID uuid.UUID, rangeName string) (*HoldingPerformance, error) {
	if s.priceHistoryRepo == nil {
		return nil, fmt.Errorf("holding perf: price history repo not configured")
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
	// within the same (tenant, account). First batch: no折算 (original currency).
	realized := s.aggregateRealizedForSecurity(ctx, h.TenantID, &h.AccountID, &h.SecurityID)
	// Unrealized (current).
	unrealized := h.UnrealizedPnL(sec.CurrentPriceCents)
	return &HoldingPerformance{
		PricePoints: pts, RealizedCents: realized, UnrealizedCents: unrealized,
		TotalCents: realized + unrealized, Currency: sec.CurrencyCode,
	}, nil
}
