package tests

import (
	"context"
	"strings"
	"testing"
	"time"

	"database/sql"
	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountdomain "github.com/yucai/server/internal/account/domain"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	accountenum "github.com/yucai/server/internal/account/ent/account"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	"github.com/yucai/server/internal/debt/application"
	"github.com/yucai/server/internal/debt/domain"
	debtent "github.com/yucai/server/internal/debt/ent"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txnent "github.com/yucai/server/internal/transaction/ent"
)

func setupDebtTestDB(t *testing.T) *debtent.Client {
	t.Helper()
	dbName := "debt_ent_" + t.Name()
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := debtent.NewClient(debtent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func TestDebtCRUD(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()
	accountID := uuid.New()

	// Create
	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationEqualPrincipal,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 12000000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}
	if resp.Version != 1 {
		t.Errorf("expected version 1, got %d", resp.Version)
	}
	debtID := resp.ID

	// Get
	detail, err := svc.GetDebt(ctx, tenantID, debtID)
	if err != nil {
		t.Fatalf("GetDebt failed: %v", err)
	}
	if len(detail.Schedule) != 6 {
		t.Errorf("expected 6 schedule entries, got %d", len(detail.Schedule))
	}

	// Update
	updated, err := svc.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:     tenantID,
		ID:           debtID,
		Counterparty: "Bank of China",
		InterestRate: 0.045,
		Version:      1,
	})
	if err != nil {
		t.Fatalf("UpdateDebt failed: %v", err)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}
	if updated.InterestRate != 0.045 {
		t.Errorf("expected rate 0.045, got %f", updated.InterestRate)
	}

	// List
	result, err := svc.ListDebts(ctx, application.ListDebtsRequest{
		TenantID: tenantID,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListDebts failed: %v", err)
	}
	if len(result.Debts) != 1 {
		t.Errorf("expected 1 debt, got %d", len(result.Debts))
	}

	// Delete
	err = svc.DeleteDebt(ctx, tenantID, debtID)
	if err != nil {
		t.Fatalf("DeleteDebt failed: %v", err)
	}

	// Verify deleted
	_, err = svc.GetDebt(ctx, tenantID, debtID)
	if err == nil {
		t.Error("expected error after delete")
	}
}

func TestEqualPrincipalInterestSchedule(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "CMB",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationEqualPrincipalInterest,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 12000000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}

	detail, err := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt failed: %v", err)
	}

	// Verify schedule has 6 entries
	if len(detail.Schedule) != 6 {
		t.Fatalf("expected 6 entries, got %d", len(detail.Schedule))
	}

	// Verify total principal sums correctly
	var totalPrincipal int64
	for _, e := range detail.Schedule {
		totalPrincipal += e.PrincipalCents
	}
	if totalPrincipal != 12000000 {
		t.Errorf("total principal should be 12000000, got %d", totalPrincipal)
	}

	// All payments should be roughly equal (within a few cents)
	firstTotal := detail.Schedule[0].TotalCents
	for i, e := range detail.Schedule {
		diff := e.TotalCents - firstTotal
		if diff > 10 || diff < -10 {
			t.Errorf("entry %d total %d differs from first %d by %d", i, e.TotalCents, firstTotal, diff)
		}
	}
}

func TestLumpSumSchedule(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "Friend",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 1000000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}

	detail, err := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt failed: %v", err)
	}

	if len(detail.Schedule) != 1 {
		t.Fatalf("expected 1 entry, got %d", len(detail.Schedule))
	}
	// Interest = 1000000 * 0.05 * 6/12 = 25000
	if detail.Schedule[0].InterestCents != 25000 {
		t.Errorf("expected interest 25000, got %d", detail.Schedule[0].InterestCents)
	}
}

func TestRecordPayment(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()

	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            uuid.New(),
		AccountID:           uuid.New(),
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationEqualPrincipal,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 900000,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}

	detail, _ := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	entryID := detail.Schedule[0].ID
	fromAccountID := uuid.New()

	// Record payment
	payResult, err := svc.RecordPayment(ctx, application.RecordPaymentRequest{
		TenantID:        resp.TenantID,
		DebtID:          resp.ID,
		ScheduleEntryID: entryID,
		FromAccountID:   fromAccountID,
	})
	if err != nil {
		t.Fatalf("RecordPayment failed: %v", err)
	}
	if payResult.TransactionID == uuid.Nil {
		t.Error("expected non-nil transaction ID")
	}
	if !payResult.Entry.Paid {
		t.Error("expected entry to be paid")
	}

	// Verify remaining principal decreased
	updated, _ := svc.GetDebt(ctx, resp.TenantID, resp.ID)
	if updated.Debt.RemainingPrincipal >= 900000 {
		t.Errorf("remaining should have decreased, got %d", updated.Debt.RemainingPrincipal)
	}
}

func TestUpdateDebtSubtype(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()
	accountID := uuid.New()

	// Create with subtype A.
	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 12000000,
		DebtType:            domain.BorrowedIn,
		Subtype:             domain.DebtSubtypeMortgage,
	})
	if err != nil {
		t.Fatalf("CreateDebt failed: %v", err)
	}
	if resp.Subtype != domain.DebtSubtypeMortgage {
		t.Fatalf("expected subtype %q at create, got %q", domain.DebtSubtypeMortgage, resp.Subtype)
	}

	// Update with subtype B: non-empty replaces.
	updated, err := svc.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:     tenantID,
		ID:           resp.ID,
		Counterparty: "ICBC",
		InterestRate: 0.05,
		Version:      1,
		Subtype:      domain.DebtSubtypeAutoLoan,
	})
	if err != nil {
		t.Fatalf("UpdateDebt with subtype failed: %v", err)
	}
	if updated.Subtype != domain.DebtSubtypeAutoLoan {
		t.Errorf("expected subtype %q after update, got %q", domain.DebtSubtypeAutoLoan, updated.Subtype)
	}

	// Read back: the new subtype must persist.
	detail, err := svc.GetDebt(ctx, tenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt failed: %v", err)
	}
	if detail.Debt.Subtype != domain.DebtSubtypeAutoLoan {
		t.Errorf("expected persisted subtype %q, got %q", domain.DebtSubtypeAutoLoan, detail.Debt.Subtype)
	}

	// Update without subtype (empty string): keeps the current value
	// (legacy clients never send the field — NFR-2).
	kept, err := svc.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:     tenantID,
		ID:           resp.ID,
		Counterparty: "Bank of China",
		InterestRate: 0.05,
		Version:      2,
	})
	if err != nil {
		t.Fatalf("UpdateDebt without subtype failed: %v", err)
	}
	if kept.Subtype != domain.DebtSubtypeAutoLoan {
		t.Errorf("empty subtype must keep current value: expected %q, got %q", domain.DebtSubtypeAutoLoan, kept.Subtype)
	}

	// Read back again: still unchanged after the empty-subtype update.
	detail2, err := svc.GetDebt(ctx, tenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt after empty-subtype update failed: %v", err)
	}
	if detail2.Debt.Subtype != domain.DebtSubtypeAutoLoan {
		t.Errorf("expected subtype to stay %q after empty update, got %q", domain.DebtSubtypeAutoLoan, detail2.Debt.Subtype)
	}
	if detail2.Debt.Counterparty != "Bank of China" {
		t.Errorf("expected counterparty updated to %q, got %q", "Bank of China", detail2.Debt.Counterparty)
	}
}

func TestDebtTenantIsolation(t *testing.T) {
	client := setupDebtTestDB(t)
	repo := debtrepo.NewDebtRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	// Create for tenant A
	_, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantA,
		AccountID:           uuid.New(),
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: 500000,
	})
	if err != nil {
		t.Fatalf("CreateDebt for A failed: %v", err)
	}

	// Tenant B should see no debts
	result, err := svc.ListDebts(ctx, application.ListDebtsRequest{
		TenantID: tenantB,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListDebts for B failed: %v", err)
	}
	if len(result.Debts) != 0 {
		t.Errorf("tenant B should see 0 debts, got %d", len(result.Debts))
	}
}

// --- F36 T2: liability posting invariant tests ---

// equityCarryoverName is the system equity account the client's
// _ensureSettlementAccount auto-creates ("historical repayment carryover") —
// the counterpart account for every liability-side opening/adjustment posting.
const equityCarryoverName = "历史还款结转"

// setupDebtPostingTestDB opens ONE shared in-memory sqlite and migrates the
// account + transaction + debt ent schemas against the same driver so the debt
// service's liability postings flow through the real transaction service +
// BalanceUpdater into the same DB the accounts live in. SetMaxOpenConns(1)
// pins the pool to a single connection (see sqltx integration tests).
func setupDebtPostingTestDB(t *testing.T) (*accountent.Client, *txnent.Client, *debtent.Client) {
	t.Helper()
	dbName := "debt_posting_" + strings.ReplaceAll(t.Name(), "/", "_")
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	db.SetMaxOpenConns(1)
	t.Cleanup(func() { db.Close() })

	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)

	acctClient := accountent.NewClient(accountent.Driver(drv))
	txnClient := txnent.NewClient(txnent.Driver(drv))
	debtClient := debtent.NewClient(debtent.Driver(drv))

	ctx := context.Background()
	if err := acctClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create account schema: %v", err)
	}
	if err := txnClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create transaction schema: %v", err)
	}
	if err := debtClient.Schema.Create(ctx); err != nil {
		t.Fatalf("create debt schema: %v", err)
	}

	t.Cleanup(func() { acctClient.Close() })
	t.Cleanup(func() { txnClient.Close() })
	t.Cleanup(func() { debtClient.Close() })
	return acctClient, txnClient, debtClient
}

// setupDebtPostingHarness wires a real debt application service against real
// ent-backed repos + a real BalanceUpdater sharing one in-memory sqlite, so
// liability postings are observable through real account balance reads. The
// account repo doubles as the debt service's AccountLookup (currency + equity
// resolution). debtSvc.db stays nil at the integration level — same-DB
// atomicity is covered by debt/application/service_tx_test.go (mirrors the
// debt double-write harness precedent).
func setupDebtPostingHarness(t *testing.T) (*application.Service, *accountapp.Service, *accountent.Client, uuid.UUID) {
	t.Helper()
	acctClient, txnClient, debtClient := setupDebtPostingTestDB(t)

	accountRepo := accountrepo.NewAccountRepository(acctClient)
	chartRepo := accountrepo.NewChartRepository(acctClient)
	acctSvc := accountapp.NewService(accountRepo, chartRepo)

	txnRepo := txnrepo.NewTransactionRepository(txnClient, nil)
	balanceUpdater := txnbalance.NewBalanceUpdater(accountRepo)
	txnSvc := txnapp.NewService(txnRepo, accountRepo, balanceUpdater, nil)

	debtRepo := debtrepo.NewDebtRepository(debtClient)
	debtSvc := application.NewService(debtRepo)
	debtSvc.SetAccountLookup(accountRepo)
	debtSvc.SetCashRecorder(txnapp.NewRepaymentCashRecorderAdapter(txnSvc))

	return debtSvc, acctSvc, acctClient, uuid.New()
}

// seedLiabilityAccounts creates the liability account a borrowed-in debt hangs
// on plus the system equity carryover account, mirroring a synced F36 client
// tenant. Returns both account IDs. The equity account is inserted through the
// ent client directly (raw row, like the sync path): no user-facing category
// maps to the equity type — NewAccountWithCategory derives asset/liability only
// — so a CreateAccount-shaped request cannot express it.
func seedLiabilityAccounts(t *testing.T, acctSvc *accountapp.Service, acctClient *accountent.Client, ctx context.Context, tenantID uuid.UUID) (liabilityID, equityID uuid.UUID) {
	t.Helper()
	liab, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Liability",
		AccountType:  accountdomain.AccountTypeLiability,
		Category:     accountdomain.AccountCategoryOtherLiability,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create liability account: %v", err)
	}
	equityID = uuid.New()
	if err := acctClient.Account.Create().
		SetID(equityID).
		SetTenantID(tenantID).
		SetName(equityCarryoverName).
		SetAccountType(accountenum.AccountTypeEquity).
		SetCategory(accountenum.CategoryOtherAsset).
		SetCurrencyCode("CNY").
		Exec(ctx); err != nil {
		t.Fatalf("create equity carryover account: %v", err)
	}
	return liab.ID, equityID
}

// assertAccountBalance reads the persisted balance of one account through the
// real account service (black-box) and compares it with want.
func assertAccountBalance(t *testing.T, acctSvc *accountapp.Service, ctx context.Context, tenantID, accountID uuid.UUID, want int64, label string) {
	t.Helper()
	acc, err := acctSvc.GetAccount(ctx, tenantID, accountID)
	if err != nil {
		t.Fatalf("%s: get account: %v", label, err)
	}
	if acc.CurrentBalanceCents != want {
		t.Errorf("%s: balance got %d, want %d", label, acc.CurrentBalanceCents, want)
	}
}

// assertLiabilityInvariant is the F36 north-star helper: after any operation
// sequence, the liability account balance must equal Σremaining where
// remaining = totalPrincipalCents − Σ entry.paidCents (the client's convention,
// paid
// totals include interest per ADR-2). SIGN CONVENTION: the stored balance is
// liability-credit-positive (BalanceCalculator.ApplyEntryDelta = credit −
// debit, mirrored by the client's BalanceLocalUpdater), so the invariant is
// asserted as +Σremaining — the brief's "−Σremaining" is the same invariant
// in asset-position sign. The client's committed T1 test pins the identical
// convention (debt_local_ds_test.dart asserts balance == Σ remaining).
// remainings holds each debt on the account's current remaining cents.
func assertLiabilityInvariant(t *testing.T, acctSvc *accountapp.Service, ctx context.Context, tenantID, liabilityID uuid.UUID, remainings ...int64) {
	t.Helper()
	var sum int64
	for _, r := range remainings {
		sum += r
	}
	assertAccountBalance(t, acctSvc, ctx, tenantID, liabilityID, sum, "invariant")
}

// debtRemainingCents computes a debt's remaining = total − Σ paidCents from a
// freshly loaded detail (the invariant convention, NOT domain.RemainingPrincipal which
// sums paid principals without interest).
func debtRemainingCents(detail *application.DebtDetailDTO) int64 {
	var paid int64
	for _, e := range detail.Schedule {
		paid += e.PaidCents
	}
	return detail.Debt.TotalPrincipalCents - paid
}

// TestDebtPostingInvariant_CreateWithoutSource: sequence ① — a borrowed-in
// debt created with NO source account must post debit equity +P / credit
// liability +P, so the liability balance equals −P right after creation.
func TestDebtPostingInvariant_CreateWithoutSource(t *testing.T) {
	svc, acctSvc, acctClient, tenantID := setupDebtPostingHarness(t)
	ctx := context.Background()
	liabID, equityID := seedLiabilityAccounts(t, acctSvc, acctClient, ctx, tenantID)

	const principal int64 = 500000
	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           liabID,
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: principal,
		DebtType:            domain.BorrowedIn,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	if resp.ID == uuid.Nil {
		t.Fatal("CreateDebt returned empty debt")
	}

	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liabID, principal)
	assertAccountBalance(t, acctSvc, ctx, tenantID, equityID, -principal, "equity carryover after no-source create")
}

// TestDebtPostingInvariant_CreateWithSourcePayAndUpdate: sequence ② — create
// with a source account (debit source +P / credit liability +P), record a
// repayment (debit liability −T / credit source −T), then raise the total
// principal (credit liability +Δ / debit equity −Δ). After every step the
// liability balance must equal −Σremaining.
func TestDebtPostingInvariant_CreateWithSourcePayAndUpdate(t *testing.T) {
	svc, acctSvc, acctClient, tenantID := setupDebtPostingHarness(t)
	ctx := context.Background()
	liabID, equityID := seedLiabilityAccounts(t, acctSvc, acctClient, ctx, tenantID)

	const initialSource int64 = 1000000
	source, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:            tenantID,
		Name:                "Cash",
		AccountType:         accountdomain.AccountTypeAsset,
		Category:            accountdomain.AccountCategorySavings,
		CurrencyCode:        "CNY",
		InitialBalanceCents: initialSource,
	})
	if err != nil {
		t.Fatalf("create source account: %v", err)
	}

	const principal int64 = 500000
	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           liabID,
		Counterparty:        "CMB",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationEqualPrincipal,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: principal,
		DebtType:            domain.BorrowedIn,
		SourceAccountID:     &source.ID,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}

	// After create: liability −P, source +P.
	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liabID, principal)
	assertAccountBalance(t, acctSvc, ctx, tenantID, source.ID, initialSource+principal, "source after create")

	// Repay the first installment WITH its cash side (mirrors the gRPC handler's
	// buildRepaymentCashRecord: debit liability −T / credit source −T).
	detail, err := svc.GetDebt(ctx, tenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt: %v", err)
	}
	entry := detail.Schedule[0]
	if _, err := svc.RecordPayment(ctx, application.RecordPaymentRequest{
		TenantID:        tenantID,
		DebtID:          resp.ID,
		ScheduleEntryID: entry.ID,
		FromAccountID:   source.ID,
		CashRecord: &domain.RepaymentCashRecordRequest{
			TenantID:        tenantID,
			TransactionDate: time.Now(),
			Description:     "RecordPayment double-write",
			Entries: []domain.RepaymentCashEntry{
				{AccountID: liabID, DebitCents: entry.TotalCents},
				{AccountID: source.ID, CreditCents: entry.TotalCents},
			},
		},
	}); err != nil {
		t.Fatalf("RecordPayment: %v", err)
	}

	// Re-read the paid total (interest included) and assert the invariant.
	// RecordPayment bumps the optimistic-lock version (MarkPaid), so the
	// follow-up update must carry the re-read version.
	detail, err = svc.GetDebt(ctx, tenantID, resp.ID)
	if err != nil {
		t.Fatalf("GetDebt after payment: %v", err)
	}
	remainingAfterPay := debtRemainingCents(detail)
	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liabID, remainingAfterPay)

	// Raise the total principal: credit liability +Δ / debit equity −Δ.
	const delta int64 = 200000
	newTotal := principal + delta
	if _, err := svc.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:            tenantID,
		ID:                  resp.ID,
		Counterparty:        "CMB",
		InterestRate:        0.05,
		Version:             detail.Debt.Version,
		TotalPrincipalCents: &newTotal,
	}); err != nil {
		t.Fatalf("UpdateDebt with new total: %v", err)
	}

	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liabID, remainingAfterPay+delta)
	assertAccountBalance(t, acctSvc, ctx, tenantID, equityID, -delta, "equity carryover after total raise")
}

// TestDebtPostingInvariant_CreateAndDelete: sequence ③ — delete a borrowed-in
// debt with remaining > 0 posts the settlement pair (debit liability −remaining
// / credit equity), leaving the liability balance at 0 while other debts on
// other accounts are unaffected.
func TestDebtPostingInvariant_CreateAndDelete(t *testing.T) {
	svc, acctSvc, acctClient, tenantID := setupDebtPostingHarness(t)
	ctx := context.Background()
	liabID, equityID := seedLiabilityAccounts(t, acctSvc, acctClient, ctx, tenantID)

	const principal int64 = 400000
	resp, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           liabID,
		Counterparty:        "ICBC",
		InterestRate:        0.05,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: principal,
		DebtType:            domain.BorrowedIn,
	})
	if err != nil {
		t.Fatalf("CreateDebt: %v", err)
	}
	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liabID, principal)

	// An unrelated debt on a second liability account must stay untouched.
	liab2, err := acctSvc.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:     tenantID,
		Name:         "Liability 2",
		AccountType:  accountdomain.AccountTypeLiability,
		Category:     accountdomain.AccountCategoryOtherLiability,
		CurrencyCode: "CNY",
	})
	if err != nil {
		t.Fatalf("create second liability account: %v", err)
	}
	const principal2 int64 = 100000
	if _, err := svc.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           liab2.ID,
		Counterparty:        "Friend",
		InterestRate:        0,
		AmortizationMethod:  domain.AmortizationLumpSum,
		StartDate:           time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		DueDate:             time.Date(2026, 7, 1, 0, 0, 0, 0, time.UTC),
		TotalPrincipalCents: principal2,
		DebtType:            domain.BorrowedIn,
	}); err != nil {
		t.Fatalf("CreateDebt second: %v", err)
	}
	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liab2.ID, principal2)

	// Delete the first debt (remaining = full principal > 0 → settlement pair).
	if err := svc.DeleteDebt(ctx, tenantID, resp.ID); err != nil {
		t.Fatalf("DeleteDebt: %v", err)
	}

	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liabID, 0)
	// Equity: −principal (create) − principal2 (create) + principal (settlement)
	// = −principal2.
	assertAccountBalance(t, acctSvc, ctx, tenantID, equityID, -principal2, "equity carryover after delete settlement")
	assertLiabilityInvariant(t, acctSvc, ctx, tenantID, liab2.ID, principal2)
}
