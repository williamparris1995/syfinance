// Package entitywriter holds the per-module SyncEntityWriter implementations
// (F11 ADR-1): each writer decodes one pushed change payload into the target
// module's domain entity and delegates the write to that module's repository.
// This mirrors the accepted backup-exporter shape — sync imports the module
// repos, never their ent codegen. The find-then-update/create upsert and the
// hard-delete cascade live in each repo (UpsertForSync / HardDeleteForSync)
// so field mapping stays inside the owning module.
package entitywriter

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	syncdomain "github.com/yucai/server/internal/sync/domain"
)

// AccountRepository is the account-repo port subset the sync writer consumes.
// Declared as a type alias so sync does not import the concrete account repo
// type (port pattern, mirrors the backup exporter aliases).
type AccountRepository = interface {
	UpsertForSync(ctx context.Context, a *accountdomain.Account) error
	HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error
}

// AccountWriter persists pushed account changes (entity_type "account").
type AccountWriter struct {
	repo AccountRepository
}

// NewAccountWriter constructs an AccountWriter.
func NewAccountWriter(repo AccountRepository) *AccountWriter {
	return &AccountWriter{repo: repo}
}

// Name returns the entity_type key (client SyncModule name).
func (w *AccountWriter) Name() string { return "account" }

// Upsert decodes one account payload and upserts it under tenantID. The
// authenticated tenant always wins over the payload's tenant_id (anti
// cross-tenant injection, same contract as backup import).
func (w *AccountWriter) Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error {
	var a accountdomain.Account
	if err := json.Unmarshal(payload, &a); err != nil {
		return fmt.Errorf("unmarshal account payload: %w", err)
	}
	a.TenantID = tenantID
	if err := w.repo.UpsertForSync(ctx, &a); err != nil {
		return fmt.Errorf("upsert account %s: %w", a.ID, err)
	}
	return nil
}

// Delete hard-deletes one account by id under tenantID.
func (w *AccountWriter) Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error {
	id, err := uuid.Parse(entityID)
	if err != nil {
		return fmt.Errorf("parse account id %q: %w", entityID, err)
	}
	if err := w.repo.HardDeleteForSync(ctx, tenantID, id); err != nil {
		return fmt.Errorf("delete account %s: %w", id, err)
	}
	return nil
}

// Compile-time assertion: AccountWriter satisfies the sync port.
var _ syncdomain.SyncEntityWriter = (*AccountWriter)(nil)
