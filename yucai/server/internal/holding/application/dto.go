package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
)

type CreateSecurityRequest struct {
	Symbol       string
	Name         string
	SecurityType domain.SecurityType
	Exchange     string
	CurrencyCode string
}

type SecurityDTO struct {
	ID                uuid.UUID
	Symbol            string
	Name              string
	SecurityType      domain.SecurityType
	Exchange          string
	CurrencyCode      string
	CurrentPriceCents int64
	CreatedAt         time.Time
}

type ListSecuritiesResult struct {
	Securities   []SecurityDTO
	NextPageToken string
	TotalCount    int32
}

type HoldingTradeRequest struct {
	TenantID     uuid.UUID
	AccountID    uuid.UUID
	SecurityID   uuid.UUID
	Quantity     float64
	PriceCents   int64
	FeeCents     int64
	TradeDate    time.Time
	Notes        string
}

type RecordDividendRequest struct {
	TenantID          uuid.UUID
	AccountID         uuid.UUID
	SecurityID        uuid.UUID
	Quantity          float64
	CashPerShareCents int64
	TotalAmountCents  int64
	TradeDate         time.Time
	Notes             string
}

type RecordSplitRequest struct {
	TenantID   uuid.UUID
	AccountID  uuid.UUID
	SecurityID uuid.UUID
	Ratio      float64
	SplitDate  time.Time
	Notes      string
}

type HoldingDTO struct {
	ID               uuid.UUID
	AccountID        uuid.UUID
	SecurityID       uuid.UUID
	SecurityName     string
	SecuritySymbol   string
	Quantity         float64
	AvgCostCents     int64
	MarketValueCents int64
	UnrealizedPnL    int64
	Version          int64
}

type HoldingTransactionDTO struct {
	ID            uuid.UUID
	AccountID     uuid.UUID
	SecurityID    uuid.UUID
	TradeType     domain.TradeType
	Quantity      float64
	PriceCents    int64
	AmountCents   int64
	FeeCents      int64
	TradeDate     time.Time
	Notes         string
	CreatedAt     time.Time
}

type ListHoldingsResult struct {
	Holdings     []HoldingDTO
	NextPageToken string
	TotalCount    int32
}

type ListTradesResult struct {
	Trades       []HoldingTransactionDTO
	NextPageToken string
	TotalCount    int32
}

func SecurityToDTO(s *domain.Security) SecurityDTO {
	return SecurityDTO{
		ID: s.ID, Symbol: s.Symbol, Name: s.Name,
		SecurityType: s.SecurityType, Exchange: s.Exchange,
		CurrencyCode: s.CurrencyCode, CurrentPriceCents: s.CurrentPriceCents,
		CreatedAt: s.CreatedAt,
	}
}

func HoldingToDTO(h *domain.Holding, s *domain.Security) HoldingDTO {
	mv := h.MarketValue(s.CurrentPriceCents)
	pnl := h.UnrealizedPnL(s.CurrentPriceCents)
	return HoldingDTO{
		ID: h.ID, AccountID: h.AccountID, SecurityID: h.SecurityID,
		SecurityName: s.Name, SecuritySymbol: s.Symbol,
		Quantity: h.Quantity, AvgCostCents: h.AvgCostCents,
		MarketValueCents: mv, UnrealizedPnL: pnl, Version: h.Version,
	}
}

func TradeToDTO(tr *domain.HoldingTransaction) HoldingTransactionDTO {
	return HoldingTransactionDTO{
		ID: tr.ID, AccountID: tr.AccountID, SecurityID: tr.SecurityID,
		TradeType: tr.TradeType, Quantity: tr.Quantity,
		PriceCents: tr.PriceCents, AmountCents: tr.AmountCents,
		FeeCents: tr.FeeCents, TradeDate: tr.TradeDate,
		Notes: tr.Notes, CreatedAt: tr.CreatedAt,
	}
}
