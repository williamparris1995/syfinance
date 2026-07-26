package grpc

import (
	"context"
	"log/slog"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/debt/application"
	"github.com/yucai/server/internal/debt/domain"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	pb "github.com/yucai/server/internal/proto/debt/v1"
	transactionApp "github.com/yucai/server/internal/transaction/application"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// DebtHandler implements the generated DebtServiceServer.
type DebtHandler struct {
	pb.UnimplementedDebtServiceServer
	service        *application.Service
	transactionSvc *transactionApp.Service      // double-write: RecordPayment will create a transaction (Task 2)
	accountLookup  transactionApp.AccountLookup // account chart_code lookup + balance validation (Task 2-3)
}

// NewDebtHandler creates a new DebtHandler.
func NewDebtHandler(service *application.Service, txnSvc *transactionApp.Service, accountLookup transactionApp.AccountLookup) *DebtHandler {
	return &DebtHandler{service: service, transactionSvc: txnSvc, accountLookup: accountLookup}
}

// CreateDebt creates a new debt with amortization schedule.
//
// borrowedOut double-write (create-debt-dual-write): when creating a loan the
// user lent out, a balancing transaction moves the lent principal from the
// source (cash) account to the receivable account, so the receivable balance
// reflects the principal from creation (fixes the negative-receivable bug
// where RecordPayment reduced a zero-initial receivable).
//
// Flow:
//  1. Parse source_account_id (borrowedOut required; borrowedIn ignores it).
//  2. validateSourceAccount BEFORE service.CreateDebt — fail fast so an
//     invalid source leaves no debt persisted.
//  3. service.CreateDebt generates schedule + persists (unchanged).
//  4. recordCreateTransaction (best-effort): on failure, log + swallow; the
//     debt is already created and is not rolled back (mirrors RecordPayment).
func (h *DebtHandler) CreateDebt(ctx context.Context, req *pb.CreateDebtRequest) (*pb.DebtResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	accountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}

	startDate, err := parseDate(req.StartDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid start_date")
	}
	dueDate, err := parseDate(req.DueDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid due_date")
	}

	debtType := protoToDebtType(req.DebtType)

	// borrowedOut: validate the cash source BEFORE creating the debt so an
	// invalid source fails fast and no debt is persisted. borrowedIn ignores
	// the source entirely (no double-write).
	var sourceAcc *accountdomain.Account
	var sourceAccountID uuid.UUID
	if debtType == domain.BorrowedOut {
		sourceAccountID, err = uuid.Parse(req.SourceAccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid source_account_id")
		}
		sourceAcc, err = h.validateSourceAccount(ctx, tenantID, sourceAccountID, accountID, req.TotalPrincipalCents)
		if err != nil {
			return nil, err
		}
	}

	// Build the application request. For BorrowedOut the cash source (validated
	// above) doubles as the collection account — every repayment the receivable
	// absorbs lands back in that account. Contact/ContractRef pass through
	// verbatim.
	appReq := application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        req.Counterparty,
		InterestRate:        req.InterestRate,
		AmortizationMethod:  protoToMethod(req.AmortizationMethod),
		StartDate:           startDate,
		DueDate:             dueDate,
		TotalPrincipalCents: req.TotalPrincipalCents,
		DebtType:            debtType,
		Subtype:             req.Subtype,
		Contact:             req.Contact,
		ContractRef:         req.ContractRef,
	}
	if debtType == domain.BorrowedOut {
		// Collection account = where repayments land.
		//
		// Spec B6 (create-debt form): collection_account_id defaults to the
		// cash source (source_account_id) when the request omits it — the
		// receivable is paid back into the same asset account the principal
		// was lent out of, which is the common case. The handler mirrors that
		// form default so a direct RPC caller with no collection_account_id
		// gets the same behavior as the UI.
		//
		// A malformed (non-empty, non-UUID) collection_account_id is rejected
		// with InvalidArgument — we never silently fall back to the source,
		// mirroring UpdateDebt's parse handling below.
		coll := sourceAccountID
		if req.CollectionAccountId != "" {
			parsed, perr := uuid.Parse(req.CollectionAccountId)
			if perr != nil {
				return nil, status.Error(codes.InvalidArgument, "invalid collection_account_id")
			}
			coll = parsed
		}
		appReq.CollectionAccountID = &coll
	}

	resp, err := h.service.CreateDebt(ctx, appReq)
	if err != nil {
		return nil, mapError(err)
	}

	// Double-write: move the lent principal from source (cash) to receivable.
	// Best-effort (debt already created); see recordCreateTransaction doc.
	if debtType == domain.BorrowedOut {
		h.recordCreateTransaction(ctx, tenantID, sourceAccountID, sourceAcc, accountID, req.TotalPrincipalCents)
	}

	return &pb.DebtResponse{Debt: debtToProto(*resp)}, nil
}

// validateSourceAccount reads the source + receivable (debt) accounts and
// enforces the CreateDebt borrowedOut invariants BEFORE service.CreateDebt, so
// an invalid source fails fast and no debt is persisted.
//
//  1. source must exist (NotFound otherwise).
//  2. source must be an asset account (InvalidArgument otherwise).
//  3. source must differ from the receivable account (InvalidArgument — no
//     self-transfer).
//  4. source and the receivable account must share a currency (InvalidArgument
//     otherwise — cross-currency needs manual FX handling).
//  5. source balance must cover the lent principal (FailedPrecondition).
//
// debtAccountID is req.AccountId (the receivable account for borrowedOut).
// Returns nil,(nil,nil) if accountLookup is unwired (defensive, mirrors
// validateFromAccount) so unit tests without deps skip validation.
func (h *DebtHandler) validateSourceAccount(ctx context.Context, tenantID, sourceAccountID, debtAccountID uuid.UUID, principalCents int64) (*accountdomain.Account, error) {
	if h.accountLookup == nil {
		return nil, nil
	}

	sourceAcc, err := h.accountLookup.FindByID(ctx, tenantID, sourceAccountID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "source_account not found: "+err.Error())
	}
	if sourceAcc.AccountType != accountdomain.AccountTypeAsset {
		return nil, status.Error(codes.InvalidArgument, "source_account must be asset")
	}
	if sourceAccountID == debtAccountID {
		return nil, status.Error(codes.InvalidArgument, "source_account must differ from receivable account")
	}

	debtAcc, err := h.accountLookup.FindByID(ctx, tenantID, debtAccountID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "receivable account not found: "+err.Error())
	}
	if sourceAcc.CurrencyCode != debtAcc.CurrencyCode {
		return nil, status.Error(codes.InvalidArgument, "cross-currency, manual handling required")
	}

	if sourceAcc.CurrentBalanceCents < principalCents {
		return nil, status.Error(codes.FailedPrecondition, "source_account balance insufficient")
	}

	return sourceAcc, nil
}

// recordCreateTransaction builds the borrowedOut double-entry pair (credit
// source / debit receivable) via buildCreateEntries and records it through the
// transaction service. It is best-effort: any failure (account lookup or the
// transaction write) is logged with English structured fields and swallowed so
// the already-created debt is not rolled back. Returns nothing — callers
// ignore the outcome by design.
//
// sourceAcc is the source already fetched + validated by CreateDebt; passing
// it in avoids a redundant lookup here.
func (h *DebtHandler) recordCreateTransaction(ctx context.Context, tenantID, sourceAccountID uuid.UUID, sourceAcc *accountdomain.Account, debtAccountID uuid.UUID, principalCents int64) {
	if h.transactionSvc == nil || h.accountLookup == nil {
		return
	}
	if sourceAcc == nil {
		return
	}

	debtAcc, err := h.accountLookup.FindByID(ctx, tenantID, debtAccountID)
	if err != nil {
		slog.Error("create debt double-write: receivable account lookup failed",
			"operation", "debt.CreateDebt.recordCreateTransaction",
			"source_account_id", sourceAccountID.String(),
			"debt_account_id", debtAccountID.String(),
			"amount_cents", principalCents,
			"error", err.Error())
		return
	}

	entries := buildCreateEntries(*sourceAcc, *debtAcc, principalCents)
	if _, err := h.transactionSvc.RecordTransaction(ctx, transactionApp.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "CreateDebt double-write",
		Entries:         entries,
	}); err != nil {
		slog.Error("create debt double-write: transaction write failed",
			"operation", "debt.CreateDebt.recordCreateTransaction",
			"source_account_id", sourceAccountID.String(),
			"debt_account_id", debtAccountID.String(),
			"amount_cents", principalCents,
			"error", err.Error())
	}
}

// UpdateDebt updates a debt's mutable fields.
func (h *DebtHandler) UpdateDebt(ctx context.Context, req *pb.UpdateDebtRequest) (*pb.DebtResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	// Contact, ContractRef and CollectionAccountID pass through verbatim.
	var collectionAccountID *uuid.UUID
	if req.CollectionAccountId != "" {
		parsed, err := uuid.Parse(req.CollectionAccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid collection_account_id")
		}
		collectionAccountID = &parsed
	}
	resp, err := h.service.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:            tenantID,
		ID:                  id,
		Counterparty:        req.Counterparty,
		InterestRate:        req.InterestRate,
		Version:             req.Version,
		Contact:             req.Contact,
		ContractRef:         req.ContractRef,
		CollectionAccountID: collectionAccountID,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.DebtResponse{Debt: debtToProto(*resp)}, nil
}

// DeleteDebt deletes a debt.
func (h *DebtHandler) DeleteDebt(ctx context.Context, req *pb.DeleteDebtRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.DeleteDebt(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// RecordPayment records a payment for a schedule entry.
//
// Transactional flow (Task 6 / D3, supersedes the credit-card-sync Tasks 2-3
// best-effort double-write):
//  1. Pre-validate from_account BEFORE marking the debt paid — fail fast so an
//     invalid from_account (non-asset, insufficient balance, cross-currency)
//     leaves the debt untouched (Task 3). Needs the debt detail (for DebtType +
//     account_id + the target entry total) and the from_account; the cash
//     record builder reuses both.
//  2. Build the cash-side double-entry pair (buildRepaymentCashRecord) keyed by
//     DebtType, returns nil when validation was skipped (accountLookup not
//     wired) so the service skips the cash write on that path.
//  3. h.service.RecordPayment wraps schedule.Paid + principal persist + the
//     cash-side record in ONE sqltx.WithTx (Task 6). A cash-write failure now
//     rolls back the debt write — replacing the pre-Task-6 best-effort swallow
//     that left the debt marked paid with no cash debit (D3 defect:
//     "debt marked paid but cash not debited, net worth inflated").
func (h *DebtHandler) RecordPayment(ctx context.Context, req *pb.RecordPaymentRequest) (*pb.RecordPaymentResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	debtID, _ := uuid.Parse(req.DebtId)
	entryID, _ := uuid.Parse(req.ScheduleEntryId)
	fromAccountID, _ := uuid.Parse(req.FromAccountId)

	// Pre-validate from_account BEFORE marking the debt paid, so an invalid
	// from_account fails fast and the debt stays untouched. Returns fromAcc +
	// debtAcc + debtType + entryTotal so the cash-record builder can synthesize
	// the double-entry pair without a second lookup pass. Mirrors Task 5's
	// validateTradeFromAccount shape (returns both accounts from one lookup).
	fromAcc, debtAcc, debtType, entryTotal, validationErr := h.validateFromAccount(ctx, tenantID, debtID, entryID, fromAccountID)
	if validationErr != nil {
		return nil, validationErr
	}

	resp, err := h.service.RecordPayment(ctx, application.RecordPaymentRequest{
		TenantID:        tenantID,
		DebtID:          debtID,
		ScheduleEntryID: entryID,
		FromAccountID:   fromAccountID,
		CashRecord:      buildRepaymentCashRecord(tenantID, fromAcc, debtAcc, debtType, entryTotal),
	})
	if err != nil {
		return nil, mapError(err)
	}

	return &pb.RecordPaymentResponse{
		TransactionId: resp.TransactionID.String(),
		Entry:         entryToProto(resp.Entry),
	}, nil
}

// validateFromAccount reads the debt detail + from_account and enforces the
// three RecordPayment invariants (Task 3). Runs BEFORE h.service.RecordPayment
// so an invalid from_account leaves the debt untouched (fail fast).
//
// Returns fromAcc + debtAcc + debtType + entryTotal so the caller can build the
// cash-side double-entry pair (buildRepaymentCashRecord) without a second
// lookup pass — debtAcc + debtType + entryTotal were already loaded here for the
// currency + balance checks. Mirrors Task 5's validateTradeFromAccount shape.
//
//  1. from_account must be an asset account (InvalidArgument otherwise).
//  2. For BorrowedIn (repayment), from_account must have enough balance to
//     cover the TARGET schedule entry's total (FailedPrecondition otherwise).
//  3. from_account and the debt's account must share a currency
//     (InvalidArgument otherwise — cross-currency needs manual FX handling).
func (h *DebtHandler) validateFromAccount(ctx context.Context, tenantID, debtID, entryID, fromAccountID uuid.UUID) (
	fromAcc *accountdomain.Account,
	debtAcc *accountdomain.Account,
	debtType domain.DebtType,
	entryTotal int64,
	err error,
) {
	// Without a lookup wired in (e.g., a unit test missing deps) we cannot
	// validate; skip rather than block the payment. Production wires the lookup.
	// Returns nil/zero for every value the cash-record builder needs so
	// buildRepaymentCashRecord also skips (returns nil) on this path.
	if h.accountLookup == nil {
		return nil, nil, domain.DebtTypeUnspecified, 0, nil
	}

	fromAcc, err = h.accountLookup.FindByID(ctx, tenantID, fromAccountID)
	if err != nil {
		return nil, nil, domain.DebtTypeUnspecified, 0, status.Error(codes.NotFound, "from_account not found: "+err.Error())
	}
	if fromAcc.AccountType != accountdomain.AccountTypeAsset {
		return nil, nil, domain.DebtTypeUnspecified, 0, status.Error(codes.InvalidArgument, "from_account must be asset")
	}

	// Debt detail carries DebtType + AccountID + the schedule (for the entry
	// total) needed for the remaining checks.
	detail, err := h.service.GetDebt(ctx, tenantID, debtID)
	if err != nil {
		return nil, nil, domain.DebtTypeUnspecified, 0, status.Error(codes.NotFound, "debt not found: "+err.Error())
	}
	debtAcc, err = h.accountLookup.FindByID(ctx, tenantID, detail.Debt.AccountID)
	if err != nil {
		return nil, nil, domain.DebtTypeUnspecified, 0, status.Error(codes.NotFound, "debt account not found: "+err.Error())
	}
	if fromAcc.CurrencyCode != debtAcc.CurrencyCode {
		return nil, nil, domain.DebtTypeUnspecified, 0, status.Error(codes.InvalidArgument, "跨币种,需手动处理")
	}

	// BorrowedIn repayment: from_account must cover the target entry's total.
	entryTotal, ok := lookupEntryTotal(detail.Schedule, entryID)
	if !ok {
		entryTotal = 0 // unknown entry id — let the service surface NotFound
	}
	if detail.Debt.DebtType == domain.BorrowedIn && ok && fromAcc.CurrentBalanceCents < entryTotal {
		return nil, nil, domain.DebtTypeUnspecified, 0, status.Error(codes.FailedPrecondition, "from_account 余额不足")
	}

	return fromAcc, debtAcc, detail.Debt.DebtType, entryTotal, nil
}

// buildRepaymentCashRecord assembles the debt-owned cash-side transaction the
// service records atomically with schedule.Paid + principal persist (Task 6 D3
// — replaces the handler's pre-Task-6 best-effort recordPaymentTransaction).
// Returns nil when either account is nil (the skip-validation path — keeps
// perf-test/sync harnesses that pass nil accountLookup green), so the service
// skips the cash write. Entries are built by buildPaymentEntries, keyed by
// debtType. amountCents is the schedule entry total.
func buildRepaymentCashRecord(tenantID uuid.UUID, fromAcc, debtAcc *accountdomain.Account, debtType domain.DebtType, totalCents int64) *domain.RepaymentCashRecordRequest {
	if fromAcc == nil || debtAcc == nil {
		return nil
	}
	return &domain.RepaymentCashRecordRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "RecordPayment double-write",
		Entries:         buildPaymentEntries(debtType, *fromAcc, *debtAcc, totalCents),
	}
}

// lookupEntryTotal scans the schedule for the given entry id and returns its
// TotalCents. Returns ok=false if the entry is not found (the service layer
// will surface a NotFound for the unknown entry id; we skip the balance check).
func lookupEntryTotal(schedule []application.PaymentEntryDTO, entryID uuid.UUID) (int64, bool) {
	for _, e := range schedule {
		if e.ID == entryID {
			return e.TotalCents, true
		}
	}
	return 0, false
}

// (recordPaymentTransaction was deleted in Task 6 D3 — the cash-side double-
// write for repayment now lives inside the debt service's sqltx.WithTx via the
// RepaymentCashRecorder port. A failure no longer swallows; it rolls back the
// schedule.Paid/principal write.)

// buildPaymentEntries constructs the double-entry pair for a debt payment,
// keyed by DebtType. amountCents is the schedule entry total.
//
//	borrowedIn (我还债): credit from_account (asset -) + debit debt.account_id (liability -)
//	borrowedOut (我收款): debit from_account (asset +) + credit debt.account_id (receivable asset -)
//
// Each entry carries the account's ChartOfAccountCode so the transaction
// service (via the RepaymentCashRecorder adapter) can persist and route it
// correctly. Returns debt-domain RepaymentCashEntry legs (Task 6 D3) — the
// handler hands them to the service via RecordPaymentRequest.CashRecord, where
// they are recorded atomically inside the service's sqltx.WithTx.
func buildPaymentEntries(debtType domain.DebtType, fromAcc, debtAcc accountdomain.Account, amountCents int64) []domain.RepaymentCashEntry {
	if debtType == domain.BorrowedOut {
		return []domain.RepaymentCashEntry{
			{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, DebitCents: amountCents},
			{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, CreditCents: amountCents},
		}
	}
	// BorrowedIn (and Unspecified, which resolves to BorrowedIn) → repayment.
	return []domain.RepaymentCashEntry{
		{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, CreditCents: amountCents},
		{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, DebitCents: amountCents},
	}
}

// buildCreateEntries constructs the borrowedOut creation double-entry pair.
// amountCents is the lent principal (TotalPrincipalCents). It is the inverse
// of buildPaymentEntries for BorrowedOut:
//
//	credit source_account  (asset −, cash out)
//	debit  debt.account_id (asset receivable +)
//
// Each entry carries the account's ChartOfAccountCode so the transaction
// service can persist and route it correctly.
func buildCreateEntries(sourceAcc, debtAcc accountdomain.Account, amountCents int64) []transactionApp.EntryInput {
	return []transactionApp.EntryInput{
		{AccountID: sourceAcc.ID, ChartOfAccountCode: sourceAcc.ChartCode, CreditCents: amountCents},
		{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, DebitCents: amountCents},
	}
}

// GetDebt retrieves a debt with its payment schedule.
func (h *DebtHandler) GetDebt(ctx context.Context, req *pb.GetDebtRequest) (*pb.DebtDetailResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	resp, err := h.service.GetDebt(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.DebtDetailResponse{Debt: detailToProto(*resp)}, nil
}

// ListDebts returns a paginated list of debts.
func (h *DebtHandler) ListDebts(ctx context.Context, req *pb.ListDebtsRequest) (*pb.ListDebtsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	pageReq := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	// type_filter is optional: UNSPECIFIED means "all types" (no filter applied).
	var typeFilter *domain.DebtType
	if req.TypeFilter != pb.DebtType_DEBT_TYPE_UNSPECIFIED {
		t := protoToDebtType(req.TypeFilter)
		typeFilter = &t
	}

	result, err := h.service.ListDebts(ctx, application.ListDebtsRequest{
		TenantID:   tenantID,
		Page:       pageReq,
		TypeFilter: typeFilter,
	})
	if err != nil {
		return nil, mapError(err)
	}

	debts := make([]*pb.DebtDTO, len(result.Debts))
	for i, d := range result.Debts {
		debts[i] = debtToProto(d)
	}

	return &pb.ListDebtsResponse{
		Debts: debts,
		Page:  &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// GetReceivablesSummary aggregates every receivable (DebtType=BorrowedOut) for
// the caller's tenant: total/remaining/collected principal, overdue count +
// amount, pending interest, month-over-month principal/remaining trend (from
// debt_progress_snapshot rows written by the scheduler), and the globally
// earliest unpaid entry as next_payment. Replaces
// UnimplementedDebtServiceServer.GetReceivablesSummary.
//
// Per-tenant: only the caller's receivables are aggregated. The trend is Σ over
// debts that have a snapshot in BOTH this month and last month; the scheduler
// (Task 6) writes those snapshots, so the trend stays 0 until snapshots exist.
// Mirrors the goal SyncInvestmentGoals handler pattern (getTenantID → service
// call → wrap DTO in the response).
func (h *DebtHandler) GetReceivablesSummary(ctx context.Context, _ *pb.GetReceivablesSummaryRequest) (*pb.ReceivablesSummaryResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	dto, err := h.service.GetReceivablesSummary(ctx, tenantID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	return &pb.ReceivablesSummaryResponse{Summary: summaryToProto(*dto)}, nil
}

// summaryToProto maps the application ReceivablesSummaryDTO to the proto
// ReceivablesSummaryDTO. Fields map 1:1 (same names/types); this is the single
// place that translation happens so the wire stays application→proto.
func summaryToProto(s application.ReceivablesSummaryDTO) *pb.ReceivablesSummaryDTO {
	return &pb.ReceivablesSummaryDTO{
		TotalPrincipalCents:     s.TotalPrincipalCents,
		TotalRemainingCents:     s.TotalRemainingCents,
		TotalCollectedCents:     s.TotalCollectedCents,
		PendingInterestCents:    s.PendingInterestCents,
		Count:                   s.Count,
		OverdueCount:            s.OverdueCount,
		OverdueAmountCents:      s.OverdueAmountCents,
		PrincipalTrendCents:     s.PrincipalTrendCents,
		RemainingTrendCents:     s.RemainingTrendCents,
		NextPaymentDate:         s.NextPaymentDate,
		NextPaymentAmountCents:  s.NextPaymentAmountCents,
		NextPaymentCounterparty: s.NextPaymentCounterparty,
		NextPaymentPeriodNo:     s.NextPaymentPeriodNo,
		NewCountThisMonth:       s.NewCountThisMonth,
	}
}

// GetUpcomingPayments returns payments due within daysAhead.
func (h *DebtHandler) GetUpcomingPayments(ctx context.Context, req *pb.GetUpcomingPaymentsRequest) (*pb.ListDebtsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	daysAhead := int(req.DaysAhead)
	if daysAhead <= 0 {
		daysAhead = 30
	}

	result, err := h.service.GetUpcomingPayments(ctx, tenantID, daysAhead)
	if err != nil {
		return nil, mapError(err)
	}

	// Return entries as a flat list in DebtDTO format for simplicity
	debts := make([]*pb.DebtDTO, 0)
	for _, e := range result.Entries {
		debts = append(debts, &pb.DebtDTO{
			Id:        e.ID.String(),
			AccountId: e.DebtID.String(),
		})
	}

	return &pb.ListDebtsResponse{Debts: debts}, nil
}

func debtToProto(d application.DebtDTO) *pb.DebtDTO {
	p := &pb.DebtDTO{
		Id:                      d.ID.String(),
		AccountId:               d.AccountID.String(),
		Counterparty:            d.Counterparty,
		InterestRate:            d.InterestRate,
		AmortizationMethod:      methodToProto(d.AmortizationMethod),
		StartDate:               d.StartDate.Format("2006-01-02"),
		DueDate:                 d.DueDate.Format("2006-01-02"),
		TotalPrincipalCents:     d.TotalPrincipalCents,
		DebtType:                debtTypeToProto(d.DebtType),
		Subtype:                 d.Subtype,
		Contact:                 d.Contact,
		ContractRef:             d.ContractRef,
		NextPaymentDate:         d.NextPaymentDate,
		NextPaymentAmountCents:  d.NextPaymentAmountCents,
		NextPaymentPeriodNo:     d.NextPaymentPeriodNo,
		RemainingPrincipalCents: d.RemainingPrincipal,
		Version:                 d.Version,
		CreatedAt:               timestamppb.New(d.CreatedAt),
		UpdatedAt:               timestamppb.New(d.UpdatedAt),
	}
	if d.CollectionAccountID != nil {
		p.CollectionAccountId = d.CollectionAccountID.String()
	}
	return p
}

func entryToProto(e application.PaymentEntryDTO) *pb.PaymentEntryDTO {
	dto := &pb.PaymentEntryDTO{
		Id:             e.ID.String(),
		PaymentDate:    e.PaymentDate.Format("2006-01-02"),
		PrincipalCents: e.PrincipalCents,
		InterestCents:  e.InterestCents,
		TotalCents:     e.TotalCents,
		Paid:           e.Paid,
		PaidCents:      e.PaidCents,
	}
	if e.TransactionID != nil {
		dto.TransactionId = e.TransactionID.String()
	}
	return dto
}

func detailToProto(d application.DebtDetailDTO) *pb.DebtDetailDTO {
	schedule := make([]*pb.PaymentEntryDTO, len(d.Schedule))
	for i, e := range d.Schedule {
		schedule[i] = entryToProto(e)
	}
	return &pb.DebtDetailDTO{
		Debt:     debtToProto(d.Debt),
		Schedule: schedule,
	}
}

func protoToMethod(m pb.AmortizationMethod) domain.AmortizationMethod {
	switch m {
	case pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL_INTEREST:
		return domain.AmortizationEqualPrincipalInterest
	case pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL:
		return domain.AmortizationEqualPrincipal
	case pb.AmortizationMethod_AMORTIZATION_LUMP_SUM:
		return domain.AmortizationLumpSum
	default:
		return domain.AmortizationEqualPrincipalInterest
	}
}

func methodToProto(m domain.AmortizationMethod) pb.AmortizationMethod {
	switch m {
	case domain.AmortizationEqualPrincipalInterest:
		return pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL_INTEREST
	case domain.AmortizationEqualPrincipal:
		return pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL
	case domain.AmortizationLumpSum:
		return pb.AmortizationMethod_AMORTIZATION_LUMP_SUM
	default:
		return pb.AmortizationMethod_AMORTIZATION_UNSPECIFIED
	}
}

// protoToDebtType converts a proto DebtType to the domain enum.
// Mapping is NAME-BASED (not by numeric value) to avoid off-by-one bugs across
// the proto/domain boundary. UNSPECIFIED/unknown resolves to BorrowedIn, matching
// the ent column default so legacy/omitted values behave as borrowed_in.
func protoToDebtType(t pb.DebtType) domain.DebtType {
	switch t {
	case pb.DebtType_DEBT_TYPE_BORROWED_IN:
		return domain.BorrowedIn
	case pb.DebtType_DEBT_TYPE_BORROWED_OUT:
		return domain.BorrowedOut
	default: // DEBT_TYPE_UNSPECIFIED or unknown
		return domain.BorrowedIn
	}
}

// debtTypeToProto converts a domain DebtType to the proto enum.
// Mapping is NAME-BASED. Unspecified/unknown resolves to BORROWED_IN.
func debtTypeToProto(t domain.DebtType) pb.DebtType {
	switch t {
	case domain.BorrowedOut:
		return pb.DebtType_DEBT_TYPE_BORROWED_OUT
	case domain.BorrowedIn, domain.DebtTypeUnspecified:
		return pb.DebtType_DEBT_TYPE_BORROWED_IN
	default:
		return pb.DebtType_DEBT_TYPE_BORROWED_IN
	}
}

func parseDate(s string) (time.Time, error) {
	return time.Parse("2006-01-02", s)
}

func getTenantID(ctx context.Context) (uuid.UUID, error) {
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	return tenantID, err
}

func mapError(err error) error {
	msg := err.Error()
	switch {
	case contains(msg, "not found"):
		return status.Error(codes.NotFound, msg)
	case contains(msg, "invalid"), contains(msg, "must"):
		return status.Error(codes.InvalidArgument, msg)
	case contains(msg, "optimistic lock"):
		return status.Error(codes.Aborted, msg)
	default:
		return status.Error(codes.Internal, msg)
	}
}

func contains(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

var _ = time.Time{}
