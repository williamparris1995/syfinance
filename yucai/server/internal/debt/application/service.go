package application

import (
	"context"
	"fmt"
	"log/slog"

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
}

// NewService creates a new debt application service.
func NewService(repo domain.DebtRepository) *Service {
	return &Service{repo: repo}
}

// SetAccountLookup injects the account lookup used by SumRemainingByCurrency to
// resolve each debt's currency from its parent account. Called by wire after
// construction (NewService signature stays unchanged so existing tests and
// callers are not broken). nil = every debt bucketed under CNY.
func (s *Service) SetAccountLookup(l AccountLookup) { s.accountLookup = l }

// CreateDebt validates, generates schedule, and persists a new debt.
func (s *Service) CreateDebt(ctx context.Context, req CreateDebtRequest) (*DebtDTO, error) {
	debt, err := domain.NewDebtDetails(
		req.TenantID, req.AccountID,
		req.Counterparty,
		req.InterestRate,
		req.AmortizationMethod,
		req.StartDate, req.DueDate,
		req.TotalPrincipalCents,
		req.DebtType,
		req.Subtype,
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

// SumRemainingByCurrency sums the remaining principal of every debt for a
// tenant, grouped by currency. Implements networth/domain.DebtSource
// (structural — networth does not import debt).
//
// Currency resolution: DebtDetails has no CurrencyCode field, so each debt's
// currency is read from its parent account via the injected AccountLookup. When
// accountLookup is nil (unwired) or the account lookup fails, the debt falls
// back to CNY (the app default) rather than being dropped — logged as a warning.
// Paginates at PageSize 100.
func (s *Service) SumRemainingByCurrency(ctx context.Context, tenantID uuid.UUID) (map[string]int64, error) {
	byCur := map[string]int64{}
	page := domain.PageRequest{PageSize: 100}
	for {
		result, err := s.repo.FindAll(ctx, tenantID, page, nil)
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
