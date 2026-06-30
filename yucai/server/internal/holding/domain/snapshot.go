package domain

import (
	"time"

	"github.com/google/uuid"
)

// SecurityPriceHistory is one day of price history for a security (original
// currency). Supports single-security curve (holding_detail) + benchmark curve
// (CSI300). Tenant-free — price is global master data.
type SecurityPriceHistory struct {
	ID           uuid.UUID
	SecurityID   uuid.UUID
	PriceDate    time.Time
	PriceCents   int64
	CurrencyCode string
	Source       string
	CreatedAt    time.Time
}

// HoldingSnapshot is one day of market-value snapshot for a holding (original
// currency). Supports portfolio curve (Σ × rate_history → CNY). Tenant-scoped.
type HoldingSnapshot struct {
	ID                 uuid.UUID
	TenantID           uuid.UUID
	HoldingID          uuid.UUID
	SecurityID         uuid.UUID
	AccountID          uuid.UUID
	SnapshotDate       time.Time
	MarketValueCents   int64
	UnrealizedPnlCents int64
	CurrencyCode       string
	CreatedAt          time.Time
}
