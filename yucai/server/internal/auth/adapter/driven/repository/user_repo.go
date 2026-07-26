package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/ent"
	"github.com/yucai/server/internal/auth/ent/user"
	"github.com/yucai/server/internal/auth/ent/useridentity"
)

// UserRepository implements domain.UserRepository using entGo.
type UserRepository struct {
	client *ent.Client
}

// NewUserRepository creates a new UserRepository.
func NewUserRepository(client *ent.Client) *UserRepository {
	return &UserRepository{client: client}
}

// Save persists a user to the database.
func (r *UserRepository) Save(ctx context.Context, u *domain.User) error {
	_, err := r.client.User.Create().
		SetID(u.ID).
		SetTenantID(u.TenantID).
		SetEmail(u.Email).
		SetDisplayName(u.DisplayName).
		SetAvatarURL(u.AvatarURL).
		SetFamilyRole(user.FamilyRole(u.FamilyRole.String())).
		SetIsAdmin(u.IsAdmin).
		SetCreatedAt(u.CreatedAt).
		SetUpdatedAt(u.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save user: %w", err)
	}
	return nil
}

// FindByID retrieves a user by their ID.
func (r *UserRepository) FindByID(ctx context.Context, id uuid.UUID) (*domain.User, error) {
	u, err := r.client.User.Get(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find user by id: %w", err)
	}
	return toDomainUser(u), nil
}

// FindByProviderSubject looks up a user via an attached OIDC identity.
func (r *UserRepository) FindByProviderSubject(ctx context.Context, provider, subject string) (*domain.User, error) {
	u, err := r.client.User.Query().
		Where(user.HasIdentitiesWith(
			useridentity.Provider(provider),
			useridentity.Subject(subject),
		)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find user by provider subject: %w", err)
	}
	return toDomainUser(u), nil
}

// Update updates an existing user.
func (r *UserRepository) Update(ctx context.Context, u *domain.User) error {
	_, err := r.client.User.UpdateOneID(u.ID).
		SetDisplayName(u.DisplayName).
		SetAvatarURL(u.AvatarURL).
		SetIsAdmin(u.IsAdmin).
		SetUpdatedAt(u.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	return nil
}

// Count returns the total number of User rows across all tenants. Used by the
// JIT provisioning path to detect the first-ever user (promoted to admin).
func (r *UserRepository) Count(ctx context.Context) (int, error) {
	n, err := r.client.User.Query().Count(ctx)
	if err != nil {
		return 0, fmt.Errorf("count users: %w", err)
	}
	return n, nil
}

func toDomainUser(u *ent.User) *domain.User {
	return &domain.User{
		ID:          u.ID,
		TenantID:    u.TenantID,
		Email:       u.Email,
		DisplayName: u.DisplayName,
		AvatarURL:   u.AvatarURL,
		FamilyRole:  domain.ParseFamilyRole(string(u.FamilyRole)),
		IsAdmin:     u.IsAdmin,
		CreatedAt:   u.CreatedAt,
		UpdatedAt:   u.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.UserRepository = (*UserRepository)(nil)
