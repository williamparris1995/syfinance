package application

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountent "github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/account/ent/account"
	tmplrepo "github.com/yucai/server/internal/template/adapter/driven/repository"
	"github.com/yucai/server/internal/template/domain"
	tmplent "github.com/yucai/server/internal/template/ent"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txndomain "github.com/yucai/server/internal/transaction/domain"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

// txTestDialect is the ent dialect string for SQLite
// (== entgo.io/ent/dialect.SQLite). Forwarded to the service's WithTx call so
// ent's mutation builders emit "?" placeholders instead of PostgreSQL's "$1".
const txTestDialect = "sqlite3"

// setupTemplateTxTestDB opens ONE shared in-memory SQLite database, runs the
// account + transaction + template ent auto-migrations against it, and returns
// the underlying *sql.DB plus ready ent clients for each module. The shared
// *sql.DB is what the template Service's WithTx opens its transaction on, and
// what the downstream txn Service's runInTx joins (Task 1's provideDB pattern).
//
// SetMaxOpenConns(1) is mandatory for shared in-memory SQLite — it pins the
// pool to a single physical connection so the *sql.Tx grabbed by WithTx and
// the subsequent read-through-default-client hit the same database.
func setupTemplateTxTestDB(t *testing.T) (*sql.DB, *tmplent.Client, *txnent.Client, *accountent.Client) {
	t.Helper()
	dbName := "template_app_shared_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { _ = db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}
	db.SetMaxOpenConns(1)

	drv := entsql.OpenDB(txTestDialect, db)

	tmplClient := tmplent.NewClient(tmplent.Driver(drv))
	if err := tmplClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate template schema: %v", err)
	}
	txnClient := txnent.NewClient(txnent.Driver(drv))
	if err := txnClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate transaction schema: %v", err)
	}
	accountClient := accountent.NewClient(accountent.Driver(drv))
	if err := accountClient.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate account schema: %v", err)
	}
	t.Cleanup(func() {
		_ = tmplClient.Close()
		_ = txnClient.Close()
		_ = accountClient.Close()
	})
	return db, tmplClient, txnClient, accountClient
}

// inlineBalanceUpdater mirrors balance.BalanceUpdaterImpl's applyEntries path
// (accountRepo.FindByID → BalanceCalculator.ApplyEntryDelta → accountRepo.Update).
// Duplicated inline here because importing the real balance package would form
// an import cycle (balance imports transaction/application). The path is
// identical to the production balance updater so the test exercises the same
// write sequence the recorder triggers inside the WithTx wrapper.
type inlineBalanceUpdater struct {
	accountRepo accountdomain.AccountRepository
}

func (u *inlineBalanceUpdater) UpdateBalances(ctx context.Context, tenantID uuid.UUID, entries []txndomain.TransactionEntry) error {
	return u.applyEntries(ctx, tenantID, entries, 1)
}
func (u *inlineBalanceUpdater) ReverseBalances(ctx context.Context, tenantID uuid.UUID, entries []txndomain.TransactionEntry) error {
	return u.applyEntries(ctx, tenantID, entries, -1)
}
func (u *inlineBalanceUpdater) applyEntries(ctx context.Context, tenantID uuid.UUID, entries []txndomain.TransactionEntry, sign int64) error {
	calc := accountdomain.BalanceCalculator{}
	for _, e := range entries {
		acc, err := u.accountRepo.FindByID(ctx, tenantID, e.AccountID)
		if err != nil {
			return fmt.Errorf("find account %s: %w", e.AccountID, err)
		}
		delta := calc.ApplyEntryDelta(acc.AccountType, e.DebitCents, e.CreditCents) * sign
		acc.CurrentBalanceCents += delta
		acc.IncrementVersion()
		if err := u.accountRepo.Update(ctx, acc); err != nil {
			return fmt.Errorf("update account balance: %w", err)
		}
	}
	return nil
}

// failingUpdateTemplateRepo wraps a real domain.TemplateRepository, delegating
// every method to the inner repo EXCEPT Update, which returns the injected
// error. This simulates a mid-flow persistence failure on the NextDate-advance
// step (the second write phase of RecordTransaction, AFTER recorder.Record has
// created the transaction) so the rollback test can assert the earlier
// transaction header + entries + balance writes were rolled back.
//
// Embedding the interface promotes all methods; shadowing just Update keeps the
// wrapper resilient to future TemplateRepository growth (a new method is
// auto-delegated, not silently dropped). Mirrors the failingUpdateAccountRepo
// pattern from Task 4's service_tx_test.go and failingLotRepo from Task 5.
type failingUpdateTemplateRepo struct {
	domain.TemplateRepository
	failUpdate error
}

func (r *failingUpdateTemplateRepo) Update(_ context.Context, _ *domain.TransactionTemplate) error {
	return r.failUpdate
}

// seedAccountForTemplateTx inserts one account row directly via the ent client
// so the test starts from a known state without invoking any service path.
func seedAccountForTemplateTx(t *testing.T, ctx context.Context, c *accountent.Client, id, tenantID uuid.UUID, name string, accountType account.AccountType, balanceCents int64) {
	t.Helper()
	if _, err := c.Account.Create().
		SetID(id).
		SetTenantID(tenantID).
		SetName(name).
		SetAccountType(accountType).
		SetCurrentBalanceCents(balanceCents).
		SetInitialBalanceCents(balanceCents).
		Save(ctx); err != nil {
		t.Fatalf("seed account %s: %v", name, err)
	}
}

// seedTemplateRow inserts one transaction_template row directly via the ent
// client so RecordTransaction's FindByID has a row to load. Uses the minimum
// required field set; the rest get ent defaults. direction="expense" so the
// recorder dispatches to SimpleExpense.
func seedTemplateRow(t *testing.T, ctx context.Context, c *tmplent.Client, tmpl *domain.TransactionTemplate) {
	t.Helper()
	create := c.TransactionTemplate.Create().
		SetID(tmpl.ID).
		SetTenantID(tmpl.TenantID).
		SetName(tmpl.Name).
		SetDescription(tmpl.Description).
		SetAmountCents(tmpl.AmountCents).
		SetDirection(tmpl.Direction.String()).
		SetSourceAccountID(tmpl.SourceAccountID).
		SetCycle(tmpl.Cycle.String()).
		SetCycleDays(tmpl.CycleDays).
		SetBillingDay(tmpl.BillingDay).
		SetNextDate(tmpl.NextDate).
		SetStartDate(tmpl.StartDate).
		SetAutoRecord(tmpl.AutoRecord).
		SetPaused(tmpl.Paused).
		SetCategory(tmpl.Category).
		SetVersion(tmpl.Version).
		SetCreatedAt(tmpl.CreatedAt).
		SetUpdatedAt(tmpl.UpdatedAt)
	if _, err := create.Save(ctx); err != nil {
		t.Fatalf("seed template %s: %v", tmpl.Name, err)
	}
}

// TestRecordTransaction_RollbackOnNextDateAdvanceFailure is the headline
// transactional guarantee for Task 7 (audit D4): when the template Update
// (which persists the advanced NextDate + LastTransactionID) fails AFTER
// recorder.Record has created the transaction (header + entries + balance
// update), the entire operation must roll back — leaving zero transaction
// rows, zero entry rows, and the asset account's balance unchanged.
// Pre-Task-7 (no sqltx.WithTx wrapping of template.Service.RecordTransaction),
// recorder.Record's inner SimpleExpense WithTx commits independently and the
// transaction persists despite the later template Update failure, so on the
// next scheduler tick the template is still due and the record repeats →
// duplicate. Post-Task-7 the outer WithTx rolls back everything with the
// failed template Update (Task 8 will additionally guard the concurrent-tick
// case via a template_record_log idempotency key).
func TestRecordTransaction_RollbackOnNextDateAdvanceFailure(t *testing.T) {
	db, tmplClient, txnClient, accountClient := setupTemplateTxTestDB(t)

	tenantID := uuid.New()
	assetID := uuid.New()
	expenseID := uuid.New()
	ctx := context.Background()

	seedAccountForTemplateTx(t, ctx, accountClient, assetID, tenantID, "Cash", account.AccountTypeAsset, 1000_00)
	seedAccountForTemplateTx(t, ctx, accountClient, expenseID, tenantID, "Food", account.AccountTypeExpense, 0)

	// Real template pointing at the seeded accounts (expense → SimpleExpense).
	tmpl, err := domain.NewTransactionTemplate(
		tenantID, "Rent", 50_00, domain.DirectionExpense, assetID,
		domain.CycleMonthly, 1, time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	)
	if err != nil {
		t.Fatalf("build template: %v", err)
	}
	tmpl.Category = expenseID.String()
	seedTemplateRow(t, ctx, tmplClient, tmpl)

	// Real repos wired over the shared db.
	tmplRepo := tmplrepo.NewTemplateRepository(tmplClient)
	txnRepo := txnrepo.NewTransactionRepository(txnClient, db).SetDialect(txnrepo.DialectSQLite3)
	accountRepo := accountrepo.NewAccountRepository(accountClient)

	// Wrap the real template repo so Update (the NextDate-advance persist step
	// after recorder.Record) returns errFake. FindByID and every other method
	// keep working, so the recorder path completes normally before the
	// template Update trips.
	errFake := errors.New("simulated next-date advance failure")
	failingRepo := &failingUpdateTemplateRepo{TemplateRepository: tmplRepo, failUpdate: errFake}

	// Production-shaped transaction service + real recorder adapter. The txn
	// service gets the shared db so SimpleExpense's runInTx JOINS the outer
	// template WithTx (join-existing-tx semantics) rather than committing
	// independently.
	bu := &inlineBalanceUpdater{accountRepo: accountRepo}
	txnSvc := txnapp.NewService(txnRepo, accountRepo, bu, db)
	recorder := txnapp.NewTransactionRecorderAdapter(txnSvc)

	tmplSvc := NewService(failingRepo, recorder)
	tmplSvc.SetDB(db) // Task 7: shared *sql.DB → RecordTransaction wraps in sqltx.WithTx

	_, err = tmplSvc.RecordTransaction(ctx, tenantID, tmpl.ID)
	if err == nil {
		t.Fatal("expected RecordTransaction to surface the next-date advance error, got nil")
	}
	if !errors.Is(err, errFake) {
		t.Fatalf("expected error to wrap errFake, got %v", err)
	}

	// Headline assertion: the transaction header + every entry must have been
	// rolled back. Pre-Task-7 the recorder's SimpleExpense WithTx commits
	// independently (header=1, entries=2); post-Task-7 the outer WithTx rolls
	// them back with the failed template Update.
	headerCount, err := txnClient.Transaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count transactions: %v", err)
	}
	if headerCount != 0 {
		t.Errorf("transaction header should have rolled back, got %d row(s)", headerCount)
	}
	entryCount, err := txnClient.TransactionEntry.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count entries: %v", err)
	}
	if entryCount != 0 {
		t.Errorf("transaction entries should have rolled back, got %d row(s)", entryCount)
	}

	// Sanity: the asset account's balance must be unchanged (the decrement
	// inside the rolled-back tx never committed).
	asset, err := accountClient.Account.Get(ctx, assetID)
	if err != nil {
		t.Fatalf("reload asset account: %v", err)
	}
	if asset.CurrentBalanceCents != 1000_00 {
		t.Errorf("asset balance should be unchanged at 100000, got %d", asset.CurrentBalanceCents)
	}

	// Sanity: the template's persisted NextDate must be unchanged too — the
	// advance was inside the rolled-back tx.
	reloaded, err := tmplClient.TransactionTemplate.Get(ctx, tmpl.ID)
	if err != nil {
		t.Fatalf("reload template: %v", err)
	}
	if !reloaded.NextDate.Equal(tmpl.NextDate) {
		t.Errorf("template NextDate should be unchanged at %v, got %v", tmpl.NextDate, reloaded.NextDate)
	}
}

// TestRecordTransaction_CommitsOnSuccess is the paired control for the rollback
// test: when every step succeeds, the WithTx wrapper commits and the
// transaction header + entries + balance update + template advance are all
// durable. Without this control a bug where WithTx always rolled back would
// pass the rollback test silently.
func TestRecordTransaction_CommitsOnSuccess(t *testing.T) {
	db, tmplClient, txnClient, accountClient := setupTemplateTxTestDB(t)

	tenantID := uuid.New()
	assetID := uuid.New()
	expenseID := uuid.New()
	ctx := context.Background()

	seedAccountForTemplateTx(t, ctx, accountClient, assetID, tenantID, "Cash", account.AccountTypeAsset, 1000_00)
	seedAccountForTemplateTx(t, ctx, accountClient, expenseID, tenantID, "Food", account.AccountTypeExpense, 0)

	tmpl, err := domain.NewTransactionTemplate(
		tenantID, "Rent", 50_00, domain.DirectionExpense, assetID,
		domain.CycleMonthly, 1, time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	)
	if err != nil {
		t.Fatalf("build template: %v", err)
	}
	tmpl.Category = expenseID.String()
	seedTemplateRow(t, ctx, tmplClient, tmpl)

	tmplRepo := tmplrepo.NewTemplateRepository(tmplClient)
	txnRepo := txnrepo.NewTransactionRepository(txnClient, db).SetDialect(txnrepo.DialectSQLite3)
	accountRepo := accountrepo.NewAccountRepository(accountClient)

	bu := &inlineBalanceUpdater{accountRepo: accountRepo}
	txnSvc := txnapp.NewService(txnRepo, accountRepo, bu, db)
	recorder := txnapp.NewTransactionRecorderAdapter(txnSvc)

	tmplSvc := NewService(tmplRepo, recorder)
	tmplSvc.SetDB(db)

	res, err := tmplSvc.RecordTransaction(ctx, tenantID, tmpl.ID)
	if err != nil {
		t.Fatalf("RecordTransaction succeeded-path: %v", err)
	}
	if res == nil {
		t.Fatal("expected non-nil RecordResult on success")
	}

	// Transaction + entries committed.
	headerCount, err := txnClient.Transaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count transactions: %v", err)
	}
	if headerCount != 1 {
		t.Errorf("transaction header should have committed, got %d row(s)", headerCount)
	}
	entryCount, err := txnClient.TransactionEntry.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count entries: %v", err)
	}
	if entryCount != 2 {
		t.Errorf("expected 2 entries committed, got %d row(s)", entryCount)
	}

	// Balance update committed: asset balance dropped by 50.00.
	asset, err := accountClient.Account.Get(ctx, assetID)
	if err != nil {
		t.Fatalf("reload asset account: %v", err)
	}
	if asset.CurrentBalanceCents != 950_00 {
		t.Errorf("asset balance should be 95000 after 50.00 expense, got %d", asset.CurrentBalanceCents)
	}

	// Template NextDate advanced + LastTransactionID set + version bumped.
	// NewTransactionTemplate(startDate=Jan 1, CycleMonthly, billingDay=1)
	// seeds NextDate=Feb 1; one record advances it to Mar 1.
	reloaded, err := tmplClient.TransactionTemplate.Get(ctx, tmpl.ID)
	if err != nil {
		t.Fatalf("reload template: %v", err)
	}
	wantNext := time.Date(2026, 3, 1, 0, 0, 0, 0, time.UTC)
	if !reloaded.NextDate.Equal(wantNext) {
		t.Errorf("template NextDate should advance to %v, got %v", wantNext, reloaded.NextDate)
	}
	if reloaded.LastTransactionID == nil || *reloaded.LastTransactionID != res.TransactionID {
		t.Errorf("template LastTransactionID should be %s, got %v", res.TransactionID, reloaded.LastTransactionID)
	}
	if reloaded.Version != tmpl.Version+1 {
		t.Errorf("template Version should bump to %d, got %d", tmpl.Version+1, reloaded.Version)
	}
}

// TestRecordTransaction_Idempotent_OnSameRecordDate is the headline Task 8
// guarantee (audit C1 / D4 concurrent-tick guard): a duplicate autoRecord
// attempt for the same (template, record_date) must NOT create a duplicate
// transaction. The first record commits both the new transaction AND a
// template_record_log row keyed by (tenant_id, template_id, NextDate) inside
// the same WithTx. A second attempt with the same NextDate (simulating a
// concurrent scheduler tick OR a crash-retry where the NextDate advance did
// not yet persist) hits the UNIQUE(tenant_id, template_id, record_date)
// conflict on Upsert → returns inserted=false → autoRecord skips
// recorder.Record entirely (empty tx commits). Assertion: exactly 1
// transaction row + exactly 1 log row after both calls.
//
// Pre-Task-8 (no log table / no idempotency check), the second call would
// re-record → 2 transactions + double-spend the asset account, and on the
// next tick the duplicate would compound. Post-Task-8 the unique index is the
// mechanism and Upsert is the policy.
func TestRecordTransaction_Idempotent_OnSameRecordDate(t *testing.T) {
	db, tmplClient, txnClient, accountClient := setupTemplateTxTestDB(t)

	tenantID := uuid.New()
	assetID := uuid.New()
	expenseID := uuid.New()
	ctx := context.Background()

	seedAccountForTemplateTx(t, ctx, accountClient, assetID, tenantID, "Cash", account.AccountTypeAsset, 1000_00)
	seedAccountForTemplateTx(t, ctx, accountClient, expenseID, tenantID, "Food", account.AccountTypeExpense, 0)

	tmpl, err := domain.NewTransactionTemplate(
		tenantID, "Rent", 50_00, domain.DirectionExpense, assetID,
		domain.CycleMonthly, 1, time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
	)
	if err != nil {
		t.Fatalf("build template: %v", err)
	}
	tmpl.Category = expenseID.String()
	seedTemplateRow(t, ctx, tmplClient, tmpl)

	// Real repos wired over the shared db. tmplClient.TemplateRecordLog is
	// the Task 8 ent entity; the repo wraps it with the try-insert +
	// IsConstraintError idempotency pattern.
	tmplRepo := tmplrepo.NewTemplateRepository(tmplClient)
	txnRepo := txnrepo.NewTransactionRepository(txnClient, db).SetDialect(txnrepo.DialectSQLite3)
	accountRepo := accountrepo.NewAccountRepository(accountClient)
	logRepo := tmplrepo.NewTemplateRecordLogRepository(tmplClient)

	bu := &inlineBalanceUpdater{accountRepo: accountRepo}
	txnSvc := txnapp.NewService(txnRepo, accountRepo, bu, db)
	recorder := txnapp.NewTransactionRecorderAdapter(txnSvc)

	tmplSvc := NewService(tmplRepo, recorder)
	tmplSvc.SetDB(db)       // Task 7: wrap recorder.Record + NextDate in WithTx
	tmplSvc.SetLogRepo(logRepo) // Task 8: idempotency check active

	// First call: succeeds → 1 transaction + 1 log row (with txnID back-fill)
	// + NextDate advances + asset balance drops by 50.00.
	res1, err := tmplSvc.RecordTransaction(ctx, tenantID, tmpl.ID)
	if err != nil {
		t.Fatalf("first RecordTransaction: %v", err)
	}
	if res1 == nil {
		t.Fatal("expected non-nil result on first call")
	}

	// Simulate a duplicate attempt against the SAME record_date. Two real-world
	// shapes: (a) two scheduler ticks fire concurrently before either commits;
	// (b) crash between commit and the NextDate-advance persist. Task 7 made
	// (b) impossible (NextDate-advance is inside the same WithTx), but (a) and
	// "old scheduler snapshot" are still possible — that's what Task 8 guards.
	// We reset the persisted NextDate back to the original value to simulate
	// "the second tick sees the same NextDate as the first". The log row from
	// call 1 is still keyed on the original NextDate, so the second call's
	// Upsert conflicts → autoRecord returns nil (skip) inside the WithTx fn.
	originalNext := tmpl.NextDate // Jan 1 + CycleMonthly/billingDay 1 → Feb 1
	if _, err := tmplClient.TransactionTemplate.UpdateOneID(tmpl.ID).
		SetNextDate(originalNext).
		Save(ctx); err != nil {
		t.Fatalf("reset NextDate for duplicate-attempt simulation: %v", err)
	}

	// Second call: same (template, NextDate) → log Upsert hits UNIQUE conflict
	// → inserted=false → autoRecord returns nil without calling recorder.Record.
	res2, err := tmplSvc.RecordTransaction(ctx, tenantID, tmpl.ID)
	if err != nil {
		t.Fatalf("second RecordTransaction (idempotency hit should not error): %v", err)
	}
	if res2 != nil {
		t.Errorf("expected nil result on idempotency skip, got %+v", res2)
	}

	// Headline: exactly 1 transaction + 1 log row (no duplicate).
	headerCount, err := txnClient.Transaction.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count transactions: %v", err)
	}
	if headerCount != 1 {
		t.Errorf("transaction should have exactly 1 row (no duplicate), got %d", headerCount)
	}

	logCount, err := tmplClient.TemplateRecordLog.Query().Count(ctx)
	if err != nil {
		t.Fatalf("count log rows: %v", err)
	}
	if logCount != 1 {
		t.Errorf("log should have exactly 1 row, got %d", logCount)
	}

	// The single log row's transaction_id must equal res1.TransactionID — the
	// SetTransactionID back-fill ran inside the first WithTx after recorder.Record.
	logRows, err := tmplClient.TemplateRecordLog.Query().All(ctx)
	if err != nil {
		t.Fatalf("query log: %v", err)
	}
	if len(logRows) != 1 {
		t.Fatalf("expected 1 log row, got %d", len(logRows))
	}
	if logRows[0].TransactionID == nil || *logRows[0].TransactionID != res1.TransactionID {
		t.Errorf("log transaction_id should be %s, got %+v", res1.TransactionID, logRows[0].TransactionID)
	}
	// Sanity: log row key fields match the original (template, record_date).
	if logRows[0].TemplateID != tmpl.ID {
		t.Errorf("log template_id should be %s, got %s", tmpl.ID, logRows[0].TemplateID)
	}
	if !logRows[0].RecordDate.Equal(originalNext) {
		t.Errorf("log record_date should be %v, got %v", originalNext, logRows[0].RecordDate)
	}

	// Sanity: the asset account was debited exactly once (50.00, not 100.00).
	// Pre-Task-8 the duplicate would have compounded.
	asset, err := accountClient.Account.Get(ctx, assetID)
	if err != nil {
		t.Fatalf("reload asset account: %v", err)
	}
	if asset.CurrentBalanceCents != 950_00 {
		t.Errorf("asset balance should be 95000 after one 50.00 expense, got %d", asset.CurrentBalanceCents)
	}
}

// ensure dialect import is used even if the helper signatures change later.
var _ = dialect.SQLite
