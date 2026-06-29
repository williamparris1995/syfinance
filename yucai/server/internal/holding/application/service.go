package application

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

// Service orchestrates holding operations.
type Service struct {
	securityRepo domain.SecurityRepository
	holdingRepo  domain.HoldingRepository
	tradeRepo    domain.TradeRepository
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

	if err := s.holdingRepo.SaveOrUpdate(ctx, h); err != nil {
		return nil, fmt.Errorf("save holding: %w", err)
	}

	trade := &domain.HoldingTransaction{
		ID: uuid.New(), TenantID: req.TenantID,
		AccountID: req.AccountID, SecurityID: req.SecurityID,
		TradeType: domain.TradeTypeBuy, Quantity: req.Quantity,
		PriceCents: req.PriceCents, AmountCents: int64(float64(req.PriceCents) * req.Quantity),
		FeeCents: req.FeeCents, TradeDate: req.TradeDate, Notes: req.Notes,
		CreatedAt: h.UpdatedAt,
	}
	if err := s.tradeRepo.Save(ctx, trade); err != nil {
		return nil, fmt.Errorf("save trade: %w", err)
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

	_, err = h.ApplySell(req.Quantity, req.PriceCents)
	if err != nil {
		return nil, err
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
		CreatedAt: h.UpdatedAt,
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
