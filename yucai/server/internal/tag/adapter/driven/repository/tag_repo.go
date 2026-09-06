package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/sqltx"
	"github.com/yucai/server/internal/tag/domain"
	tagent "github.com/yucai/server/internal/tag/ent"
	"github.com/yucai/server/internal/tag/ent/tag"
	"github.com/yucai/server/internal/tag/ent/transactiontag"
)

// TagRepository implements domain.TagRepository using entGo.
type TagRepository struct {
	client *tagent.Client
}

// NewTagRepository creates a new TagRepository.
func NewTagRepository(client *tagent.Client) *TagRepository {
	return &TagRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx) it returns a tx-bound client whose reads
// join the outer transaction (so backup reads share the REPEATABLE READ
// snapshot tx instead of a fresh connection that could tear the backup);
// otherwise it returns the default r.client.
func (r *TagRepository) clientFor(ctx context.Context) *tagent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return tagent.NewClient(tagent.Driver(d))
	}
	return r.client
}

// Save persists a new tag.
func (r *TagRepository) Save(ctx context.Context, t *domain.Tag) error {
	_, err := r.clientFor(ctx).Tag.Create().
		SetID(t.ID).
		SetTenantID(t.TenantID).
		SetName(t.Name).
		SetColor(t.Color).
		SetVersion(t.Version).
		SetCreatedAt(t.CreatedAt).
		SetUpdatedAt(t.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save tag: %w", err)
	}
	return nil
}

// FindByID retrieves a tag by ID (excluding soft-deleted).
func (r *TagRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Tag, error) {
	t, err := r.client.Tag.Query().
		Where(
			tag.ID(id),
			tag.TenantID(tenantID),
			tag.DeletedAtIsNil(),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find tag: %w", err)
	}
	return toDomainTag(t), nil
}

// FindAll returns paginated tags with optional name search.
func (r *TagRepository) FindAll(ctx context.Context, tenantID uuid.UUID, search string, page domain.PageRequest) (*domain.PaginatedResult[domain.Tag], error) {
	query := r.client.Tag.Query().
		Where(
			tag.TenantID(tenantID),
			tag.DeletedAtIsNil(),
		)

	if search != "" {
		query.Where(tag.NameContains(search))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count tags: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(tag.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query tags: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	tags := make([]domain.Tag, len(results))
	for i, t := range results {
		tags[i] = *toDomainTag(t)
	}

	return &domain.PaginatedResult[domain.Tag]{
		Items:         tags,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update persists changes to a tag.
func (r *TagRepository) Update(ctx context.Context, t *domain.Tag) error {
	_, err := r.client.Tag.UpdateOneID(t.ID).
		Where(tag.Version(t.Version - 1)).
		SetName(t.Name).
		SetColor(t.Color).
		SetVersion(t.Version).
		SetUpdatedAt(t.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update tag: %w", err)
	}
	return nil
}

// SoftDelete soft-deletes a tag.
func (r *TagRepository) SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error {
	now := time.Now()
	_, err := r.client.Tag.UpdateOneID(id).
		Where(tag.TenantID(tenantID)).
		SetDeletedAt(now).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("soft delete tag: %w", err)
	}
	return nil
}

// AddTagToTransaction creates a tag-transaction association.
func (r *TagRepository) AddTagToTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error {
	_, err := r.client.TransactionTag.Create().
		SetTagID(tagID).
		SetTransactionID(transactionID).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("add tag to transaction: %w", err)
	}
	return nil
}

// RemoveTagFromTransaction removes a tag-transaction association.
func (r *TagRepository) RemoveTagFromTransaction(ctx context.Context, tagID, transactionID uuid.UUID) error {
	_, err := r.client.TransactionTag.Delete().
		Where(
			transactiontag.TagID(tagID),
			transactiontag.TransactionID(transactionID),
		).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("remove tag from transaction: %w", err)
	}
	return nil
}

// FindByTransaction returns all tags for a transaction.
func (r *TagRepository) FindByTransaction(ctx context.Context, tenantID, transactionID uuid.UUID) ([]domain.Tag, error) {
	// Find junction entries
	junctions, err := r.client.TransactionTag.Query().
		Where(
			transactiontag.TransactionID(transactionID),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find transaction tags: %w", err)
	}

	tags := make([]domain.Tag, 0, len(junctions))
	for _, j := range junctions {
		t, err := r.client.Tag.Query().
			Where(
				tag.ID(j.TagID),
				tag.TenantID(tenantID),
				tag.DeletedAtIsNil(),
			).
			Only(ctx)
		if err != nil {
			continue // skip deleted or not found tags
		}
		tags = append(tags, *toDomainTag(t))
	}
	return tags, nil
}

func toDomainTag(t *tagent.Tag) *domain.Tag {
	return &domain.Tag{
		ID:        t.ID,
		TenantID:  t.TenantID,
		Name:      t.Name,
		Color:     t.Color,
		Version:   t.Version,
		DeletedAt: t.DeletedAt,
		CreatedAt: t.CreatedAt,
		UpdatedAt: t.UpdatedAt,
	}
}

// FindAllForBackup returns every non-soft-deleted tag for a tenant (no
// pagination). Soft-deleted tags are excluded, mirroring account/transaction
// backup semantics — only live business data is backed up.
func (r *TagRepository) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.Tag, error) {
	results, err := r.clientFor(ctx).Tag.Query().
		Where(
			tag.TenantID(tenantID),
			tag.DeletedAtIsNil(),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("backup query tags: %w", err)
	}
	tags := make([]domain.Tag, len(results))
	for i, t := range results {
		tags[i] = *toDomainTag(t)
	}
	return tags, nil
}

// DeleteByTenant hard-deletes every tag for a tenant (including soft-deleted
// rows) and the transaction_tag junction rows referencing those tags. The
// junction table has no tenant_id column (only tag_id + transaction_id), so the
// tenant's tag IDs are collected first and used to scope the junction cleanup.
// Ordering: junction rows first (logically child of tags), then tags.
func (r *TagRepository) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	tagIDs, err := r.clientFor(ctx).Tag.Query().
		Where(tag.TenantID(tenantID)).
		IDs(ctx)
	if err != nil {
		return fmt.Errorf("collect tag IDs for delete: %w", err)
	}
	if len(tagIDs) > 0 {
		if _, err := r.clientFor(ctx).TransactionTag.Delete().
			Where(transactiontag.TagIDIn(tagIDs...)).
			Exec(ctx); err != nil {
			return fmt.Errorf("delete transaction_tag junction: %w", err)
		}
	}
	if _, err := r.clientFor(ctx).Tag.Delete().
		Where(tag.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("delete tags: %w", err)
	}
	return nil
}

// UpsertForSync applies one offline-sync push for a single tag: find by
// id+tenant (soft-deleted rows included — an upsert from the client, the
// single-device source of truth, resurrects them), then a full-field update
// trusting the client version per F11 v1 — no optimistic lock on this path —
// or a create via Save with the client-supplied id. Tx-aware via clientFor.
// Tag-transaction junction rows are NOT synced (same scope decision as the
// backup exporter: they are derivative of transaction existence).
func (r *TagRepository) UpsertForSync(ctx context.Context, tg *domain.Tag) error {
	c := r.clientFor(ctx)
	_, err := c.Tag.Query().
		Where(tag.ID(tg.ID), tag.TenantID(tg.TenantID)).
		First(ctx)
	switch {
	case err == nil:
		if _, err := c.Tag.UpdateOneID(tg.ID).
			SetName(tg.Name).
			SetColor(tg.Color).
			SetVersion(tg.Version).
			SetUpdatedAt(tg.UpdatedAt).
			ClearDeletedAt(). // client truth says the row is alive
			Save(ctx); err != nil {
			return fmt.Errorf("sync upsert tag %s: %w", tg.ID, err)
		}
		return nil
	case tagent.IsNotFound(err):
		return r.Save(ctx, tg) // create with the client-supplied id
	default:
		return fmt.Errorf("sync find tag %s: %w", tg.ID, err)
	}
}

// HardDeleteForSync physically removes one tag on the offline-sync DELETE path
// (single-device hard-delete semantics; the soft-delete used by SoftDelete is
// a server-only concept, never used here). Junction rows first so no dangling
// transaction_tag reference survives — mirroring DeleteByTenant's cleanup.
// Idempotent by design: a tombstone for an already-absent tag is a no-op so
// re-delivery never fails the batch (FR-3).
func (r *TagRepository) HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error {
	c := r.clientFor(ctx)
	if _, err := c.TransactionTag.Delete().
		Where(transactiontag.TagIDEQ(id)).
		Exec(ctx); err != nil {
		return fmt.Errorf("sync delete transaction_tag junction for tag %s: %w", id, err)
	}
	if _, err := c.Tag.Delete().
		Where(tag.ID(id), tag.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("sync hard delete tag %s: %w", id, err)
	}
	return nil
}

// FindForSync returns the tenant's current tag row for the offline-sync
// conflict check (F16 ADR-4) — the read dual of UpsertForSync: soft-deleted
// rows are INCLUDED (they own their version until a push resurrects or
// hard-deletes them). found=false means the tenant holds no row for the id.
// Tx-aware via clientFor so the check reads inside the push batch transaction.
func (r *TagRepository) FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*domain.Tag, bool, error) {
	t, err := r.clientFor(ctx).Tag.Query().
		Where(tag.ID(id), tag.TenantID(tenantID)).
		First(ctx)
	if err != nil {
		if tagent.IsNotFound(err) {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("sync find tag %s: %w", id, err)
	}
	return toDomainTag(t), true, nil
}

// Compile-time check.
var _ domain.TagRepository = (*TagRepository)(nil)

var _ = time.Time{}
