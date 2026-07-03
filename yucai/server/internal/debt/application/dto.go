package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/debt/domain"
)

// CreateDebtRequest holds input for creating a debt.
// Subtype is a plain string persisted verbatim; pass a DebtSubtype* /
// ReceivableSubtype* const (or "" when unspecified).
// Contact and ContractRef are optional free-form metadata (pass "" when
// unspecified). CollectionAccountID is the asset account a receivable's
// repayments land in; nil for borrowed-in debts (the receivable-required
// check lives here in application.CreateDebt, not in the domain constructor).
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
	Contact             string
	ContractRef         string
	CollectionAccountID *uuid.UUID
}

// UpdateDebtRequest holds input for updating a debt.
// Contact, ContractRef and CollectionAccountID pass through to the aggregate
// (Task 5 receivables alignment). They mirror CreateDebtRequest semantics: an
// empty Contact/ContractRef clears the field, and a nil CollectionAccountID
// clears it.
type UpdateDebtRequest struct {
	TenantID            uuid.UUID
	ID                  uuid.UUID
	Counterparty        string
	InterestRate        float64
	Version             int64
	Contact             string
	ContractRef         string
	CollectionAccountID *uuid.UUID
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
//
// NextPayment* fields are derived from the schedule: the earliest !paid entry
// (sorted by PaymentDate ascending) populates NextPaymentDate ("2006-01-02"
// formatted), NextPaymentAmountCents (its TotalCents) and NextPaymentPeriodNo
// (1-based schedule index). When every entry is paid (or the schedule is empty)
// these fields are zero-valued.
type DebtDTO struct {
	ID                    uuid.UUID
	TenantID              uuid.UUID
	AccountID             uuid.UUID
	Counterparty          string
	InterestRate          float64
	AmortizationMethod    domain.AmortizationMethod
	StartDate             time.Time
	DueDate               time.Time
	TotalPrincipalCents   int64
	DebtType              domain.DebtType
	Subtype               string
	Contact               string
	ContractRef           string
	CollectionAccountID   *uuid.UUID
	NextPaymentDate       string // "2006-01-02" of earliest unpaid entry; "" when none
	NextPaymentAmountCents int64
	NextPaymentPeriodNo   int32 // 1-based schedule index of earliest unpaid entry; 0 when none
	RemainingPrincipal    int64
	Version               int64
	CreatedAt             time.Time
	UpdatedAt             time.Time
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

// ReceivablesSummaryDTO aggregates every receivable (BorrowedOut debt) for a
// tenant, used by the receivables dashboard. All amounts are in cents and in
// the original debt currency (server does no FX conversion; the client converts
// to the user's preferred currency in Task 9).
//
// Trend fields compare this month's snapshot against last month's per debt:
//   - PrincipalTrendCents = Σ (this_month_total_principal − last_month_total_principal)
//     → month-over-month new lending (positive = lent more out).
//   - RemainingTrendCents = Σ (this_month_remaining − last_month_remaining)
//     → negative = principal collected back; positive = balance grew (more lent).
//
// The trend is Σ only over debts that have a snapshot in BOTH months; a debt
// missing either month's snapshot contributes nothing (no valid baseline, we
// do not fabricate a delta by treating the missing side as 0).
type ReceivablesSummaryDTO struct {
	TotalPrincipalCents   int64
	TotalRemainingCents   int64
	TotalCollectedCents   int64
	PendingInterestCents  int64
	Count                 int32
	OverdueCount          int32
	OverdueAmountCents    int64
	PrincipalTrendCents   int64
	RemainingTrendCents   int64
	NextPaymentDate       string // "2006-01-02" of globally earliest unpaid entry; "" when none
	NextPaymentAmountCents int64
	NextPaymentCounterparty string
	NextPaymentPeriodNo   int32
}

// DebtToDTO converts domain DebtDetails to DTO. Populates NextPayment* fields
// from the earliest unpaid schedule entry (sorted by PaymentDate ascending).
func DebtToDTO(d *domain.DebtDetails) DebtDTO {
	dto := DebtDTO{
		ID:                   d.ID,
		TenantID:             d.TenantID,
		AccountID:            d.AccountID,
		Counterparty:         d.Counterparty,
		InterestRate:         d.InterestRate,
		AmortizationMethod:   d.AmortizationMethod,
		StartDate:            d.StartDate,
		DueDate:              d.DueDate,
		TotalPrincipalCents:  d.TotalPrincipalCents,
		DebtType:             d.DebtType,
		Subtype:              d.Subtype,
		Contact:              d.Contact,
		ContractRef:          d.ContractRef,
		CollectionAccountID:  d.CollectionAccountID,
		RemainingPrincipal:   d.RemainingPrincipal(),
		Version:              d.Version,
		CreatedAt:            d.CreatedAt,
		UpdatedAt:            d.UpdatedAt,
	}

	// Find earliest unpaid entry by PaymentDate. The amortization calculator
	// emits entries in chronological order, but we sort defensively so a
	// hand-built schedule (e.g. in tests) is handled the same way.
	type entryIdx struct {
		idx int
		e   domain.PaymentScheduleEntry
	}
	var unpaid []entryIdx
	for i := range d.Schedule {
		if !d.Schedule[i].Paid {
			unpaid = append(unpaid, entryIdx{i, d.Schedule[i]})
		}
	}
	if len(unpaid) > 0 {
		earliest := unpaid[0]
		for _, u := range unpaid[1:] {
			if u.e.PaymentDate.Before(earliest.e.PaymentDate) {
				earliest = u
			}
		}
		dto.NextPaymentDate = earliest.e.PaymentDate.Format("2006-01-02")
		dto.NextPaymentAmountCents = earliest.e.TotalCents
		dto.NextPaymentPeriodNo = int32(earliest.idx + 1) // 1-based
	}

	return dto
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
