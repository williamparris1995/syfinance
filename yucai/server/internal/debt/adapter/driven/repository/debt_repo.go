package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/debt/domain"
	debtent "github.com/yucai/server/internal/debt/ent"
	"github.com/yucai/server/internal/debt/ent/debtdetails"
	"github.com/yucai/server/internal/debt/ent/paymentschedule"
)

// DebtRepository implements domain.DebtRepository using entGo.
type DebtRepository struct {
	client *debtent.Client
}

// NewDebtRepository creates a new DebtRepository.
func NewDebtRepository(client *debtent.Client) *DebtRepository {
	return &DebtRepository{client: client}
}

// Save persists a debt and its payment schedule.
func (r *DebtRepository) Save(ctx context.Context, d *domain.DebtDetails) error {
	_, err := r.client.DebtDetails.Create().
		SetID(d.ID).
		SetTenantID(d.TenantID).
		SetAccountID(d.AccountID).
		SetCounterparty(d.Counterparty).
		SetInterestRate(d.InterestRate).
		SetAmortizationMethod(d.AmortizationMethod.String()).
		SetStartDate(d.StartDate).
		SetDueDate(d.DueDate).
		SetTotalPrincipalCents(d.TotalPrincipalCents).
		SetVersion(d.Version).
		SetCreatedAt(d.CreatedAt).
		SetUpdatedAt(d.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save debt: %w", err)
	}

	for _, entry := range d.Schedule {
		create := r.client.PaymentSchedule.Create().
			SetID(entry.ID).
			SetDebtID(d.ID).
			SetPaymentDate(entry.PaymentDate).
			SetPrincipalCents(entry.PrincipalCents).
			SetInterestCents(entry.InterestCents).
			SetTotalCents(entry.TotalCents).
			SetPaid(entry.Paid).
			SetPaidCents(entry.PaidCents)
		if entry.TransactionID != nil {
			create.SetTransactionID(*entry.TransactionID)
		}
		if _, err := create.Save(ctx); err != nil {
			return fmt.Errorf("save payment schedule: %w", err)
		}
	}
	return nil
}

// FindByID retrieves a debt with its payment schedule.
func (r *DebtRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.DebtDetails, error) {
	dd, err := r.client.DebtDetails.Query().
		Where(
			debtdetails.ID(id),
			debtdetails.TenantID(tenantID),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find debt: %w", err)
	}

	entries, err := r.client.PaymentSchedule.Query().
		Where(paymentschedule.DebtID(dd.ID)).
		Order(debtent.Asc(paymentschedule.FieldPaymentDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find payment schedule: %w", err)
	}

	return toDomainDebt(dd, entries), nil
}

// FindAll returns paginated debts (without schedule for performance).
func (r *DebtRepository) FindAll(ctx context.Context, tenantID uuid.UUID, page domain.PageRequest) (*domain.PaginatedResult[domain.DebtDetails], error) {
	query := r.client.DebtDetails.Query().
		Where(debtdetails.TenantID(tenantID))

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count debts: %w", err)
	}

	pageSize := int(page.PageSize)
	if pageSize <= 0 {
		pageSize = 20
	}
	query.Limit(pageSize + 1)

	if page.PageToken != "" {
		cursorID, err := uuid.Parse(page.PageToken)
		if err == nil {
			query.Where(debtdetails.IDGTE(cursorID))
		}
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query debts: %w", err)
	}

	var nextToken string
	if len(results) > pageSize {
		nextToken = results[pageSize-1].ID.String()
		results = results[:pageSize]
	}

	debts := make([]domain.DebtDetails, len(results))
	for i, dd := range results {
		// Load schedule for each debt
		entries, err := r.client.PaymentSchedule.Query().
			Where(paymentschedule.DebtID(dd.ID)).
			Order(debtent.Asc(paymentschedule.FieldPaymentDate)).
			All(ctx)
		if err != nil {
			return nil, fmt.Errorf("load schedule for debt %s: %w", dd.ID, err)
		}
		debts[i] = *toDomainDebt(dd, entries)
	}

	return &domain.PaginatedResult[domain.DebtDetails]{
		Items:         debts,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update persists changes to a debt and its schedule.
func (r *DebtRepository) Update(ctx context.Context, d *domain.DebtDetails) error {
	// Update schedule entries
	for _, entry := range d.Schedule {
		update := r.client.PaymentSchedule.UpdateOneID(entry.ID).
			SetPrincipalCents(entry.PrincipalCents).
			SetInterestCents(entry.InterestCents).
			SetTotalCents(entry.TotalCents).
			SetPaid(entry.Paid).
			SetPaidCents(entry.PaidCents)
		if entry.TransactionID != nil {
			update.SetTransactionID(*entry.TransactionID)
		}
		if _, err := update.Save(ctx); err != nil {
			return fmt.Errorf("update payment schedule: %w", err)
		}
	}

	// Update debt header
	_, err := r.client.DebtDetails.UpdateOneID(d.ID).
		Where(debtdetails.Version(d.Version - 1)).
		SetCounterparty(d.Counterparty).
		SetInterestRate(d.InterestRate).
		SetVersion(d.Version).
		SetUpdatedAt(d.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update debt: %w", err)
	}
	return nil
}

// Delete removes a debt and its schedule.
func (r *DebtRepository) Delete(ctx context.Context, tenantID, id uuid.UUID) error {
	// Delete schedule entries first
	r.client.PaymentSchedule.Delete().
		Where(paymentschedule.DebtID(id)).
		Exec(ctx)

	// Delete debt
	err := r.client.DebtDetails.DeleteOneID(id).
		Where(debtdetails.TenantID(tenantID)).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("delete debt: %w", err)
	}
	return nil
}

// FindUpcomingPayments returns unpaid schedule entries due within daysAhead.
func (r *DebtRepository) FindUpcomingPayments(ctx context.Context, tenantID uuid.UUID, daysAhead int) ([]domain.PaymentScheduleEntry, error) {
	now := time.Now()
	endDate := now.AddDate(0, 0, daysAhead)

	entries, err := r.client.PaymentSchedule.Query().
		Where(
			paymentschedule.PaymentDateGTE(now),
			paymentschedule.PaymentDateLTE(endDate),
			paymentschedule.PaidEQ(false),
		).
		Order(debtent.Asc(paymentschedule.FieldPaymentDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find upcoming payments: %w", err)
	}

	// Filter by tenant: need to join with debt details
	result := make([]domain.PaymentScheduleEntry, 0, len(entries))
	for _, e := range entries {
		dd, err := r.client.DebtDetails.Query().
			Where(
				debtdetails.ID(e.DebtID),
				debtdetails.TenantID(tenantID),
			).
			Only(ctx)
		if err != nil {
			continue // skip entries not belonging to this tenant
		}
		_ = dd
		result = append(result, toDomainEntry(e))
	}
	return result, nil
}

func toDomainDebt(dd *debtent.DebtDetails, entries []*debtent.PaymentSchedule) *domain.DebtDetails {
	schedule := make([]domain.PaymentScheduleEntry, len(entries))
	for i, e := range entries {
		schedule[i] = toDomainEntry(e)
	}
	return &domain.DebtDetails{
		ID:                  dd.ID,
		TenantID:            dd.TenantID,
		AccountID:           dd.AccountID,
		Counterparty:        dd.Counterparty,
		InterestRate:        dd.InterestRate,
		AmortizationMethod:  domain.ParseAmortizationMethod(dd.AmortizationMethod),
		StartDate:           dd.StartDate,
		DueDate:             dd.DueDate,
		TotalPrincipalCents: dd.TotalPrincipalCents,
		Schedule:            schedule,
		Version:             dd.Version,
		CreatedAt:           dd.CreatedAt,
		UpdatedAt:           dd.UpdatedAt,
	}
}

func toDomainEntry(e *debtent.PaymentSchedule) domain.PaymentScheduleEntry {
	return domain.PaymentScheduleEntry{
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

// Compile-time check.
var _ domain.DebtRepository = (*DebtRepository)(nil)
