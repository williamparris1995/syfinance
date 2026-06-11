package domain

import (
	"context"

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
	FindAll(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, page PageRequest) (*PaginatedResult[Holding], error)
}

// TradeRepository defines persistence for holding transactions.
type TradeRepository interface {
	Save(ctx context.Context, trade *HoldingTransaction) error
	FindAll(ctx context.Context, tenantID uuid.UUID, accountID, securityID *uuid.UUID, page PageRequest) (*PaginatedResult[HoldingTransaction], error)
}
