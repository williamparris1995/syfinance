package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// PageRequest is a shared pagination type.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult is a generic paginated response.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

// CurrencyRepository is the port interface for currency persistence.
type CurrencyRepository interface {
	Save(ctx context.Context, currency *Currency) error
	FindByID(ctx context.Context, id uuid.UUID) (*Currency, error)
	FindByCode(ctx context.Context, code string) (*Currency, error)
	FindAll(ctx context.Context, activeOnly bool, page PageRequest) (*PaginatedResult[Currency], error)
	// FindAllActive returns all active currencies (no pagination).
	FindAllActive(ctx context.Context) ([]Currency, error)
	Update(ctx context.Context, currency *Currency) error
}

// RateHistoryRepository persists daily exchange-rate history. FindRate
// forward-fills to the most recent rate at or before `date` (weekend/holiday
// gaps) and returns 1.0 when no history exists (graceful base-currency fallback).
type RateHistoryRepository interface {
	FindRate(ctx context.Context, code string, date time.Time) (float64, error)
	FindRange(ctx context.Context, code string, from, to time.Time) ([]RateHistory, error)
	Save(ctx context.Context, r RateHistory) error
}
