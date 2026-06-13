package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/domain"
	currencyent "github.com/yucai/server/internal/currency/ent"
	"github.com/yucai/server/internal/currency/ent/currency"
)

// CurrencyRepository implements domain.CurrencyRepository.
type CurrencyRepository struct {
	client *currencyent.Client
}

// NewCurrencyRepository creates a new CurrencyRepository.
func NewCurrencyRepository(client *currencyent.Client) *CurrencyRepository {
	return &CurrencyRepository{client: client}
}

// Save creates a new currency record.
func (r *CurrencyRepository) Save(ctx context.Context, c *domain.Currency) error {
	_, err := r.client.Currency.Create().
		SetID(c.ID).SetCode(c.Code).SetName(c.Name).
		SetSymbol(c.Symbol).SetExchangeRate(c.ExchangeRate).
		SetIsActive(c.IsActive).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("create currency: %w", err)
	}
	return nil
}

// FindByID retrieves a currency by ID.
func (r *CurrencyRepository) FindByID(ctx context.Context, id uuid.UUID) (*domain.Currency, error) {
	c, err := r.client.Currency.Query().
		Where(currency.ID(id)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find currency by id: %w", err)
	}
	return toDomain(c), nil
}

// FindByCode retrieves a currency by ISO code.
func (r *CurrencyRepository) FindByCode(ctx context.Context, code string) (*domain.Currency, error) {
	c, err := r.client.Currency.Query().
		Where(currency.Code(code)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find currency by code: %w", err)
	}
	return toDomain(c), nil
}

// FindAll returns paginated currencies.
func (r *CurrencyRepository) FindAll(ctx context.Context, activeOnly bool, page domain.PageRequest) (*domain.PaginatedResult[domain.Currency], error) {
	query := r.client.Currency.Query()

	if activeOnly {
		query.Where(currency.IsActive(true))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count currencies: %w", err)
	}

	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 50
	}
	query.Limit(ps + 1)

	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(currency.IDGTE(cursorID))
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query currencies: %w", err)
	}

	nextToken := ""
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}

	items := make([]domain.Currency, len(results))
	for i, c := range results {
		items[i] = *toDomain(c)
	}

	return &domain.PaginatedResult[domain.Currency]{
		Items:         items,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update saves changes to an existing currency.
func (r *CurrencyRepository) Update(ctx context.Context, c *domain.Currency) error {
	_, err := r.client.Currency.UpdateOneID(c.ID).
		SetExchangeRate(c.ExchangeRate).
		SetIsActive(c.IsActive).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update currency: %w", err)
	}
	return nil
}

func toDomain(c *currencyent.Currency) *domain.Currency {
	return &domain.Currency{
		ID: c.ID, Code: c.Code, Name: c.Name, Symbol: c.Symbol,
		ExchangeRate: c.ExchangeRate, IsActive: c.IsActive,
	}
}
