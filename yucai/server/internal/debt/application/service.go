package application

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	"github.com/yucai/server/internal/debt/domain"
)

// AccountLookup is the account-reading port used by the debt service to resolve
// a debt's currency (DebtDetails has no CurrencyCode field — currency lives on
// the parent account). Only the read method needed for currency lookup is
// exposed; the concrete account domain.AccountRepository satisfies this.
// Defined locally (mirrors transaction/application.AccountLookup) so debt
// application does not import transaction.
type AccountLookup interface {
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*accountdomain.Account, error)
}

// Service orchestrates debt operations.
type Service struct {
	repo          domain.DebtRepository
	accountLookup AccountLookup // optional: resolves per-debt currency; nil = default CNY
	snapshotRepo  domain.DebtSnapshotRepository // optional: progress snapshots; nil = SyncAllDebts is a noop
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
	debt, err := domain.NewDebtDetails(
		req.TenantID, req.AccountID,
		req.Counterparty,
		req.InterestRate,
		req.AmortizationMethod,
		req.StartDate, req.DueDate,
		req.TotalPrincipalCents,
		req.DebtType,
		req.Subtype,
		req.Contact,
		req.ContractRef,
		req.CollectionAccountID,
	)
	if err != nil {
		return nil, fmt.Errorf("create debt: %w", err)
	}

	debt.GenerateSchedule()

	if err := s.repo.Save(ctx, debt); err != nil {
		return nil, fmt.Errorf("save debt: %w", err)
	}

	dto := DebtToDTO(debt)
	return &dto, nil
}

// UpdateDebt updates a debt's mutable fields.
func (s *Service) UpdateDebt(ctx context.Context, req UpdateDebtRequest) (*DebtDTO, error) {
	debt, err := s.repo.FindByID(ctx, req.TenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("debt not found: %w", err)
	}

	if debt.Version != req.Version {
		return nil, fmt.Errorf("optimistic lock conflict: expected version %d, got %d", req.Version, debt.Version)
	}

	debt.Counterparty = req.Counterparty
	debt.InterestRate = req.InterestRate
	debt.Contact = req.Contact
	debt.ContractRef = req.ContractRef
	debt.CollectionAccountID = req.CollectionAccountID
	debt.IncrementVersion()

	if err := s.repo.Update(ctx, debt); err != nil {
		return nil, fmt.Errorf("update debt: %w", err)
	}

	dto := DebtToDTO(debt)
	return &dto, nil
}

// DeleteDebt deletes a debt by ID.
func (s *Service) DeleteDebt(ctx context.Context, tenantID, id uuid.UUID) error {
	return s.repo.Delete(ctx, tenantID, id)
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

// RecordPayment marks a schedule entry as paid and returns the result.
// Note: actual transaction creation is handled by the gRPC handler layer.
func (s *Service) RecordPayment(ctx context.Context, req RecordPaymentRequest) (*RecordPaymentResult, error) {
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
