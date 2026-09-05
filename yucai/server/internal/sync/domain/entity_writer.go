package domain

import (
	"context"

	"github.com/google/uuid"
)

// SyncEntityWriter is the per-module write port the sync module consumes to
// persist pushed changes into business tables (consumer-side port pattern,
// mirroring backup's TenantDataPort: each module implements it in its own
// adapter, sync never imports another module's ent codegen).
//
// Semantics (single-device sync, client is source of truth):
//   - Upsert: payload is the module domain entity serialized as JSON (the
//     backup envelope per-row shape). The writer decodes it, stamps the
//     authenticated tenantID (a client-crafted tenant_id never reaches the
//     repo), then upserts by entity id: found -> full-field update trusting
//     the client version; missing -> create with the client-supplied id.
//   - Delete: HARD delete (tombstones are client-side only; server soft-delete
//     columns are a server-only concept, never used on the sync path). The
//     writer cascades in-module children (entries, schedules, links, ...).
type SyncEntityWriter interface {
	// Name returns the entity_type key (the client SyncModule name: account,
	// transaction, debt, budget, goal, holding, tag, template).
	Name() string
	// Upsert applies one CREATE/UPDATE payload under tenantID.
	Upsert(ctx context.Context, tenantID uuid.UUID, payload []byte) error
	// Delete hard-deletes one entity by id under tenantID.
	Delete(ctx context.Context, tenantID uuid.UUID, entityID string) error
}
