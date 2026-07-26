package domain

import (
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
)

// Security is a global reference to a tradable security (no tenant).
type Security struct {
	ID                uuid.UUID
	Symbol            string
	Name              string
	SecurityType      SecurityType
	Exchange          string
	CurrencyCode      string
	CurrentPriceCents int64
	CreatedAt         time.Time
}

// NewSecurity creates a validated Security.
func NewSecurity(symbol, name string, securityType SecurityType, exchange, currencyCode string) (*Security, error) {
	symbol = trimSpace(symbol)
	if symbol == "" {
		return nil, fmt.Errorf("symbol must not be empty")
	}
	name = trimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("name must not be empty")
	}
	if securityType == 0 {
		return nil, fmt.Errorf("security type must be specified")
	}
	if currencyCode == "" {
		currencyCode = "CNY"
	}
	return &Security{
		ID:           uuid.New(),
		Symbol:       symbol,
		Name:         name,
		SecurityType: securityType,
		Exchange:     exchange,
		CurrencyCode: currencyCode,
		CreatedAt:    time.Now(),
	}, nil
}

// Holding tracks a position in a security.
type Holding struct {
	ID           uuid.UUID
	TenantID     uuid.UUID
	AccountID    uuid.UUID
	SecurityID   uuid.UUID
	Quantity     float64
	AvgCostCents int64
	Version      int64
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// ApplyBuy adds shares and recalculates average cost, capitalizing the buy fee
// into the cost basis (brokerage standard): the fee is part of what the holder
// paid to acquire the position, so it is folded into per-share cost.
//
// new per-share avg = (oldAvg×oldQty + price×qty + fee) / (oldQty + qty)
//
// BACKWARD COMPATIBILITY: holdings/lots created before this fix have
// fee-EXCLUSIVE AvgCostCents (only price×qty, no fee). New buys produce
// fee-INCLUSIVE values. For the local-first dev app this is acceptable —
// re-seed holdings to get fully consistent data. No migration is written;
// mixing pre-fix and post-fix lots only slightly understates cost basis on
// legacy positions.
func (h *Holding) ApplyBuy(quantity float64, priceCents int64, feeCents int64) {
	totalCostBefore := float64(h.AvgCostCents) * h.Quantity
	costAdded := float64(priceCents)*quantity + float64(feeCents)
	h.Quantity += quantity
	if h.Quantity > 0 {
		h.AvgCostCents = int64(math.Round((totalCostBefore + costAdded) / h.Quantity))
	}
	h.Version++
	h.UpdatedAt = time.Now()
}

// ApplySell removes shares. Returns realized P&L.
func (h *Holding) ApplySell(quantity float64, priceCents int64) (realizedPnL int64, err error) {
	if quantity > h.Quantity {
		return 0, fmt.Errorf("cannot sell %.4f shares, only %.4f held", quantity, h.Quantity)
	}
	realizedPnL = int64(math.Round(float64(priceCents-h.AvgCostCents) * quantity))
	h.Quantity -= quantity
	if h.Quantity == 0 {
		h.AvgCostCents = 0
	}
	h.Version++
	h.UpdatedAt = time.Now()
	return realizedPnL, nil
}

// ApplyDividend records a cash dividend.
func (h *Holding) ApplyDividend(quantity float64, cashPerShareCents int64) int64 {
	return int64(math.Round(float64(cashPerShareCents) * quantity))
}

// ApplySplit adjusts quantity and avg cost by ratio.
func (h *Holding) ApplySplit(ratio float64) {
	h.Quantity *= ratio
	if ratio > 0 {
		h.AvgCostCents = int64(math.Round(float64(h.AvgCostCents) / ratio))
	}
	h.Version++
	h.UpdatedAt = time.Now()
}

// MarketValue returns current market value.
func (h *Holding) MarketValue(currentPriceCents int64) int64 {
	return int64(math.Round(float64(currentPriceCents) * h.Quantity))
}

// UnrealizedPnL returns unrealized profit/loss.
func (h *Holding) UnrealizedPnL(currentPriceCents int64) int64 {
	return h.MarketValue(currentPriceCents) - int64(math.Round(float64(h.AvgCostCents)*h.Quantity))
}

// HoldingTransaction is an append-only trade record.
type HoldingTransaction struct {
	ID               uuid.UUID
	TenantID         uuid.UUID
	AccountID        uuid.UUID
	SecurityID       uuid.UUID
	TradeType        TradeType
	Quantity         float64
	PriceCents       int64
	AmountCents      int64
	FeeCents         int64
	RealizedPnLCents int64 // FIFO realized P&L on sell (0 for buy/dividend/split)
	TradeDate        time.Time
	TransactionID    *uuid.UUID
	Notes            string
	CreatedAt        time.Time
}

func trimSpace(s string) string {
	result := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] != ' ' && s[i] != '\t' && s[i] != '\n' && s[i] != '\r' {
			result = append(result, s[i])
		}
	}
	return string(result)
}
