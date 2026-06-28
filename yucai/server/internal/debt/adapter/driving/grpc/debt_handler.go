package grpc

import (
	"context"
	"log/slog"
	"time"

	pb "github.com/yucai/server/internal/proto/debt/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/debt/application"
	"github.com/yucai/server/internal/debt/domain"
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
	transactionSvc *transactionApp.Service     // double-write: RecordPayment will create a transaction (Task 2)
	accountLookup  transactionApp.AccountLookup // account chart_code lookup + balance validation (Task 2-3)
}

// NewDebtHandler creates a new DebtHandler.
func NewDebtHandler(service *application.Service, txnSvc *transactionApp.Service, accountLookup transactionApp.AccountLookup) *DebtHandler {
	return &DebtHandler{service: service, transactionSvc: txnSvc, accountLookup: accountLookup}
}

// CreateDebt creates a new debt with amortization schedule.
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

	resp, err := h.service.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        req.Counterparty,
		InterestRate:        req.InterestRate,
		AmortizationMethod:  protoToMethod(req.AmortizationMethod),
		StartDate:           startDate,
		DueDate:             dueDate,
		TotalPrincipalCents: req.TotalPrincipalCents,
		DebtType:            protoToDebtType(req.DebtType),
		Subtype:             req.Subtype,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.DebtResponse{Debt: debtToProto(*resp)}, nil
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

	resp, err := h.service.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:     tenantID,
		ID:           id,
		Counterparty: req.Counterparty,
		InterestRate: req.InterestRate,
		Version:      req.Version,
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
// Double-write flow (credit-card-sync Task 2):
//  1. h.service.RecordPayment marks the schedule entry paid (debt side).
//  2. The debt's DebtType + AccountID are not carried on RecordPaymentResult,
//     so we re-fetch the debt detail to drive entry construction.
//  3. Look up from_account + debt.account_id via accountLookup to get each
//     account's ChartOfAccountCode.
//  4. Build double-entry pairs by DebtType and call transactionSvc.RecordTransaction
//     so UpdateBalances adjusts both accounts.
//
// The transaction write is BEST-EFFORT: if it fails after the debt is already
// marked paid, we log (English structured) and keep the debt paid rather than
// surfacing an error to the client. Task 3 will refine failure handling.
func (h *DebtHandler) RecordPayment(ctx context.Context, req *pb.RecordPaymentRequest) (*pb.RecordPaymentResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	debtID, _ := uuid.Parse(req.DebtId)
	entryID, _ := uuid.Parse(req.ScheduleEntryId)
	fromAccountID, _ := uuid.Parse(req.FromAccountId)

	resp, err := h.service.RecordPayment(ctx, application.RecordPaymentRequest{
		TenantID:        tenantID,
		DebtID:          debtID,
		ScheduleEntryID: entryID,
		FromAccountID:   fromAccountID,
	})
	if err != nil {
		return nil, mapError(err)
	}

	// Double-write: record a balancing transaction so account balances move.
	// Failures are best-effort (debt stays paid); see function doc.
	h.recordPaymentTransaction(ctx, tenantID, debtID, fromAccountID, resp.Entry.TotalCents)

	return &pb.RecordPaymentResponse{
		TransactionId: resp.TransactionID.String(),
		Entry:         entryToProto(resp.Entry),
	}, nil
}

// recordPaymentTransaction builds double-entry pairs by DebtType and records
// them via the transaction service. It is best-effort: any failure (debt
// lookup, account lookup, or the transaction write itself) is logged with
// English structured fields and swallowed so the already-paid debt is not
// rolled back. Returns nothing — callers ignore the outcome by design.
func (h *DebtHandler) recordPaymentTransaction(ctx context.Context, tenantID, debtID, fromAccountID uuid.UUID, totalCents int64) {
	if h.transactionSvc == nil || h.accountLookup == nil {
		// Wiring incomplete (e.g., unit test without txn deps); nothing to do.
		return
	}

	// RecordPaymentResult carries neither DebtType nor the debt's AccountID,
	// so re-fetch the debt detail to drive entry construction.
	detail, err := h.service.GetDebt(ctx, tenantID, debtID)
	if err != nil {
		slog.Error("record payment double-write: debt lookup failed",
			"operation", "debt.RecordPayment.recordPaymentTransaction",
			"debt_id", debtID.String(), "error", err.Error())
		return
	}

	fromAcc, err := h.accountLookup.FindByID(ctx, tenantID, fromAccountID)
	if err != nil {
		slog.Error("record payment double-write: from_account lookup failed",
			"operation", "debt.RecordPayment.recordPaymentTransaction",
			"debt_id", debtID.String(), "from_account_id", fromAccountID.String(), "error", err.Error())
		return
	}
	debtAcc, err := h.accountLookup.FindByID(ctx, tenantID, detail.Debt.AccountID)
	if err != nil {
		slog.Error("record payment double-write: debt account lookup failed",
			"operation", "debt.RecordPayment.recordPaymentTransaction",
			"debt_id", debtID.String(), "debt_account_id", detail.Debt.AccountID.String(), "error", err.Error())
		return
	}

	entries := buildPaymentEntries(detail.Debt.DebtType, *fromAcc, *debtAcc, totalCents)
	if _, err := h.transactionSvc.RecordTransaction(ctx, transactionApp.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "RecordPayment double-write",
		Entries:         entries,
	}); err != nil {
		slog.Error("record payment double-write: transaction write failed",
			"operation", "debt.RecordPayment.recordPaymentTransaction",
			"debt_id", debtID.String(), "total_cents", totalCents, "error", err.Error())
	}
}

// buildPaymentEntries constructs the double-entry pair for a debt payment,
// keyed by DebtType. amountCents is the schedule entry total.
//
//	borrowedIn (我还债): credit from_account (asset -) + debit debt.account_id (liability -)
//	borrowedOut (我收款): debit from_account (asset +) + credit debt.account_id (receivable asset -)
//
// Each entry carries the account's ChartOfAccountCode so the transaction
// service can persist and route it correctly.
func buildPaymentEntries(debtType domain.DebtType, fromAcc, debtAcc accountdomain.Account, amountCents int64) []transactionApp.EntryInput {
	if debtType == domain.BorrowedOut {
		return []transactionApp.EntryInput{
			{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, DebitCents: amountCents},
			{AccountID: debtAcc.ID, ChartOfAccountCode: debtAcc.ChartCode, CreditCents: amountCents},
		}
	}
	// BorrowedIn (and Unspecified, which resolves to BorrowedIn) → repayment.
	return []transactionApp.EntryInput{
		{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, CreditCents: amountCents},
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
			Id:       e.ID.String(),
			AccountId: e.DebtID.String(),
		})
	}

	return &pb.ListDebtsResponse{Debts: debts}, nil
}

func debtToProto(d application.DebtDTO) *pb.DebtDTO {
	return &pb.DebtDTO{
		Id:                  d.ID.String(),
		AccountId:           d.AccountID.String(),
		Counterparty:        d.Counterparty,
		InterestRate:        d.InterestRate,
		AmortizationMethod:  methodToProto(d.AmortizationMethod),
		StartDate:           d.StartDate.Format("2006-01-02"),
		DueDate:             d.DueDate.Format("2006-01-02"),
		TotalPrincipalCents: d.TotalPrincipalCents,
		DebtType:            debtTypeToProto(d.DebtType),
		Subtype:             d.Subtype,
		RemainingPrincipalCents: d.RemainingPrincipal,
		Version:             d.Version,
		CreatedAt:           timestamppb.New(d.CreatedAt),
		UpdatedAt:           timestamppb.New(d.UpdatedAt),
	}
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
