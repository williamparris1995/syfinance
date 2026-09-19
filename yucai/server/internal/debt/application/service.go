package application

import (
	"context"
	"database/sql"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/debt/domain"
	"github.com/yucai/server/internal/shared/domain/recurrence"
	"github.com/yucai/server/internal/sqltx"
)

// AccountLookup is the account-reading port used by the debt service to resolve
// a debt's currency (DebtDetails has no CurrencyCode field — currency lives on
// the parent account) and, since F36, the tenant's equity carryover account for
// liability postings. Only the read methods needed by the debt service are
// exposed; the concrete account domain.AccountRepository satisfies this
// unchanged. Defined locally (mirrors transaction/application.AccountLookup) so
// debt application does not import transaction.
type AccountLookup interface {
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*accountdomain.Account, error)
	// FindByAccountType returns all non-deleted accounts of one type. F36 uses
	// it to list the tenant's equity accounts when resolving the carryover
	// account ("historical repayment carryover") as the counterpart of every
	// liability opening/adjustment/settlement posting. Minimal port extension
	// per ADR-4/5/7: the method already exists on the concrete repo, so wire
	// keeps passing the same accountRepo with no provider change.
	FindByAccountType(ctx context.Context, tenantID uuid.UUID, accountType accountdomain.AccountType) ([]accountdomain.Account, error)
}

// Service orchestrates debt operations.
type Service struct {
	repo          domain.DebtRepository
	accountLookup AccountLookup                 // optional: resolves per-debt currency; nil = default CNY
	snapshotRepo  domain.DebtSnapshotRepository // optional: progress snapshots; nil = SyncAllDebts is a noop
	cashRecorder  domain.RepaymentCashRecorder  // D3: cash-side repayment double-write port (nil = skip)
	db            *sql.DB                       // D3: shared *sql.DB backing the debt ent client
	now           func() time.Time              // injectable clock; defaults to time.Now
}

// NewService creates a new debt application service.
func NewService(repo domain.DebtRepository) *Service {
	return &Service{repo: repo, now: time.Now}
}

// SetAccountLookup injects the account lookup used by SumRemainingByCurrency to
// resolve each debt's currency from its parent account. Called by wire after
// construction (NewService signature stays unchanged so existing tests and
// callers are not broken). nil = every debt bucketed under CNY.
func (s *Service) SetAccountLookup(l AccountLookup) { s.accountLookup = l }

// SetSnapshotRepo injects the snapshot repository used by GetReceivablesSummary
// (trend computation) and SyncAllDebts (snapshot writes). Called by wire after
// construction so NewService's signature stays unchanged. nil = SyncAllDebts is
// a noop and trend fields are 0. Mirrors goal SetAccountMarketValueSource.
func (s *Service) SetSnapshotRepo(r domain.DebtSnapshotRepository) { s.snapshotRepo = r }

// SetCashRecorder injects the cross-module recorder used to write the cash side
// of a debt repayment (debit/credit the from/cash account + the debt account)
// as a double-entry transaction inside the same WithTx as the schedule.Paid +
// principal persist. Wire binds the transaction application service's adapter;
// nil = the cash side is skipped (test / seed-data path). Mirrors Task 5's
// holding.Service.SetCashRecorder.
func (s *Service) SetCashRecorder(r domain.RepaymentCashRecorder) { s.cashRecorder = r }

// SetDB injects the shared *sql.DB backing the debt ent client. RecordPayment
// wraps its schedule.Paid + principal persist (+ optional cash record) writes
// in a single sqltx.WithTx over db so a partial failure rolls back the whole
// operation (Task 6 / audit D3). Nil preserves the legacy non-transactional
// behavior that mock-based unit tests rely on; production wire always injects
// the shared db (Task 1's provideDB). Mirrors Task 5's holding.Service.SetDB.
func (s *Service) SetDB(db *sql.DB) { s.db = db }

// SetNow injects a clock for deterministic testing. Production callers leave
// the default (time.Now).
func (s *Service) SetNow(f func() time.Time) {
	if f == nil {
		f = time.Now
	}
	s.now = f
}

// CreateDebt validates, generates schedule, and persists a new debt.
// Receivables (DebtType=BorrowedOut) must carry a CollectionAccountID: every
// repayment a receivable absorbs must land in a concrete asset account, so a
// missing collection account is rejected here (not in the domain constructor,
// which stays valid for both debt shapes). Borrowed-in debts ignore the field.
func (s *Service) CreateDebt(ctx context.Context, req CreateDebtRequest) (*DebtDTO, error) {
	if req.DebtType == domain.BorrowedOut && req.CollectionAccountID == nil {
		return nil, fmt.Errorf("create debt: receivable requires collection account")
	}

	// Normalize the rule (zero cycle = legacy monthly) and validate ranges.
	rule := req.Rule()
	if rule.Cycle == 0 {
		rule.Cycle = recurrence.CycleMonthly
	}
	if err := rule.Validate(); err != nil {
		return nil, fmt.Errorf("create debt: %w", err)
	}

	// By-periods mode: derive due from the last occurrence so the stored
	// due_date stays consistent with the generated schedule.
	due := req.DueDate
	if req.TermPeriods > 0 {
		dates := domain.ScheduleDatesFrom(rule, req.StartDate, req.DueDate, req.TermPeriods)
		due = dates[len(dates)-1]
	}

	debt, err := domain.NewDebtDetails(
		req.TenantID, req.AccountID,
		req.Counterparty,
		req.InterestRate,
		req.AmortizationMethod,
		req.StartDate, due,
		req.TotalPrincipalCents,
		req.DebtType,
		req.Subtype,
		req.Contact,
		req.ContractRef,
		req.CollectionAccountID,
		req.GuarantorName,
		req.GuarantorContact,
	)
	if err != nil {
		return nil, fmt.Errorf("create debt: %w", err)
	}
	debt.Cycle = rule.Cycle
	debt.Interval = rule.Interval
	debt.WeekdayMask = rule.WeekdayMask
	debt.MonthlyMode = rule.MonthlyMode
	debt.Nth = rule.Nth
	debt.InterestWaivedCents = req.InterestWaivedCents

	debt.GenerateSchedule()

	if req.InterestWaivedCents > domain.TotalInterest(debt.Schedule) {
		return nil, fmt.Errorf("create debt: interest waiver must not exceed total interest")
	}

	// F36 liability posting (BorrowedIn only; the BorrowedOut creation
	// double-write stays handler-side best-effort, untouched): the debt persist
	// and its ledger move share one sqltx.WithTx — same pipeline as the
	// repayment path (runWriteTx + the cashRecorder port; the transaction
	// service's join-existing-tx semantics enlists the posting in this tx).
	// With a source account → debit source +P / credit liability +P (a lookup
	// failure fails the create: the caller explicitly named the account);
	// without → debit equity carryover +P / credit liability +P (ADR-4).
	posting, err := s.buildCreatePosting(ctx, debt, req.SourceAccountID)
	if err != nil {
		return nil, err
	}
	if err := s.runWriteTx(ctx, func(ctxT context.Context) error {
		if err := s.repo.Save(ctxT, debt); err != nil {
			return fmt.Errorf("save debt: %w", err)
		}
		if posting != nil {
			if _, err := s.cashRecorder.Record(ctxT, *posting); err != nil {
				return fmt.Errorf("record debt creation posting: %w", err)
			}
		}
		return nil
	}); err != nil {
		return nil, err
	}

	dto := DebtToDTO(debt)
	return &dto, nil
}

// equityCarryoverAccountName is the well-known name of the system equity
// account used as the counterpart of every liability opening/adjustment/
// settlement posting. It matches the client's _ensureSettlementAccount
// constant; the value itself is the product-defined account NAME (Chinese) and
// syncs up from clients as data — comments and log strings stay English.
const equityCarryoverAccountName = "历史还款结转"

// ledgerRecord wraps a balanced leg pair in the debt-owned
// RepaymentCashRecordRequest — the generic double-entry carrier of the
// cross-module cashRecorder port (the transaction application's adapter maps
// each leg to its EntryInput and enlists in the caller's sqltx.WithTx).
func (s *Service) ledgerRecord(tenantID uuid.UUID, description string, legs []domain.RepaymentCashEntry) *domain.RepaymentCashRecordRequest {
	return &domain.RepaymentCashRecordRequest{
		TenantID:        tenantID,
		TransactionDate: s.now(),
		Description:     description,
		Entries:         legs,
	}
}

// resolveEquityCarryover finds the tenant's equity carryover account (ADR-4/5/7
// counterpart account). Resolution convention: equity-type accounts via the
// AccountLookup port, filtered by the client's well-known name. Returns
// (nil, nil) when the tenant has no such account yet — callers degrade to a
// warning + skipped posting: a bound-remote tenant may not have synced the
// carryover account yet, and hard-failing would break debt operations for
// exactly those tenants. The F36 client-side repair (T3) converges the balance
// later by syncing its adjustment entries up as normal transactions.
func (s *Service) resolveEquityCarryover(ctx context.Context, tenantID uuid.UUID) (*accountdomain.Account, error) {
	if s.accountLookup == nil {
		return nil, nil
	}
	accounts, err := s.accountLookup.FindByAccountType(ctx, tenantID, accountdomain.AccountTypeEquity)
	if err != nil {
		return nil, fmt.Errorf("resolve equity carryover: %w", err)
	}
	for i := range accounts {
		if accounts[i].Name == equityCarryoverAccountName {
			return &accounts[i], nil
		}
	}
	return nil, nil
}

// buildCreatePosting assembles the F36 creation posting for a BorrowedIn debt:
//
//	with source account:      debit source +P / credit liability +P
//	without (ADR-4):          debit equity carryover +P / credit liability +P
//
// The with-source path validates the explicit input like the handler's
// borrowedOut create validation (exists, asset, not the debt account, same
// currency — no balance-cover check: the principal ARRIVES on the source).
// Returns nil when no posting applies: BorrowedOut debts, no recorder wired
// (test/seed path), or — on the no-source path — the counterpart accounts
// being unresolvable (warn + skip; see resolveEquityCarryover).
func (s *Service) buildCreatePosting(ctx context.Context, debt *domain.DebtDetails, sourceAccountID *uuid.UUID) (*domain.RepaymentCashRecordRequest, error) {
	if debt.DebtType != domain.BorrowedIn || s.cashRecorder == nil || s.accountLookup == nil {
		return nil, nil
	}

	if sourceAccountID != nil {
		sourceAcc, err := s.accountLookup.FindByID(ctx, debt.TenantID, *sourceAccountID)
		if err != nil {
			return nil, fmt.Errorf("create debt: source account lookup: %w", err)
		}
		if sourceAcc == nil {
			return nil, fmt.Errorf("create debt: source account not found")
		}
		if sourceAcc.AccountType != accountdomain.AccountTypeAsset {
			return nil, fmt.Errorf("create debt: source_account must be asset")
		}
		if *sourceAccountID == debt.AccountID {
			return nil, fmt.Errorf("create debt: source_account must differ from the debt account")
		}
		debtAcc, err := s.accountLookup.FindByID(ctx, debt.TenantID, debt.AccountID)
		if err != nil {
			return nil, fmt.Errorf("create debt: debt account lookup: %w", err)
		}
		if debtAcc == nil {
			return nil, fmt.Errorf("create debt: debt account not found")
		}
		if sourceAcc.CurrencyCode != debtAcc.CurrencyCode {
			return nil, fmt.Errorf("create debt: cross-currency, manual handling required")
		}
		return s.ledgerRecord(debt.TenantID, "CreateDebt liability posting", []domain.RepaymentCashEntry{
			{AccountID: sourceAcc.ID, ChartOfAccountCode: sourceAcc.ChartCode, DebitCents: debt.TotalPrincipalCents},
			{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, CreditCents: debt.TotalPrincipalCents},
		}), nil
	}

	// No source: the equity-side pair. Best-effort counterpart resolution —
	// an unresolvable account degrades to warn + skip (documented drift the
	// F36 repair converges), never a failed create.
	equityAcc, err := s.resolveEquityCarryover(ctx, debt.TenantID)
	if err != nil {
		slog.Warn("debt create posting: equity carryover lookup failed, skip",
			slog.String("tenant_id", debt.TenantID.String()),
			slog.String("error", err.Error()),
			slog.String("operation", "buildCreatePosting"))
		return nil, nil
	}
	debtAcc, err := s.accountLookup.FindByID(ctx, debt.TenantID, debt.AccountID)
	if err != nil || debtAcc == nil {
		slog.Warn("debt create posting: liability account lookup failed, skip",
			slog.String("tenant_id", debt.TenantID.String()),
			slog.String("account_id", debt.AccountID.String()),
			slog.String("operation", "buildCreatePosting"))
		return nil, nil
	}
	if equityAcc == nil {
		slog.Warn("debt create posting: equity carryover account not found, skip",
			slog.String("tenant_id", debt.TenantID.String()),
			slog.String("operation", "buildCreatePosting"))
		return nil, nil
	}
	return s.ledgerRecord(debt.TenantID, "CreateDebt equity posting", []domain.RepaymentCashEntry{
		{AccountID: equityAcc.ID, ChartOfAccountCode: equityAcc.ChartCode, DebitCents: debt.TotalPrincipalCents},
		{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, CreditCents: debt.TotalPrincipalCents},
	}), nil
}

// UpdateDebt updates a debt's mutable fields. Schedule-affecting fields
// (amortization method, interest rate, recurrence rule, term) follow the
// Google-Calendar semantics confirmed by the user: already-recorded entries
// (paid / partially paid / tied to a transaction) are frozen and untouched;
// the future schedule regenerates from the remaining principal under the new
// parameters. Zero values on the schedule-affecting fields keep the current
// value so legacy callers (header-only updates) behave exactly as before.
func (s *Service) UpdateDebt(ctx context.Context, req UpdateDebtRequest) (*DebtDTO, error) {
	debt, err := s.repo.FindByID(ctx, req.TenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("debt not found: %w", err)
	}

	if debt.Version != req.Version {
		return nil, fmt.Errorf("optimistic lock conflict: expected version %d, got %d", req.Version, debt.Version)
	}

	// Resolve schedule-affecting parameters (zero/nil = keep current).
	method := debt.AmortizationMethod
	if req.AmortizationMethod != 0 {
		method = req.AmortizationMethod
	}
	rate := req.InterestRate
	rule := debt.Rule()
	ruleChanged := false
	if req.Cycle != 0 {
		newRule := recurrence.Rule{
			Cycle:       req.Cycle,
			Interval:    req.Interval,
			WeekdayMask: req.WeekdayMask,
			MonthlyMode: req.MonthlyMode,
			Nth:         req.Nth,
		}
		if err := newRule.Validate(); err != nil {
			return nil, fmt.Errorf("update debt: %w", err)
		}
		ruleChanged = newRule != rule
		rule = newRule
	}
	due := debt.DueDate
	dueChanged := false
	if req.DueDate != nil && !req.DueDate.Equal(debt.DueDate) {
		due = *req.DueDate
		dueChanged = true
	}
	// Waiver: presence-aware (nil = keep); schedule-affecting because the
	// regenerated schedule must re-apply the (possibly new) waiver.
	waiver := debt.InterestWaivedCents
	waiverChanged := false
	if req.InterestWaivedCents != nil {
		waiverChanged = *req.InterestWaivedCents != debt.InterestWaivedCents
		waiver = *req.InterestWaivedCents
	}

	scheduleChanged := method != debt.AmortizationMethod || rate != debt.InterestRate ||
		ruleChanged || dueChanged || req.TermPeriods > 0 || waiverChanged

	debt.Counterparty = req.Counterparty
	debt.Contact = req.Contact
	debt.ContractRef = req.ContractRef
	debt.CollectionAccountID = req.CollectionAccountID
	debt.GuarantorName = req.GuarantorName
	debt.GuarantorContact = req.GuarantorContact
	// Subtype: empty keeps the current value (legacy clients never send the
	// field, so empty must not wipe it); non-empty replaces verbatim. Unlike
	// Contact/ContractRef, empty does NOT clear.
	if req.Subtype != "" {
		debt.Subtype = req.Subtype
	}
	debt.InterestRate = rate
	debt.AmortizationMethod = method
	debt.Cycle = rule.Cycle
	debt.Interval = rule.Interval
	debt.WeekdayMask = rule.WeekdayMask
	debt.MonthlyMode = rule.MonthlyMode
	debt.Nth = rule.Nth
	debt.InterestWaivedCents = waiver
	if dueChanged {
		debt.DueDate = due
	}

	// F36 balance adjustment input: nil = keep the current total (legacy
	// callers unchanged). Applied BEFORE the schedule regeneration so the
	// regenerated future schedule is built from the new total (mirrors the
	// client's edit-total flow); the regeneration logic itself is unchanged.
	oldTotal := debt.TotalPrincipalCents
	if req.TotalPrincipalCents != nil {
		if *req.TotalPrincipalCents <= 0 {
			return nil, fmt.Errorf("update debt: total principal must be positive")
		}
		debt.TotalPrincipalCents = *req.TotalPrincipalCents
	}
	totalDelta := debt.TotalPrincipalCents - oldTotal

	var future []domain.PaymentScheduleEntry
	if scheduleChanged {
		future, err = s.regenerateFuture(debt, rule, req.TermPeriods)
		if err != nil {
			return nil, err
		}
	}

	// F36 adjustment posting (BorrowedIn, Δ ≠ 0): credit liability ±Δ with the
	// equity account as counterpart (ADR-5). nil = nothing to post.
	adjustment := s.buildPrincipalAdjustment(ctx, debt, totalDelta)

	debt.IncrementVersion()

	if scheduleChanged || adjustment != nil {
		// debt.Schedule holds only the frozen entries here so repo.Update's
		// per-entry loop touches existing rows only; the future rows are
		// inserted by ReplaceFutureSchedule in the same tx.
		if err := s.runWriteTx(ctx, func(ctxT context.Context) error {
			if scheduleChanged {
				if err := s.repo.ReplaceFutureSchedule(ctxT, debt.ID, future); err != nil {
					return fmt.Errorf("replace future schedule: %w", err)
				}
			}
			if err := s.repo.Update(ctxT, debt); err != nil {
				return fmt.Errorf("update debt: %w", err)
			}
			if adjustment != nil {
				if _, err := s.cashRecorder.Record(ctxT, *adjustment); err != nil {
					return fmt.Errorf("record debt principal adjustment: %w", err)
				}
			}
			return nil
		}); err != nil {
			return nil, err
		}
		if scheduleChanged {
			debt.Schedule = append(debt.Schedule, future...)
		}
	} else {
		if err := s.repo.Update(ctx, debt); err != nil {
			return nil, fmt.Errorf("update debt: %w", err)
		}
	}

	dto := DebtToDTO(debt)
	return &dto, nil
}

// buildPrincipalAdjustment assembles the F36 same-tx adjustment posting for a
// BorrowedIn debt whose total principal changed by Δ ≠ 0 (ADR-5):
//
//	Δ > 0: credit liability Δ  / debit equity carryover Δ
//	Δ < 0: debit liability |Δ| / credit equity carryover |Δ|
//
// Returns nil when no posting applies: not BorrowedIn (BorrowedOut updates
// keep their current no-posting behavior), Δ == 0, no recorder wired, or the
// counterpart accounts being unresolvable (warn + skip; see
// resolveEquityCarryover — the F36 repair converges the drift later).
func (s *Service) buildPrincipalAdjustment(ctx context.Context, debt *domain.DebtDetails, delta int64) *domain.RepaymentCashRecordRequest {
	if debt.DebtType != domain.BorrowedIn || delta == 0 || s.cashRecorder == nil || s.accountLookup == nil {
		return nil
	}
	debtAcc, err := s.accountLookup.FindByID(ctx, debt.TenantID, debt.AccountID)
	if err != nil || debtAcc == nil {
		slog.Warn("debt adjustment posting: liability account lookup failed, skip",
			slog.String("tenant_id", debt.TenantID.String()),
			slog.String("account_id", debt.AccountID.String()),
			slog.String("operation", "buildPrincipalAdjustment"))
		return nil
	}
	equityAcc, err := s.resolveEquityCarryover(ctx, debt.TenantID)
	if err != nil || equityAcc == nil {
		slog.Warn("debt adjustment posting: equity carryover unresolvable, skip",
			slog.String("tenant_id", debt.TenantID.String()),
			slog.String("operation", "buildPrincipalAdjustment"))
		return nil
	}
	amount := delta
	if amount < 0 {
		amount = -amount
	}
	if delta > 0 {
		// Total grew: the liability increases (credit) against equity.
		return s.ledgerRecord(debt.TenantID, "UpdateDebt principal adjustment", []domain.RepaymentCashEntry{
			{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, CreditCents: amount},
			{AccountID: equityAcc.ID, ChartOfAccountCode: equityAcc.ChartCode, DebitCents: amount},
		})
	}
	// Total shrank: the liability decreases (debit) back into equity.
	return s.ledgerRecord(debt.TenantID, "UpdateDebt principal adjustment", []domain.RepaymentCashEntry{
		{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, DebitCents: amount},
		{AccountID: equityAcc.ID, ChartOfAccountCode: equityAcc.ChartCode, CreditCents: amount},
	})
}

// regenerateFuture rebuilds the post-frozen schedule on the debt aggregate:
// frozen (already-recorded) entries keep their dates and amounts (left in
// debt.Schedule); the returned future entries are built from the remaining
// principal, anchored after the last frozen date (or the start date when
// nothing is frozen). DueDate is updated to the last future date so the
// header stays consistent with the schedule.
func (s *Service) regenerateFuture(debt *domain.DebtDetails, rule recurrence.Rule, termPeriods int32) ([]domain.PaymentScheduleEntry, error) {
	frozen := debt.FrozenEntries()

	anchor := debt.StartDate
	if len(frozen) > 0 {
		anchor = frozen[len(frozen)-1].PaymentDate
	}

	var paidPrincipal int64
	for _, e := range frozen {
		paidPrincipal += e.PrincipalCents
	}
	remaining := debt.TotalPrincipalCents - paidPrincipal
	if remaining < 0 {
		remaining = 0
	}

	dates := domain.ScheduleDatesFrom(rule, anchor, debt.DueDate, termPeriods)
	if len(dates) == 0 {
		return nil, fmt.Errorf("regenerate future schedule: no future dates resolved")
	}

	calc := domain.AmortizationCalculator{}
	future := calc.RegenerateFutureSchedule(debt, anchor, dates, remaining)
	domain.ApplyInterestWaiver(future, debt.InterestWaivedCents)
	if debt.InterestWaivedCents > domain.TotalInterest(future) {
		return nil, fmt.Errorf("update debt: interest waiver must not exceed total interest")
	}
	for i := range future {
		future[i].DebtID = debt.ID
	}
	debt.DueDate = dates[len(dates)-1]
	debt.Schedule = frozen
	return future, nil
}

// runWriteTx wraps fn in a single sqltx.WithTx (nil db = run directly, same
// semantics as runInTx). Used by the schedule-regenerating update path so the
// unpaid-entries delete + future insert + header update commit atomically.
func (s *Service) runWriteTx(ctx context.Context, fn func(ctx context.Context) error) error {
	if s.db == nil {
		return fn(ctx)
	}
	return sqltx.WithTx(ctx, s.db, "postgres", nil, func(ctxT context.Context) error {
		return fn(ctxT)
	})
}

// DeleteDebt deletes a debt by ID. F36 settlement (ADR-1, BorrowedIn with
// remaining > 0): the deletion and its clearing posting share one sqltx.WithTx
// — debit liability −remaining / credit equity carryover. remaining =
// totalPrincipalCents − Σ entry.paidCents (the client's convention; paid totals
// include interest per ADR-2). A fully-paid debt (remaining == 0) deletes
// without a posting — the liability side is already zero. BorrowedOut
// deletions keep their current no-posting behavior (out of F36 T2 scope).
func (s *Service) DeleteDebt(ctx context.Context, tenantID, id uuid.UUID) error {
	debt, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return fmt.Errorf("delete debt: %w", err)
	}
	settlement := s.buildDeleteSettlement(ctx, debt)
	if err := s.runWriteTx(ctx, func(ctxT context.Context) error {
		if err := s.repo.Delete(ctxT, tenantID, id); err != nil {
			return fmt.Errorf("delete debt: %w", err)
		}
		if settlement != nil {
			if _, err := s.cashRecorder.Record(ctxT, *settlement); err != nil {
				return fmt.Errorf("record debt delete settlement: %w", err)
			}
		}
		return nil
	}); err != nil {
		return err
	}
	return nil
}

// buildDeleteSettlement assembles the F36 clearing posting for a BorrowedIn
// debt deleted with remaining > 0: debit liability −remaining / credit equity
// carryover (terminal settlement — historical cash-flow entries stay put,
// ADR-1). Returns nil when no posting applies: not BorrowedIn, remaining == 0,
// no recorder wired, or the counterpart accounts being unresolvable (warn +
// skip; see resolveEquityCarryover).
func (s *Service) buildDeleteSettlement(ctx context.Context, debt *domain.DebtDetails) *domain.RepaymentCashRecordRequest {
	if debt.DebtType != domain.BorrowedIn || s.cashRecorder == nil || s.accountLookup == nil {
		return nil
	}
	var paidCents int64
	for _, e := range debt.Schedule {
		if e.Paid {
			paidCents += e.PaidCents
		}
	}
	remaining := debt.TotalPrincipalCents - paidCents
	if remaining <= 0 {
		return nil
	}
	debtAcc, err := s.accountLookup.FindByID(ctx, debt.TenantID, debt.AccountID)
	if err != nil || debtAcc == nil {
		slog.Warn("debt delete settlement: liability account lookup failed, skip",
			slog.String("tenant_id", debt.TenantID.String()),
			slog.String("account_id", debt.AccountID.String()),
			slog.String("operation", "buildDeleteSettlement"))
		return nil
	}
	equityAcc, err := s.resolveEquityCarryover(ctx, debt.TenantID)
	if err != nil || equityAcc == nil {
		slog.Warn("debt delete settlement: equity carryover unresolvable, skip",
			slog.String("tenant_id", debt.TenantID.String()),
			slog.String("operation", "buildDeleteSettlement"))
		return nil
	}
	return s.ledgerRecord(debt.TenantID, "DeleteDebt settlement", []domain.RepaymentCashEntry{
		{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, DebitCents: remaining},
		{AccountID: equityAcc.ID, ChartOfAccountCode: equityAcc.ChartCode, CreditCents: remaining},
	})
}

// MarkEntryPaidRequest is the input for MarkEntryPaid.
type MarkEntryPaidRequest struct {
	TenantID uuid.UUID
	DebtID   uuid.UUID
	EntryID  uuid.UUID
}

// MarkEntryPaid marks ONE unpaid schedule entry as already repaid WITHOUT
// booking a cash transaction — for installments settled before the debt was
// entered into the app. The entry becomes frozen (paid/paidCents set,
// TransactionID stays null so it is distinguishable from a booked repayment).
func (s *Service) MarkEntryPaid(ctx context.Context, req MarkEntryPaidRequest) (*PaymentEntryDTO, error) {
	debt, err := s.repo.FindByID(ctx, req.TenantID, req.DebtID)
	if err != nil {
		return nil, fmt.Errorf("debt not found: %w", err)
	}
	idx := -1
	for i := range debt.Schedule {
		if debt.Schedule[i].ID == req.EntryID {
			idx = i
			break
		}
	}
	if idx < 0 {
		return nil, fmt.Errorf("schedule entry %s not found", req.EntryID)
	}
	entry := debt.Schedule[idx]
	if entry.Paid || entry.PaidCents > 0 || entry.TransactionID != nil {
		return nil, fmt.Errorf("schedule entry is already recorded and must stay frozen")
	}

	debt.Schedule[idx].Paid = true
	debt.Schedule[idx].PaidCents = debt.Schedule[idx].TotalCents
	debt.IncrementVersion()
	if err := s.repo.Update(ctx, debt); err != nil {
		return nil, fmt.Errorf("update debt: %w", err)
	}

	dto := entryToDTO(debt.Schedule[idx])
	return &dto, nil
}

// SetPaymentDateRequest is the input for SetPaymentDate.
type SetPaymentDateRequest struct {
	TenantID    uuid.UUID
	DebtID      uuid.UUID
	EntryID     uuid.UUID
	PaymentDate time.Time
}

// SetPaymentDate moves ONE unpaid schedule entry to a new date (Google-
// Calendar per-occurrence edit). Already-recorded entries (paid / partially
// paid / transaction-linked) are frozen and rejected; the target date must
// not collide with another entry of the same debt (the DB enforces a
// UNIQUE(debt_id, payment_date) index) and must stay after the start date.
// Amounts are untouched — moving a date is administrative, not a re-quote.
func (s *Service) SetPaymentDate(ctx context.Context, req SetPaymentDateRequest) (*PaymentEntryDTO, error) {
	debt, err := s.repo.FindByID(ctx, req.TenantID, req.DebtID)
	if err != nil {
		return nil, fmt.Errorf("debt not found: %w", err)
	}

	idx := -1
	for i := range debt.Schedule {
		if debt.Schedule[i].ID == req.EntryID {
			idx = i
			break
		}
	}
	if idx < 0 {
		return nil, fmt.Errorf("schedule entry %s not found", req.EntryID)
	}
	entry := debt.Schedule[idx]
	if entry.Paid || entry.PaidCents > 0 || entry.TransactionID != nil {
		return nil, fmt.Errorf("schedule entry is already recorded and must stay frozen")
	}
	newDate := time.Date(req.PaymentDate.Year(), req.PaymentDate.Month(), req.PaymentDate.Day(), 0, 0, 0, 0, req.PaymentDate.Location())
	if !newDate.After(debt.StartDate) {
		return nil, fmt.Errorf("payment date must be after the start date")
	}
	for i := range debt.Schedule {
		if i != idx && debt.Schedule[i].PaymentDate.Equal(newDate) {
			return nil, fmt.Errorf("payment date must not collide with another entry on %s", newDate.Format("2006-01-02"))
		}
	}

	debt.Schedule[idx].PaymentDate = newDate
	debt.IncrementVersion()
	if err := s.repo.Update(ctx, debt); err != nil {
		return nil, fmt.Errorf("update debt: %w", err)
	}

	dto := entryToDTO(debt.Schedule[idx])
	return &dto, nil
}

// GetDebt retrieves a debt with its full payment schedule.
func (s *Service) GetDebt(ctx context.Context, tenantID, id uuid.UUID) (*DebtDetailDTO, error) {
	debt, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("debt not found: %w", err)
	}
	dto := DebtToDetailDTO(debt)
	return &dto, nil
}

// ListDebts returns a paginated list of debts.
// When req.TypeFilter is non-nil, results are restricted to that debt type.
func (s *Service) ListDebts(ctx context.Context, req ListDebtsRequest) (*ListDebtsResult, error) {
	result, err := s.repo.FindAll(ctx, req.TenantID, req.Page, req.TypeFilter)
	if err != nil {
		return nil, fmt.Errorf("list debts: %w", err)
	}
	dtos := make([]DebtDTO, len(result.Items))
	for i, d := range result.Items {
		dtos[i] = DebtToDTO(&d)
	}
	return &ListDebtsResult{
		Debts:         dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}

// SumRemainingByCurrency sums the remaining principal of every borrowed-in debt
// for a tenant, grouped by currency. Implements networth/domain.DebtSource
// (structural — networth does not import debt). BorrowedOut receivables are
// excluded (they're tracked as asset account balances via debt double-write).
//
// Currency resolution: DebtDetails has no CurrencyCode field, so each debt's
// currency is read from its parent account via the injected AccountLookup. When
// accountLookup is nil (unwired) or the account lookup fails, the debt falls
// back to CNY (the app default) rather than being dropped — logged as a warning.
// Paginates at PageSize 100.
func (s *Service) SumRemainingByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error) {
	byCur := map[string]int64{}
	page := domain.PageRequest{PageSize: 100}
	in := domain.BorrowedIn // networth liab 只含 borrowed-in;BorrowedOut receivable 已在 asset account balance via double-write
	for {
		result, err := s.repo.FindAll(ctx, tenantID, page, &in)
		if err != nil {
			return nil, fmt.Errorf("sum remaining by currency: list debts: %w", err)
		}
		for _, d := range result.Items {
			if err := ctx.Err(); err != nil {
				return nil, err
			}
			code := s.debtCurrencyCode(ctx, tenantID, d.AccountID)
			byCur[code] += d.RemainingPrincipal()
		}
		if result.NextPageToken == "" || len(result.Items) == 0 {
			break
		}
		page.PageToken = result.NextPageToken
	}
	return byCur, nil
}

// GetDebtsPaid returns Σ paid amount (TotalPrincipalCents − RemainingPrincipal)
// of the given debts (DebtPayoff goal progress source). Implements
// goal/domain.DebtProgressSource (structural — goal does not import debt).
//
// Best-effort: a debt that is missing or fails to load is skipped + logged, not
// fatal — the remaining debts still contribute (mirrors holding
// GetAccountMarketValue's skip-missing-security pattern). Tenant scoping is
// enforced by the repo's FindByID. Empty debtIDs returns 0.
func (s *Service) GetDebtsPaid(ctx context.Context, tenantID uuid.UUID, debtIDs []uuid.UUID) (int64, error) {
	var sum int64
	for _, id := range debtIDs {
		if err := ctx.Err(); err != nil {
			return sum, err
		}
		d, err := s.repo.FindByID(ctx, tenantID, id)
		if err != nil || d == nil {
			slog.Warn("goal debt: missing, skip",
				slog.String("debt_id", id.String()),
				slog.String("operation", "GetDebtsPaid"))
			continue
		}
		sum += d.TotalPrincipalCents - d.RemainingPrincipal()
	}
	return sum, nil
}

// debtCurrencyCode resolves a debt's currency from its parent account. Falls
// back to CNY when accountLookup is nil or the lookup fails (best-effort,
// logged — a missing currency must not drop the debt's principal from the sum).
func (s *Service) debtCurrencyCode(ctx context.Context, tenantID, accountID uuid.UUID) string {
	if s.accountLookup == nil {
		return "CNY"
	}
	acc, err := s.accountLookup.FindByID(ctx, tenantID, accountID)
	if err != nil || acc == nil {
		slog.Warn("debt currency lookup failed, defaulting to CNY",
			slog.String("account_id", accountID.String()),
			slog.String("operation", "SumRemainingByCurrency"))
		return "CNY"
	}
	if acc.CurrencyCode == "" {
		return "CNY"
	}
	return acc.CurrencyCode
}

// RecordPayment marks a schedule entry as paid and returns the result. The
// entire operation — schedule.Paid + principal persist + (when req.CashRecord
// is non-nil) the cash-side double-entry transaction via cashRecorder — runs
// inside one sqltx.WithTx so a partial failure rolls back the whole repayment.
// See runInTx for the nil-skip / join-existing-tx semantics.
func (s *Service) RecordPayment(ctx context.Context, req RecordPaymentRequest) (*RecordPaymentResult, error) {
	return s.runInTx(ctx, func(ctx context.Context) (*RecordPaymentResult, error) {
		return s.repay(ctx, req)
	})
}

// repay is the transactional-body implementation of RecordPayment. Every repo
// call it makes must receive the ctx threaded down from runInTx (either the
// original ctx on the nil-skip path or the tx-bound ctxT) so the writes join
// the surrounding transaction.
func (s *Service) repay(ctx context.Context, req RecordPaymentRequest) (*RecordPaymentResult, error) {
	debt, err := s.repo.FindByID(ctx, req.TenantID, req.DebtID)
	if err != nil {
		return nil, fmt.Errorf("debt not found: %w", err)
	}

	txnID := uuid.New()
	if err := debt.MarkPaid(req.ScheduleEntryID, txnID); err != nil {
		return nil, fmt.Errorf("mark paid: %w", err)
	}

	if err := s.repo.Update(ctx, debt); err != nil {
		return nil, fmt.Errorf("update debt: %w", err)
	}

	// Cash side (D3 atomicity): record the cash + debt-account legs as a double-
	// entry transaction inside the same tx. Skipped when CashRecord is nil
	// (seed/perf/test path) or when no recorder is injected. recorder.Record
	// delegates to transaction.Service.RecordTransaction whose runInTx join-
	// existing-tx semantics (Task 4) enlist it in this outer WithTx — so a
	// cash-write failure rolls back the schedule.Paid/principal write, and a
	// debt-write failure (above) means this call never fires. Replaces the
	// pre-Task-6 best-effort swallow in the gRPC handler.
	if req.CashRecord != nil && s.cashRecorder != nil {
		if _, err := s.cashRecorder.Record(ctx, *req.CashRecord); err != nil {
			return nil, fmt.Errorf("record repayment cash: %w", err)
		}
	}

	// Find the updated entry
	var entry PaymentEntryDTO
	for _, e := range debt.Schedule {
		if e.ID == req.ScheduleEntryID {
			entry = entryToDTO(e)
			break
		}
	}

	return &RecordPaymentResult{
		TransactionID: txnID,
		Entry:         entry,
	}, nil
}

// runInTx wraps fn in a single sqltx.WithTx over the shared *sql.DB so the
// debt write (schedule.Paid + principal persist) and the optional cash-side
// transaction via cashRecorder all join one atomic DB transaction. A failure
// anywhere in fn (e.g. a cash-record error after schedule.Paid has succeeded)
// rolls back the whole operation.
//
// When s.db is nil the wrapper is skipped and fn runs directly against the
// repos' default (auto-commit) clients. This preserves the legacy
// non-transactional behavior that mock-based unit tests rely on (they inject
// mock repos without a *sql.DB); production wire always injects the shared db
// from Task 1's provideDB, so the rollback guarantee holds in deployment.
//
// Join-existing-tx semantics: when ctx already carries a tx driver (an outer
// WithTx — e.g. a future caller composing RecordPayment into a larger flow),
// sqltx.WithTx runs fn against that outer driver without opening a new
// transaction; the outermost caller owns commit/rollback. Mirrors Task 4/5's
// runInTx in transaction/holding application services.
func (s *Service) runInTx(ctx context.Context, fn func(ctx context.Context) (*RecordPaymentResult, error)) (*RecordPaymentResult, error) {
	if s.db == nil {
		return fn(ctx)
	}
	var dto *RecordPaymentResult
	err := sqltx.WithTx(ctx, s.db, "postgres", nil, func(ctxT context.Context) error {
		d, e := fn(ctxT)
		dto = d
		return e
	})
	return dto, err
}

// GetUpcomingPayments returns payment entries due within the given days.
func (s *Service) GetUpcomingPayments(ctx context.Context, tenantID uuid.UUID, daysAhead int) (*UpcomingPaymentsResult, error) {
	entries, err := s.repo.FindUpcomingPayments(ctx, tenantID, daysAhead)
	if err != nil {
		return nil, fmt.Errorf("find upcoming payments: %w", err)
	}
	dtos := make([]PaymentEntryDTO, len(entries))
	for i, e := range entries {
		dtos[i] = entryToDTO(e)
	}
	return &UpcomingPaymentsResult{Entries: dtos}, nil
}

// GetReceivablesSummary aggregates every receivable (DebtType=BorrowedOut) for
// a tenant into a single dashboard snapshot. The repo filters BorrowedOut for
// us; Borrowed-in debts are excluded.
//
// Aggregates (over the schedule of each receivable):
//   - TotalPrincipalCents     Σ TotalPrincipalCents
//   - TotalRemainingCents     Σ RemainingPrincipal() (total − paid principal)
//   - TotalCollectedCents     Σ (TotalPrincipalCents − RemainingPrincipal)
//   - PendingInterestCents    Σ interest of every unpaid schedule entry
//   - OverdueCount/Amount     Σ unpaid entries whose PaymentDate < now
//
// Trend:
//   - PrincipalTrendCents     Σ TotalPrincipalCents of receivables with
//                             created_at in [monthStart, nextMonthStart) — i.e.
//                             new lending this month. totalPrincipal only grows
//                             with new debts, so month-over-month delta ≡ new
//                             lending; computed from created_at (cold-start
//                             safe, no snapshot history needed).
//   - NewCountThisMonth       count of receivables created this month.
//   - RemainingTrendCents     Σ (this_month_remaining − last_month_remaining)
//                             via snapshotRepo. "This month" = [monthStart(now),
//                             monthStart(now)+1mo); "last month" = [monthStart
//                             (now)-1mo, monthStart(now)). Per-debt: Σ only over
//                             debts with a snapshot in BOTH months; a debt
//                             missing either side's snapshot is skipped (no valid
//                             baseline). nil snapshotRepo → 0.
//
// NextPayment* are the globally earliest unpaid entry across every receivable's
// schedule (ties broken by first-debt-seen), with the host debt's counterparty
// and 1-based schedule index.
//
// When snapshotRepo is nil, the trend fields are 0 (still a valid summary).
func (s *Service) GetReceivablesSummary(ctx context.Context, tenantID uuid.UUID) (*ReceivablesSummaryDTO, error) {
	out := domain.BorrowedOut
	result, err := s.repo.FindAll(ctx, tenantID, domain.PageRequest{PageSize: 1000}, &out)
	if err != nil {
		return nil, fmt.Errorf("receivables summary: list: %w", err)
	}
	debts := result.Items
	// Paginate defensively (a tenant is unlikely to exceed 1000 receivables).
	for result.NextPageToken != "" && len(result.Items) > 0 {
		page := domain.PageRequest{PageSize: 1000, PageToken: result.NextPageToken}
		result, err = s.repo.FindAll(ctx, tenantID, page, &out)
		if err != nil {
			return nil, fmt.Errorf("receivables summary: list page: %w", err)
		}
		debts = append(debts, result.Items...)
	}

	now := s.now()
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())
	lastMonthStart := monthStart.AddDate(0, -1, 0)
	nextMonthStart := monthStart.AddDate(0, 1, 0)

	summary := &ReceivablesSummaryDTO{}

	// next_payment tracking: earliest unpaid entry across all receivables.
	var haveNext bool
	var nextDate time.Time
	var nextAmount int64
	var nextCounterparty string
	var nextPeriodNo int32

	debtIDs := make([]uuid.UUID, 0, len(debts))
	for i := range debts {
		d := &debts[i]
		debtIDs = append(debtIDs, d.ID)

		remaining := d.RemainingPrincipal()
		collected := d.TotalPrincipalCents - remaining

		summary.TotalPrincipalCents += d.TotalPrincipalCents
		summary.TotalRemainingCents += remaining
		summary.TotalCollectedCents += collected

		// Principal trend: new lending this month (created_at in this month).
		// totalPrincipal only grows with new debts, so month-over-month delta
		// ≡ new lending — computable from created_at without snapshot history
		// (cold-start safe). See dto.go ReceivablesSummaryDTO trend notes.
		if !d.CreatedAt.Before(monthStart) && d.CreatedAt.Before(nextMonthStart) {
			summary.PrincipalTrendCents += d.TotalPrincipalCents
			summary.NewCountThisMonth++
		}

		for j := range d.Schedule {
			e := &d.Schedule[j]
			if e.Paid {
				continue
			}
			summary.PendingInterestCents += e.InterestCents
			if e.PaymentDate.Before(now) {
				summary.OverdueCount++
				summary.OverdueAmountCents += e.TotalCents
			}
			// earliest unpaid globally (by PaymentDate)
			if !haveNext || e.PaymentDate.Before(nextDate) {
				haveNext = true
				nextDate = e.PaymentDate
				nextAmount = e.TotalCents
				nextCounterparty = d.Counterparty
				nextPeriodNo = int32(j + 1) // 1-based schedule index
			}
		}
	}
	summary.Count = int32(len(debts))

	if haveNext {
		summary.NextPaymentDate = nextDate.Format("2006-01-02")
		summary.NextPaymentAmountCents = nextAmount
		summary.NextPaymentCounterparty = nextCounterparty
		summary.NextPaymentPeriodNo = nextPeriodNo
	}

	// Remaining trend via snapshots (principal trend is computed above from
	// created_at; remaining depends on payments so it still needs snapshot
	// history). nil snapshotRepo → remaining trend stays 0.
	if s.snapshotRepo != nil && len(debtIDs) > 0 {
		snaps, err := s.snapshotRepo.FindSnapshotRange(ctx, tenantID, debtIDs, lastMonthStart, nextMonthStart)
		if err != nil {
			slog.Warn("receivables summary: snapshot range failed, remaining trend zeroed",
				slog.String("error", err.Error()),
				slog.String("operation", "GetReceivablesSummary"))
		} else {
			// index by (debtID, in-this-month?) → latest snapshot per bucket per debt.
			thisMonthByDebt := map[uuid.UUID]domain.DebtProgressSnapshot{}
			lastMonthByDebt := map[uuid.UUID]domain.DebtProgressSnapshot{}
			for _, sn := range snaps {
				if !sn.SnapshotDate.Before(monthStart) && sn.SnapshotDate.Before(nextMonthStart) {
					// this month — keep latest (snapshot_date asc from repo assumed; last wins).
					thisMonthByDebt[sn.DebtID] = sn
				} else if !sn.SnapshotDate.Before(lastMonthStart) && sn.SnapshotDate.Before(monthStart) {
					lastMonthByDebt[sn.DebtID] = sn
				}
			}
			// Remaining trend per debt only when both months are present — a
			// debt snapshotted in only one month has no valid baseline, so it
			// contributes 0 rather than skewing the delta.
			for id, thisM := range thisMonthByDebt {
				lastM, ok := lastMonthByDebt[id]
				if !ok {
					continue
				}
				summary.RemainingTrendCents += thisM.RemainingCents - lastM.RemainingCents
			}
		}
	}

	return summary, nil
}

// SyncAllDebts recomputes each debt's remaining/paid totals and writes a daily
// DebtProgressSnapshot. Scheduler operator (mirrors goal SyncAllGoals). Iterates
// every debt regardless of direction (snapshot is direction-agnostic).
//
// Best-effort: a per-debt snapshot save failure is logged and skipped without
// aborting the batch — return value is the number of debts snapshotted
// successfully. When snapshotRepo is nil the call is a noop returning (0, nil).
// The snapshot date is truncated to the day so the repo's UNIQUE constraint
// collapses same-day writes into a single upsert.
func (s *Service) SyncAllDebts(ctx context.Context, tenantID uuid.UUID) (int, error) {
	if s.snapshotRepo == nil {
		return 0, nil
	}

	result, err := s.repo.FindAll(ctx, tenantID, domain.PageRequest{PageSize: 1000}, nil)
	if err != nil {
		return 0, fmt.Errorf("sync all debts: list: %w", err)
	}
	debts := result.Items
	for result.NextPageToken != "" && len(result.Items) > 0 {
		page := domain.PageRequest{PageSize: 1000, PageToken: result.NextPageToken}
		result, err = s.repo.FindAll(ctx, tenantID, page, nil)
		if err != nil {
			return 0, fmt.Errorf("sync all debts: list page: %w", err)
		}
		debts = append(debts, result.Items...)
	}

	today := truncateToDate(s.now())
	count := 0
	for i := range debts {
		if err := ctx.Err(); err != nil {
			return count, err
		}
		d := &debts[i]
		remaining := d.RemainingPrincipal()
		paidTotal := d.TotalPrincipalCents - remaining
		snap := &domain.DebtProgressSnapshot{
			ID:                  uuid.New(),
			TenantID:            tenantID,
			DebtID:              d.ID,
			SnapshotDate:        today,
			TotalPrincipalCents: d.TotalPrincipalCents,
			RemainingCents:      remaining,
			PaidTotalCents:      paidTotal,
			CreatedAt:           s.now(),
		}
		if err := s.snapshotRepo.SaveSnapshot(ctx, snap); err != nil {
			slog.Warn("debt sync: snapshot save failed, skip",
				slog.String("debt_id", d.ID.String()),
				slog.String("error", err.Error()),
				slog.String("operation", "SyncAllDebts"))
			continue
		}
		count++
	}
	return count, nil
}

// truncateToDate zeros the time-of-day so two snapshots on the same day collapse
// into a single row via the repo's UNIQUE(tenant_id, debt_id, snapshot_date).
func truncateToDate(t time.Time) time.Time {
	return time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location())
}
