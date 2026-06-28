package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/debt/domain"
)

// Service orchestrates debt operations.
type Service struct {
	repo domain.DebtRepository
}

// NewService creates a new debt application service.
func NewService(repo domain.DebtRepository) *Service {
	return &Service{repo: repo}
}

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
