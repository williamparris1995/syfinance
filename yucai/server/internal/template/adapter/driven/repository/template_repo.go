package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/template/domain"
	tmplent "github.com/yucai/server/internal/template/ent"
	"github.com/yucai/server/internal/template/ent/transactiontemplate"
)

// TemplateRepository implements domain.TemplateRepository using entGo.
type TemplateRepository struct {
	client *tmplent.Client
}

// NewTemplateRepository creates a new TemplateRepository.
func NewTemplateRepository(client *tmplent.Client) *TemplateRepository {
	return &TemplateRepository{client: client}
}

// Save persists a new template.
func (r *TemplateRepository) Save(ctx context.Context, t *domain.TransactionTemplate) error {
	create := r.client.TransactionTemplate.Create().
		SetID(t.ID).
		SetTenantID(t.TenantID).
		SetName(t.Name).
		SetDescription(t.Description).
		SetAmountCents(t.AmountCents).
		SetDirection(t.Direction.String()).
		SetSourceAccountID(t.SourceAccountID).
		SetCycle(t.Cycle.String()).
		SetCycleDays(t.CycleDays).
		SetBillingDay(t.BillingDay).
		SetNextDate(t.NextDate).
		SetStartDate(t.StartDate).
		SetAutoRecord(t.AutoRecord).
		SetPaused(t.Paused).
		SetCategory(t.Category).
		SetVersion(t.Version).
		SetCreatedAt(t.CreatedAt).
		SetUpdatedAt(t.UpdatedAt)

	if t.DestinationAccountID != nil {
		create.SetDestinationAccountID(*t.DestinationAccountID)
	}
	if t.EndDate != nil {
		create.SetEndDate(*t.EndDate)
	}
	if t.LastTransactionID != nil {
		create.SetLastTransactionID(*t.LastTransactionID)
	}

	if _, err := create.Save(ctx); err != nil {
		return fmt.Errorf("save template: %w", err)
	}
	return nil
}

// FindByID retrieves a template by ID.
func (r *TemplateRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.TransactionTemplate, error) {
	t, err := r.client.TransactionTemplate.Query().
		Where(
			transactiontemplate.ID(id),
			transactiontemplate.TenantID(tenantID),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find template: %w", err)
	}
	return toDomainTemplate(t), nil
}

// FindAll returns paginated templates with optional paused filter.
func (r *TemplateRepository) FindAll(ctx context.Context, tenantID uuid.UUID, paused *bool, page domain.PageRequest) (*domain.PaginatedResult[domain.TransactionTemplate], error) {
	query := r.client.TransactionTemplate.Query().
		Where(transactiontemplate.TenantID(tenantID))

	if paused != nil {
		query.Where(transactiontemplate.PausedEQ(*paused))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count templates: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(transactiontemplate.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query templates: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	templates := make([]domain.TransactionTemplate, len(results))
	for i, t := range results {
		templates[i] = *toDomainTemplate(t)
	}

	return &domain.PaginatedResult[domain.TransactionTemplate]{
		Items:         templates,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// FindDue returns templates that are due for execution.
func (r *TemplateRepository) FindDue(ctx context.Context, today time.Time) ([]domain.TransactionTemplate, error) {
	results, err := r.client.TransactionTemplate.Query().
		Where(
			transactiontemplate.PausedEQ(false),
			transactiontemplate.NextDateLTE(today),
		).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find due templates: %w", err)
	}
	templates := make([]domain.TransactionTemplate, len(results))
	for i, t := range results {
		templates[i] = *toDomainTemplate(t)
	}
	return templates, nil
}

// Update persists changes to a template.
func (r *TemplateRepository) Update(ctx context.Context, t *domain.TransactionTemplate) error {
	update := r.client.TransactionTemplate.UpdateOneID(t.ID).
		Where(transactiontemplate.Version(t.Version - 1)).
		SetName(t.Name).
		SetDescription(t.Description).
		SetAmountCents(t.AmountCents).
		SetCycle(t.Cycle.String()).
		SetCycleDays(t.CycleDays).
		SetNextDate(t.NextDate).
		SetAutoRecord(t.AutoRecord).
		SetPaused(t.Paused).
		SetCategory(t.Category).
		SetVersion(t.Version).
		SetUpdatedAt(t.UpdatedAt)

	if t.EndDate != nil {
		update.SetEndDate(*t.EndDate)
	} else {
		update.ClearEndDate()
	}
	if t.LastTransactionID != nil {
		update.SetLastTransactionID(*t.LastTransactionID)
	} else {
		update.ClearLastTransactionID()
	}
	if t.DestinationAccountID != nil {
		update.SetDestinationAccountID(*t.DestinationAccountID)
	} else {
		update.ClearDestinationAccountID()
	}

	if _, err := update.Save(ctx); err != nil {
		return fmt.Errorf("update template: %w", err)
	}
	return nil
}

// Delete removes a template.
func (r *TemplateRepository) Delete(ctx context.Context, tenantID, id uuid.UUID) error {
	err := r.client.TransactionTemplate.DeleteOneID(id).
		Where(transactiontemplate.TenantID(tenantID)).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("delete template: %w", err)
	}
	return nil
}

func toDomainTemplate(t *tmplent.TransactionTemplate) *domain.TransactionTemplate {
	return &domain.TransactionTemplate{
		ID:                   t.ID,
		TenantID:             t.TenantID,
		Name:                 t.Name,
		Description:          t.Description,
		AmountCents:          t.AmountCents,
		Direction:            domain.ParseTemplateDirection(t.Direction),
		SourceAccountID:      t.SourceAccountID,
		DestinationAccountID: t.DestinationAccountID,
		Cycle:                domain.ParseTemplateCycle(t.Cycle),
		CycleDays:            t.CycleDays,
		BillingDay:           t.BillingDay,
		NextDate:             t.NextDate,
		StartDate:            t.StartDate,
		EndDate:              t.EndDate,
		AutoRecord:           t.AutoRecord,
		Paused:               t.Paused,
		LastTransactionID:    t.LastTransactionID,
		Category:             t.Category,
		Version:              t.Version,
		CreatedAt:            t.CreatedAt,
		UpdatedAt:            t.UpdatedAt,
	}
}

// FindAllForBackup returns every template for a tenant without pagination.
// Templates have no DeletedAt column (Delete is hard), so no soft-delete filter
// is applied — every row is returned.
func (r *TemplateRepository) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.TransactionTemplate, error) {
	results, err := r.client.TransactionTemplate.Query().
		Where(transactiontemplate.TenantID(tenantID)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("backup query templates: %w", err)
	}
	templates := make([]domain.TransactionTemplate, len(results))
	for i, t := range results {
		templates[i] = *toDomainTemplate(t)
	}
	return templates, nil
}

// DeleteByTenant hard-deletes every template for a tenant.
func (r *TemplateRepository) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	if _, err := r.client.TransactionTemplate.Delete().
		Where(transactiontemplate.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("delete templates: %w", err)
	}
	return nil
}

var _ domain.TemplateRepository = (*TemplateRepository)(nil)
var _ = time.Time{}
