package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/debt/domain"
)

// CreateDebtRequest holds input for creating a debt.
// Subtype is a plain string persisted verbatim; pass a DebtSubtype* /
// ReceivableSubtype* const (or "" when unspecified).
type CreateDebtRequest struct {
	TenantID            uuid.UUID
	AccountID           uuid.UUID
	Counterparty        string
	InterestRate        float64
	AmortizationMethod  domain.AmortizationMethod
	StartDate           time.Time
	DueDate             time.Time
	TotalPrincipalCents int64
	DebtType            domain.DebtType
	Subtype             string
}

// UpdateDebtRequest holds input for updating a debt.
type UpdateDebtRequest struct {
	TenantID     uuid.UUID
	ID           uuid.UUID
	Counterparty string
	InterestRate float64
	Version      int64
}

// RecordPaymentRequest holds input for recording a payment.
type RecordPaymentRequest struct {
	TenantID        uuid.UUID
	DebtID          uuid.UUID
	ScheduleEntryID uuid.UUID
	FromAccountID   uuid.UUID
}

// ListDebtsRequest holds input for listing debts.
// TypeFilter is optional: a nil pointer returns debts of all types.
type ListDebtsRequest struct {
	TenantID   uuid.UUID
	Page       domain.PageRequest
	TypeFilter *domain.DebtType
}

// DebtDTO is the data transfer object.
type DebtDTO struct {
	ID                  uuid.UUID
	TenantID            uuid.UUID
	AccountID           uuid.UUID
	Counterparty        string
	InterestRate        float64
	AmortizationMethod  domain.AmortizationMethod
	StartDate           time.Time
	DueDate             time.Time
	TotalPrincipalCents int64
	DebtType            domain.DebtType
	Subtype             string
	RemainingPrincipal  int64
	Version             int64
	CreatedAt           time.Time
	UpdatedAt           time.Time
}

// PaymentEntryDTO is the DTO for a payment schedule entry.
type PaymentEntryDTO struct {
	ID             uuid.UUID
	DebtID         uuid.UUID
	PaymentDate    time.Time
	PrincipalCents int64
	InterestCents  int64
	TotalCents     int64
	Paid           bool
	PaidCents      int64
	TransactionID  *uuid.UUID
}

// DebtDetailDTO extends DebtDTO with the payment schedule.
type DebtDetailDTO struct {
	Debt     DebtDTO
	Schedule []PaymentEntryDTO
}

// RecordPaymentResult wraps the payment result.
type RecordPaymentResult struct {
	TransactionID uuid.UUID
	Entry         PaymentEntryDTO
}

// ListDebtsResult wraps paginated debt DTOs.
type ListDebtsResult struct {
	Debts         []DebtDTO
	NextPageToken string
	TotalCount    int32
}

// UpcomingPaymentsResult wraps upcoming payment entries.
type UpcomingPaymentsResult struct {
	Entries []PaymentEntryDTO
}

// DebtToDTO converts domain DebtDetails to DTO.
func DebtToDTO(d *domain.DebtDetails) DebtDTO {
	return DebtDTO{
		ID:                  d.ID,
		TenantID:            d.TenantID,
		AccountID:           d.AccountID,
		Counterparty:        d.Counterparty,
		InterestRate:        d.InterestRate,
		AmortizationMethod:  d.AmortizationMethod,
		StartDate:           d.StartDate,
		DueDate:             d.DueDate,
		TotalPrincipalCents: d.TotalPrincipalCents,
		DebtType:            d.DebtType,
		Subtype:             d.Subtype,
		RemainingPrincipal:  d.RemainingPrincipal(),
		Version:             d.Version,
		CreatedAt:           d.CreatedAt,
		UpdatedAt:           d.UpdatedAt,
	}
}

// DebtToDetailDTO converts domain DebtDetails to detail DTO.
func DebtToDetailDTO(d *domain.DebtDetails) DebtDetailDTO {
	entries := make([]PaymentEntryDTO, len(d.Schedule))
	for i, e := range d.Schedule {
		entries[i] = entryToDTO(e)
	}
	return DebtDetailDTO{
		Debt:     DebtToDTO(d),
		Schedule: entries,
	}
}

func entryToDTO(e domain.PaymentScheduleEntry) PaymentEntryDTO {
	return PaymentEntryDTO{
		ID:             e.ID,
		DebtID:         e.DebtID,
		PaymentDate:    e.PaymentDate,
		PrincipalCents: e.PrincipalCents,
		InterestCents:  e.InterestCents,
		TotalCents:     e.TotalCents,
		Paid:           e.Paid,
		PaidCents:      e.PaidCents,
		TransactionID:  e.TransactionID,
	}
}
