package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/debt/domain"
	debtent "github.com/yucai/server/internal/debt/ent"
	"github.com/yucai/server/internal/shared/domain/recurrence"
	"github.com/yucai/server/internal/debt/ent/debtdetails"
	"github.com/yucai/server/internal/debt/ent/paymentschedule"
	"github.com/yucai/server/internal/sqltx"
)

// DebtRepository implements domain.DebtRepository using entGo.
type DebtRepository struct {
	client *debtent.Client
}

// NewDebtRepository creates a new DebtRepository.
func NewDebtRepository(client *debtent.Client) *DebtRepository {
	return &DebtRepository{client: client}
}

// clientFor returns the ent client appropriate for ctx: if ctx carries a tx
// driver (injected by sqltx.WithTx) it returns a tx-bound client whose writes
// join the outer transaction; otherwise it returns the default r.client (the
// non-transactional path, preserving backward compatibility).
//
// Used by Save / FindByID / Update / Delete (Task 6 D3): Save+Update+Delete are
// the writes that must join the outer sqltx.WithTx wrapping RecordPayment, and
// FindByID is the read issued inside the same WithTx fn — without binding to
// the tx driver it would self-deadlock on the single pooled connection (same
// guard as Task 4's account repo / Task 5's holding+lot repos). The other
// reads (FindAll, FindUpcomingPayments, FindAllForBackup) stay on r.client
// because they are not invoked inside a WithTx fn.
func (r *DebtRepository) clientFor(ctx context.Context) *debtent.Client {
	if d, ok := sqltx.DriverFrom(ctx); ok {
		return debtent.NewClient(debtent.Driver(d))
	}
	return r.client
}

// Save persists a debt and its payment schedule.
func (r *DebtRepository) Save(ctx context.Context, d *domain.DebtDetails) error {
	_, err := r.clientFor(ctx).DebtDetails.Create().
		SetID(d.ID).
		SetTenantID(d.TenantID).
		SetAccountID(d.AccountID).
		SetCounterparty(d.Counterparty).
		SetInterestRate(d.InterestRate).
		SetAmortizationMethod(d.AmortizationMethod.String()).
		SetCycle(d.Cycle.String()).
		SetInterval(d.Interval).
		SetWeekdayMask(d.WeekdayMask).
		SetMonthlyMode(int32(d.MonthlyMode)).
		SetNth(d.Nth).
		SetInterestWaivedCents(d.InterestWaivedCents).
		SetStartDate(d.StartDate).
		SetDueDate(d.DueDate).
		SetTotalPrincipalCents(d.TotalPrincipalCents).
		SetDebtType(d.DebtType.String()).
		SetSubtype(d.Subtype).
		SetContact(d.Contact).
		SetContractRef(d.ContractRef).
		SetNillableCollectionAccountID(d.CollectionAccountID).
		SetGuarantorName(d.GuarantorName).
		SetGuarantorContact(d.GuarantorContact).
		SetVersion(d.Version).
		SetCreatedAt(d.CreatedAt).
		SetUpdatedAt(d.UpdatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("save debt: %w", err)
	}

	for _, entry := range d.Schedule {
		create := r.clientFor(ctx).PaymentSchedule.Create().
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
	dd, err := r.clientFor(ctx).DebtDetails.Query().
		Where(
			debtdetails.ID(id),
			debtdetails.TenantID(tenantID),
		).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find debt: %w", err)
	}

	entries, err := r.clientFor(ctx).PaymentSchedule.Query().
		Where(paymentschedule.DebtID(dd.ID)).
		Order(debtent.Asc(paymentschedule.FieldPaymentDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("find payment schedule: %w", err)
	}

	return toDomainDebt(dd, entries), nil
}

// FindAll returns paginated debts (without schedule for performance).
// If typeFilter is non-nil, results are restricted to the given debt type.
func (r *DebtRepository) FindAll(ctx context.Context, tenantID uuid.UUID, page domain.PageRequest, typeFilter *domain.DebtType) (*domain.PaginatedResult[domain.DebtDetails], error) {
	query := r.client.DebtDetails.Query().
		Where(debtdetails.TenantID(tenantID))

	if typeFilter != nil {
		query.Where(debtdetails.DebtTypeEQ((*typeFilter).String()))
	}

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
		update := r.clientFor(ctx).PaymentSchedule.UpdateOneID(entry.ID).
			SetPaymentDate(entry.PaymentDate).
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
	_, err := r.clientFor(ctx).DebtDetails.UpdateOneID(d.ID).
		Where(debtdetails.Version(d.Version - 1)).
		SetCounterparty(d.Counterparty).
		SetInterestRate(d.InterestRate).
		SetAmortizationMethod(d.AmortizationMethod.String()).
		SetCycle(d.Cycle.String()).
		SetInterval(d.Interval).
		SetWeekdayMask(d.WeekdayMask).
		SetMonthlyMode(int32(d.MonthlyMode)).
		SetNth(d.Nth).
		SetInterestWaivedCents(d.InterestWaivedCents).
		SetDueDate(d.DueDate).
		SetContact(d.Contact).
		SetContractRef(d.ContractRef).
		SetNillableCollectionAccountID(d.CollectionAccountID).
		SetGuarantorName(d.GuarantorName).
		SetGuarantorContact(d.GuarantorContact).
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
	r.clientFor(ctx).PaymentSchedule.Delete().
		Where(paymentschedule.DebtID(id)).
		Exec(ctx)

	// Delete debt
	err := r.clientFor(ctx).DebtDetails.DeleteOneID(id).
		Where(debtdetails.TenantID(tenantID)).
		Exec(ctx)
	if err != nil {
		return fmt.Errorf("delete debt: %w", err)
	}
	return nil
}

// UpsertForSync applies one offline-sync push for a single debt (header +
// nested payment schedule): find by id+tenant, then a full-field update with
// the schedule fully replaced (delete old, insert new — the client is the
// single-device source of truth and its version is trusted per F11 v1) or a
// create via Save with the client-supplied id. Tx-aware via clientFor.
func (r *DebtRepository) UpsertForSync(ctx context.Context, d *domain.DebtDetails) error {
	// Schedule rows are scoped by debt_id; force the header id so a malformed
	// payload cannot orphan schedule rows onto another debt.
	for i := range d.Schedule {
		d.Schedule[i].DebtID = d.ID
	}

	c := r.clientFor(ctx)
	_, err := c.DebtDetails.Query().
		Where(debtdetails.ID(d.ID), debtdetails.TenantID(d.TenantID)).
		First(ctx)
	switch {
	case err == nil:
		if _, err := c.PaymentSchedule.Delete().
			Where(paymentschedule.DebtID(d.ID)).
			Exec(ctx); err != nil {
			return fmt.Errorf("sync replace schedule for debt %s: %w", d.ID, err)
		}
		for _, entry := range d.Schedule {
			create := c.PaymentSchedule.Create().
				SetID(entry.ID).
				SetDebtID(entry.DebtID).
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
				return fmt.Errorf("sync insert schedule: %w", err)
			}
		}
		// AccountID is immutable (ent schema) — the debt's parent account is
		// set at create and cannot move on the sync update path.
		if _, err := c.DebtDetails.UpdateOneID(d.ID).
			SetCounterparty(d.Counterparty).
			SetInterestRate(d.InterestRate).
			SetAmortizationMethod(d.AmortizationMethod.String()).
			SetCycle(d.Cycle.String()).
			SetInterval(d.Interval).
			SetWeekdayMask(d.WeekdayMask).
			SetMonthlyMode(int32(d.MonthlyMode)).
			SetNth(d.Nth).
			SetInterestWaivedCents(d.InterestWaivedCents).
			SetStartDate(d.StartDate).
			SetDueDate(d.DueDate).
			SetTotalPrincipalCents(d.TotalPrincipalCents).
			SetDebtType(d.DebtType.String()).
			SetSubtype(d.Subtype).
			SetContact(d.Contact).
			SetContractRef(d.ContractRef).
			SetNillableCollectionAccountID(d.CollectionAccountID).
			SetVersion(d.Version).
			SetUpdatedAt(d.UpdatedAt).
			Save(ctx); err != nil {
			return fmt.Errorf("sync upsert debt %s: %w", d.ID, err)
		}
		return nil
	case debtent.IsNotFound(err):
		return r.Save(ctx, d) // create with the client-supplied id
	default:
		return fmt.Errorf("sync find debt %s: %w", d.ID, err)
	}
}

// HardDeleteForSync physically removes one debt and its payment schedule on
// the offline-sync DELETE path (single-device hard-delete semantics; debts
// have no soft-delete column). Schedule first, then the header — mirroring
// DeleteByTenant's FK ordering, but with the schedule-delete error checked.
// Idempotent by design: a tombstone for an already-absent debt is a no-op so
// re-delivery never fails the batch (FR-3).
func (r *DebtRepository) HardDeleteForSync(ctx context.Context, tenantID, id uuid.UUID) error {
	c := r.clientFor(ctx)
	if _, err := c.PaymentSchedule.Delete().
		Where(paymentschedule.DebtID(id)).
		Exec(ctx); err != nil {
		return fmt.Errorf("sync delete schedule for debt %s: %w", id, err)
	}
	if _, err := c.DebtDetails.Delete().
		Where(debtdetails.ID(id), debtdetails.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("sync hard delete debt %s: %w", id, err)
	}
	return nil
}

// FindForSync returns the tenant's current debt (header + payment schedule)
// for the offline-sync conflict check (F16 ADR-4) — the read dual of
// UpsertForSync (debts carry no soft-delete column, so every row counts).
// found=false means the tenant holds no row for the id. Tx-aware via
// clientFor so the check reads inside the push batch transaction.
func (r *DebtRepository) FindForSync(ctx context.Context, tenantID, id uuid.UUID) (*domain.DebtDetails, bool, error) {
	dd, err := r.clientFor(ctx).DebtDetails.Query().
		Where(debtdetails.ID(id), debtdetails.TenantID(tenantID)).
		First(ctx)
	if err != nil {
		if debtent.IsNotFound(err) {
			return nil, false, nil
		}
		return nil, false, fmt.Errorf("sync find debt %s: %w", id, err)
	}
	entries, err := r.clientFor(ctx).PaymentSchedule.Query().
		Where(paymentschedule.DebtID(dd.ID)).
		All(ctx)
	if err != nil {
		return nil, false, fmt.Errorf("sync find schedule for debt %s: %w", id, err)
	}
	return toDomainDebt(dd, entries), true, nil
}

// FindAllForBackup returns every debt for a tenant with its payment schedule
// eager-loaded in a single batched query (loadSchedulesByDebt, avoiding the N+1
// read that the per-debt FindAll loop would incur). Backup export is the only
// caller; it serializes the full debt graph without paging. Unlike the main
// FindAll, debts here carry no soft-delete concept, so all rows are returned.
func (r *DebtRepository) FindAllForBackup(ctx context.Context, tenantID uuid.UUID) ([]domain.DebtDetails, error) {
	results, err := r.clientFor(ctx).DebtDetails.Query().
		Where(debtdetails.TenantID(tenantID)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query debts for backup: %w", err)
	}

	debtIDs := make([]uuid.UUID, len(results))
	for i, d := range results {
		debtIDs[i] = d.ID
	}
	scheduleByDebt, err := r.loadSchedulesByDebt(ctx, debtIDs)
	if err != nil {
		return nil, err
	}

	debts := make([]domain.DebtDetails, len(results))
	for i, d := range results {
		debts[i] = *toDomainDebt(d, scheduleByDebt[d.ID])
	}
	return debts, nil
}

// loadSchedulesByDebt fetches all payment schedules for the given debt IDs in a
// single query and groups them by debt_id, ordered by payment_date for stable
// output. Returns an empty map (not nil) when there are no debts, and ensures
// every requested debt has a non-nil slice (consistent with FindByID/FindAll).
func (r *DebtRepository) loadSchedulesByDebt(ctx context.Context, debtIDs []uuid.UUID) (map[uuid.UUID][]*debtent.PaymentSchedule, error) {
	out := make(map[uuid.UUID][]*debtent.PaymentSchedule)
	if len(debtIDs) == 0 {
		return out, nil
	}
	entries, err := r.clientFor(ctx).PaymentSchedule.Query().
		Where(paymentschedule.DebtIDIn(debtIDs...)).
		Order(debtent.Asc(paymentschedule.FieldPaymentDate)).
		All(ctx)
	if err != nil {
		return nil, fmt.Errorf("batch load schedules: %w", err)
	}
	for _, e := range entries {
		out[e.DebtID] = append(out[e.DebtID], e)
	}
	for _, id := range debtIDs {
		if out[id] == nil {
			out[id] = []*debtent.PaymentSchedule{}
		}
	}
	return out, nil
}

// DeleteByTenant hard-deletes every debt for a tenant. Child payment_schedules
// are deleted first because they reference debts via debt_id and have no
// tenant_id column of their own (scope by the tenant's debt IDs). Used by the
// backup exporter's Purge step.
func (r *DebtRepository) DeleteByTenant(ctx context.Context, tenantID uuid.UUID) error {
	debtIDs, err := r.clientFor(ctx).DebtDetails.Query().
		Where(debtdetails.TenantID(tenantID)).
		IDs(ctx)
	if err != nil {
		return fmt.Errorf("list debt ids for purge: %w", err)
	}
	if len(debtIDs) > 0 {
		if _, err := r.clientFor(ctx).PaymentSchedule.Delete().
			Where(paymentschedule.DebtIDIn(debtIDs...)).
			Exec(ctx); err != nil {
			return fmt.Errorf("purge payment schedules: %w", err)
		}
	}
	if _, err := r.clientFor(ctx).DebtDetails.Delete().
		Where(debtdetails.TenantID(tenantID)).
		Exec(ctx); err != nil {
		return fmt.Errorf("purge debts: %w", err)
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

// ReplaceFutureSchedule deletes every not-yet-recorded schedule entry
// (paid=false AND paid_cents=0 AND transaction_id IS NULL) and inserts the
// given future entries. Already-recorded (frozen) rows stay untouched —
// the persistence dual of DebtDetails.FrozenEntries. Tx-aware via clientFor.
func (r *DebtRepository) ReplaceFutureSchedule(ctx context.Context, debtID uuid.UUID, future []domain.PaymentScheduleEntry) error {
	c := r.clientFor(ctx)
	if _, err := c.PaymentSchedule.Delete().
		Where(
			paymentschedule.DebtID(debtID),
			paymentschedule.PaidEQ(false),
			paymentschedule.PaidCentsEQ(0),
			paymentschedule.TransactionIDIsNil(),
		).
		Exec(ctx); err != nil {
		return fmt.Errorf("replace future schedule delete: %w", err)
	}
	for i := range future {
		entry := future[i]
		create := c.PaymentSchedule.Create().
			SetID(entry.ID).
			SetDebtID(debtID).
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
			return fmt.Errorf("replace future schedule insert: %w", err)
		}
	}
	return nil
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
		Cycle:               recurrence.ParseCycle(dd.Cycle),
		Interval:            dd.Interval,
		WeekdayMask:         dd.WeekdayMask,
		MonthlyMode:         recurrence.MonthlyMode(dd.MonthlyMode),
		Nth:                 dd.Nth,
		InterestWaivedCents: dd.InterestWaivedCents,
		StartDate:           dd.StartDate,
		DueDate:             dd.DueDate,
		TotalPrincipalCents: dd.TotalPrincipalCents,
		DebtType:            domain.ParseDebtType(dd.DebtType),
		Subtype:             dd.Subtype,
		Contact:             dd.Contact,
		ContractRef:         dd.ContractRef,
		CollectionAccountID: dd.CollectionAccountID,
		GuarantorName:       dd.GuarantorName,
		GuarantorContact:    dd.GuarantorContact,
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

// AccountReferenceSourceName implements the account module's
// AccountReferenceSource port (structural — this package does not import
// account).
func (r *DebtRepository) AccountReferenceSourceName() string {
	return "debt"
}

// CountAccountReferences counts debts whose asset account or collection
// account is accountID. Debts have no soft delete, so every row counts.
func (r *DebtRepository) CountAccountReferences(ctx context.Context, tenantID, accountID uuid.UUID) (int64, error) {
	n, err := r.clientFor(ctx).DebtDetails.Query().
		Where(
			debtdetails.TenantID(tenantID),
			debtdetails.Or(
				debtdetails.AccountID(accountID),
				debtdetails.CollectionAccountID(accountID),
			),
		).
		Count(ctx)
	if err != nil {
		return 0, fmt.Errorf("count debts referencing account %s: %w", accountID, err)
	}
	return int64(n), nil
}
