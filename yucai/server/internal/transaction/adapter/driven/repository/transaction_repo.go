package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
	"github.com/yucai/server/internal/transaction/ent/transaction"
	txnentryent "github.com/yucai/server/internal/transaction/ent/transactionentry"
)

// TransactionRepository implements domain.TransactionRepository using entGo.
type TransactionRepository struct {
	client *txnent.Client
}

// NewTransactionRepository creates a new TransactionRepository.
func NewTransactionRepository(client *txnent.Client) *TransactionRepository {
	return &TransactionRepository{client: client}
}

// Save persists a transaction and its entries in a single operation.
func (r *TransactionRepository) Save(ctx context.Context, tx *domain.Transaction) error {
	_, err := r.client.Transaction.Create().
		SetID(tx.ID).
		SetTenantID(tx.TenantID).
		SetTransactionDate(tx.TransactionDate).
		SetDescription(tx.Description).
		SetVersion(tx.Version).
		SetCreatedAt(tx.CreatedAt).
		SetUpdatedAt(tx.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save transaction: %w", err)
	}

	for _, e := range tx.Entries {
		_, err := r.client.TransactionEntry.Create().
			SetID(e.ID).
			SetTransactionID(e.TransactionID).
			SetAccountID(e.AccountID).
			SetChartOfAccountCode(e.ChartOfAccountCode).
			SetDebitCents(e.DebitCents).
			SetCreditCents(e.CreditCents).
			SetNote(e.Note).
			Save(ctx)
		if err != nil {
			return fmt.Errorf("save entry: %w", err)
		}
	}
	return nil
}

// FindByID retrieves a transaction with its entries, excluding soft-deleted.
func (r *TransactionRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Transaction, error) {
	txn, err := r.client.Transaction.Query().
		Where(
			transaction.ID(id),
			transaction.TenantID(tenantID),
			transaction.DeletedAtIsNil(),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find transaction: %w", err)
	}

	entries, err := r.client.TransactionEntry.Query().
		Where(txnentryent.TransactionID(txn.ID)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find entries: %w", err)
	}

	return toDomainTransaction(txn, entries), nil
}

// FindAll returns paginated transactions with optional filters.
func (r *TransactionRepository) FindAll(ctx context.Context, tenantID uuid.UUID, filter domain.TransactionFilter, page domain.PageRequest) (*domain.PaginatedResult[domain.Transaction], error) {
	query := r.client.Transaction.Query().
		Where(
			transaction.TenantID(tenantID),
			transaction.DeletedAtIsNil(),
		)

	if filter.AccountID != nil {
		// Join through entries — get transactions that have an entry for this account
		entryResults, err := r.client.TransactionEntry.Query().
			Where(txnentryent.AccountID(*filter.AccountID)).
			All(ctx)
		if err != nil {
			return nil, fmt.Errorf("filter by account: %w", err)
		}
		txnIDs := make([]uuid.UUID, len(entryResults))
		for i, e := range entryResults {
			txnIDs[i] = e.TransactionID
		}
		if len(txnIDs) > 0 {
			query.Where(transaction.IDIn(txnIDs...))
		} else {
			return &domain.PaginatedResult[domain.Transaction]{}, nil
		}
	}
	if filter.DateFrom != nil {
		query.Where(transaction.TransactionDateGTE(*filter.DateFrom))
	}
	if filter.DateTo != nil {
		query.Where(transaction.TransactionDateLTE(*filter.DateTo))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count transactions: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(transaction.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query transactions: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	txns := make([]domain.Transaction, len(results))
	for i, t := range results {
		entries, err := r.client.TransactionEntry.Query().
			Where(txnentryent.TransactionID(t.ID)).
			All(ctx)
		if err != nil {
			return nil, fmt.Errorf("load entries for %s: %w", t.ID, err)
		}
		txns[i] = *toDomainTransaction(t, entries)
	}

	return &domain.PaginatedResult[domain.Transaction]{
		Items:         txns,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update replaces entries and updates the transaction.
func (r *TransactionRepository) Update(ctx context.Context, tx *domain.Transaction) error {
	// Delete old entries
	_, err := r.client.TransactionEntry.Delete().
		Where(txnentryent.TransactionID(tx.ID)).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("delete old entries: %w", err)
	}

	// Insert new entries
	for _, e := range tx.Entries {
		_, err := r.client.TransactionEntry.Create().
			SetID(e.ID).
			SetTransactionID(e.TransactionID).
			SetAccountID(e.AccountID).
			SetChartOfAccountCode(e.ChartOfAccountCode).
			SetDebitCents(e.DebitCents).
			SetCreditCents(e.CreditCents).
			SetNote(e.Note).
			Save(ctx)
		if err != nil {
			return fmt.Errorf("insert entry: %w", err)
		}
	}

	// Update transaction with optimistic lock
	_, err = r.client.Transaction.UpdateOneID(tx.ID).
		Where(transaction.Version(tx.Version - 1)).
		SetTransactionDate(tx.TransactionDate).
		SetDescription(tx.Description).
		SetVersion(tx.Version).
		SetUpdatedAt(tx.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update transaction: %w", err)
	}
	return nil
}

// SoftDelete marks the transaction as deleted.
func (r *TransactionRepository) SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error {
	now := time.Now()
	_, err := r.client.Transaction.UpdateOneID(id).
		Where(transaction.TenantID(tenantID)).
		SetDeletedAt(now).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("soft delete transaction: %w", err)
	}
	return nil
}

func toDomainTransaction(t *txnent.Transaction, entries []*txnent.TransactionEntry) *domain.Transaction {
	domainEntries := make([]domain.TransactionEntry, len(entries))
	for i, e := range entries {
		domainEntries[i] = domain.TransactionEntry{
			ID:                 e.ID,
			TransactionID:      e.TransactionID,
			AccountID:          e.AccountID,
			ChartOfAccountCode: e.ChartOfAccountCode,
			DebitCents:         e.DebitCents,
			CreditCents:        e.CreditCents,
			Note:               e.Note,
		}
	}
	return &domain.Transaction{
		ID:              t.ID,
		TenantID:        t.TenantID,
		TransactionDate: t.TransactionDate,
		Description:     t.Description,
		Entries:         domainEntries,
		Version:         t.Version,
		DeletedAt:       t.DeletedAt,
		CreatedAt:       t.CreatedAt,
		UpdatedAt:       t.UpdatedAt,
	}
}

// Compile-time check.
var _ domain.TransactionRepository = (*TransactionRepository)(nil)
