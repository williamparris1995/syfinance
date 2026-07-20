package repository

import (
	"context"
	"fmt"

	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/ent"
	"github.com/yucai/server/internal/auth/ent/useridentity"
)

// IdentityRepository implements domain.IdentityRepository using entGo.
type IdentityRepository struct {
	client *ent.Client
}

// NewIdentityRepository creates a new IdentityRepository.
func NewIdentityRepository(client *ent.Client) *IdentityRepository {
	return &IdentityRepository{client: client}
}

// Save persists a UserIdentity to the database.
func (r *IdentityRepository) Save(ctx context.Context, id *domain.UserIdentity) error {
	_, err := r.client.UserIdentity.Create().
		SetID(id.ID).
		SetTenantID(id.TenantID).
		SetUserID(id.UserID).
		SetProvider(id.Provider).
		SetSubject(id.Subject).
		SetIssuer(id.Issuer).
		SetEmailAtProvider(id.EmailAtProvider).
		SetCreatedAt(id.CreatedAt).
		SetUpdatedAt(id.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save identity: %w", err)
	}
	return nil
}

// FindByProviderSubject returns the identity matching the (provider, subject)
// pair, or an error (wrapping ent's NotFound) when no match exists.
func (r *IdentityRepository) FindByProviderSubject(ctx context.Context, provider, subject string) (*domain.UserIdentity, error) {
	i, err := r.client.UserIdentity.Query().
		Where(
			useridentity.Provider(provider),
			useridentity.Subject(subject),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find identity: %w", err)
	}
	return toDomainIdentity(i), nil
}

func toDomainIdentity(i *ent.UserIdentity) *domain.UserIdentity {
	return &domain.UserIdentity{
		ID:              i.ID,
		TenantID:        i.TenantID,
		UserID:          i.UserID,
		Provider:        i.Provider,
		Subject:         i.Subject,
		Issuer:          i.Issuer,
		EmailAtProvider: i.EmailAtProvider,
		CreatedAt:       i.CreatedAt,
		UpdatedAt:       i.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.IdentityRepository = (*IdentityRepository)(nil)
