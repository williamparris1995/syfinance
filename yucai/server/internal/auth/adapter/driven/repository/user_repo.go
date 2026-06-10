package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/auth/domain"
	"github.com/yucai/server/internal/auth/ent"
	"github.com/yucai/server/internal/auth/ent/user"
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
		SetPasswordHash(u.PasswordHash).
		SetDisplayName(u.DisplayName).
		SetAvatarURL(u.AvatarURL).
		SetOauthProvider(u.OAuthProvider).
		SetOauthID(u.OAuthID).
		SetFamilyRole(user.FamilyRole(u.FamilyRole.String())).
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

// FindByEmail finds a user by email within a specific tenant.
func (r *UserRepository) FindByEmail(ctx context.Context, tenantID uuid.UUID, email string) (*domain.User, error) {
	u, err := r.client.User.Query().
		Where(
			user.TenantID(tenantID),
			user.Email(email),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find user by email: %w", err)
	}
	return toDomainUser(u), nil
}

// FindByEmailGlobal finds a user by email across all tenants.
func (r *UserRepository) FindByEmailGlobal(ctx context.Context, email string) (*domain.User, error) {
	u, err := r.client.User.Query().
		Where(user.Email(email)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find user by email globally: %w", err)
	}
	return toDomainUser(u), nil
}

// Update updates an existing user.
func (r *UserRepository) Update(ctx context.Context, u *domain.User) error {
	_, err := r.client.User.UpdateOneID(u.ID).
		SetDisplayName(u.DisplayName).
		SetAvatarURL(u.AvatarURL).
		SetUpdatedAt(u.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update user: %w", err)
	}
	return nil
}

func toDomainUser(u *ent.User) *domain.User {
	return &domain.User{
		ID:            u.ID,
		TenantID:      u.TenantID,
		Email:         u.Email,
		PasswordHash:  u.PasswordHash,
		DisplayName:   u.DisplayName,
		AvatarURL:     u.AvatarURL,
		OAuthProvider: u.OauthProvider,
		OAuthID:       u.OauthID,
		FamilyRole:    domain.ParseFamilyRole(string(u.FamilyRole)),
		CreatedAt:     u.CreatedAt,
		UpdatedAt:     u.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.UserRepository = (*UserRepository)(nil)
