package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// PageRequest for cursor-based pagination.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult wraps results with pagination metadata.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

// SecurityRepository defines persistence for global securities.
type SecurityRepository interface {
	Save(ctx context.Context, security *Security) error
	FindByID(ctx context.Context, id uuid.UUID) (*Security, error)
	FindAll(ctx context.Context, securityType *SecurityType, page PageRequest) (*PaginatedResult[Security], error)
	FindBySymbol(ctx context.Context, symbol, exchange string) (*Security, error)
	Search(ctx context.Context, query string, limit int) ([]Security, error)
	UpdatePrice(ctx context.Context, id uuid.UUID, priceCents int64) error
}

// HoldingRepository defines persistence for holdings.
type HoldingRepository interface {
	SaveOrUpdate(ctx context.Context, holding *Holding) error
	FindByAccountAndSecurity(ctx context.Context, tenantID, accountID, securityID uuid.UUID) (*Holding, error)
	FindByID(ctx context.Context, holdingID uuid.UUID) (*Holding, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, page PageRequest) (*PaginatedResult[Holding], error)
}

// TradeRepository defines persistence for holding transactions.
type TradeRepository interface {
	Save(ctx context.Context, trade *HoldingTransaction) error
	FindAll(ctx context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID, page PageRequest) (*PaginatedResult[HoldingTransaction], error)
}

// SnapshotRepository persists daily holding market-value snapshots.
type SnapshotRepository interface {
	FindSnapshots(ctx context.Context, tenantID uuid.UUID, from, to time.Time, accountID, securityID *uuid.UUID) ([]HoldingSnapshot, error)
	Save(ctx context.Context, s HoldingSnapshot) error
}

// LotRepository persists FIFO cost lots. FindByHolding returns lots ordered
// by AcquiredDate ascending (FIFO consume order).
type LotRepository interface {
	FindByHolding(ctx context.Context, holdingID uuid.UUID) ([]HoldingLot, error)
	SaveAll(ctx context.Context, lots []HoldingLot) error
}

// PriceHistoryRepository persists daily security price history.
type PriceHistoryRepository interface {
	FindBySecurity(ctx context.Context, securityID uuid.UUID, from, to time.Time) ([]SecurityPriceHistory, error)
	SaveAll(ctx context.Context, ph []SecurityPriceHistory) error
	Save(ctx context.Context, p SecurityPriceHistory) error
	Exists(ctx context.Context, securityID uuid.UUID) (bool, error)
}

// RateHistoryRepository reads exchange-rate history for CNY折算 of portfolio
// curves. Implemented by currency's RateHistoryRepo (structural type — holding
// does not import currency). FindRange returns a date→rate map for O(1) lookup
// when assembling a curve; the wire layer adapts currency's slice form to map.
type RateHistoryRepository interface {
	FindRate(ctx context.Context, code string, date time.Time) (float64, error)
	FindRange(ctx context.Context, code string, from, to time.Time) (map[time.Time]float64, error)
}

// TenantLister enumerates every tenant ID in the system. Used by cross-tenant
// batch jobs (SnapshotAllHoldings) that must fan out per-tenant because
// HoldingRepository.FindAll is tenant-scoped (TenantID=uuid.Nil returns empty,
// not all rows). Structural type — auth's TenantRepository satisfies it via
// its FindAllIDs method (wire injects the concrete adapter).
type TenantLister interface {
	FindAllIDs(ctx context.Context) ([]uuid.UUID, error)
}
