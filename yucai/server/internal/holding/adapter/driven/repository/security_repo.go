package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	"github.com/yucai/server/internal/holding/ent/security"
)

// SecurityRepository implements domain.SecurityRepository.
type SecurityRepository struct {
	client *holdingent.Client
}

// NewSecurityRepository creates a new SecurityRepository.
func NewSecurityRepository(client *holdingent.Client) *SecurityRepository {
	return &SecurityRepository{client: client}
}

func (r *SecurityRepository) Save(ctx context.Context, s *domain.Security) error {
	_, err := r.client.Security.Create().
		SetID(s.ID).
		SetSymbol(s.Symbol).
		SetName(s.Name).
		SetSecurityType(s.SecurityType.String()).
		SetExchange(s.Exchange).
		SetCurrencyCode(s.CurrencyCode).
		SetCurrentPriceCents(s.CurrentPriceCents).
		SetCreatedAt(s.CreatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save security: %w", err)
	}
	return nil
}

func (r *SecurityRepository) FindByID(ctx context.Context, id uuid.UUID) (*domain.Security, error) {
	s, err := r.client.Security.Query().Where(security.ID(id)).Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find security: %w", err)
	}
	return toDomainSecurity(s), nil
}

func (r *SecurityRepository) FindAll(ctx context.Context, securityType *domain.SecurityType, page domain.PageRequest) (*domain.PaginatedResult[domain.Security], error) {
	query := r.client.Security.Query()
	if securityType != nil {
		query.Where(security.SecurityTypeEQ((*securityType).String()))
	}
	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count securities: %w", err)
	}
	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 20
	}
	query.Limit(ps + 1)
	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(security.IDGTE(cursorID))
	}
	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query securities: %w", err)
	}
	var nextToken string
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}
	items := make([]domain.Security, len(results))
	for i, s := range results {
		items[i] = *toDomainSecurity(s)
	}
	return &domain.PaginatedResult[domain.Security]{Items: items, NextPageToken: nextToken, TotalCount: int32(total)}, nil
}

func (r *SecurityRepository) FindBySymbol(ctx context.Context, symbol, exchange string) (*domain.Security, error) {
	s, err := r.client.Security.Query().
		Where(security.Symbol(symbol), security.ExchangeEQ(exchange)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find security by symbol: %w", err)
	}
	return toDomainSecurity(s), nil
}

func (r *SecurityRepository) Search(ctx context.Context, query string, limit int) ([]domain.Security, error) {
	results, err := r.client.Security.Query().
		Where(security.Or(security.SymbolContains(query), security.NameContains(query))).
		Limit(limit).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("search securities: %w", err)
	}
	items := make([]domain.Security, len(results))
	for i, s := range results {
		items[i] = *toDomainSecurity(s)
	}
	return items, nil
}

func (r *SecurityRepository) UpdatePrice(ctx context.Context, id uuid.UUID, priceCents int64) error {
	_, err := r.client.Security.UpdateOneID(id).
		SetCurrentPriceCents(priceCents).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update security price: %w", err)
	}
	return nil
}

func toDomainSecurity(s *holdingent.Security) *domain.Security {
	return &domain.Security{
		ID: s.ID, Symbol: s.Symbol, Name: s.Name,
		SecurityType: domain.ParseSecurityType(s.SecurityType),
		Exchange: s.Exchange, CurrencyCode: s.CurrencyCode,
		CurrentPriceCents: s.CurrentPriceCents, CreatedAt: s.CreatedAt,
	}
}

var _ domain.SecurityRepository = (*SecurityRepository)(nil)
