package repository

import (
	"context"
	"fmt"
	"time"

	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
	"github.com/yucai/server/internal/transaction/ent/transaction"
	txnentryent "github.com/yucai/server/internal/transaction/ent/transactionentry"
)

// Shared SQLite table names. The transaction and account modules run against
// one physical database in production, so a transaction's entries can JOIN the
// accounts table to read account_type for the Type filter. The ent schemas in
// each module declare no cross-module edges (per-module ent design), so the
// JOIN is expressed as raw SQL via sql.ExprP below.
const (
	accountsTable         = "accounts"
	transactionEntryTable = "transaction_entries"
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
//
// Performance: entries are loaded in a single batched query
// (`WHERE transaction_id IN (...)`) rather than once per transaction,
// eliminating the N+1 read pattern that previously scaled with page size.
//
// Type filter: the income/expense/transfer classification is inferred from
// the account_type of each entry's account (account-as-category model). Since
// the transaction and account ent modules share one physical database but
// declare no cross-module edges, the classification is expressed as a raw
// EXISTS subquery joining transaction_entries → accounts.
func (r *TransactionRepository) FindAll(ctx context.Context, tenantID uuid.UUID, filter domain.TransactionFilter, page domain.PageRequest) (*domain.PaginatedResult[domain.Transaction], error) {
	query := r.client.Transaction.Query().
		Where(
			transaction.TenantID(tenantID),
			transaction.DeletedAtIsNil(),
		)

	if filter.AccountID != nil {
		// Restrict to transactions that have at least one entry for this account.
		// Expressed as an EXISTS subquery so the page/count stay consistent and
		// we avoid the previous two-step (fetch entry txnIDs, then filter).
		query.Where(hasEntryForAccount(*filter.AccountID))
	}
	if filter.DateFrom != nil {
		query.Where(transaction.TransactionDateGTE(*filter.DateFrom))
	}
	if filter.DateTo != nil {
		query.Where(transaction.TransactionDateLTE(*filter.DateTo))
	}
	if filter.Type != nil {
		query.Where(typePredicate(*filter.Type))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count transactions: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}

	// Deterministic ordering is required for keyset (cursor) pagination:
	// IDGT(cursor) only has stable semantics when results are ordered by id.
	query.Order(transaction.ByID(entsql.OrderAsc()))
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			// Exclusive cursor: the last item of the previous page must not
			// reappear. Use GT (not GTE) so page boundaries don't overlap.
			query.Where(transaction.IDGT(cursorID))
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

	// Eager-load entries in ONE batched query (avoids N+1).
	entriesByTxn, err := r.loadEntriesByTransaction(ctx, results)
	if err != nil {
		return nil, err
	}

	txns := make([]domain.Transaction, len(results))
	for i, t := range results {
		txns[i] = *toDomainTransaction(t, entriesByTxn[t.ID])
	}

	return &domain.PaginatedResult[domain.Transaction]{
		Items:         txns,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// loadEntriesByTransaction fetches all entries for the given transactions in a
// single query and groups them by transaction_id. Returns an empty map (not nil)
// when there are no transactions, so callers can index safely.
func (r *TransactionRepository) loadEntriesByTransaction(ctx context.Context, txns []*txnent.Transaction) (map[uuid.UUID][]*txnent.TransactionEntry, error) {
	out := make(map[uuid.UUID][]*txnent.TransactionEntry)
	if len(txns) == 0 {
		return out, nil
	}

	ids := make([]uuid.UUID, len(txns))
	for i, t := range txns {
		ids[i] = t.ID
	}

	entries, err := r.client.TransactionEntry.Query().
		Where(txnentryent.TransactionIDIn(ids...)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("batch load entries: %w", err)
	}

	for _, e := range entries {
		out[e.TransactionID] = append(out[e.TransactionID], e)
	}
	// Ensure every transaction has a non-nil slice (consistent with FindByID).
	for _, id := range ids {
		if out[id] == nil {
			out[id] = []*txnent.TransactionEntry{}
		}
	}
	return out, nil
}

// hasEntryForAccount builds a predicate restricting transactions to those that
// have at least one entry pointing at the given account. Uses a raw EXISTS
// subquery against the shared transaction_entries table.
func hasEntryForAccount(accountID uuid.UUID) func(*entsql.Selector) {
	return func(s *entsql.Selector) {
		// s.C(transaction.FieldID) yields the correlated outer column, e.g. "t0"."id".
		s.Where(entsql.ExprP(
			"EXISTS (SELECT 1 FROM "+transactionEntryTable+
				" WHERE "+transactionEntryTable+"."+transactionEntryFieldTransactionID+" = "+s.C(transaction.FieldID)+
				" AND "+transactionEntryTable+"."+transactionEntryFieldAccountID+" = ?)",
			accountID,
		))
	}
}

// typePredicate builds the income/expense/transfer classification predicate.
//
//	account-as-category + double-entry inference:
//	  income   — EXISTS an entry on an Income account credited (credit_cents > 0)
//	  expense  — EXISTS an entry on an Expense account debited (debit_cents > 0)
//	  transfer — every entry's account is an Asset account (NOT EXISTS a non-asset)
//
// Implemented as raw EXISTS subqueries joining transaction_entries → accounts.
// The transaction and account ent modules share one physical database, so the
// cross-table JOIN is valid even though no ent edge connects them.
func typePredicate(t domain.TransactionType) func(*entsql.Selector) {
	return func(s *entsql.Selector) {
		outerID := s.C(transaction.FieldID) // correlated outer column, e.g. "t0"."id"
		join := " FROM " + transactionEntryTable +
			" JOIN " + accountsTable +
			" ON " + transactionEntryTable + "." + transactionEntryFieldAccountID +
			" = " + accountsTable + "." + accountsFieldID +
			" WHERE " + transactionEntryTable + "." + transactionEntryFieldTransactionID + " = " + outerID

		switch t {
		case domain.TransactionTypeIncome:
			s.Where(entsql.ExprP(
				"EXISTS (SELECT 1"+join+
					" AND "+accountsTable+"."+accountsFieldAccountType+" = ?"+
					" AND "+transactionEntryTable+"."+transactionEntryFieldCreditCents+" > 0)",
				accountTypeIncome,
			))

		case domain.TransactionTypeExpense:
			s.Where(entsql.ExprP(
				"EXISTS (SELECT 1"+join+
					" AND "+accountsTable+"."+accountsFieldAccountType+" = ?"+
					" AND "+transactionEntryTable+"."+transactionEntryFieldDebitCents+" > 0)",
				accountTypeExpense,
			))

		case domain.TransactionTypeTransfer:
			// A transfer is a transaction whose entries only touch Asset accounts.
			// Equivalently: NOT EXISTS an entry whose account is NOT an Asset.
			s.Where(entsql.ExprP(
				"NOT EXISTS (SELECT 1"+join+
					" AND "+accountsTable+"."+accountsFieldAccountType+" != ?)",
				accountTypeAsset,
			))
		}
	}
}

// Field/column name constants for the raw JOINs. Kept here rather than imported
// from the account ent package (cross-module) or hardcoded inline.
const (
	transactionEntryFieldTransactionID = "transaction_id"
	transactionEntryFieldAccountID     = "account_id"
	transactionEntryFieldDebitCents    = "debit_cents"
	transactionEntryFieldCreditCents   = "credit_cents"

	accountsFieldID          = "id"
	accountsFieldAccountType = "account_type"

	accountTypeIncome  = "income"
	accountTypeExpense = "expense"
	accountTypeAsset   = "asset"
)

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
