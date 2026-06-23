package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strconv"
	"strings"
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
	transactionTable      = "transactions"
)

// Dialect constants for the raw TransactionSummary SQL. The raw query is built
// per-call because the two backends (SQLite tests, PostgreSQL production) need
// different date extraction and placeholder syntax.
const (
	// DialectSQLite3 matches the modernc/sqlite driver registered name and the
	// ent SQLite dialect. Tests use this.
	DialectSQLite3 = "sqlite3"
	// DialectPostgres matches the ent postgres dialect. Production (pgx) uses this.
	DialectPostgres = "postgres"
)

// TransactionRepository implements domain.TransactionRepository using entGo.
type TransactionRepository struct {
	client *txnent.Client
	// rawDB is the underlying *sql.DB shared with the ent client. It is used for
	// the TransactionSummary aggregation query, which performs a multi-table
	// JOIN + GROUP BY that ent's query builder (without cross-module edges)
	// cannot express cleanly. May be nil; TransactionSummary returns an error
	// in that case (CRUD operations are unaffected).
	rawDB *sql.DB
	// rawDialect is the SQL dialect of rawDB ("sqlite3" or "postgres"). It
	// selects the placeholder style and date extraction for TransactionSummary.
	// Defaults to DialectSQLite3 (the in-memory test backend). Production wire
	// wiring sets it to DialectPostgres via SetDialect.
	rawDialect string
}

// NewTransactionRepository creates a new TransactionRepository. db is the
// underlying *sql.DB the ent client was built on; it powers the raw
// TransactionSummary aggregation. Pass nil only in narrow test scenarios that
// do not exercise summary aggregation.
//
// The raw SQL dialect defaults to SQLite (the in-memory test backend). For
// PostgreSQL production deployments, call SetDialect(repository.DialectPostgres)
// on the returned repo before first use.
func NewTransactionRepository(client *txnent.Client, db *sql.DB) *TransactionRepository {
	return &TransactionRepository{client: client, rawDB: db, rawDialect: DialectSQLite3}
}

// SetDialect configures the SQL dialect used by the raw TransactionSummary
// query. Must be one of DialectSQLite3 or DialectPostgres. It must match the
// dialect backing rawDB; otherwise the summary query will fail at runtime.
// Returns the receiver for chaining.
func (r *TransactionRepository) SetDialect(d string) *TransactionRepository {
	r.rawDialect = d
	return r
}

// Save persists a transaction and its entries in a single operation.
func (r *TransactionRepository) Save(ctx context.Context, tx *domain.Transaction) error {
	_, err := r.client.Transaction.Create().
		SetID(tx.ID).
		SetTenantID(tx.TenantID).
		SetTransactionDate(tx.TransactionDate).
		SetNillableTransactionTime(tx.TransactionTime).
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

// FindRecentByAccount returns the most recent transactions that have at least
// one entry on the given account, ordered by transaction_date DESC (newest
// first). Under the account-as-category model this is the "same-category recent
// transactions" view (e.g. other expenses charged to the same Food account).
//
// limit is clamped: <= 0 falls back to defaultRecentLimit, and values above
// maxRecentLimit are capped. Tenant scoping and soft-delete exclusion are
// applied. Entries are eager-loaded in a single batched query (same pattern as
// FindAll) to avoid N+1.
func (r *TransactionRepository) FindRecentByAccount(ctx context.Context, tenantID, accountID uuid.UUID, limit int) ([]domain.Transaction, error) {
	if limit <= 0 {
		limit = defaultRecentLimit
	}
	if limit > maxRecentLimit {
		limit = maxRecentLimit
	}

	query := r.client.Transaction.Query().
		Where(
			transaction.TenantID(tenantID),
			transaction.DeletedAtIsNil(),
			// Restrict to transactions that have at least one entry on this
			// account. Expressed as the same EXISTS subquery FindAll uses for
			// its AccountID filter, so semantics stay consistent.
			hasEntryForAccount(accountID),
		).
		// Primary sort: date DESC (newest first). Secondary sort: id DESC so
		// transactions sharing a date have a deterministic order (avoids rows
		// shuffling between calls).
		Order(
			transaction.ByTransactionDate(entsql.OrderDesc()),
			transaction.ByID(entsql.OrderDesc()),
		).
		Limit(limit)

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query recent transactions by account %s: %w", accountID, err)
	}

	entriesByTxn, err := r.loadEntriesByTransaction(ctx, results)
	if err != nil {
		return nil, err
	}

	txns := make([]domain.Transaction, len(results))
	for i, t := range results {
		txns[i] = *toDomainTransaction(t, entriesByTxn[t.ID])
	}
	return txns, nil
}

// Limits for FindRecentByAccount. The default keeps the "recent" panel light,
// and the cap protects against unbounded result sets from a misbehaving caller.
const (
	defaultRecentLimit = 10
	maxRecentLimit     = 50
)

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
//
// The predicate is built with entsql.P + b.Arg rather than entsql.ExprP, so the
// bound parameter is rewritten to the dialect-correct placeholder: '?' on
// SQLite and '$N' on PostgreSQL. ExprP leaves literal '?' in the SQL string,
// which PostgreSQL/pqx rejects with "syntax error at or near ..." (pgx does not
// rebind '?' placeholders, unlike SQLite's native driver).
func hasEntryForAccount(accountID uuid.UUID) func(*entsql.Selector) {
	return func(s *entsql.Selector) {
		s.Where(entsql.P(func(b *entsql.Builder) {
			// s.C(transaction.FieldID) yields the correlated outer column, e.g. "transactions"."id".
			b.WriteString("EXISTS (SELECT 1 FROM " + transactionEntryTable +
				" WHERE " + transactionEntryTable + "." + transactionEntryFieldTransactionID + " = " + s.C(transaction.FieldID) +
				" AND " + transactionEntryTable + "." + transactionEntryFieldAccountID + " = ")
			b.Arg(accountID)
			b.WriteByte(')')
		}))
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
//
// Built with entsql.P + b.Arg (not entsql.ExprP) so the bound account-type
// parameter is rewritten to the dialect placeholder ('?' on SQLite, '$N' on
// PostgreSQL). ExprP leaves literal '?' in the SQL string and pgx rejects it.
func typePredicate(t domain.TransactionType) func(*entsql.Selector) {
	return func(s *entsql.Selector) {
		outerID := s.C(transaction.FieldID) // correlated outer column, e.g. "transactions"."id"
		join := " FROM " + transactionEntryTable +
			" JOIN " + accountsTable +
			" ON " + transactionEntryTable + "." + transactionEntryFieldAccountID +
			" = " + accountsTable + "." + accountsFieldID +
			" WHERE " + transactionEntryTable + "." + transactionEntryFieldTransactionID + " = " + outerID

		switch t {
		case domain.TransactionTypeIncome:
			s.Where(entsql.P(func(b *entsql.Builder) {
				b.WriteString("EXISTS (SELECT 1" + join +
					" AND " + accountsTable + "." + accountsFieldAccountType + " = ")
				b.Arg(accountTypeIncome)
				b.WriteString(" AND " + transactionEntryTable + "." + transactionEntryFieldCreditCents + " > 0)")
			}))

		case domain.TransactionTypeExpense:
			s.Where(entsql.P(func(b *entsql.Builder) {
				b.WriteString("EXISTS (SELECT 1" + join +
					" AND " + accountsTable + "." + accountsFieldAccountType + " = ")
				b.Arg(accountTypeExpense)
				b.WriteString(" AND " + transactionEntryTable + "." + transactionEntryFieldDebitCents + " > 0)")
			}))

		case domain.TransactionTypeTransfer:
			// A transfer is a transaction whose entries only touch Asset accounts.
			// Equivalently: NOT EXISTS an entry whose account is NOT an Asset.
			s.Where(entsql.P(func(b *entsql.Builder) {
				b.WriteString("NOT EXISTS (SELECT 1" + join +
					" AND " + accountsTable + "." + accountsFieldAccountType + " != ")
				b.Arg(accountTypeAsset)
				b.WriteByte(')')
			}))
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
	upd := r.client.Transaction.UpdateOneID(tx.ID).
		Where(transaction.Version(tx.Version - 1)).
		SetTransactionDate(tx.TransactionDate).
		SetDescription(tx.Description).
		SetVersion(tx.Version).
		SetUpdatedAt(tx.UpdatedAt)
	if tx.TransactionTime != nil {
		upd = upd.SetTransactionTime(*tx.TransactionTime)
	} else {
		upd = upd.ClearTransactionTime()
	}
	_, err = upd.Save(ctx)
	if err != nil {
		return fmt.Errorf("update transaction: %w", err)
	}
	return nil
}

// TransactionSummary aggregates a tenant's income/expense flows for a period
// selected by scope.Scope, broken down by bucket (day/month/single) and by
// Income/Expense account (the account-as-category breakdown). It runs a single
// raw SQL query that JOINs transactions → entries → accounts and GROUPs BY
// (bucket, account). The query returns one row per (bucket, account) pair; the
// Go layer rolls those rows up into MonthlySummary / SummaryDailyItem /
// SummaryCategoryItem.
//
// Scope granularity:
//   - ScopeDay:   one single bucket aggregating the whole day. Day must be set.
//   - ScopeMonth: per-day buckets (existing behavior, default).
//   - ScopeYear:  per-month buckets.
//
// Direction rules (account-as-category + double-entry, same as BalanceCalculator):
//   - Income account leg contributes its credit_cents to IncomeCents.
//   - Expense account leg contributes its debit_cents to ExpenseCents.
//   - Asset/Liability/Equity legs are neither income nor expense and are
//     filtered out by the CASE expressions (so an asset→asset transfer
//     contributes 0 to both totals but its bucket still appears with no
//     categories).
//
// AccountID, when set, scopes the aggregation to that single account's legs.
func (r *TransactionRepository) TransactionSummary(ctx context.Context, scope domain.SummaryScope) (*domain.MonthlySummary, error) {
	if r.rawDB == nil {
		return nil, fmt.Errorf("transaction summary requires the underlying *sql.DB (rawDB is nil)")
	}

	start, end, err := scopeRange(scope.Scope, scope.Year, scope.Month, scope.Day)
	if err != nil {
		return nil, err
	}

	// dateExpr selects how each row's transaction_date is bucketed for GROUP BY:
	//   DAY   — single bucket: a constant literal collapses every row into one
	//            group (the whole day aggregates together, no per-day split).
	//   MONTH — substr(...,1,10) slices "YYYY-MM-DD ..." to per-day buckets.
	//   YEAR  — substr(...,1,7) slices to "YYYY-MM" per-month buckets.
	// The default (Scope zero / ScopeUnspecified) matches MONTH for backward
	// compatibility with callers that omit Scope.
	dateExpr := "substr(CAST(t.transaction_date AS TEXT), 1, 10)" // MONTH default
	switch scope.Scope {
	case domain.ScopeDay:
		// A literal constant makes GROUP BY collapse to one bucket for the day.
		// The selected column is still returned (callers index it), so use a
		// stable string rather than NULL to keep the row-level scan path uniform.
		dateExpr = "'" + singleBucketKey + "'"
	case domain.ScopeYear:
		dateExpr = "substr(CAST(t.transaction_date AS TEXT), 1, 7)"
	}

	// One row per (bucket, account). amount is the directional contribution:
	// income accounts: credit_cents; expense accounts: debit_cents; else 0.
	//
	// Bucket extraction is dialect-aware:
	//   SQLite   — transaction_date is stored as TEXT "YYYY-MM-DD ...", so
	//              substr(CAST(... AS TEXT), 1, N) slices the calendar prefix.
	//   Postgres — transaction_date is timestamptz; CAST(... AS TEXT) yields
	//              "YYYY-MM-DD HH:MM:SS+TZ" so the same substr() slicing works.
	// For DAY scope dateExpr is a constant literal so GROUP BY collapses every
	// row of the day into a single bucket.
	//
	// Placeholders: the SQL is written with '?' (SQLite-native), then rebound
	// to '$N' for PostgreSQL because pgx's stdlib driver does not rewrite '?'
	// (unlike modernc/sqlite which binds '?' positionally).
	// Account-scope: filter TRANSACTIONS that hit the scoped account (not entry
	// rows). The pre-fix clause "e.account_id = ?" filtered entry rows directly,
	// so when scope.AccountID pointed at an asset/liability account only that
	// account's own leg survived — and since the CASE below returns 0 for asset/
	// liability/equity accounts, the account-detail page's monthly income/
	// expense was dead-data 0. The subquery "t.id IN (SELECT transaction_id
	// FROM <entryTable> WHERE account_id = ?)" selects the transactions touching
	// the account, preserving ALL their entry legs (including the counterparty
	// income/expense category account).
	//
	// Placeholders: the SQL is written with '?' (SQLite-native), then rebound
	// to '$N' for PostgreSQL because pgx's stdlib driver does not rewrite '?'.
	// PostgreSQL cannot infer the type of a bound NULL parameter that appears
	// only in "x IS NULL" (SQLSTATE 42P18), so on Postgres the parameter is
	// cast to the uuid type. SQLite ignores the "::uuid" suffix as a no-op cast
	// on its dynamic typing.
	accountScopeClause := "(? IS NULL OR t.id IN (SELECT " +
		transactionEntryTable + "." + transactionEntryFieldTransactionID + " FROM " +
		transactionEntryTable + " WHERE " +
		transactionEntryTable + "." + transactionEntryFieldAccountID + " = ?))"
	if r.rawDialect == DialectPostgres {
		accountScopeClause = "(?::uuid IS NULL OR t.id IN (SELECT " +
			transactionEntryTable + "." + transactionEntryFieldTransactionID + " FROM " +
			transactionEntryTable + " WHERE " +
			transactionEntryTable + "." + transactionEntryFieldAccountID + " = ?::uuid))"
	}
	q := `
		SELECT
			` + dateExpr + `                                          AS d,
			e.account_id                                              AS account_id,
			a.name                                                    AS account_name,
			a.account_type                                            AS account_type,
			CASE
				WHEN a.account_type = ? THEN COALESCE(e.credit_cents, 0)
				WHEN a.account_type = ? THEN COALESCE(e.debit_cents, 0)
				ELSE 0
			END                                                       AS amount
		FROM ` + transactionTable + ` t
		JOIN ` + transactionEntryTable + ` e ON e.transaction_id = t.id
		JOIN ` + accountsTable + ` a ON a.id = e.account_id
		WHERE t.tenant_id = ?
		  AND t.deleted_at IS NULL
		  AND t.transaction_date >= ?
		  AND t.transaction_date < ?
		  AND ` + accountScopeClause + `
		ORDER BY d ASC, account_name ASC
	`
	q = rebindPlaceholders(q, r.rawDialect)

	args := []any{
		accountTypeIncome, accountTypeExpense,
		scope.TenantID,
		start, end,
		scope.AccountID, scope.AccountID,
	}

	rows, err := r.rawDB.QueryContext(ctx, q, args...)
	if err != nil {
		return nil, fmt.Errorf("query transaction summary: %w", err)
	}
	defer rows.Close()

	type dayAccountKey struct {
		day       string
		accountID uuid.UUID
	}

	// Aggregate per (bucket, account) into a category, and per-bucket totals.
	// The "bucket" is a calendar day (MONTH scope), a calendar month (YEAR
	// scope), or the single-bucket sentinel (DAY scope).
	type categoryAcc struct {
		accountID   uuid.UUID
		name        string
		accountType string
		amount      int64
	}
	type dayAcc struct {
		date        time.Time
		totalIncome int64
		categories  []categoryAcc
	}

	dayOrder := []string{} // preserve ASC order of first appearance
	days := map[string]*dayAcc{}
	perDayAccount := map[dayAccountKey]*categoryAcc{}

	// parseBucket converts a SQL bucket string into the time.Time recorded on the
	// resulting SummaryDailyItem. The format depends on scope:
	//   DAY   — bucket is the singleBucketKey sentinel; the item's Date is the
	//           normalized start of the scoped day (start, computed above).
	//   MONTH — "YYYY-MM-DD" → parsed as a calendar day.
	//   YEAR  — "YYYY-MM"    → parsed as the first day of that month.
	parseBucket := func(bucket string) (time.Time, error) {
		if scope.Scope == domain.ScopeDay {
			return start, nil
		}
		if scope.Scope == domain.ScopeYear {
			t, err := time.Parse("2006-01", bucket)
			if err != nil {
				return time.Time{}, fmt.Errorf("parse month bucket %q: %w", bucket, err)
			}
			return t, nil
		}
		t, err := time.Parse("2006-01-02", bucket)
		if err != nil {
			return time.Time{}, fmt.Errorf("parse day bucket %q: %w", bucket, err)
		}
		return t, nil
	}

	for rows.Next() {
		var (
			dayStr       string
			accountIDStr string
			name         string
			acctType     string
			amount       int64
		)
		if err := rows.Scan(&dayStr, &accountIDStr, &name, &acctType, &amount); err != nil {
			return nil, fmt.Errorf("scan summary row: %w", err)
		}
		accountID, parseErr := uuid.Parse(accountIDStr)
		if parseErr != nil {
			return nil, fmt.Errorf("parse account id %q: %w", accountIDStr, parseErr)
		}

		day, dateErr := parseBucket(dayStr)
		if dateErr != nil {
			return nil, dateErr
		}

		if _, ok := days[dayStr]; !ok {
			days[dayStr] = &dayAcc{date: day}
			dayOrder = append(dayOrder, dayStr)
		}

		// Skip zero-amount legs (e.g. the asset/transfer legs): they do not
		// form a category, though their bucket already exists.
		if amount == 0 {
			continue
		}

		key := dayAccountKey{day: dayStr, accountID: accountID}
		acc, ok := perDayAccount[key]
		if !ok {
			acc = &categoryAcc{accountID: accountID, name: name, accountType: acctType}
			perDayAccount[key] = acc
			days[dayStr].categories = append(days[dayStr].categories, categoryAcc{
				accountID: accountID, name: name, accountType: acctType,
			})
			// Point the map entry at the slice element so later rows accumulate
			// into the same struct.
			acc = &days[dayStr].categories[len(days[dayStr].categories)-1]
			perDayAccount[key] = acc
		}
		acc.amount += amount
		if acctType == accountTypeIncome {
			days[dayStr].totalIncome += amount
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate summary rows: %w", err)
	}

	// Build the result in day order.
	summary := &domain.MonthlySummary{}
	byDay := make([]domain.SummaryDailyItem, 0, len(dayOrder))
	for _, ds := range dayOrder {
		d := days[ds]
		cats := make([]domain.SummaryCategoryItem, len(d.categories))
		dayExpense := int64(0)
		for i, c := range d.categories {
			cats[i] = domain.SummaryCategoryItem{
				AccountID:   c.accountID,
				Name:        c.name,
				AccountType: c.accountType,
				Amount:      c.amount,
			}
			if c.accountType == accountTypeExpense {
				dayExpense += c.amount
			}
		}
		summary.IncomeCents += d.totalIncome
		summary.ExpenseCents += dayExpense
		byDay = append(byDay, domain.SummaryDailyItem{
			Date:        d.date,
			TotalIncome: d.totalIncome,
			ByCategory:  cats,
		})
	}

	summary.NetCents = summary.IncomeCents - summary.ExpenseCents
	if n := len(byDay); n > 0 {
		summary.DailyAvgCents = summary.NetCents / int64(n)
	}
	summary.ByDay = byDay
	return summary, nil
}

// singleBucketKey is the SQL literal selected as the "bucket" column when
// scope == ScopeDay. Because it is a constant (not derived from
// transaction_date), GROUP BY collapses every row of the day into one bucket,
// which is exactly the DAY-scope aggregation contract (a single sum for the
// day, no per-date breakdown). It is a short stable string so the row scan
// path stays uniform with the MONTH/YEAR branches.
const singleBucketKey = "__day__"

// scopeRange returns the [start, end) UTC time window covering the period
// selected by scope:
//
//   - ScopeDay:   [y-m-d 00:00, y-m-(d+1) 00:00) — requires day non-nil.
//   - ScopeMonth: [y-m-1 00:00, y-(m+1)-1 00:00) — existing monthRange logic.
//   - ScopeYear:  [y-1-1 00:00, (y+1)-1-1 00:00).
//
// Scope zero (ScopeUnspecified) defaults to MONTH for backward compatibility
// with callers that omit Scope. month is 1-12; values outside that range are an
// error (ignored for ScopeYear). day is 1-31 and is only consulted for
// ScopeDay; the caller must validate the calendar day for the month.
func scopeRange(scope domain.Scope, year, month int, day *int) (time.Time, time.Time, error) {
	switch scope {
	case domain.ScopeDay:
		if day == nil {
			return time.Time{}, time.Time{}, fmt.Errorf("scope DAY requires a non-nil day")
		}
		if month < 1 || month > 12 {
			return time.Time{}, time.Time{}, fmt.Errorf("invalid month %d (want 1-12)", month)
		}
		if *day < 1 || *day > 31 {
			return time.Time{}, time.Time{}, fmt.Errorf("invalid day %d (want 1-31)", *day)
		}
		start := time.Date(year, time.Month(month), *day, 0, 0, 0, 0, time.UTC)
		// AddDate normalizes overflow (e.g. Jan 32 → Feb 1, Dec 31 → Jan 1 next
		// year), so the end is always the next calendar day regardless of month
		// or year boundaries.
		end := start.AddDate(0, 0, 1)
		return start, end, nil

	case domain.ScopeYear:
		start := time.Date(year, time.January, 1, 0, 0, 0, 0, time.UTC)
		end := start.AddDate(1, 0, 0)
		return start, end, nil

	default: // ScopeMonth, ScopeUnspecified (zero), and any unknown value.
		if month < 1 || month > 12 {
			return time.Time{}, time.Time{}, fmt.Errorf("invalid month %d (want 1-12)", month)
		}
		start := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.UTC)
		end := start.AddDate(0, 1, 0)
		return start, end, nil
	}
}

// rebindPlaceholders converts '?' placeholders in a raw SQL string to the
// dialect's positional style. SQLite and MySQL keep '?'; PostgreSQL needs '$N'
// because the pgx stdlib driver does not rebind '?' (unlike modernc/sqlite,
// which binds '?' positionally). Only bare '?' are converted — '?' inside
// string literals is left untouched. For dialects other than postgres the
// string is returned unchanged.
func rebindPlaceholders(query, dialect string) string {
	if dialect != DialectPostgres {
		return query
	}
	var (
		out      strings.Builder
		n        int
		inSingle bool
	)
	for i := 0; i < len(query); i++ {
		c := query[i]
		if c == '\'' {
			// Toggle single-quote literal mode. Standard SQL doubles '' for an
			// escaped quote, but this raw query contains no string literals with
			// embedded quotes, so a simple toggle is sufficient.
			inSingle = !inSingle
			out.WriteByte(c)
			continue
		}
		if c == '?' && !inSingle {
			n++
			out.WriteString("$")
			out.WriteString(strconv.Itoa(n))
			continue
		}
		out.WriteByte(c)
	}
	return out.String()
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
		TransactionTime: t.TransactionTime,
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
